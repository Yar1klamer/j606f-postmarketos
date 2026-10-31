#!/bin/sh
# One-time switch of an existing install to the untagged port repository that device-lenovo-j606f r18+
# ships in /usr/lib/apk/repositories.d, so a plain `apk upgrade` keeps the port up to date:
#  - drops the old "@j606f https://repo.yarnick.ru/j606f" line (or a plain copy of the URL) from /etc/apk/repositories;
#  - in /etc/apk/world drops linux-nura-qcom-sm61x5 (replaced by linux-lenovo-j606f), the @j606f tags and
#    version or file-checksum pins of the port's packages (left by `apk add <file>.apk` or test kits);
#  - runs apk update and removes the now unneeded linux-nura-qcom-sm61x5 (its files already belong to
#    linux-lenovo-j606f); the rest of the system is left for the usual `apk upgrade`.
# Backups: /etc/apk/repositories.before-j606f-<time>, /etc/apk/world.before-j606f-<time>.
set -eu

URL=https://repo.yarnick.ru/j606f
LIST=/usr/lib/apk/repositories.d/j606f.list
PORT='device-lenovo-j606f[a-z0-9-]*|linux-lenovo-j606f|firmware-lenovo-j606f|hexagonrpcd[a-z-]*'

die() { echo "j606f-repo-migrate: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root (sudo)"
grep -qx "$URL" "$LIST" 2>/dev/null || die "no $LIST: install device-lenovo-j606f r18 or newer first"
apk info -e linux-lenovo-j606f >/dev/null || die "linux-lenovo-j606f is not installed yet"

stamp=$(date +%Y%m%d-%H%M%S)
cp -p /etc/apk/repositories "/etc/apk/repositories.before-j606f-$stamp"
cp -p /etc/apk/world "/etc/apk/world.before-j606f-$stamp"

# the tagged line and a plain duplicate of the shipped list
sed -i -e "\\#^@j606f[[:space:]][[:space:]]*$URL/*[[:space:]]*\$#d" -e "\\#^$URL/*[[:space:]]*\$#d" /etc/apk/repositories
grep -q "^@j606f[[:space:]]" /etc/apk/repositories &&
	echo "j606f-repo-migrate: another @j606f line is left in /etc/apk/repositories, check it" >&2

sed -i -E \
	-e '/^linux-nura-qcom-sm61x5([@=<>~]|$)/d' \
	-e 's/@j606f//' \
	-e "s/^($PORT)[=<>~].*/\\1/" \
	/etc/apk/world

echo "repositories: $(grep -c . /etc/apk/repositories) lines + $LIST"
grep -E "^($PORT)\$" /etc/apk/world | sed 's/^/world: /'

apk update
if apk info -e linux-nura-qcom-sm61x5 >/dev/null; then
	apk del linux-nura-qcom-sm61x5
fi
apk info -e linux-nura-qcom-sm61x5 >/dev/null && die "linux-nura-qcom-sm61x5 is still installed"
echo "done; from now on: apk update && apk upgrade"
