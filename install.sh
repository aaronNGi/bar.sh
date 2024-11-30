#!/bin/sh -e

if [ "$(id -u)" = 0 ]; then
	PREFIX=${PREFIX:-/usr/local}
else
	PREFIX=${PREFIX:-$HOME/.local}
fi

[ -e "$PREFIX"/etc/bar/mods-enabled.d ] &&
	rm -rv -- "$PREFIX"/etc/bar/mods-enabled.d

mkdir -vp -- "$PREFIX"/bin "$PREFIX"/etc/bar
cp -v bar.sh "$PREFIX"/bin/

cp -rv bar.rc.example mods-available mods-enabled.d "$PREFIX"/etc/bar/

conf_dir=${XDG_CONFIG_HOME:-$HOME/.config}/bar
printf '%s\n' "Installation done" \
	"You should copy $PREFIX/etc/bar to /etc/ or to $conf_dir/"
