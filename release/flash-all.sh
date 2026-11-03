#!/bin/sh
# postmarketOS for Lenovo Tab P11 (TB-J606F): install from fastboot.
# Writes userdata (the whole system), boot_b (kernel), erases dtbo_b and makes slot b active.
# Slot a (Android boot, dtbo, vbmeta) and all other partitions are not touched.
# Usage: ./flash-all.sh            (fastboot from PATH)
#        FASTBOOT=/path/to/fastboot ./flash-all.sh
set -e
cd "$(dirname "$0")"
FB=${FASTBOOT:-fastboot}

die() { echo; echo "ОШИБКА / ERROR: $*"; exit 1; }
var() { "$FB" getvar "$1" 2>&1 | sed -n "s/^$1: *//p" | head -n 1 | tr -d '\r'; }

command -v "$FB" >/dev/null 2>&1 || die "fastboot не найден. Установите Android platform-tools / fastboot not found"
for f in userdata.img boot.img SHA256SUMS; do
	[ -f "$f" ] || die "нет файла $f — распакуйте архив целиком / $f is missing"
done

echo "== Проверка файлов (sha256) / checking files"
if command -v sha256sum >/dev/null 2>&1; then
	sha256sum -c SHA256SUMS || die "файлы повреждены, скачайте архив заново / checksum mismatch"
else
	shasum -a 256 -c SHA256SUMS || die "файлы повреждены, скачайте архив заново / checksum mismatch"
fi

echo "== Ищу планшет в fastboot (Vol- + Power) / waiting for the tablet in fastboot"
n=0
until "$FB" devices 2>/dev/null | grep -q fastboot; do
	n=$((n + 1))
	[ $n -gt 60 ] && die "планшет не найден в режиме fastboot / no device in fastboot mode"
	sleep 1
done

[ "$(var product)" = "bengal" ] || die "это не Lenovo Tab P11 J606F (product: $(var product))"
[ "$(var unlocked)" = "yes" ] || die "загрузчик заблокирован — сначала разблокируйте / bootloader is locked"
[ -n "$(var partition-size:boot_b)" ] || die "нет раздела boot_b / no boot_b partition"
SLOT=$(var current-slot)

echo
echo "Устройство: Lenovo Tab P11 (bengal), загрузчик разблокирован, текущий слот: $SLOT"
echo
echo "ВНИМАНИЕ: раздел userdata будет стёрт ПОЛНОСТЬЮ (все данные Android пропадут)."
echo "WARNING: userdata will be ERASED completely."
if [ "$SLOT" = "b" ]; then
	echo "Сейчас активен слот b: то, что в нём загружается (Android или старая установка),"
	echo "будет заменено postmarketOS. Вернуть Android: fastboot --set-active=a (если в слоте a"
	echo "рабочий Android) или прошивка стока."
fi
printf "Продолжить? Введите YES / Type YES to continue: "
read -r answer
[ "$answer" = "YES" ] || die "отменено / cancelled"

"$FB" flash userdata userdata.img
"$FB" flash boot_b boot.img
"$FB" erase dtbo_b
"$FB" --set-active=b
"$FB" reboot

echo
echo "Готово. Первая загрузка: планшет сам перезагрузится один раз (берёт прошивки из своих разделов)."
echo "Done. On the first boot the tablet reboots once by itself (it takes its firmware from its own partitions)."
