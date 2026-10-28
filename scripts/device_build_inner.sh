#!/bin/bash
# Внутри chroot Alpine на планшете (см. device_buildenv.sh). $1 = http://MAC:8080
set -ex
P=$1
cd /build
[ -d linux ] || { wget -q -O linux.tar.gz $P/local/linux-v7.2.3-r0.tar.gz; tar xzf linux.tar.gz; rm -f linux.tar.gz; }
cd linux
if [ ! -f .j606f-prepared ]; then
  wget -q -O /build/0001.patch $P/local/0001-drm-panel-himax-hx83102-add-Lenovo-J606F-BOE-HX83102P.patch
  wget -q -O /build/0002.patch $P/local/0002-HACK-soc-qcom-match-qcom-bengalp-root-compatible.patch
  wget -q -O /build/0003.patch $P/local/0003-arm64-dts-qcom-sm6115p-lenovo-j606f-add-HX83102P-SKU.patch
  patch -p1 < /build/0001.patch
  patch -p1 < /build/0002.patch
  patch -p1 < /build/0003.patch
  wget -q -O .config $P/local/config-7.2.3-sm61x5
  ./scripts/config --module DRM_PANEL_HIMAX_HX83102 --module REGULATOR_TPS65132 --module FUEL_GAUGE_MM8013
  make LLVM=1 olddefconfig
  grep -q "CONFIG_DEBUG_INFO_BTF_MODULES=y" .config
  make LLVM=1 -j8 modules_prepare
  touch .j606f-prepared
fi
# DTS берётся из патча 0003 (включает abl-sink.dtsi); штатная сборка DTB через kbuild
make LLVM=1 qcom/sm6115p-lenovo-j606f-hx83102p.dtb
rm -rf /build/ext; mkdir -p /build/ext
cp drivers/gpu/drm/panel/panel-himax-hx83102.c drivers/regulator/tps65132-regulator.c drivers/power/supply/mm8013.c \
   drivers/soc/qcom/ubwc_config.c drivers/soc/qcom/qcom_pd_mapper.c /build/ext/
cp drivers/soc/qcom/pdr_internal.h /build/ext/ 2>/dev/null || true
printf "obj-m += panel-himax-hx83102.o tps65132-regulator.o mm8013.o ubwc_config.o qcom_pd_mapper.o\n" > /build/ext/Kbuild
make LLVM=1 -j8 M=/build/ext KBUILD_MODPOST_WARN=1 modules 2>&1 | grep -vE "undefined!|suppressed"
rm -rf /build/out; mkdir -p /build/out
cp /build/ext/*.ko /build/out/
cp arch/arm64/boot/dts/qcom/sm6115p-lenovo-j606f-hx83102p.dtb /build/out/
cd /build && tar cf /build/out.tar out
ls -l /build/out
echo INNER_DONE
