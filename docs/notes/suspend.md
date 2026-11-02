# Сон (s2idle)

## Статус (2026-11-02)
- Работает с оговорками: ядро r110 (патч 0010 — UTMI-клок dwc3 после resume) убрало «failed to enable ep0out», r111 — успешный s2idle.
- Помощник `j606f-sleep.service` (`/usr/lib/j606f/sleep pre|post`, на нашем планшете вручную, в device-пакет ещё не входит): перед сном останавливает
  iio-sensor-proxy и hexagonrpcd-adsp-sensorspd (иначе sensor_process роняет ADSP) и выключает BT через rfkill (UART BT будит систему), после — возвращает.
- 02.11, r121: сон 4.5 мин → пробуждение без ep0out и падений ADSP, звук (3 карты), BT, Wi-Fi на месте.
  **Баг:** датчики не возвращаются — у штатного hexagonrpcd-adsp-sensorspd.service `Conflicts=suspend.target`, и `systemctl start --no-block`
  из ExecStop нашего юнита не срабатывает (iio-sensor-proxy поднимается, sensorspd нет; ручной `systemctl start` помогает).
  Исправить отдельным юнитом After=suspend.target и только потом упаковывать.
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
