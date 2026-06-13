#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin, outputs a single formatted status line.

# ---------------------------------------------------------------------------
# 1. Read stdin
# ---------------------------------------------------------------------------
input=$(cat)

# ---------------------------------------------------------------------------
# 2. ANSI helpers
# ---------------------------------------------------------------------------
RESET="\033[0m"
DIM="\033[2m"
GREEN="\033[92m"       # bright green  (0-60%)
DIM_GREEN="\033[2;32m" # dim green     (60-70%)
YELLOW="\033[93m"      # yellow        (70-80%)
RED="\033[91m"         # red           (80-100%)

# ---------------------------------------------------------------------------
# 3. Parse JSON with jq (graceful fallback if jq absent)
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
    CWD=$(echo "$input"   | jq -r '.workspace.current_dir // .cwd // ""')
    TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // ""')
    SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')

    # Context: prefer pre-calculated used_percentage
    RAW_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

    # If not available, try deriving from token counts
    if [ -z "$RAW_PCT" ]; then
        TOTAL_INPUT=$(echo "$input" | jq -r '
            (.context_window.total_input_tokens
             // (.context_window.current_usage |
                 if . then
                     (.input_tokens // 0)
                     + (.cache_read_input_tokens // 0)
                     + (.cache_creation_input_tokens // 0)
                 else empty end)
            ) // empty')
        if [ -n "$TOTAL_INPUT" ] && [ "$TOTAL_INPUT" != "null" ]; then
            RAW_PCT=$(echo "$TOTAL_INPUT" | awk '{printf "%.2f", ($1/160000)*100}')
        fi
    fi
else
    # Fallback: crude grep-based extraction
    MODEL=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | cut -d'"' -f4)
    MODEL="${MODEL:-Claude}"
    CWD=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | cut -d'"' -f4)
    TRANSCRIPT=""
    RAW_PCT=""
fi

# If still no percentage, try reading the transcript file
if [ -z "$RAW_PCT" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    # Last message that contains token usage fields
    LAST_TOKENS=$(grep -o '"input_tokens":[0-9]*' "$TRANSCRIPT" 2>/dev/null | tail -1 | grep -o '[0-9]*')
    LAST_CACHE_READ=$(grep -o '"cache_read_input_tokens":[0-9]*' "$TRANSCRIPT" 2>/dev/null | tail -1 | grep -o '[0-9]*')
    LAST_CACHE_WRITE=$(grep -o '"cache_creation_input_tokens":[0-9]*' "$TRANSCRIPT" 2>/dev/null | tail -1 | grep -o '[0-9]*')
    T=${LAST_TOKENS:-0}
    CR=${LAST_CACHE_READ:-0}
    CW=${LAST_CACHE_WRITE:-0}
    TOTAL=$(( T + CR + CW ))
    if [ "$TOTAL" -gt 0 ]; then
        RAW_PCT=$(echo "$TOTAL" | awk '{printf "%.2f", ($1/160000)*100}')
    fi
fi

# Default to 0 if still empty
RAW_PCT="${RAW_PCT:-0}"

# Clamp to 0-100
PCT=$(echo "$RAW_PCT" | awk '{
    v = int($1 + 0.5)
    if (v < 0) v = 0
    if (v > 100) v = 100
    print v
}')

# ---------------------------------------------------------------------------
# 4. Directory basename
# ---------------------------------------------------------------------------
if [ -n "$CWD" ]; then
    DIRNAME="${CWD##*/}"
else
    DIRNAME="$(basename "$(pwd)")"
fi

# ---------------------------------------------------------------------------
# 5. Context color based on threshold
# ---------------------------------------------------------------------------
if [ "$PCT" -ge 80 ]; then
    CTX_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then
    CTX_COLOR="$YELLOW"
elif [ "$PCT" -ge 60 ]; then
    CTX_COLOR="$DIM_GREEN"
else
    CTX_COLOR="$GREEN"
fi

# ---------------------------------------------------------------------------
# 6. 10-block progress bar: ▰ filled, ▱ empty
# ---------------------------------------------------------------------------
FILLED=$(( PCT / 10 ))
EMPTY=$(( 10 - FILLED ))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR="${BAR}▰"; done
for ((i=0; i<EMPTY;  i++)); do BAR="${BAR}▱"; done

# ---------------------------------------------------------------------------
# 7. Git branch (run in CWD; silently skip if not a repo)
# ---------------------------------------------------------------------------
GIT_BRANCH=""
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    GIT_BRANCH=$(git -C "$CWD" --no-optional-locks branch --show-current 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# 8. Session elapsed time
#    Claude Code does not expose start time in JSON, so we use the transcript
#    file mtime as a proxy for session start (oldest reliable timestamp).
#    If unavailable, we fall back to a session-file-based approach.
# ---------------------------------------------------------------------------
ELAPSED=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    # macOS stat
    FILE_MTIME=$(stat -f "%m" "$TRANSCRIPT" 2>/dev/null)
    if [ -z "$FILE_MTIME" ]; then
        # GNU stat fallback
        FILE_MTIME=$(stat -c "%Y" "$TRANSCRIPT" 2>/dev/null)
    fi
    if [ -n "$FILE_MTIME" ]; then
        NOW=$(date +%s)
        SECS=$(( NOW - FILE_MTIME ))
        if [ "$SECS" -lt 0 ]; then SECS=0; fi
        H=$(( SECS / 3600 ))
        M=$(( (SECS % 3600) / 60 ))
        S=$(( SECS % 60 ))
        if [ "$H" -gt 0 ]; then
            ELAPSED=$(printf "%dh%02dm" "$H" "$M")
        else
            ELAPSED=$(printf "%dm%02ds" "$M" "$S")
        fi
    fi
fi
ELAPSED="${ELAPSED:-0m00s}"

# ---------------------------------------------------------------------------
# 9. Warning message
# ---------------------------------------------------------------------------
WARN_MSG=""
WARN_COLOR=""
if [ "$PCT" -ge 80 ]; then
    WARN_MSG="  [!!!] /handoff-prompt EXECUTE NOW"
    WARN_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then
    WARN_MSG="  [!!] /handoff-prompt - dontsleeponai.com"
    WARN_COLOR="$YELLOW"
elif [ "$PCT" -ge 60 ]; then
    WARN_MSG="  [!] HANDOFF >> dontsleeponai.com/handoff-prompt"
    WARN_COLOR="$DIM_GREEN"
fi

# ---------------------------------------------------------------------------
# 10. Assemble the status line
# ---------------------------------------------------------------------------
# Segment: model (dimmed)
SEG_MODEL="${DIM}${MODEL}${RESET}"

# Segment: directory (dimmed)
SEG_DIR="${DIM}${DIRNAME}${RESET}"

# Segment: context bar + percentage
SEG_CTX="${CTX_COLOR}${BAR} ${PCT}%${RESET}"

# Build the line
LINE="${SEG_MODEL} | ${SEG_DIR} | ${SEG_CTX}"

# Segment: git branch (if present)
if [ -n "$GIT_BRANCH" ]; then
    LINE="${LINE} | ${DIM}${GIT_BRANCH}${RESET}"
fi

# Segment: elapsed time
LINE="${LINE} | ${DIM}${ELAPSED}${RESET}"

# Append warning (if any)
if [ -n "$WARN_MSG" ]; then
    LINE="${LINE}${WARN_COLOR}${WARN_MSG}${RESET}"
fi

# ---------------------------------------------------------------------------
# 11. Print — use printf to honour escape sequences
# ---------------------------------------------------------------------------
printf '%b\n' "$LINE"
