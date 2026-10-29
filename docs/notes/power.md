# Питание, батарея, зарядка, Type-C

## Факты (root, 2026-10-28)
- PMIC: pm6125 (SPMI sid 0), pmi632 (sid 2/3), pm2250 (аудио-кодек rouleur).
- Батарея: Li-ion, **CHARGE_FULL_DESIGN = 7518000 мкАч (7518 мАч)**.
- power_supply «battery» берёт напряжение и ток с **mm8013** (I2C0 0x55, совпадают 4353 мВ / −259 мА); «bms» = Qualcomm QG (pmi632 qpnp-qg, в dmesg `QG-K`).
- Зарядник: pmi632 qpnp-smb5 (typec port0 тоже там). Параллельный зарядник **smb1355** (power_supply «parallel», model_name smb1355; I2C1 0x0c `qcom,i2c-pmic` с драйвером i2c_pmic; I2C1 0x09 без драйвера).
- Type-C: в стоке typec-класс от pmi632 smb5. На I2C0 есть fusb302 (0x22, драйвер привязан) и rt1711h (0x4e, драйвер не привязан, видимо альт. SKU), irq у обоих tlmm gpio 97.
- fsa4480 (I2C1 0x42): аудиосвитч USB-C.
- Vbus для pogo: dock_pogo (usb_vbus gpio 38, charge_enable gpio 74, dock_status gpio 67, usb_charge_status gpio 66, mcu_switch gpio 41, mcu_reset gpio 48).

## Mainline v7.2.3
- mm8013: есть (`mitsumi,mm8013`, drivers/power/supply/mm8013.c). Стоковый compatible `qcom,mm8013` поменять на `mitsumi,mm8013`.
- pmi632: есть pmi632.dtsi (typec `qcom,pmi632-typec`, vbus-reg, adc5, adc-tm5, gpio, lpg, vib).
- Зарядник pmi632: **драйвера нет** (qcom_smbx знает только pm660 и pmi8998). Зарядка без драйвера, скорее всего, идёт на аппаратных дефолтах (проверить: ток и напряжение при подключённом USB).
- smb1355: драйвера нет.
- fusb302: драйвер есть (tcpm/fusb302.c). Но в стоке typec обслуживает pmi632. Что подключено к CC-линиям, выяснить.

## Статус (29.10)
- mm8013: работает (100%, 4.39 В, 328 циклов); в pmOS грузится через modules-load (device r3+). Патч 0005 (ядро r105): знак current_now по ABI, связь с зарядником, Li-ion — UPower/Plasma показывают заряд/разряд верно.
- Зарядка идёт на настройках загрузчика (FCC 3 А, FV 4.40 В); драйвер зарядника pmi632 только на чтение (патч 0004, ниже). Thermal-троттлинг CPU подключён (тест 9).

## Thermal в mainline (2026-10-29)
- Зоны cpu*-thermal: trip 90 °C passive, 95 °C passive, 110 °C critical (выключение); gpu-thermal: 85 °C passive, 110 °C critical; прочие 115/125 °C.
- Cooling-устройства: только ath10k_thermal и devfreq-5900000.gpu. **CPU cooling (cpufreq) не зарегистрирован** → Linux не троттлит CPU по температуре (остаётся аппаратный LMH/OSM). ~~TODO~~ **Сделано (тест 9):** `#cooling-cells` в cpu0–7 и cooling-maps в нашем DTS, cooling_device cpufreq-cpu0/cpu4.
- Под полной нагрузкой 8 ядер + GPU: 42 → 65 °C за 4 мин (тест остановлен моей страховкой на 65 °C).
## Зарядка без драйвера (2026-10-29)
- В простое с USB от Mac: mm8013 current_now −136…−141 мА, charge_now растёт (+1 мА·ч за ~20 с) → заряд идёт на HW-дефолтах pmi632. Под полной нагрузкой разряд ≈ +160 мА сверх USB.

## Драйвер зарядника PMI632 (SMB5), шаг 1 — только чтение (2026-10-29)
- Патч `0004-power-supply-add-read-only-Qualcomm-PMI632-charger-driver.patch`: drivers/power/supply/qcom_pmi632_charger.c + Kconfig CHARGER_QCOM_PMI632 + узел
  `&spmi_bus { pmic@2 { charger@1000 { compatible = "qcom,pmi632-charger"; reg = <0x1000>; }; }; }`. Регистры — по smb5-reg.h / qpnp-smb5.c (smb5_pmi632_params) Qualcomm (GPL-2.0).
- power_supply `pmi632-charger` (USB): ONLINE, STATUS, CHARGE_TYPE, USB_TYPE (APSD), HEALTH, INPUT_CURRENT_LIMIT (ICL_STATUS), CONSTANT_CHARGE_CURRENT/VOLTAGE (FCC/FV cfg). Опрос 5 с.
- Значения от загрузчика (USB порт Mac): FCC 0x3c = 3.0 А, FV 0x50 = 4.40 В (= профиль стока), ICL max 1.5 А, ICL фактически 950 мА, APSD = SDP, статус FULLON/Fast.
- Шаг 2 (не делали): запись USB ICL под DCP-адаптер (до 3 А), JEITA (1.5 А и 4.2 В при 45–50 °C), step-charging, SMB1355 (параллельный, I2C1 0x0c).

## Исходники Lenovo (2026-10-29): github.com/adazem009/kernel_lenovo_tbj606 → `src/kernel_lenovo_tbj606/drivers/power/supply/qcom/`
- `qpnp-smb5.c` (`smb5_pmi632_params`, `PMI632_MAX_ICL_UA 3000000`, JEITA), `smb5-lib.c/.h`, `smb5-reg.h` — стоковая логика зарядника с правками Lenovo
  (для шага 2: ICL под DCP/адаптер, JEITA, step-charging).
- `smb1355-charger.c` — параллельный зарядник SMB1355 (I2C1 0x0c), образец для mainline-драйвера.
- `qg-*.c` — Qualcomm QG (fuel gauge pmi632) и профиль батареи; `mm8013.c` — версия Lenovo (сравнить с mainline и патчем 0005).
