# Lum - Lightweight User Manager

A small GUI app for managing user accounts on Linux systems.

## Why?

Certain desktop environments, such as XFCE, don't come with one. To install the one from Gnome or Plasma requires a boatload of dependencies. Lum does not.

## Building From Source

1. Clone the source `git clone https://github.com/Dvlv/lum`
2. Cd into the directory `cd lum`
3. Build with dub `dub build`
4. Execute `./lum`

### Build dependencies
- `dub`
- `dmd`

Search your package manager for `dmd`, `dub`, or a `dlang` metapackage.

#### Arch
`sudo pacman -S dlang`

#### OpenSUSE
`sudo zypper install dub dmd`

