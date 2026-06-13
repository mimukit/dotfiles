#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin, outputs a single formatted status line.

# ---------------------------------------------------------------------------
# 1. Read stdin
# ---------------------------------------------------------------------------
input=$(cat)

# ---------------------------------------------------------------------------
# 2. ANSI color helpers
#    Palette:
#      Soft blue  (0-60%)   — #6699cc → closest 256-color: 68
#      Lavender   (60-70%)  — #b0a4e3 → closest 256-color: 146
#      Peach      (70-80%)  — #ffb347 → closest 256-color: 215
#      Soft pink  (80%+)    — #ff9aac → closest 256-color: 211
# ---------------------------------------------------------------------------
RESET="\033[0m"
DIM="\033[2m"

SOFT_BLUE="\033[38;5;68m"    # 0-60%
LAVENDER="\033[38;5;146m"    # 60-70%
PEACH="\033[38;5;215m"       # 70-80%
SOFT_PINK="\033[38;5;211m"   # 80%+

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
    else                          printf '%b' "$SOFT_BLUE"
    fi
}

pick_icon() {
    local pct="$1"
    if   [ "$pct" -ge 80 ]; then echo "💗"
    elif [ "$pct" -ge 70 ]; then echo "🌸"
    elif [ "$pct" -ge 60 ]; then echo "💭"
    else                          echo ""
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
    local icon
    icon=$(pick_icon "$pct")
    local bar
    bar=$(make_bar "$pct")
    # Format: [icon ]bar pct%  label
    local seg
    if [ -n "$icon" ]; then
        seg="${icon} ${color}${bar} ${pct}%${RESET}"
    else
        seg="${color}${bar} ${pct}%${RESET}"
    fi
    # Prepend label in dim
    printf '%b' "${DIM}${label}${RESET} ${seg}"
}

# ---------------------------------------------------------------------------
# 9. Assemble the status line
# ---------------------------------------------------------------------------

# Dimmed model name
SEG_MODEL="${DIM}${MODEL}${RESET}"

# Dimmed directory
SEG_DIR="${DIM}${DIRNAME}${RESET}"

# Context window segment
CTX_COLOR=$(pick_color "$CTX_PCT")
CTX_ICON=$(pick_icon  "$CTX_PCT")
CTX_BAR=$(make_bar    "$CTX_PCT")
if [ -n "$CTX_ICON" ]; then
    SEG_CTX="${CTX_ICON} ${CTX_COLOR}${CTX_BAR} ${CTX_PCT}%${RESET}"
else
    SEG_CTX="${CTX_COLOR}${CTX_BAR} ${CTX_PCT}%${RESET}"
fi

# Build base line
LINE="${SEG_MODEL} | ${SEG_DIR} | ctx ${SEG_CTX}"

# 5-hour rate limit segment (only when data present)
if [ -n "$FIVE_H" ]; then
    FH_PCT=$(clamp_pct "$FIVE_H")
    FH_COLOR=$(pick_color "$FH_PCT")
    FH_ICON=$(pick_icon  "$FH_PCT")
    FH_BAR=$(make_bar    "$FH_PCT")
    if [ -n "$FH_ICON" ]; then
        SEG_5H="${FH_ICON} ${FH_COLOR}${FH_BAR} ${FH_PCT}%${RESET}"
    else
        SEG_5H="${FH_COLOR}${FH_BAR} ${FH_PCT}%${RESET}"
    fi
    LINE="${LINE} | 5h ${SEG_5H}"
fi

# 7-day rate limit segment (only when data present)
if [ -n "$SEVEN_D" ]; then
    SD_PCT=$(clamp_pct "$SEVEN_D")
    SD_COLOR=$(pick_color "$SD_PCT")
    SD_ICON=$(pick_icon  "$SD_PCT")
    SD_BAR=$(make_bar    "$SD_PCT")
    if [ -n "$SD_ICON" ]; then
        SEG_7D="${SD_ICON} ${SD_COLOR}${SD_BAR} ${SD_PCT}%${RESET}"
    else
        SEG_7D="${SD_COLOR}${SD_BAR} ${SD_PCT}%${RESET}"
    fi
    LINE="${LINE} | 7d ${SEG_7D}"
fi

# ---------------------------------------------------------------------------
# 10. Print — printf to honour ANSI escape sequences
# ---------------------------------------------------------------------------
printf '%b\n' "$LINE"
