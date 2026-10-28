#!/bin/bash
# Сборка на планшете (в chroot /mnt/root, Alpine edge): DTB для HX83102P + модули
# panel-himax-hx83102, tps65132-regulator, mm8013 под готовое ядро 7.2.3-sm61x5.
set -ex
P=http://169.254.203.202:8080
cd /build
[ -f linux.tar.gz ] || wget -q -O linux.tar.gz $P/local/linux-v7.2.3-r0.tar.gz
[ -d linux ] || tar xzf linux.tar.gz
cd linux
wget -q -O .config $P/local/config-7.2.3-sm61x5
wget -q -O /build/panel.patch $P/local/0001-drm-panel-himax-hx83102-add-Lenovo-J606F-BOE-HX83102P.patch
patch -p1 --forward < /build/panel.patch || true
for f in sm6115p-lenovo-j606f-hx83102p.dts sm6115p-lenovo-j606f-fbonly.dts; do
  wget -q -O arch/arm64/boot/dts/qcom/$f $P/local/$f
done
./scripts/config --module DRM_PANEL_HIMAX_HX83102 --module REGULATOR_TPS65132 --module FUEL_GAUGE_MM8013 --module DRM_PANEL_NOVATEK_NT36523
make LLVM=1 olddefconfig
make LLVM=1 -j8 modules_prepare
make LLVM=1 -j8 M=drivers/gpu/drm/panel CONFIG_DRM_PANEL_HIMAX_HX83102=m modules 2>&1 | tail -20
make LLVM=1 -j8 M=drivers/regulator modules 2>&1 | tail -5 || true
make LLVM=1 -j8 M=drivers/power/supply modules 2>&1 | tail -5 || true
# DTB (без -@: метки стокового оверлея подменяются «отстойником» на Mac)
for n in sm6115p-lenovo-j606f-hx83102p sm6115p-lenovo-j606f-fbonly; do
  clang -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I include -I arch/arm64/boot/dts -I arch/arm64/boot/dts/qcom -I scripts/dtc/include-prefixes \
    arch/arm64/boot/dts/qcom/$n.dts -o /build/$n.pp.dts
  dtc -I dts -O dtb -o /build/$n.dtb /build/$n.pp.dts
done
mkdir -p /build/out
find drivers/gpu/drm/panel drivers/regulator drivers/power/supply -name "*.ko" -newer .config -exec cp {} /build/out/ \;
cp /build/*.dtb /build/out/
ls -l /build/out
