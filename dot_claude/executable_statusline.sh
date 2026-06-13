#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin, outputs a single formatted status line.

# ---------------------------------------------------------------------------
# 1. Read stdin
# ---------------------------------------------------------------------------
input=$(cat)

# ---------------------------------------------------------------------------
# 2. ANSI color helpers — Catppuccin Mocha (truecolor)
#    Palette:
#      Blue      (0-60%)   — #89b4fa
#      Lavender  (60-70%)  — #b4befe
#      Peach     (70-80%)  — #fab387
#      Red       (80%+)    — #f38ba8
#      Overlay1  (muted)   — #7f849c  (replaces the old DIM)
# ---------------------------------------------------------------------------
RESET="\033[0m"

# Usage-load ramp (applied to ctx / 5h / 7d percentages)
GREEN="\033[38;2;166;227;161m"   # Green    0-60%
LAVENDER="\033[38;2;180;190;254m"    # Lavender 60-70%
PEACH="\033[38;2;250;179;135m"       # Peach    70-80%
SOFT_PINK="\033[38;2;243;139;168m"   # Red      80%+

# Per-segment identity colors
MAUVE="\033[38;2;203;166;247m"       # Mauve    — model name
SKY="\033[38;2;137;220;235m"         # Sky      — directory
LABEL="\033[38;2;147;153;178m"       # Overlay2 — segment labels (ctx/5h/7d)
SEP="\033[38;2;88;91;112m"           # Surface2 — separators

# ---------------------------------------------------------------------------
# 3. Parse JSON with jq
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
    CWD=$(echo "$input"   | jq -r '.workspace.current_dir // .cwd // ""')

    # Context window used percentage (pre-calculated)
    RAW_CTX=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

    # Rate limits
    FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
    SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
else
    MODEL=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | cut -d'"' -f4)
    MODEL="${MODEL:-Claude}"
    CWD=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | cut -d'"' -f4)
    RAW_CTX=""
    FIVE_H=""
    SEVEN_D=""
fi

# ---------------------------------------------------------------------------
# 4. Clamp percentage helper (integer, 0-100)
# ---------------------------------------------------------------------------
clamp_pct() {
    echo "${1:-0}" | awk '{
        v = int($1 + 0.5)
        if (v < 0)   v = 0
        if (v > 100) v = 100
        print v
    }'
}

CTX_PCT=$(clamp_pct "$RAW_CTX")

# ---------------------------------------------------------------------------
# 5. Directory basename (dimmed)
# ---------------------------------------------------------------------------
if [ -n "$CWD" ]; then
    DIRNAME="${CWD##*/}"
else
    DIRNAME="$(basename "$(pwd)")"
fi

# ---------------------------------------------------------------------------
# 6. Color + icon selector based on percentage
# ---------------------------------------------------------------------------
pick_color() {
    local pct="$1"
    if   [ "$pct" -ge 80 ]; then printf '%b' "$SOFT_PINK"
    elif [ "$pct" -ge 70 ]; then printf '%b' "$PEACH"
    elif [ "$pct" -ge 60 ]; then printf '%b' "$LAVENDER"
    else                          printf '%b' "$GREEN"
    fi
}

# ---------------------------------------------------------------------------
# 7. Progress bar builder: ◆ filled, ◇ empty, 10 blocks
# ---------------------------------------------------------------------------
make_bar() {
    local pct="$1"
    local filled=$(( pct / 10 ))
    local empty=$(( 10 - filled ))
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar="${bar}◆"; done
    for ((i=0; i<empty;  i++)); do bar="${bar}◇"; done
    echo "$bar"
}

# ---------------------------------------------------------------------------
# 8. Segment builder: bar + percentage (+ optional icon)
# ---------------------------------------------------------------------------
make_segment() {
    local label="$1"
    local pct="$2"
    local color
    color=$(pick_color "$pct")
    local bar
    bar=$(make_bar "$pct")
    printf '%b' "${LABEL}${label}${RESET} ${color}${bar} ${pct}%${RESET}"
}

# ---------------------------------------------------------------------------
# 9. Assemble the status line
# ---------------------------------------------------------------------------

# Separator
BAR_SEP="${SEP} | ${RESET}"

# Model name (mauve)
SEG_MODEL="${MAUVE}${MODEL}${RESET}"

# Directory (sky)
SEG_DIR="${SKY}${DIRNAME}${RESET}"

# Context window segment
CTX_COLOR=$(pick_color "$CTX_PCT")
CTX_BAR=$(make_bar    "$CTX_PCT")
SEG_CTX="${LABEL}ctx${RESET} ${CTX_COLOR}${CTX_BAR} ${CTX_PCT}%${RESET}"

# Build base line
LINE="${SEG_MODEL}${BAR_SEP}${SEG_DIR}${BAR_SEP}${SEG_CTX}"

# 5-hour rate limit segment (only when data present)
if [ -n "$FIVE_H" ]; then
    FH_PCT=$(clamp_pct "$FIVE_H")
    FH_COLOR=$(pick_color "$FH_PCT")
    LINE="${LINE}${BAR_SEP}${LABEL}5h${RESET} ${FH_COLOR}${FH_PCT}%${RESET}"
fi

# 7-day rate limit segment (only when data present)
if [ -n "$SEVEN_D" ]; then
    SD_PCT=$(clamp_pct "$SEVEN_D")
    SD_COLOR=$(pick_color "$SD_PCT")
    LINE="${LINE}${BAR_SEP}${LABEL}7d${RESET} ${SD_COLOR}${SD_PCT}%${RESET}"
fi

# ---------------------------------------------------------------------------
# 10. Print — printf to honour ANSI escape sequences
# ---------------------------------------------------------------------------
printf '%b\n' "$LINE"
