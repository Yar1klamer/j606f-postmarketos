#!/usr/bin/env python3
"""Порт стокового драйвера Himax HX83102E (Lenovo TB-J606F, ядро 4.19) на mainline 7.2.

Берёт файлы из orig/ (как в github.com/adazem009/kernel_lenovo_tbj606, lineage-18.1,
drivers/input/touchscreen/himax83102p) и пишет исправленные копии в out/.
Всё собирается в один модуль himax_hx83102e.ko (без debug/inspection и без kallsyms).
Запуск: python3 -I port.py
"""
import os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "orig")
DST = os.path.join(HERE, "out")

FILES = ["himax_common.c", "himax_common.h", "himax_platform.c", "himax_platform.h",
         "himax_ic_incell_core.c", "himax_ic_HX83102.c", "himax_ic_HX83102.h",
         "himax_ic_core.h", "himax_modular.h", "himax_modular_table.h",
         "himax_inspection.h", "himax_debug.h"]

text = {}


def sub(name, old, new, count=1):
    s = text[name]
    n = s.count(old)
    if n == 0 or (count and n != count):
        sys.exit(f"{name}: ожидалось {count} вхождений, найдено {n}: {old[:70]!r}")
    text[name] = s.replace(old, new)


def resub(name, pattern, new, count=1, flags=re.S):
    s, n = re.subn(pattern, lambda m: m.expand(new) if "\\1" in new else new, text[name], flags=flags)
    if n == 0 or (count and n != count):
        sys.exit(f"{name}: шаблон {pattern[:60]!r}: {n} совпадений, нужно {count}")
    text[name] = s


for f in FILES:
    with open(os.path.join(SRC, f), encoding="utf-8", errors="surrogateescape") as fh:
        text[f] = fh.read()

# --- himax_common.h: заголовки 4.19, режим DRM, поле panel follower ---
sub("himax_common.h", "#include <asm/segment.h>\n", "")
sub("himax_common.h", "#include <linux/buffer_head.h>\n", "")
sub("himax_common.h", "#include <linux/kallsyms.h>\n", "")
sub("himax_common.h", "\t#include <linux/of_gpio.h>\n",
    "\t#include <linux/of.h>\n\t#include <linux/gpio/consumer.h>\n")
# Makefile стока ставил HX_CONFIG_DRM при CONFIG_DRM=y; уведомления панели — через drm_panel_follower
sub("himax_common.h", "#undef HX_CONFIG_FB\n", "#undef HX_CONFIG_FB\n#ifndef HX_CONFIG_DRM\n#define HX_CONFIG_DRM\n#endif\n")
sub("himax_common.h", "\tstruct notifier_block fb_notif;\n",
    "\tstruct notifier_block fb_notif;\n\tstruct drm_panel_follower panel_follower;\n\tbool follower_ready;\n")

# --- himax_platform.h: журнал всегда (в стоке только с CONFIG_TOUCHSCREEN_HIMAX_DEBUG) ---
resub("himax_platform.h",
      r"#if defined\(CONFIG_TOUCHSCREEN_HIMAX_DEBUG\)\n#define D\(x\.\.\.\).*?#define DIF\(x\.\.\.\)\n#endif\n",
      "#define D(x...) pr_debug(\"[HXTP] \" x)\n#define I(x...) pr_info(\"[HXTP] \" x)\n"
      "#define W(x...) pr_warn(\"[HXTP][WARNING] \" x)\n#define E(x...) pr_err(\"[HXTP][ERROR] \" x)\n"
      "#define DIF(x...) do { if (debug_flag) pr_debug(\"[HXTP][DEBUG] \" x); } while (0)\n")

# --- himax_common.c ---
sub("himax_common.c", "#include <linux/hqsysfs.h>\n", "")
resub("himax_common.c", r"\thq_regiser_hw_info\(HWID_LCM.*?\n\thq_regiser_hw_info\(HWID_CTP.*?\n", "")
# kallsyms_lookup_name недоступен модулям с 5.7; getname_kernel/file_open_name нужны только debug/inspection
resub("himax_common.c",
      r"\tI\(\"Prepare kernel fp\\n\"\);\n\tkp_getname_kernel = .*?goto err_xfer_buff_fail;\n\t\}\n", "")
# регистрация в панели: drm_panel_follower вместо downstream drm_panel_notifier
resub("himax_common.c",
      r"#elif defined\(HX_CONFIG_DRM\)\n#if defined\(__HIMAX_MOD__\)\n\thx_msm_drm_register_client =.*?#endif\n#endif\n\tif \(ret\)",
      "#elif defined(HX_CONFIG_DRM)\n"
      "\tif (drm_is_panel_follower(ts->dev)) {\n"
      "\t\tts->panel_follower.funcs = &himax_panel_follower_funcs;\n"
      "\t\tret = drm_panel_add_follower(ts->dev, &ts->panel_follower);\n"
      "\t\t/* до этого момента события панели игнорируем (prepared при добавлении) */\n"
      "\t\tts->follower_ready = !ret;\n"
      "\t} else {\n"
      "\t\tI(\"%s: no panel in DT, suspend/resume follows nothing\\n\", __func__);\n"
      "\t}\n#endif\n\tif (ret)")
resub("himax_common.c",
      r"#elif defined\(HX_CONFIG_DRM\)\n#if defined\(__HIMAX_MOD__\)\n\thx_msm_drm_unregister_client =.*?#endif\n\tcancel_delayed_work_sync\(&ts->work_att\);",
      "#elif defined(HX_CONFIG_DRM)\n\tcancel_delayed_work_sync(&ts->work_att);\n"
      "\tif (ts->follower_ready) {\n\t\tts->follower_ready = false;\n"
      "\t\tdrm_panel_remove_follower(&ts->panel_follower);\n\t}")
# active_panel / himax_ts_check_dt не нужны
resub("himax_common.c", r"#if defined\(HX_CONFIG_DRM\)\nstatic struct drm_panel \*active_panel;\n#endif\n", "")
resub("himax_common.c", r"#if defined\(HX_CONFIG_DRM\)\nint himax_ts_check_dt\(struct device_node \*np\)\n\{.*?\n\}\n#endif\n", "")
resub("himax_common.c", r"\n\tstruct device_node \*dt = ts->dev->of_node;\n\thimax_ts_check_dt\(dt\);\n", "\n")
sub("himax_common.h", "int himax_ts_check_dt(struct device_node *np);\n", "")
# объявление ops follower (реализация в himax_platform.c)
sub("himax_common.c", "#if defined(HX_CONFIG_FB) || defined(HX_CONFIG_DRM)\nstatic void himax_fb_register",
    "#if defined(HX_CONFIG_DRM)\nextern const struct drm_panel_follower_funcs himax_panel_follower_funcs;\n#endif\n"
    "#if defined(HX_CONFIG_FB) || defined(HX_CONFIG_DRM)\nstatic void himax_fb_register")

# --- himax_platform.c ---
# GPIO из DT: of_get_named_gpio убран из 7.x; номер берём через gpiod и сразу отпускаем,
# дальше драйвер работает со старым API (CONFIG_GPIOLIB_LEGACY=y)
sub("himax_platform.c", "bool himax_screen_off = false;",
    "static int himax_dt_gpio(struct device *dev, const char *con_id)\n{\n"
    "\tstruct gpio_desc *desc = gpiod_get_optional(dev, con_id, GPIOD_ASIS);\n\tint num;\n\n"
    "\tif (IS_ERR(desc))\n\t\treturn PTR_ERR(desc);\n\tif (!desc)\n\t\treturn -ENOENT;\n"
    "\tnum = desc_to_gpio(desc);\n\tgpiod_put(desc);\n\treturn num;\n}\n\n"
    "bool himax_screen_off = false;")
for prop in ["irq", "rst", "3v3", "pon"]:
    sub("himax_platform.c", f'of_get_named_gpio(dt, "himax,{prop}-gpio", 0)',
        f'himax_dt_gpio(private_ts->dev, "himax,{prop}")')
sub("himax_platform.c", 'of_get_named_gpio(dt, "himax,lcm-rst", 0)', 'himax_dt_gpio(private_ts->dev, "himax,lcm-rst")')
# SPI API 7.x
sub("himax_platform.c", "spi->master->flags & SPI_MASTER_HALF_DUPLEX", "spi->controller->flags & SPI_CONTROLLER_HALF_DUPLEX")
sub("himax_platform.c", "\tspi->chip_select = 0;\n", "")
sub("himax_platform.c", "int himax_chip_common_remove(struct spi_device *spi)", "void himax_chip_common_remove(struct spi_device *spi)")
resub("himax_platform.c", r"(\tI\(\"%s: completed.\\n\", __func__\);\n)\n\treturn 0;\n\}", r"\1}")
sub("himax_platform.c", "\t\t.owner =\tTHIS_MODULE,\n", "")
# DRM-уведомления → drm_panel_follower: prepared = экран включён, unpreparing = выключается
resub("himax_platform.c",
      r"int himax_drm_notifier_callback\(struct notifier_block \*self,.*?\n\treturn 0;\n\}\n#endif\n",
      "static int himax_panel_prepared(struct drm_panel_follower *follower)\n{\n"
      "\tstruct himax_ts_data *ts = container_of(follower, struct himax_ts_data, panel_follower);\n\n"
      "\tts_drm_data = ts;\n\tif (!ts->follower_ready)\n\t\treturn 0;\n"
      "\tts->ts_suspend = false;\n\tqueue_work(ts->himax_drm_notify_wq, &ts->himax_drm_notify);\n"
      "\thimax_screen_off = false;\n\treturn 0;\n}\n\n"
      "static int himax_panel_unpreparing(struct drm_panel_follower *follower)\n{\n"
      "\tstruct himax_ts_data *ts = container_of(follower, struct himax_ts_data, panel_follower);\n\n"
      "\tts_drm_data = ts;\n\tif (!ts->follower_ready || !ts->initialized)\n\t\treturn 0;\n"
      "\tts->ts_suspend = true;\n\t/* синхронно: команды тачу нужно отправить, пока панель ещё питается */\n"
      "\tflush_work(&ts->himax_drm_notify);\n\thimax_common_suspend(ts->dev);\n"
      "\thimax_screen_off = true;\n\treturn 0;\n}\n\n"
      "const struct drm_panel_follower_funcs himax_panel_follower_funcs = {\n"
      "\t.panel_prepared = himax_panel_prepared,\n\t.panel_unpreparing = himax_panel_unpreparing,\n};\n#endif\n")
# один модуль: регистрация IC-части вызывается отсюда, а не своим module_init
sub("himax_platform.c", "\tspi_register_driver(&himax_common_driver);\n\n\treturn 0;\n",
    "\thimax_hx83102_register();\n\treturn spi_register_driver(&himax_common_driver);\n")
sub("himax_platform.c", "static int __init himax_common_init(void)",
    "int himax_hx83102_register(void);\nvoid himax_hx83102_unregister(void);\n\nstatic int __init himax_common_init(void)")
sub("himax_platform.c", "\tspi_unregister_driver(&himax_common_driver);\n}",
    "\tspi_unregister_driver(&himax_common_driver);\n\thimax_hx83102_unregister();\n}")
sub("himax_platform.c", "\tif (spi) {\n\t\tspi_unregister_device(spi);\n\t\tspi = NULL;\n\t}\n", "")
sub("himax_platform.c", 'MODULE_DESCRIPTION("Himax_common driver");',
    'MODULE_DESCRIPTION("Himax HX83102E touchscreen (zero-flash, SPI), port of the Lenovo TB-J606F stock driver");\n'
    'MODULE_FIRMWARE("Himax_firmware.bin");\nMODULE_DEVICE_TABLE(of, himax_match_table);')
sub("himax_platform.h", "extern int fb_notifier_callback(struct notifier_block *self,",
    "int fb_notifier_callback(struct notifier_block *self,")

# --- himax_ic_HX83102.c: без собственного module_init ---
resub("himax_ic_HX83102.c",
      r"static int __init himax_hx83102_init\(void\)\n\{.*?\nmodule_init\(himax_hx83102_init\);\nmodule_exit\(himax_hx83102_exit\);\n\nMODULE_DESCRIPTION\(\"HIMAX HX83102 touch driver\"\);\nMODULE_LICENSE\(\"GPL\"\);\n",
      "int himax_hx83102_register(void)\n{\n\treturn himax_hx83102_probe();\n}\n\n"
      "void himax_hx83102_unregister(void)\n{\n\thimax_hx83102_remove();\n}\n")

# --- ориентация: панель смонтирована на 180°, тач отдаёт координаты корпуса →
# стандартные touchscreen-inverted-x/y из DT; разрешение осей пера (иначе libinput его игнорирует);
# parent у input-устройств (иначе /devices/virtual/input) ---
sub("himax_platform.h", "struct himax_i2c_platform_data {\n\tint abs_x_min;\n",
    "struct himax_i2c_platform_data {\n\tbool invert_x;\n\tbool invert_y;\n\tint abs_x_min;\n")
sub("himax_platform.c", '\tif (of_property_read_u32(dt, "report_type", &data) == 0) {',
    '\tpdata->invert_x = of_property_read_bool(dt, "touchscreen-inverted-x");\n'
    '\tpdata->invert_y = of_property_read_bool(dt, "touchscreen-inverted-y");\n'
    '\tI(" DT:invert_x=%d invert_y=%d\\n", pdata->invert_x, pdata->invert_y);\n\n'
    '\tif (of_property_read_u32(dt, "report_type", &data) == 0) {')
sub("himax_platform.c", '\tts->input_dev->name = "himax-touchscreen";\n',
    '\tts->input_dev->name = "himax-touchscreen";\n\tts->input_dev->dev.parent = ts->dev;\n')
sub("himax_platform.c", '\tts->hx_pen_dev->name = "himax-pen";\n',
    '\tts->hx_pen_dev->name = "himax-pen";\n\tts->hx_pen_dev->dev.parent = ts->dev;\n')
sub("himax_common.c", "\t\t\tinput_report_abs(ts->input_dev, ABS_MT_POSITION_X,\n\t\t\t\t\tg_target_report_data->x[i]);\n"
    "\t\t\tinput_report_abs(ts->input_dev, ABS_MT_POSITION_Y,\n\t\t\t\t\tg_target_report_data->y[i]);\n",
    "\t\t\tinput_report_abs(ts->input_dev, ABS_MT_POSITION_X,\n\t\t\t\t\tHX_RX(ts, g_target_report_data->x[i]));\n"
    "\t\t\tinput_report_abs(ts->input_dev, ABS_MT_POSITION_Y,\n\t\t\t\t\tHX_RY(ts, g_target_report_data->y[i]));\n")
sub("himax_common.c", "\t\tinput_report_abs(ts->hx_pen_dev, ABS_X,\n\t\t\t\tg_target_report_data->p_x[0]);\n"
    "\t\tinput_report_abs(ts->hx_pen_dev, ABS_Y,\n\t\t\t\tg_target_report_data->p_y[0]);\n",
    "\t\tinput_report_abs(ts->hx_pen_dev, ABS_X,\n\t\t\t\tHX_RX(ts, g_target_report_data->p_x[0]));\n"
    "\t\tinput_report_abs(ts->hx_pen_dev, ABS_Y,\n\t\t\t\tHX_RY(ts, g_target_report_data->p_y[0]));\n")
sub("himax_common.c", "\t\tinput_report_abs(ts->hx_pen_dev, ABS_TILT_X,\n\t\t\t\tg_target_report_data->p_tilt_x[0]);\n",
    "\t\tinput_report_abs(ts->hx_pen_dev, ABS_TILT_X, ts->pdata->invert_x ?\n\t\t\t\t-g_target_report_data->p_tilt_x[0] : g_target_report_data->p_tilt_x[0]);\n")
sub("himax_common.c", "\t\tinput_report_abs(ts->hx_pen_dev, ABS_TILT_Y,\n\t\t\t\tg_target_report_data->p_tilt_y[0]);\n",
    "\t\tinput_report_abs(ts->hx_pen_dev, ABS_TILT_Y, ts->pdata->invert_y ?\n\t\t\t\t-g_target_report_data->p_tilt_y[0] : g_target_report_data->p_tilt_y[0]);\n")
sub("himax_common.c", "\tinput_set_abs_params(ts->hx_pen_dev, ABS_Y, ts->pdata->abs_y_min,\n\t\t\tts->pdata->abs_y_max, ts->pdata->abs_y_fuzz, 0);\n",
    "\tinput_set_abs_params(ts->hx_pen_dev, ABS_Y, ts->pdata->abs_y_min,\n\t\t\tts->pdata->abs_y_max, ts->pdata->abs_y_fuzz, 0);\n"
    "\t/* единиц на мм: 1200 × 2000 на 143 × 235 мм (stock qcom,mdss-pan-physical-*) */\n"
    "\tinput_abs_set_res(ts->hx_pen_dev, ABS_X, 8);\n\tinput_abs_set_res(ts->hx_pen_dev, ABS_Y, 8);\n")
sub("himax_common.h", "#define HIMAX_DRIVER_VER",
    "#define HX_RX(ts, v) ((ts)->pdata->invert_x ? (ts)->pdata->abs_x_max - (v) : (v))\n"
    "#define HX_RY(ts, v) ((ts)->pdata->invert_y ? (ts)->pdata->abs_y_max - (v) : (v))\n\n#define HIMAX_DRIVER_VER")

# spi_device_id: автозагрузка по spi:hxcommon (modalias устройства) и без предупреждения ядра
sub("himax_platform.c", "static struct spi_driver himax_common_driver = {",
    "static const struct spi_device_id himax_spi_ids[] = {\n\t{ \"hxcommon\" },\n\t{ }\n};\n"
    "MODULE_DEVICE_TABLE(spi, himax_spi_ids);\n\nstatic struct spi_driver himax_common_driver = {")
sub("himax_platform.c", "\t.probe =\thimax_chip_common_probe,", "\t.id_table =\thimax_spi_ids,\n\t.probe =\thimax_chip_common_probe,")

# --- общие изменения API 4.19 → 7.2 во всех .c ---
FOPS_MAP = {".open": ".proc_open", ".read": ".proc_read", ".write": ".proc_write",
            ".release": ".proc_release", ".llseek": ".proc_lseek"}


def fops_to_proc_ops(m):
    body = m.group(2)
    body = re.sub(r"\t\.owner = THIS_MODULE,\n", "", body)
    body = re.sub(r"(\.[a-z]+)(\s*=)", lambda f: FOPS_MAP.get(f.group(1), f.group(1)) + f.group(2), body)
    return "static const struct proc_ops " + m.group(1) + " = {" + body + "};"


for f in FILES:
    if not f.endswith(".c"):
        continue
    s = text[f]
    s = re.sub(r"static const struct file_operations (\w+) = \{(.*?)\};", fops_to_proc_ops, s, flags=re.S)
    s = re.sub(r"\bstruct timespec\b", "struct timespec64", s)
    s = s.replace("getnstimeofday(", "ktime_get_real_ts64(")
    s = s.replace("strlcpy(", "strscpy(")
    text[f] = s
sub("himax_platform.c", "\t\thrtimer_init(&ts->timer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n\t\tts->timer.function = himax_ts_timer_func;\n",
    "\t\thrtimer_setup(&ts->timer, himax_ts_timer_func, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n")

os.makedirs(DST, exist_ok=True)
for f in FILES:
    with open(os.path.join(DST, f), "w", encoding="utf-8", errors="surrogateescape") as fh:
        fh.write(text[f])
with open(os.path.join(DST, "Makefile"), "w") as fh:
    fh.write("# SPDX-License-Identifier: GPL-2.0\n"
             "ccflags-y += -DCONFIG_TOUCHSCREEN_HIMAX_INCELL -DCONFIG_TOUCHSCREEN_HIMAX_IC_HX83102\n"
             "obj-m += himax_hx83102e.o\n"
             "himax_hx83102e-y := himax_platform.o himax_common.o himax_ic_incell_core.o himax_ic_HX83102.o\n")
print("ok:", DST)
