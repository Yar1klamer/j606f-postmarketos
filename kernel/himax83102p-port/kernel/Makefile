# SPDX-License-Identifier: GPL-2.0
# the vendor sources test these Kconfig symbols of their own driver tree
ccflags-y += -DCONFIG_TOUCHSCREEN_HIMAX_INCELL -DCONFIG_TOUCHSCREEN_HIMAX_IC_HX83102
obj-$(CONFIG_TOUCHSCREEN_HIMAX_HX83102E) += himax_hx83102e.o
himax_hx83102e-y := himax_platform.o himax_common.o himax_ic_incell_core.o himax_ic_HX83102.o
