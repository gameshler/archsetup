#!/usr/bin/env bash

set -euo pipefail

export FILES="$INSTALL_DIR/files"
export TABS_DIR="$INSTALL_DIR/core/tabs"
export COMMON_SCRIPT="$TABS_DIR/common-script.sh"

# SSH_PORT is deliberately not set here. The security tabs ask for it once and
# remember the answer in $SSH_PORT_FILE (core/tabs/common-script.sh), so the
# port is not published in this repo and survives INSTALL_DIR being removed on
# exit. Export it yourself to run those tabs unattended.

cleanup() {
    local status=$?

    rm -rf "$TEMP_DIR"

    if [ "$status" -eq 0 ]; then
        rm -rf "$INSTALL_DIR"
    else
        echo "Exited with status $status. Keeping $INSTALL_DIR so the run can be retried and inspected."
    fi
}

setup_display() {
    C_RESET=""
    C_DIM=""
    C_BOLD=""
    C_GREEN=""
    C_RED=""
    C_ACCENT=""
    RULE_CHAR="-"
    SEP_CHAR=">"
    COLS=80

    if command -v tput >/dev/null 2>&1; then
        COLS="$(tput cols 2>/dev/null || echo 80)"
    fi
    [ "$COLS" -ge 60 ] 2>/dev/null || COLS=80
    [ "$COLS" -le 100 ] || COLS=100

    [ -t 1 ] || return 0
    case "${TERM:-dumb}" in
    dumb | "") return 0 ;;
    esac
    command -v tput >/dev/null 2>&1 || return 0
    [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ] || return 0

    C_RESET="$(tput sgr0)"
    C_BOLD="$(tput bold)"
    C_DIM="$(tput dim 2>/dev/null || true)"
    C_GREEN="$(tput setaf 2)"
    C_RED="$(tput setaf 1)"
    C_ACCENT="$(tput setaf 6)"
}

clear_screen() {
    clear 2>/dev/null || true
}

rule() {
    local i=0 line=""
    while [ "$i" -lt "$COLS" ]; do
        line="${line}${RULE_CHAR}"
        i=$((i + 1))
    done
    printf '%s%s%s\n' "$C_DIM" "$line" "$C_RESET"
}

header() {
    rule
    printf '  %s%sarchsetup%s  %s%s%s  %s%s%s\n' \
        "$C_BOLD" "$C_ACCENT" "$C_RESET" \
        "$C_DIM" "$SEP_CHAR" "$C_RESET" \
        "$C_BOLD" "$1" "$C_RESET"
    rule
}

pause() {
    read -rp "  Press Enter to continue "
}

# Read a "# field: value" line out of a script's or .menu file's first 12 lines.
meta_field() {
    local file="$1" field="$2"
    [ -r "$file" ] || return 0
    { sed -n "1,12{s/^# *${field}: *//p;}" "$file" 2>/dev/null || true; } | head -1
}

derive_label() {
    printf '%s' "$1" | tr -- '-_' '  ' |
        awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }'
}

entry_label() {
    local path="$1" label=""

    if [[ -d "$path" ]]; then
        label="$(meta_field "$path/.menu" menu)"
    else
        label="$(meta_field "$path" menu)"
    fi

    if [ -z "$label" ]; then
        label="$(derive_label "$(basename "${path%.sh}")")"
    fi

    printf '%s' "$label"
}

entry_desc() {
    local path="$1"

    if [[ -d "$path" ]]; then
        meta_field "$path/.menu" desc
    else
        meta_field "$path" desc
    fi
}

run_tab() {
    local path="$1" label="$2"
    local status=0

    clear_screen
    header "Running  $SEP_CHAR  $label"
    printf '\n'

    bash "$path" || status=$?

    printf '\n'
    rule
    if [ "$status" -eq 0 ]; then
        printf '  %s%s%s  %s%s%s  %sfinished%s\n' \
            "$C_BOLD" "$label" "$C_RESET" \
            "$C_DIM" "$SEP_CHAR" "$C_RESET" \
            "$C_GREEN" "$C_RESET"
    else
        printf '  %s%s%s  %s%s%s  %sfailed with exit code %s%s\n' \
            "$C_BOLD" "$label" "$C_RESET" \
            "$C_DIM" "$SEP_CHAR" "$C_RESET" \
            "$C_RED" "$status" "$C_RESET"
    fi
    rule
    printf '\n'
    pause
}

draw_menu() {
    local current_dir="$1" depth="$2" crumb="$3"
    local entry label desc
    local i width avail

    clear_screen
    header "$crumb"
    printf '\n'

    ENTRIES=()
    LABELS=()
    DESCS=()

    if [ "$depth" -eq 0 ]; then
        while IFS= read -r entry; do
            ENTRIES+=("$entry")
        done < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type d | sort)
    else
        while IFS= read -r entry; do
            ENTRIES+=("$entry")
        done < <(find "$current_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type f -name "*.sh" \) | sort)
    fi

    if [ "${#ENTRIES[@]}" -eq 0 ]; then
        printf '  %sNothing here yet.%s\n\n' "$C_DIM" "$C_RESET"
    else
        width=0
        for entry in "${ENTRIES[@]}"; do
            label="$(entry_label "$entry")"
            LABELS+=("$label")
            DESCS+=("$(entry_desc "$entry")")
            [ "${#label}" -le "$width" ] || width="${#label}"
        done

        avail=$((COLS - width - 11))

        i=0
        while [ "$i" -lt "${#ENTRIES[@]}" ]; do
            label="${LABELS[$i]}"
            desc="${DESCS[$i]}"

            if [ "$avail" -lt 12 ]; then
                desc=""
            elif [ "${#desc}" -gt "$avail" ]; then
                desc="${desc:0:$((avail - 1))}..."
            fi

            printf '  %s%3d%s  %-*s  %s%s%s\n' \
                "$C_BOLD" "$((i + 1))" "$C_RESET" \
                "$width" "$label" \
                "$C_DIM" "$desc" "$C_RESET"

            i=$((i + 1))
        done
        printf '\n'
    fi

    if [ "$depth" -eq 0 ]; then
        printf '  %s  q%s  Quit\n\n' "$C_BOLD" "$C_RESET"
    else
        printf '  %s  b%s  Back      %sq%s  Quit\n\n' "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
    fi
}

choose_directory() {
    local current_dir="$TABS_DIR"
    local parent_stack=()
    local crumb_stack=()
    local crumb choice index selected n

    while true; do
        crumb="Home"
        if [ "${#crumb_stack[@]}" -gt 0 ]; then
            crumb="$(
                IFS="|"
                printf '%s' "${crumb_stack[*]}"
            )"
            crumb="${crumb//|/  $SEP_CHAR  }"
        fi

        draw_menu "$current_dir" "${#parent_stack[@]}" "$crumb"

        read -rp "  Select  $SEP_CHAR " choice || choice="q"

        case "$choice" in
        q | Q)
            clear_screen
            exit 0
            ;;
        b | B)
            n="${#parent_stack[@]}"
            if [ "$n" -gt 0 ]; then
                current_dir="${parent_stack[$((n - 1))]}"
                parent_stack=("${parent_stack[@]:0:$((n - 1))}")
                crumb_stack=("${crumb_stack[@]:0:$((n - 1))}")
            fi
            continue
            ;;
        "")
            continue
            ;;
        *[!0-9]* | 0*)
            printf '\n  %sNot a valid choice.%s\n\n' "$C_RED" "$C_RESET"
            pause
            continue
            ;;
        esac

        index=$((choice - 1))
        if [ "$index" -ge "${#ENTRIES[@]}" ]; then
            printf '\n  %sNot a valid choice.%s\n\n' "$C_RED" "$C_RESET"
            pause
            continue
        fi

        selected="${ENTRIES[$index]}"
        if [[ -d "$selected" ]]; then
            parent_stack+=("$current_dir")
            crumb_stack+=("${LABELS[$index]}")
            current_dir="$selected"
        else
            run_tab "$selected" "${LABELS[$index]}"
        fi
    done
}

main() {
    trap cleanup EXIT
    setup_display
    choose_directory
}

main
