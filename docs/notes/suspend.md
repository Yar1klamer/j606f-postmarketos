# Сон (s2idle)

## Статус (2026-11-02)
- Работает с оговорками: ядро r110 (патч 0010 — UTMI-клок dwc3 после resume) убрало «failed to enable ep0out», r111 — успешный s2idle.
- Помощник сна в device-пакете с **r21** (nt36523w — r11), файлы `j606f-sleep.sh`, `j606f-sleep.service`, `j606f-resume.service`:
  - `j606f-sleep.service` (WantedBy/Before=sleep.target, StopWhenUnneeded): `pre` — запоминает enabled hexagonrpcd-adsp-rootpd/sensorspd и активный
    iio-sensor-proxy в /run/j606f-sleep.units, останавливает их (иначе sensor_process роняет ADSP), BT — `rfkill block` (UART BT будит систему);
    `post` (при остановке sleep.target) — `rfkill unblock`.
  - `j606f-resume.service` (WantedBy/After=suspend.target, oneshot): `resume` — `systemctl start --no-block` rootpd, sensorspd, iio-sensor-proxy.
  - Два файла состояния (/run/j606f-sleep для BT, /run/j606f-sleep.units для юнитов): `post` и `resume` запускаются одновременно.
- Баг до r21 (02.11): датчики не возвращались. Причина — у штатных hexagonrpcd-adsp-*.service `Conflicts=suspend.target`: systemd останавливает их сам
  в той же транзакции, что и наш `pre` (журнал: pre 1934.258, sensorspd deactivated 1934.273), `is-active` видел их уже остановленными → не записывались
  → не поднимались. rootpd по той же причине лежал с первого сна 30.10. Исправлено: hexagonrpcd-юниты восстанавливаются по `is-enabled`.
- 02.11, r121: сон 4.5 мин → пробуждение без ep0out и падений ADSP, звук (3 карты), BT, Wi-Fi на месте. С r21 — три цикла (rtcwake + `systemctl suspend`):
  rootpd/sensorspd/iio-sensor-proxy active, `monitor-sensor` отдаёт свет/приближение/акселерометр, ADSP running, BT UP.
- Наблюдение: при сне из ssh планшет просыпается через ~2 с, `/sys/power/pm_wakeup_irq` = 114 (msmgpio 11, `4a8c000.serial:wakeup` — UART BT),
  хотя BT в rfkill block; сон по кнопке 02.11 длился 4 мин. Не разбиралось.
- Не проверено: сон с подключённым OTG-устройством после r110, долгий сон (часы), Wi-Fi без WoWLAN (переподключается после пробуждения).

## Исходный разбор (2026-10-30)

- mem_sleep: только [s2idle]; RTC pm8xxx (wakealarm есть, время 1970 — смещение не хранится; будильник ставится).
- PowerDevil сам пытается усыпить ~раз в 10 мин простоя.
- Блокеры: (1) dwc3-qcom-legacy «port-1 HS-PHY not in L2» — с OTG-устройством сон отменяется; при первой попытке xHC error in resume -110 и «hard LOCKUP on cpu 1».
  (2) После сна или смены роли host→device «dwc3: failed to enable ep0out» (CoreSoftReset в __dwc3_set_mode, HS-only + select-utmi-as-pipe-clk) — USB-гаджет до
  перезагрузки не работает, следующий сон: dwc3 suspend -11. (3) ADSP «fatal error … crash detected in adsp» при засыпании → будит через ~2 с (подозрение: SSC/hexagonrpcd).
  (4) Wi-Fi деаутентифицируется (нет WoWLAN).
- План: тест сна с остановленными hexagonrpcd/iio-sensor-proxy; dwc3 — перевод USB на qcom,snps-dwc3 (плоская привязка) или квирк на повторную инициализацию;
  пока — выключить автосон в PowerDevil.
