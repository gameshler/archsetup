#!/usr/bin/env bash

# menu: Base Setup
# desc: Core packages, pacman config and fastest mirrors

. "$COMMON_SCRIPT"

set -euo pipefail

# Rank mirrors by measured download rate, preferring the country the user picks
# and widening to the worldwide pool only when that country cannot supply enough.
# reflector.service re-runs this on every boot (see enable_reflector), so the
# list follows whatever is actually fast from here today.
readonly -a REFLECTOR_BASE_ARGS=(
    --protocol https
    --age 12
    --latest 40
    --fastest 10
    --sort rate
)

# Below this many Server lines the list is too thin to keep: pacman has no
# alternate to fall back on when one mirror drops out mid-transaction. This is
# the "finite number of mirrors in a single country" case the wiki warns about.
readonly MIN_MIRRORS=5

MIRROR_COUNTRY="${MIRROR_COUNTRY:-}"
declare -a REFLECTOR_ARGS=()

build_reflector_args() {
    REFLECTOR_ARGS=("${REFLECTOR_BASE_ARGS[@]}")
    if [[ -n "$MIRROR_COUNTRY" ]]; then
        REFLECTOR_ARGS=(--country "$MIRROR_COUNTRY" "${REFLECTOR_ARGS[@]}")
    fi
}

# The name is every field but the last two, so it survives "United States" and
# "Bosnia and Herzegovina" alike. Resolving to the code matters beyond tidiness:
# reflector.conf is split on whitespace, so a name would reach the boot service
# as two broken arguments.
resolve_country() {
    awk -v want="$1" '
        BEGIN { want = tolower(want) }
        NR > 2 && NF >= 3 {
            code = $(NF - 1)
            name = $1
            for (i = 2; i <= NF - 2; i++) name = name " " $i
            if (want == tolower(code) || want == tolower(name)) {
                print toupper(code)
                exit
            }
        }
    ' <<<"$2"
}

# Ask which country to rank in, defaulting to a geo-IP guess. An empty answer is
# a deliberate "rank worldwide", not an error.
choose_country() {
    local detected="" answer="" resolved="" list="" at_eof=0

    if [[ -n "$MIRROR_COUNTRY" ]]; then
        printf "%b\n" "Using mirror country '$MIRROR_COUNTRY' from the environment."
        return 0
    fi

    # Best effort. Without the table we can still accept a bare ISO code below.
    list="$(reflector --list-countries 2>/dev/null)" || list=""

    # '|| detected=""' is required: curl -f exits non-zero on 429/5xx and, under
    # pipefail, would fail this assignment and abort the whole tab.
    detected="$(curl -fsSL --max-time 5 https://ipapi.co/country 2>/dev/null | tr -d '[:space:]')" || detected=""
    # Geo-IP can return an HTML error body; only a real ISO code may reach reflector.
    [[ "$detected" =~ ^[A-Za-z][A-Za-z]$ ]] || detected=""

    # Ask on the terminal even when this tab's stdin is redirected. Testing
    # [ -r /dev/tty ] is not enough: the node is readable but opening it fails
    # when there is no controlling terminal, so open it for real.
    if (: </dev/tty) 2>/dev/null; then
        exec 3</dev/tty
    else
        exec 3<&0
    fi

    printf "%b\n" "Which country should mirrors be ranked in?"
    printf "%b\n" "Ranking locally is usually far faster than the worldwide pool, which"
    printf "%b\n" "is why this is asked. Press Enter with no answer to rank worldwide."

    while :; do
        if [[ -n "$detected" ]]; then
            printf "%b" "Mirror country [$detected]: "
        else
            printf "%b" "Mirror country (code or name, empty for worldwide): "
        fi

        if read -r answer <&3; then
            answer="${answer:-$detected}"
        else
            # Nothing more is coming, so re-prompting would never terminate.
            answer="$detected"
            at_eof=1
        fi

        [[ -n "$answer" ]] || break

        if [[ -n "$list" ]]; then
            resolved="$(resolve_country "$answer" "$list")"
        elif [[ "$answer" =~ ^[A-Za-z][A-Za-z]$ ]]; then
            # No table to check against, so only a bare ISO code is safe to pass
            # on; a wrong one still lands in the MIN_MIRRORS fallback below.
            resolved="${answer^^}"
        else
            resolved=""
        fi

        if [[ -n "$resolved" ]]; then
            MIRROR_COUNTRY="$resolved"
            break
        fi

        if [[ -n "$list" ]]; then
            printf "%b\n" "reflector lists no country matching '$answer'. Run 'reflector --list-countries' to see the valid names and codes."
        else
            printf "%b\n" "Could not fetch the country list; enter a two-letter ISO code such as DE."
        fi

        if ((at_eof)); then
            printf "%b\n" "No terminal to re-ask on; ranking worldwide instead."
            break
        fi
    done

    exec 3<&-
}

# reflector can exit 0 and still leave an empty or near-empty file: an
# over-narrow --country, transient mirror JSON, or every candidate timing out
# all look like success from its exit status alone.
run_reflector() {
    local out="$1" count=0

    build_reflector_args
    sudo reflector --verbose "${REFLECTOR_ARGS[@]}" --save "$out" || return 1
    # '|| true': grep -c exits 1 on zero matches, which is a valid answer here.
    count="$(grep -c '^[[:space:]]*Server' "$out" || true)"
    [[ "$count" -ge "$MIN_MIRRORS" ]]
}

rank_mirrors() {
    local tmp

    # Timestamped, so a second run cannot overwrite the pristine backup with an
    # already-reflector-generated list.
    sudo cp /etc/pacman.d/mirrorlist "/etc/pacman.d/mirrorlist.bak.$(date +%Y%m%d-%H%M%S)"

    tmp="$(mktemp)"

    if [[ -n "$MIRROR_COUNTRY" ]]; then
        printf "%b\n" "Ranking mirrors in $MIRROR_COUNTRY by download rate..."
        if ! run_reflector "$tmp"; then
            printf "%b\n" "$MIRROR_COUNTRY yielded fewer than $MIN_MIRRORS usable mirrors; widening to the worldwide pool."
            # Cleared rather than just ignored for this one run: enable_reflector
            # runs next off the same variable, so leaving it set would re-narrow
            # the list on every boot to the country that just came up short.
            MIRROR_COUNTRY=""
        fi
    fi

    if [[ -z "$MIRROR_COUNTRY" ]]; then
        printf "%b\n" "Ranking mirrors worldwide by download rate..."
        if ! run_reflector "$tmp"; then
            printf "%b\n" "reflector produced no usable mirrors; keeping the existing mirrorlist."
            rm -f "$tmp"
            return 0
        fi
    fi

    sudo install -m 644 "$tmp" /etc/pacman.d/mirrorlist
    printf "%b\n" "Mirrorlist updated:"
    # '|| true': head closes the pipe early, and under pipefail grep's resulting
    # SIGPIPE would abort the tab right after a successful install.
    grep '^[[:space:]]*Server' "$tmp" | head -5 || true
    rm -f "$tmp"
}

enable_reflector() {
    # Rebuilt here so the boot service ranks over the pool that actually worked
    # above, including the case where rank_mirrors had to widen to worldwide.
    build_reflector_args

    sudo mkdir -p /etc/xdg/reflector
    # reflector.service reads its options from this file. --save must be in it,
    # or the boot run would print to stdout and never touch the mirrorlist.
    printf '%s --save /etc/pacman.d/mirrorlist\n' "${REFLECTOR_ARGS[*]}" |
        sudo tee /etc/xdg/reflector/reflector.conf >/dev/null

    # reflector.service runs on every boot; reflector.timer runs it weekly. The
    # wiki calls enabling both redundant, and "on every boot" is what we want
    # here, so enable only the service and make sure the timer is not also armed.
    # The service needs the network genuinely up, not merely configured, so the
    # NetworkManager wait unit must back network-online.target.
    sudo systemctl enable NetworkManager-wait-online.service
    sudo systemctl enable reflector.service
    sudo systemctl disable reflector.timer 2>/dev/null || true

    printf "%b\n" "reflector.service enabled — mirrors are re-ranked on every boot${MIRROR_COUNTRY:+ within $MIRROR_COUNTRY}."
}

main() {

    printf "%b\n" "Checking System Package Manager and AUR"

    sudo "$PACKAGER" -Syu --noconfirm
    printf "%b\n" "Configuring pacman"
    sudo sed -i -E \
        -e 's/^\s*#\s*(Color)/\1/' \
        -e 's/^\s*#\s*(ParallelDownloads\s*=)/\1/' \
        /etc/pacman.conf

    # Shared with system/gpu-driver.sh, which needs multilib for its lib32-*
    # packages and cannot assume this tab has already run.
    enable_multilib

    if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
        sudo sed -i '/^ParallelDownloads *=.*/a ILoveCandy' /etc/pacman.conf
    fi

    sudo "$PACKAGER" -Syyu --noconfirm

    # Must precede the package set: reflector can only speed up downloads that
    # start after it has written the mirrorlist.
    install_packages reflector curl

    choose_country
    rank_mirrors
    enable_reflector

    install_packages \
        libreoffice-fresh vlc flatpak fastfetch p7zip unzip unrar tar rsync \
        exfat-utils fuse-exfat flac jdk-openjdk gimp \
        base-devel mangohud lib32-mangohud \
        htop steam python rust git

    printf "%b\n" "Configuring MangoHud"
    mkdir -p "$HOME/.config/MangoHud" && cp /usr/share/doc/mangohud/MangoHud.conf.example "$HOME/.config/MangoHud/MangoHud.conf" || true
    config_file="$HOME/.config/MangoHud/MangoHud.conf"

    settings_to_uncomment=(
        "gpu_stats"
        "gpu_temp"
        "gpu_core_clock"
        "gpu_mem_temp"
        "gpu_mem_clock"
        "gpu_power"
        "gpu_voltage"
        "cpu_stats"
        "cpu_temp"
        "cpu_power"
        "cpu_mhz"
        "fps"
        "frametime"
        "throttling_status"
        "frame_timing"
        "text_outline"
    )

    for setting in "${settings_to_uncomment[@]}"; do
        sed -i -E "s/^\s*#\s*(${setting})(\s*(=|$))/${setting}\2/" "$config_file"
    done

    printf "%b\n" "Setup completed successfully!"

}

main
