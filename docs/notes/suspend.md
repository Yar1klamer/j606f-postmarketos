# Сон (s2idle) — не работает (2026-10-30)

- mem_sleep: только [s2idle]; RTC pm8xxx (wakealarm есть, время 1970 — смещение не хранится; будильник ставится).
- PowerDevil сам пытается усыпить ~раз в 10 мин простоя.
- Блокеры: (1) dwc3-qcom-legacy «port-1 HS-PHY not in L2» — с OTG-устройством сон отменяется; при первой попытке xHC error in resume -110 и «hard LOCKUP on cpu 1».
  (2) После сна или смены роли host→device «dwc3: failed to enable ep0out» (CoreSoftReset в __dwc3_set_mode, HS-only + select-utmi-as-pipe-clk) — USB-гаджет до
  перезагрузки не работает, следующий сон: dwc3 suspend -11. (3) ADSP «fatal error … crash detected in adsp» при засыпании → будит через ~2 с (подозрение: SSC/hexagonrpcd).
  (4) Wi-Fi деаутентифицируется (нет WoWLAN).
- План: тест сна с остановленными hexagonrpcd/iio-sensor-proxy; dwc3 — перевод USB на qcom,snps-dwc3 (плоская привязка) или квирк на повторную инициализацию;
  пока — выключить автосон в PowerDevil.
