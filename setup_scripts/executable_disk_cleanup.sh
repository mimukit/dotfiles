#!/bin/bash

# Reclaim rebuildable macOS application, CLI, and project caches.
# Chezmoi installs this file as ~/setup_scripts/disk_cleanup.sh.

set -u

SCRIPT_NAME=${0##*/}
ASSUME_YES=false
INCLUDE_PROJECTS=true
VERBOSE=false
COLOR_MODE=auto
FAILURES=0
SKIPPED=0
REMOVED=0

if [ "${CACHE_CLEANUP_TEST_MODE:-0}" = "1" ]; then
    HOME_DIR=${CACHE_CLEANUP_HOME:-}
    case "$HOME_DIR" in
        /tmp/*|/private/tmp/*|/private/var/folders/*) ;;
        *)
            echo "Error: test mode requires CACHE_CLEANUP_HOME beneath a temporary directory." >&2
            exit 2
            ;;
    esac
else
    HOME_DIR=$HOME
fi

case "$HOME_DIR" in
    ""|"/")
        echo "Error: refusing to run with an unsafe home directory." >&2
        exit 2
        ;;
esac

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Scan rebuildable caches, print a compact estimate, and ask before cleaning.

Options:
  --yes           Clean without the confirmation prompt
  --no-projects   Skip project dependencies and generated build output
  --verbose       List every candidate and cleanup operation
  --color         Always use color, even when output is redirected
  --no-color      Never use color
  -h, --help      Show this help

Project roots default to:
  ~/Github:~/Projects:~/Herd

Override them with the colon-separated CACHE_CLEANUP_PROJECT_ROOTS variable.
OrbStack and Docker data is always report-only and is never pruned.
Automatic color is disabled when NO_COLOR is set.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --yes) ASSUME_YES=true ;;
        --no-projects) INCLUDE_PROJECTS=false ;;
        --verbose) VERBOSE=true ;;
        --color) COLOR_MODE=always ;;
        --no-color) COLOR_MODE=never ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

RESET=""
BOLD=""
DIM=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
MAGENTA=""
CYAN=""

setup_colors() {
    local use_color escape
    use_color=false

    case "$COLOR_MODE" in
        always) use_color=true ;;
        never) use_color=false ;;
        auto)
            if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] &&
                [ -z "${NO_COLOR+x}" ]; then
                use_color=true
            fi
            ;;
    esac

    if [ "$use_color" = true ]; then
        escape=$(printf '\033')
        RESET="${escape}[0m"
        BOLD="${escape}[1m"
        DIM="${escape}[2m"
        RED="${escape}[31m"
        GREEN="${escape}[32m"
        YELLOW="${escape}[33m"
        BLUE="${escape}[34m"
        MAGENTA="${escape}[35m"
        CYAN="${escape}[36m"
    fi
}

setup_colors

TMP_BASE=${TMPDIR:-/tmp}
WORK_DIR=$(mktemp -d "$TMP_BASE/cache-cleanup.XXXXXX") || exit 1
CANDIDATES="$WORK_DIR/candidates.tsv"
REGISTERED_PATHS="$WORK_DIR/paths.txt"
COMPLETED_ACTIONS="$WORK_DIR/actions.txt"
OPEN_FILES="$WORK_DIR/open-files.txt"
: > "$CANDIDATES"
: > "$REGISTERED_PATHS"
: > "$COMPLETED_ACTIONS"
: > "$OPEN_FILES"

cleanup_work_dir() {
    rm -rf "$WORK_DIR"
}
trap cleanup_work_dir EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

info() {
    printf '%s\n' "$*"
}

section() {
    printf '\n%b%s%b\n' "$BOLD$CYAN" "$*" "$RESET"
}

success() {
    printf '%b%s%b\n' "$GREEN" "$*" "$RESET"
}

warning() {
    printf '%b%s%b\n' "$YELLOW" "$*" "$RESET"
}

error() {
    printf '%b%s%b\n' "$RED" "$*" "$RESET" >&2
}

label_value() {
    printf '  %b%-24s%b %s\n' "$DIM" "$1" "$RESET" "$2"
}

verbose() {
    if [ "$VERBOSE" = true ]; then
        printf '  %b•%b %s\n' "$BLUE" "$RESET" "$*"
    fi
}

human_kb() {
    awk -v kb="$1" 'BEGIN {
        if (kb >= 1048576) printf "%.1f GiB", kb / 1048576;
        else if (kb >= 1024) printf "%.1f MiB", kb / 1024;
        else printf "%d KiB", kb;
    }'
}

display_path() {
    local path max_length left right
    path=$1
    max_length=${2:-64}

    case "$path" in
        "$HOME_DIR") path="~" ;;
        "$HOME_DIR"/*) path="~${path#"$HOME_DIR"}" ;;
    esac

    if [ "${#path}" -le "$max_length" ]; then
        printf '%s\n' "$path"
        return
    fi

    left=$((max_length / 2 - 2))
    right=$((max_length - left - 3))
    printf '%s…%s\n' "${path:0:left}" "${path:${#path}-right}"
}

output_width() {
    local width
    width=${COLUMNS:-}
    case "$width" in
        ""|*[!0-9]*) width=100 ;;
    esac
    [ "$width" -ge 72 ] || width=72
    [ "$width" -le 140 ] || width=140
    printf '%s\n' "$width"
}

compact_group() {
    case "$1" in
        "CLI/package managers") printf '%s\n' "CLI & packages" ;;
        "Application caches") printf '%s\n' "App caches" ;;
        "Application profile caches") printf '%s\n' "App profiles" ;;
        "Downloaded runtimes") printf '%s\n' "Runtimes" ;;
        "Project dependencies") printf '%s\n' "Project dependencies" ;;
        "Project build output") printf '%s\n' "Build output" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

path_kb() {
    if [ -e "$1" ] && [ ! -L "$1" ]; then
        du -sk "$1" 2>/dev/null | awk 'NR == 1 { print $1 + 0 }'
    else
        printf '0\n'
    fi
}

free_kb() {
    local volume
    volume="/System/Volumes/Data"
    if [ ! -d "$volume" ]; then
        volume="/"
    fi
    df -k "$volume" 2>/dev/null | awk 'NR == 2 { print $4 + 0 }'
}

is_registered() {
    grep -Fqx "$1" "$REGISTERED_PATHS" 2>/dev/null
}

register_candidate() {
    local group action path description process_hint kb
    group=$1
    action=$2
    path=$3
    description=$4
    process_hint=${5:-}

    [ -e "$path" ] || return 0
    [ ! -L "$path" ] || return 0
    is_registered "$path" && return 0

    kb=$(path_kb "$path")
    [ "$kb" -gt 0 ] || return 0
    printf '%s\n' "$path" >> "$REGISTERED_PATHS"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$group" "$kb" "$action" "$path" "$description" "$process_hint" >> "$CANDIDATES"
}

is_apple_cache() {
    case "${1##*/}" in
        com.apple.*|CloudKit|FamilyCircle|GameKit|GeoServices|PassKit|familycircled|storedownloadd)
            return 0
            ;;
    esac
    return 1
}

scan_cli_caches() {
    register_candidate "CLI/package managers" "brew" \
        "$HOME_DIR/Library/Caches/Homebrew" "Homebrew downloads and old package archives" "brew"
    register_candidate "CLI/package managers" "npm" \
        "$HOME_DIR/.npm" "npm package and npx cache" "npm"
    register_candidate "CLI/package managers" "pnpm" \
        "$HOME_DIR/Library/Caches/pnpm" "pnpm metadata cache and unreferenced store entries" "pnpm"
    register_candidate "CLI/package managers" "yarn" \
        "$HOME_DIR/Library/Caches/Yarn" "Yarn package cache" "yarn"
    register_candidate "CLI/package managers" "bun" \
        "$HOME_DIR/.bun/install/cache" "Bun package cache" "bun"
    register_candidate "CLI/package managers" "uv" \
        "$HOME_DIR/.cache/uv" "uv package cache" "uv"
    register_candidate "CLI/package managers" "pip" \
        "$HOME_DIR/Library/Caches/pip" "pip wheel and download cache" "pip"
    register_candidate "CLI/package managers" "composer" \
        "$HOME_DIR/Library/Caches/composer" "Composer package cache" "composer"
    register_candidate "CLI/package managers" "mise" \
        "$HOME_DIR/Library/Caches/mise" "mise metadata and download cache" "mise"
    register_candidate "CLI/package managers" "deno" \
        "$HOME_DIR/Library/Caches/deno" "Deno dependency cache" "deno"
    register_candidate "CLI/package managers" "go" \
        "$HOME_DIR/Library/Caches/go-build" "Go build and test cache" "go"
    register_candidate "CLI/package managers" "go" \
        "$HOME_DIR/go/pkg/mod" "Go module download cache" "go"

    register_candidate "CLI/package managers" "delete" \
        "$HOME_DIR/.cargo/registry/cache" "Cargo crate archives" "cargo"
    register_candidate "CLI/package managers" "delete" \
        "$HOME_DIR/.cargo/registry/src" "Cargo unpacked registry sources" "cargo"
    register_candidate "CLI/package managers" "delete" \
        "$HOME_DIR/.cargo/git/db" "Cargo Git dependency cache" "cargo"

    register_candidate "Downloaded runtimes" "delete" \
        "$HOME_DIR/.cache/codex-runtimes" "Codex runtime downloads" "codex"
    register_candidate "Downloaded runtimes" "delete" \
        "$HOME_DIR/Library/Caches/ms-playwright" "Playwright browser downloads" "playwright"
    register_candidate "Downloaded runtimes" "delete" \
        "$HOME_DIR/Library/Caches/ms-playwright-go" "Playwright for Go browser downloads" "playwright"
    register_candidate "CLI/package managers" "delete" \
        "$HOME_DIR/Library/Caches/node-gyp" "node-gyp build downloads" "node-gyp"
}

scan_third_party_cache_roots() {
    local cache_root entry
    cache_root="$HOME_DIR/Library/Caches"
    [ -d "$cache_root" ] || return 0

    for entry in "$cache_root"/*; do
        [ -e "$entry" ] || continue
        [ -d "$entry" ] || continue
        [ ! -L "$entry" ] || continue
        is_registered "$entry" && continue
        is_apple_cache "$entry" && continue
        register_candidate "Application caches" "delete" "$entry" \
            "Third-party application cache (${entry##*/})" ""
    done
}

scan_xdg_cache_root() {
    local cache_root entry
    cache_root="$HOME_DIR/.cache"
    [ -d "$cache_root" ] || return 0

    for entry in "$cache_root"/*; do
        [ -d "$entry" ] || continue
        [ ! -L "$entry" ] || continue
        is_registered "$entry" && continue
        register_candidate "CLI/package managers" "delete" "$entry" \
            "XDG-compatible CLI cache (${entry##*/})" ""
    done
}

scan_app_support_root() {
    local root process_hint path
    root=$1
    process_hint=$2
    [ -d "$root" ] || return 0

    find "$root" -maxdepth 7 -type d \
        \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" \
        -o -name "ShaderCache" -o -name "DawnCache" \
        -o -name "DawnGraphiteCache" -o -name "DawnWebGPUCache" \
        -o -name "CachedData" -o -name "CachedExtensionVSIXs" \
        -o -name "Crashpad" -o -name "CrashReports" -o -name "logs" \
        -o -name "CacheStorage" \) -print 2>/dev/null |
    while IFS= read -r path; do
        case "$path/" in
            */.git/*) continue ;;
        esac
        register_candidate "Application profile caches" "delete" "$path" \
            "Rebuildable ${path##*/}" "$process_hint"
    done
}

scan_app_profile_caches() {
    local support
    support="$HOME_DIR/Library/Application Support"

    scan_app_support_root "$support/Google/Chrome" "Google Chrome"
    scan_app_support_root "$support/Google/Chrome Beta" "Google Chrome Beta"
    scan_app_support_root "$support/Code" "Visual Studio Code"
    scan_app_support_root "$support/discord" "Discord"
    scan_app_support_root "$support/Notion" "Notion"
    scan_app_support_root "$support/orca" "Orca"
    scan_app_support_root "$support/Linear" "Linear"
    scan_app_support_root "$support/Antigravity" "Antigravity"
    scan_app_support_root "$support/Antigravity IDE" "Antigravity IDE"
    scan_app_support_root "$support/Codex" "Codex"
    scan_app_support_root "$support/com.google.GeminiMacOS" "Gemini"
    scan_app_support_root "$support/com.anthropic.claudefordesktop" "Claude"

    register_candidate "Downloaded runtimes" "delete" \
        "$support/Google/GoogleUpdater/crx_cache" "Google updater archives" "Google"
    register_candidate "Downloaded runtimes" "delete" \
        "$support/orca/speech-models" "Orca speech model downloads" "Orca"
    register_candidate "Downloaded runtimes" "delete" \
        "$support/orca/serve-sim-runtime" "Orca simulator runtime downloads" "Orca"
    register_candidate "Downloaded runtimes" "delete" \
        "$support/Zed/node/cache" "Zed Node runtime cache" "Zed"
    register_candidate "Downloaded runtimes" "delete" \
        "$support/Zed/languages" "Zed language-server downloads" "Zed"
    register_candidate "Downloaded runtimes" "delete" \
        "$support/Zed/copilot/node_modules" "Zed Copilot runtime dependencies" "Zed"
}

find_ancestor_with_file() {
    local start stop candidate name
    start=$1
    stop=$2
    shift 2

    candidate=$start
    while :; do
        for name in "$@"; do
            if [ -f "$candidate/$name" ]; then
                return 0
            fi
        done
        [ "$candidate" = "$stop" ] && break
        [ "$candidate" = "/" ] && break
        candidate=${candidate%/*}
        [ -n "$candidate" ] || candidate="/"
    done
    return 1
}

is_git_ignored_untracked_dir() {
    local path parent top relative
    path=$1
    parent=${path%/*}
    command -v git >/dev/null 2>&1 || return 1
    top=$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null) || return 1
    case "$path/" in
        "$top"/*) ;;
        *) return 1 ;;
    esac
    relative=${path#"$top"/}
    git -C "$top" check-ignore -q -- "$relative" 2>/dev/null || return 1
    if [ -n "$(git -C "$top" ls-files -- "$relative" 2>/dev/null)" ]; then
        return 1
    fi
    return 0
}

scan_project_root() {
    local root path name parent
    root=$1
    [ -d "$root" ] || return 0

    find "$root" -type d \
        \( -name node_modules -o -name vendor -o -name .venv \
        -o -name .next -o -name .nuxt -o -name .turbo \
        -o -name target -o -name dist -o -name build \) \
        -prune -print 2>/dev/null |
    while IFS= read -r path; do
        [ ! -L "$path" ] || continue
        name=${path##*/}
        parent=${path%/*}
        case "$name" in
            node_modules)
                if find_ancestor_with_file "$parent" "$root" \
                    package-lock.json npm-shrinkwrap.json pnpm-lock.yaml \
                    yarn.lock bun.lock bun.lockb; then
                    register_candidate "Project dependencies" "delete" "$path" \
                        "Lockfile-restorable JavaScript dependencies" ""
                fi
                ;;
            vendor)
                if find_ancestor_with_file "$parent" "$root" composer.lock; then
                    register_candidate "Project dependencies" "delete" "$path" \
                        "Lockfile-restorable Composer dependencies" ""
                fi
                ;;
            .venv)
                if find_ancestor_with_file "$parent" "$root" \
                    uv.lock poetry.lock Pipfile.lock; then
                    register_candidate "Project dependencies" "delete" "$path" \
                        "Lockfile-restorable Python environment" ""
                fi
                ;;
            .next|.nuxt|.turbo|target|dist|build)
                if is_git_ignored_untracked_dir "$path"; then
                    register_candidate "Project build output" "delete" "$path" \
                        "Ignored and untracked generated output" ""
                fi
                ;;
        esac
    done
}

scan_projects() {
    local roots old_ifs root
    roots=${CACHE_CLEANUP_PROJECT_ROOTS:-"$HOME_DIR/Github:$HOME_DIR/Projects:$HOME_DIR/Herd"}
    old_ifs=$IFS
    IFS=:
    for root in $roots; do
        case "$root/" in
            "$HOME_DIR"/*) scan_project_root "$root" ;;
            *) warning "Warning: skipping project root outside home: $root" ;;
        esac
    done
    IFS=$old_ifs
}

project_root_for_path() {
    local path roots old_ifs root
    path=$1
    roots=${CACHE_CLEANUP_PROJECT_ROOTS:-"$HOME_DIR/Github:$HOME_DIR/Projects:$HOME_DIR/Herd"}
    old_ifs=$IFS
    IFS=:
    for root in $roots; do
        case "$path/" in
            "$root/"*)
                IFS=$old_ifs
                printf '%s\n' "$root"
                return 0
                ;;
        esac
    done
    IFS=$old_ifs
    return 1
}

is_rebuildable_project_path() {
    local path root parent base
    path=$1
    root=$(project_root_for_path "$path") || return 1
    parent=${path%/*}
    base=${path##*/}

    [ "$path" != "$root" ] || return 1
    [ ! -L "$root" ] || return 1

    case "$base" in
        node_modules)
            find_ancestor_with_file "$parent" "$root" \
                package-lock.json npm-shrinkwrap.json pnpm-lock.yaml \
                yarn.lock bun.lock bun.lockb
            ;;
        vendor)
            find_ancestor_with_file "$parent" "$root" composer.lock
            ;;
        .venv)
            find_ancestor_with_file "$parent" "$root" \
                uv.lock poetry.lock Pipfile.lock
            ;;
        .next|.nuxt|.turbo|target|dist|build)
            is_git_ignored_untracked_dir "$path"
            ;;
        *)
            return 1
            ;;
    esac
}

report_container_storage() {
    local orb_data size status docker_summary containers images volumes
    local count shown inventory_spec inventory_label inventory_file
    local item_name item_id item_meta
    orb_data="$HOME_DIR/Library/Group Containers/HUAQ24HBR6.dev.orbstack/data"
    if [ -d "$orb_data" ]; then
        size=$(path_kb "$orb_data")
        section "Container storage · report only"
        label_value "OrbStack data" "$(human_kb "$size")"
        if [ "${CACHE_CLEANUP_TEST_MODE:-0}" != "1" ] &&
            command -v orbctl >/dev/null 2>&1; then
            status=$(orbctl status 2>/dev/null) || :
            [ -n "$status" ] || status="unavailable"
            label_value "OrbStack status" "$status"
        elif [ "${CACHE_CLEANUP_TEST_MODE:-0}" = "1" ]; then
            label_value "OrbStack status" "skipped in test mode"
        fi
        printf '  %bNo containers, images, machines, or volumes will be removed.%b\n' \
            "$DIM" "$RESET"
    fi

    if { [ -S "$HOME_DIR/.orbstack/run/docker.sock" ] ||
        { [ "${CACHE_CLEANUP_TEST_MODE:-0}" = "1" ] &&
            [ "${CACHE_CLEANUP_TEST_DOCKER_AVAILABLE:-0}" = "1" ]; }; } &&
        command -v docker >/dev/null 2>&1; then
        docker_summary="$WORK_DIR/docker-system-df.txt"
        containers="$WORK_DIR/docker-stopped-containers.tsv"
        images="$WORK_DIR/docker-dangling-images.tsv"
        volumes="$WORK_DIR/docker-unused-volumes.tsv"

        docker system df > "$docker_summary" 2>/dev/null || : > "$docker_summary"
        docker container ls -a \
            --filter status=created --filter status=exited --filter status=dead \
            --format '{{.Names}}\t{{.ID}}\t{{.Size}}' \
            > "$containers" 2>/dev/null || : > "$containers"
        docker image ls --filter dangling=true \
            --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}' \
            > "$images" 2>/dev/null || : > "$images"
        docker volume ls --filter dangling=true \
            --format '{{.Name}}\tvolume\t{{.Driver}}' \
            > "$volumes" 2>/dev/null || : > "$volumes"

        printf '\n  %bDocker disk usage%b\n' "$BOLD" "$RESET"
        if [ -s "$docker_summary" ]; then
            sed 's/^/    /' "$docker_summary"
        else
            warning "    Docker usage unavailable."
        fi

        printf '\n  %bUnused Docker resources%b\n' "$BOLD" "$RESET"
        for inventory_spec in \
            "Stopped containers:$containers" \
            "Dangling images:$images" \
            "Unused volumes:$volumes"; do
            inventory_label=${inventory_spec%%:*}
            inventory_file=${inventory_spec#*:}
            count=$(awk 'END { print NR + 0 }' "$inventory_file")
            label_value "$inventory_label" "$count"
            shown=0
            while IFS="$(printf '\t')" read -r item_name item_id item_meta; do
                [ -n "$item_name" ] || continue
                shown=$((shown + 1))
                [ "$shown" -le 5 ] || continue
                printf '    %b•%b %-28s %s %b%s%b\n' \
                    "$BLUE" "$RESET" "$(display_path "$item_name" 28)" \
                    "$item_id" "$DIM" "$item_meta" "$RESET"
            done < "$inventory_file"
            if [ "$count" -gt 5 ]; then
                printf '    %b+ %d more%b\n' "$DIM" "$((count - 5))" "$RESET"
            fi
        done

        printf '\n  %bReview these findings and remove confirmed-unused resources in the OrbStack UI.%b\n' \
            "$DIM" "$RESET"
    elif [ -d "$orb_data" ]; then
        printf '\n  %bUnused Docker resources%b\n' "$BOLD" "$RESET"
        printf '  %bUnavailable while the OrbStack Docker engine is stopped.%b\n' \
            "$DIM" "$RESET"
        printf '  %bStart OrbStack and rerun this report; it will not be started automatically.%b\n' \
            "$DIM" "$RESET"
    fi
}

print_candidates() {
    local total_kb total_count group_count group_kb group action path description
    local process_hint rank shown remaining width path_width displayed_path current_group
    total_kb=0
    total_count=0

    if [ ! -s "$CANDIDATES" ]; then
        success "No eligible rebuildable caches were found."
        return 1
    fi

    total_kb=$(awk -F '\t' '{ sum += $2 } END { print sum + 0 }' "$CANDIDATES")
    total_count=$(awk 'END { print NR + 0 }' "$CANDIDATES")

    section "Cleanup plan"
    printf '  %b%-30s %8s %11s%b\n' "$DIM" "CATEGORY" "ENTRIES" "SIZE" "$RESET"
    printf '  %b%-30s %8s %11s%b\n' "$DIM" "──────────────────────────────" \
        "────────" "───────────" "$RESET"

    awk -F '\t' '{
        count[$1]++
        size[$1] += $2
    }
    END {
        for (group in count) {
            printf "%s\t%d\t%d\n", group, count[group], size[group]
        }
    }' "$CANDIDATES" |
        sort -t "$(printf '\t')" -k3,3nr > "$WORK_DIR/groups.tsv"

    while IFS="$(printf '\t')" read -r group group_count group_kb; do
        printf '  %b%-30s%b %8d %11s\n' "$BLUE" "$group" "$RESET" \
            "$group_count" "$(human_kb "$group_kb")"
    done < "$WORK_DIR/groups.tsv"

    printf '  %b%-30s %8s %11s%b\n' "$BOLD" "TOTAL" "$total_count" \
        "$(human_kb "$total_kb")" "$RESET"

    if [ "$VERBOSE" = true ]; then
        section "All candidates"
        sort -t "$(printf '\t')" -k1,1 -k2,2nr "$CANDIDATES" > "$WORK_DIR/display.tsv"

        current_group=""
        while IFS="$(printf '\t')" read -r group kb action path description process_hint; do
            [ -n "$group" ] || continue
            if [ "$group" != "$current_group" ]; then
                printf '\n  %b%s%b\n' "$BOLD$MAGENTA" "$group" "$RESET"
                current_group=$group
            fi
            printf '    %b%9s%b  %s\n' "$GREEN" "$(human_kb "$kb")" "$RESET" \
                "$(display_path "$path" 82)"
            printf '               %b%s%b\n' "$DIM" "$description" "$RESET"
        done < "$WORK_DIR/display.tsv"
    else
        section "Largest candidates"
        sort -t "$(printf '\t')" -k2,2nr "$CANDIDATES" |
            head -n 10 > "$WORK_DIR/display.tsv"

        width=$(output_width)
        path_width=$((width - 44))
        [ "$path_width" -ge 28 ] || path_width=28
        rank=0
        shown=0
        while IFS="$(printf '\t')" read -r group kb action path description process_hint; do
            [ -n "$group" ] || continue
            rank=$((rank + 1))
            shown=$((shown + 1))
            displayed_path=$(display_path "$path" "$path_width")
            printf '  %b%2d%b  %b%9s%b  %-22s  %s\n' \
                "$DIM" "$rank" "$RESET" "$GREEN" "$(human_kb "$kb")" "$RESET" \
                "$(compact_group "$group")" "$displayed_path"
        done < "$WORK_DIR/display.tsv"

        remaining=$((total_count - shown))
        if [ "$remaining" -gt 0 ]; then
            printf '\n  %b+ %d more candidates. Use --verbose to list every path.%b\n' \
                "$DIM" "$remaining" "$RESET"
        fi
    fi

    printf '\n  %bEstimated reclaimable space:%b %b%s%b\n' \
        "$BOLD" "$RESET" "$BOLD$GREEN" "$(human_kb "$total_kb")" "$RESET"
    printf '  %bActual results can differ due to hard links, compression, and native pruning.%b\n' \
        "$DIM" "$RESET"
    return 0
}

is_safe_delete_path() {
    local path base
    path=$1
    base=${path##*/}

    [ -n "$path" ] || return 1
    [ "$path" != "/" ] || return 1
    [ "$path" != "$HOME_DIR" ] || return 1
    [ ! -L "$path" ] || return 1

    case "$path" in
        "$HOME_DIR/.npm"|\
        "$HOME_DIR/.bun/install/cache"|\
        "$HOME_DIR/.cargo/registry/cache"|\
        "$HOME_DIR/.cargo/registry/src"|\
        "$HOME_DIR/.cargo/git/db"|\
        "$HOME_DIR/go/pkg/mod")
            return 0
            ;;
    esac

    case "$path/" in
        "$HOME_DIR/Library/Caches/"?*|\
        "$HOME_DIR/.cache/"?*|\
        "$HOME_DIR/.npm/"?*|\
        "$HOME_DIR/.bun/install/cache/"?*|\
        "$HOME_DIR/.cargo/registry/cache/"?*|\
        "$HOME_DIR/.cargo/registry/src/"?*|\
        "$HOME_DIR/.cargo/git/db/"?*|\
        "$HOME_DIR/go/pkg/mod/"?*)
            return 0
            ;;
    esac

    case "$path/" in
        "$HOME_DIR/Library/Application Support/"*)
            case "$base" in
                Cache|"Code Cache"|GPUCache|ShaderCache|DawnCache|DawnGraphiteCache|\
                DawnWebGPUCache|CachedData|CachedExtensionVSIXs|Crashpad|CrashReports|\
                logs|CacheStorage|crx_cache|speech-models|serve-sim-runtime|languages|\
                node_modules)
                    return 0
                    ;;
            esac
            ;;
    esac

    if is_rebuildable_project_path "$path"; then
        return 0
    fi

    return 1
}

path_is_open() {
    local path
    path=$1
    [ -s "$OPEN_FILES" ] || return 1
    awk -v path="$path" '
        index($0, path) == 1 &&
        (length($0) == length(path) || substr($0, length(path) + 1, 1) == "/") {
            found = 1
            exit
        }
        END { exit !found }
    ' "$OPEN_FILES"
}

process_is_running() {
    local hint
    hint=$1
    [ "${CACHE_CLEANUP_TEST_MODE:-0}" != "1" ] || return 1
    [ -n "$hint" ] || return 1
    command -v pgrep >/dev/null 2>&1 || return 1
    pgrep -if "$hint" >/dev/null 2>&1
}

action_is_running() {
    case "$1" in
        brew) process_is_running '[b]rew' ;;
        npm) process_is_running '[n]pm' ;;
        pnpm) process_is_running '[p]npm' ;;
        yarn) process_is_running '[y]arn' ;;
        bun) process_is_running '[b]un' ;;
        uv) process_is_running '[u]v' ;;
        pip) process_is_running '[p]ip' ;;
        composer) process_is_running '[c]omposer' ;;
        mise) process_is_running '[m]ise' ;;
        deno) process_is_running '[d]eno' ;;
        go) process_is_running '[g]o (build|test|install|clean)' ;;
        *) return 1 ;;
    esac
}

run_native_action() {
    local action path status removed_before
    action=$1
    path=$2

    if grep -Fqx "$action" "$COMPLETED_ACTIONS"; then
        return 0
    fi

    verbose "Running native cleaner: $action"

    if [ "${CACHE_CLEANUP_TEST_MODE:-0}" = "1" ]; then
        removed_before=$REMOVED
        safe_delete "$path"
        status=$?
        REMOVED=$removed_before
        printf '%s\n' "$action" >> "$COMPLETED_ACTIONS"
        return "$status"
    fi

    case "$action" in
        brew)
            command -v brew >/dev/null 2>&1 &&
                brew cleanup --prune=all
            ;;
        npm)
            command -v npm >/dev/null 2>&1 &&
                npm cache clean --force
            ;;
        pnpm)
            command -v pnpm >/dev/null 2>&1 &&
                (cd "$HOME_DIR" && pnpm cache delete '*' && pnpm store prune)
            ;;
        yarn)
            command -v yarn >/dev/null 2>&1 &&
                yarn cache clean
            ;;
        bun)
            command -v bun >/dev/null 2>&1 &&
                bun pm cache rm
            ;;
        uv)
            command -v uv >/dev/null 2>&1 &&
                uv cache clean
            ;;
        pip)
            command -v python3 >/dev/null 2>&1 &&
                python3 -m pip cache purge
            ;;
        composer)
            command -v composer >/dev/null 2>&1 &&
                composer clear-cache --no-interaction
            ;;
        mise)
            command -v mise >/dev/null 2>&1 &&
                mise cache clear --yes
            ;;
        deno)
            command -v deno >/dev/null 2>&1 &&
                deno clean
            ;;
        go)
            command -v go >/dev/null 2>&1 &&
                go clean -cache -testcache -modcache -fuzzcache
            ;;
        *)
            return 1
            ;;
    esac
    status=$?
    printf '%s\n' "$action" >> "$COMPLETED_ACTIONS"
    return "$status"
}

safe_delete() {
    local path
    path=$1

    [ -e "$path" ] || return 0
    if ! is_safe_delete_path "$path"; then
        error "  Refused unsafe path: $path"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    if path_is_open "$path"; then
        warning "  Skipped in-use path: $path"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    verbose "Removing: $path"
    if rm -rf -- "$path"; then
        REMOVED=$((REMOVED + 1))
        return 0
    fi

    error "  Failed to remove: $path"
    FAILURES=$((FAILURES + 1))
    return 1
}

apply_candidates() {
    local group kb action path description process_hint

    while IFS="$(printf '\t')" read -r group kb action path description process_hint; do
        [ -e "$path" ] || continue

        if [ -n "$process_hint" ] && process_is_running "$process_hint"; then
            warning "  Skipped while active: $path"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        if [ "$action" = "delete" ]; then
            safe_delete "$path" || true
        else
            if action_is_running "$action"; then
                warning "  Skipped $action: a related command is running."
                SKIPPED=$((SKIPPED + 1))
            elif ! run_native_action "$action" "$path"; then
                warning "  Native cleaner failed; removing its cache path directly: $action"
                safe_delete "$path" || true
            else
                REMOVED=$((REMOVED + 1))
            fi
        fi
    done < "$CANDIDATES"
}

printf '%bDisk Cleanup%b\n' "$BOLD$CYAN" "$RESET"
printf '%bScanning rebuildable application, CLI, and project caches…%b\n' "$DIM" "$RESET"
BEFORE_FREE=$(free_kb)

scan_cli_caches
scan_xdg_cache_root
scan_third_party_cache_roots
scan_app_profile_caches
if [ "$INCLUDE_PROJECTS" = true ]; then
    scan_projects
fi

report_container_storage
if ! print_candidates; then
    exit 0
fi

if [ "$ASSUME_YES" != true ]; then
    printf '\n%bRemove the listed rebuildable caches?%b [y/N] ' "$BOLD$YELLOW" "$RESET"
    IFS= read -r reply
    case "$reply" in
        y|Y|yes|YES|Yes) ;;
        *)
            warning "Cleanup cancelled; nothing was removed."
            exit 0
            ;;
    esac
fi

section "Cleaning"
if command -v lsof >/dev/null 2>&1; then
    lsof -Fn 2>/dev/null | sed -n 's/^n//p' > "$OPEN_FILES" || :
fi
apply_candidates

AFTER_FREE=$(free_kb)
RECLAIMED=$((AFTER_FREE - BEFORE_FREE))
[ "$RECLAIMED" -ge 0 ] || RECLAIMED=0

section "Cleanup result"
label_value "Reclaimed space" "$(human_kb "$RECLAIMED")"
label_value "Completed entries" "$REMOVED"
label_value "Skipped active/in-use" "$SKIPPED"
label_value "Failures" "$FAILURES"

if [ "$FAILURES" -gt 0 ]; then
    error "Cleanup finished with errors."
    exit 1
fi

success "✓ Cleanup complete."
