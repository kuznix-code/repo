# Kuznix Arch package repositories

Static pacman repositories for **LH4051-DE**. Package files are published to GitHub Pages from this repository.

Base URL: <https://kuznix-code.github.io/repo/>

## Stable repositories

| Repository | Build environment |
| --- | --- |
| `kuznix-arch` | `archlinux:base-devel` |
| `kuznix-cachy` | `cachyos/cachyos` |
| `kuznix-cachy-v3` | `cachyos/cachyos-v3`, `-march=x86-64-v3` |
| `kuznix-cachy-v4` | `cachyos/cachyos`, `-march=x86-64-v4` |
| `kuznix-cachy-znver4` | `cachyos/cachyos`, `-march=znver4` |

## Development repositories

The same five `-dev` repositories are used for development builds from the `main` branch. Main builds run daily at 00:00 UTC and can also be started manually. Stable repositories are updated only by stable `vX.Y.Z` release tags on the `stable` branch.

## Automatic repository installer

Enable the correct repository automatically on CachyOS, Arch Linux, and Arch-based distributions:

```sh
curl -fsSL https://raw.githubusercontent.com/kuznix-code/repo/main/install.sh | sudo bash
```

Use `--dev` for development packages:

```sh
curl -fsSL https://raw.githubusercontent.com/kuznix-code/repo/main/install.sh | sudo bash -s -- --dev
```

The installer selects:
- CachyOS: `kuznix-cachy`
- Other Arch-based systems configured for `x86-64-v3`, `x86-64-v4`, or `znver4`: the matching `kuznix-cachy-v3`, `kuznix-cachy-v4`, or `kuznix-cachy-znver4`
- Other Arch-based systems: `kuznix-arch`

It detects explicit `-march` settings in makepkg configuration first, then checks CPU capabilities/model. It only enables the repository and refreshes package databases; it does not install LH4051-DE. Review the script before running it if you prefer to inspect installation scripts first.

## Enable a repository

Add the selected block to `/etc/pacman.conf` (replace the repository name to select another build):

```ini
[kuznix-arch]
SigLevel = Optional
Server = https://kuznix-code.github.io/repo/$repo/$arch
```

For development builds, use the matching `-dev` name and URL, for example:

```ini
[kuznix-arch-dev]
SigLevel = Optional
Server = https://kuznix-code.github.io/repo/$repo/$arch
```

Then refresh package databases and install LH4051-DE:

```sh
sudo pacman -Syu
sudo pacman -S lh4051-de
```

Choose **one** repository track for a given machine. The optimized CachyOS builds require a CPU that supports the selected target:
- `kuznix-cachy-v3`: x86-64-v3
- `kuznix-cachy-v4`: x86-64-v4
- `kuznix-cachy-znver4`: AMD Zen 4 (znver4)

The packages are currently built for `x86_64`. Repository databases and package files are unsigned; `SigLevel = Optional` permits their use without package signatures.

## Package set

Each repository contains the following split packages:

- `lh4051-de` and `lh4051-de-data`
- `lh4051-de-session` (Openbox X11)
- `lh4051-de-session-{xfwm4,marco,metacity,icewm,fluxbox}`
- `lh4051-de-session-wayland` (Labwc) and `lh4051-de-session-wayland-sway`
- `lh4051-de-sessions-{x11,wayland}-all` and `lh4051-de-sessions-all`
- `lh4051-de-updater` and `lh4051-de-bootstrap`

The package workflow in [LH4051-DE](https://github.com/kuznix-code/LH4051-DE/actions) runs development builds from `main` daily at 00:00 UTC or on manual dispatch, publishing to the `-dev` repositories. Stable builds run only for exact `vX.Y.Z` tags whose tagged commits are contained in `stable`.

## Publishing permission

The LH4051-DE repository needs a fine-grained personal access token with **Contents: Read and write** access to `kuznix-code/repo`. Save it as the repository Actions secret `REPO_TOKEN`. The default `GITHUB_TOKEN` from LH4051-DE cannot push commits to this separate repository.
