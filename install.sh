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

# CachyOS gets its native build by default. Other Arch-based systems use an
# optimized repository only when their configured makepkg target or CPU can
# safely use it.
if [[ "$DISTRO_ID" == "cachyos" ]]; then
    REPO="kuznix-cachy"
else
    MAKEPKG_TARGET=""
    if [[ -r /etc/makepkg.conf ]]; then
        MAKEPKG_TARGET="$(grep -Eo -- '-march=(x86-64-v[34]|znver4)' /etc/makepkg.conf | head -n1 | cut -d= -f2 || true)"
    fi
    if [[ -z "$MAKEPKG_TARGET" ]] && compgen -G '/etc/makepkg.conf.d/*.conf' >/dev/null; then
        MAKEPKG_TARGET="$(grep -hEo -- '-march=(x86-64-v[34]|znver4)' /etc/makepkg.conf.d/*.conf 2>/dev/null | head -n1 | cut -d= -f2 || true)"
    fi

    MODEL="$(grep -m1 -E '^model name[[:space:]]*:' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//' || true)"
    FLAGS="$(grep -m1 -E '^(flags|Features)[[:space:]]*:' /proc/cpuinfo 2>/dev/null || true)"

    if [[ -z "$MAKEPKG_TARGET" ]]; then
        if [[ "$MODEL" =~ (AMD[[:space:]]+EPYC[[:space:]]+9[0-9]{3}|AMD[[:space:]]+Ryzen[[:space:]]+[3579][[:space:]]+(7[0-9]{3}|704[05]|804[05])|AMD[[:space:]]+Ryzen[[:space:]]+Threadripper[[:space:]]+7[0-9]{3}) ]]; then
            MAKEPKG_TARGET="znver4"
        elif [[ "$FLAGS" == *avx512f* && "$FLAGS" == *avx512bw* && "$FLAGS" == *avx512cd* && "$FLAGS" == *avx512dq* && "$FLAGS" == *avx512vl* ]]; then
            MAKEPKG_TARGET="x86-64-v4"
        elif [[ "$FLAGS" == *avx2* && "$FLAGS" == *bmi1* && "$FLAGS" == *bmi2* && "$FLAGS" == *fma* && "$FLAGS" == *lzcnt* && "$FLAGS" == *movbe* && "$FLAGS" == *xsave* ]]; then
            MAKEPKG_TARGET="x86-64-v3"
        fi
    fi

    case "$MAKEPKG_TARGET" in
        x86-64-v3) REPO="kuznix-cachy-v3" ;;
        x86-64-v4) REPO="kuznix-cachy-v4" ;;
        znver4) REPO="kuznix-cachy-znver4" ;;
        *) REPO="kuznix-arch" ;;
    esac
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
Server = $BASE_URL/\$repo/\$arch
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
