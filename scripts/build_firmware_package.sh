#!/usr/bin/env bash
# Собрать персональный firmware-lenovo-j606f-1.tar из архивов collect_firmware.sh.
# Использование: bash scripts/build_firmware_package.sh FIRMWARE/<дата> [выходной.tar]
# Все исходники и результат — проприетарные файлы ВАШЕГО устройства: не публикуйте их.
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ $# -ge 1 ] && [ $# -le 2 ] || {
	echo "использование: bash $0 FIRMWARE/<дата> [выходной.tar]" >&2
	exit 2
}
COLLECTION=$1
OUT=${2:-"$COLLECTION/firmware-lenovo-j606f-1.tar"}
[ -d "$COLLECTION" ] || { echo "каталог не найден: $COLLECTION" >&2; exit 1; }
command -v python3 >/dev/null || { echo "нужен python3" >&2; exit 1; }
[ -f "$SCRIPT_DIR/pil_squash.py" ] || { echo "не найден $SCRIPT_DIR/pil_squash.py" >&2; exit 1; }

# временный каталог — вне каталога с архивами (это может быть бэкап, туда не пишем)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/j606f-firmware.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
for archive in vendor_firmware_mnt vendor_firmware vendor_bt_firmware; do
	[ -s "$COLLECTION/$archive.tar" ] || { echo "нет архива: $COLLECTION/$archive.tar" >&2; exit 1; }
	tar --no-same-owner --no-same-permissions -xf "$COLLECTION/$archive.tar" -C "$WORK"
	# В стоковых tar каталоги могут быть read-only; сразу делаем их writable.
	chmod -R u+rwX "$WORK"
done

DEST="$WORK/package/qcom/sm6115/LENOVO/J606F"
mkdir -p "$DEST" "$WORK/package/qca"

squash() {
	name=$1
	source_dir=$2
	[ -f "$source_dir/$name.mdt" ] || { echo "нет исходника: $source_dir/$name.mdt" >&2; exit 1; }
	python3 -B "$SCRIPT_DIR/pil_squash.py" "$DEST/$name.mbn" "$source_dir/$name.mdt"
	[ -s "$DEST/$name.mbn" ] || { echo "пустой результат: $DEST/$name.mbn" >&2; exit 1; }
}

for name in adsp cdsp modem venus; do
	squash "$name" "$WORK/image"
done
squash a610_zap "$WORK"
[ -s "$WORK/image/wlanmdsp.mbn" ] || { echo "нет image/wlanmdsp.mbn" >&2; exit 1; }
cp "$WORK/image/wlanmdsp.mbn" "$DEST/wlanmdsp.mbn"

for name in crbtfw21.tlv crnv21.bin; do
	[ -s "$WORK/image/$name" ] || { echo "нет image/$name" >&2; exit 1; }
	cp "$WORK/image/$name" "$WORK/package/qca/$name"
done
for name in Himax_firmware.bin Himax_mpfw.bin; do
	[ -s "$WORK/$name" ] || { echo "нет $name" >&2; exit 1; }
	cp "$WORK/$name" "$WORK/package/$name"
done
# настройки усилителей динамиков AW88258 (/vendor/firmware/awinic), старый формат acf: 08 f9 15 0a
EXTRA=""
if [ -s "$WORK/awinic/aw882xx_acf.bin" ]; then
	[ "$(od -An -tx1 -N4 "$WORK/awinic/aw882xx_acf.bin" | tr -d ' \n')" = "08f9150a" ] ||
		{ echo "awinic/aw882xx_acf.bin неизвестного формата" >&2; exit 1; }
	mkdir -p "$WORK/package/awinic"
	cp "$WORK/awinic/aw882xx_acf.bin" "$WORK/package/awinic/aw882xx_acf.bin"
	EXTRA=awinic
else
	echo "предупреждение: нет awinic/aw882xx_acf.bin, динамики возьмут его только с vendor" >&2
fi

mkdir -p "$(dirname -- "$OUT")"
# владелец root, без macOS-метаданных (._*, xattr) и имени пользователя сборщика
if tar --version 2>/dev/null | grep -q "GNU tar"; then
	TAR_OWNER="--owner=0 --group=0 --numeric-owner"
else
	TAR_OWNER="--uid 0 --gid 0 --uname root --gname root"
fi
# shellcheck disable=SC2086
COPYFILE_DISABLE=1 tar $TAR_OWNER -cf "$OUT" -C "$WORK/package" qcom qca Himax_firmware.bin Himax_mpfw.bin $EXTRA
for path in \
	qcom/sm6115/LENOVO/J606F/a610_zap.mbn \
	qcom/sm6115/LENOVO/J606F/adsp.mbn \
	qcom/sm6115/LENOVO/J606F/cdsp.mbn \
	qcom/sm6115/LENOVO/J606F/modem.mbn \
	qcom/sm6115/LENOVO/J606F/venus.mbn \
	qcom/sm6115/LENOVO/J606F/wlanmdsp.mbn \
	qca/crbtfw21.tlv qca/crnv21.bin Himax_firmware.bin Himax_mpfw.bin; do
	tar -tf "$OUT" | grep -Fxq "$path" || { echo "в пакете отсутствует $path" >&2; exit 1; }
done

if command -v shasum >/dev/null; then
	shasum -a 256 "$OUT"
else
	sha256sum "$OUT"
fi
printf 'готово: %s\n' "$OUT"
printf '%s\n' 'Это персональная проприетарная firmware: не публикуйте её.'
