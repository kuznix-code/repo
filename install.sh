#!/usr/bin/env bash
# Enable the appropriate Kuznix pacman repository.
set -euo pipefail

BASE_URL="https://kuznix-code.github.io/repo"
CONFIG="/etc/pacman.conf"
DEV=0

usage() {
    cat <<'EOF'
Usage: install.sh [--dev] [--stable] [--help]

Enable the matching Kuznix Arch package repository.
  --dev      Use the development repository (default: stable)
  --stable   Use the stable repository
  --help     Show this help
EOF
}

while (($#)); do
    case "$1" in
        --dev) DEV=1 ;;
        --stable) DEV=0 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if (( EUID != 0 )); then
    echo "Run this installer as root (for example, curl ... | sudo bash)." >&2
    exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
    echo "This installer supports Arch Linux and Arch-based distributions with pacman." >&2
    exit 1
fi
if [[ ! -r /etc/os-release ]]; then
    echo "Cannot identify this distribution: /etc/os-release is missing." >&2
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

case "$(uname -m)" in
    x86_64) ;;
    *) echo "Kuznix repositories currently provide x86_64 packages only." >&2; exit 1 ;;
esac

DISTRO_ID="${ID,,}"
DISTRO_LIKE="${ID_LIKE,,}"
if [[ "$DISTRO_ID" != "cachyos" && "$DISTRO_ID" != "arch" && " $DISTRO_LIKE " != *" arch "* ]]; then
    echo "Unsupported distribution: ${PRETTY_NAME:-$DISTRO_ID}. Expected Arch Linux, CachyOS, or an Arch-based distribution." >&2
    exit 1
fi

# Detect the active CachyOS repository variant from pacman.conf.
# This follows the variant the system actually uses (for example cachyos-v3),
# rather than guessing from the CPU or makepkg compiler flags.
if [[ "$DISTRO_ID" == "cachyos" ]]; then
    REPO="kuznix-cachy"
    if grep -Eq '^[[:space:]]*\\[cachyos-v4\\][[:space:]]*$' "$CONFIG"; then
        REPO="kuznix-cachy-v4"
    elif grep -Eq '^[[:space:]]*\\[cachyos-v3\\][[:space:]]*$' "$CONFIG"; then
        REPO="kuznix-cachy-v3"
    elif grep -Eq '^[[:space:]]*\\[cachyos-znver4\\][[:space:]]*$' "$CONFIG"; then
        REPO="kuznix-cachy-znver4"
    fi
else
    REPO="kuznix-arch"
fi

if (( DEV )); then
    REPO="${REPO}-dev"
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
# Remove the previous installer-managed block, if present, so reruns or
# switching repository tracks never leave duplicate active Kuznix entries.
awk '
    /^# BEGIN KUZNIX REPOSITORY$/ { skip=1; next }
    /^# END KUZNIX REPOSITORY$/ { skip=0; next }
    !skip { print }
' "$CONFIG" > "$TMP"
cat >> "$TMP" <<EOF

# BEGIN KUZNIX REPOSITORY
[$REPO]
SigLevel = Optional
Server = $BASE_URL/$REPO/x86_64
# END KUZNIX REPOSITORY
EOF
install -m 0644 "$TMP" "$CONFIG"
trap - EXIT
rm -f "$TMP"

echo "Enabled [$REPO] in $CONFIG"
echo "Refreshing pacman repository databases..."
pacman -Syy
echo
echo "Repository ready. Update your system with: pacman -Syu"
echo "Install LH4051-DE with: pacman -S lh4051-de-meta"
