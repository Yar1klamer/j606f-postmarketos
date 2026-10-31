# Установка на ревизию с панелью Novatek NT36523W

> **Статус: не проверено на железе.** Порт делался на ревизии HX83102P. Для NT36523W собраны свой DTB
> (`sm6115p-lenovo-j606f-nt36523w.dts`) и device-пакет `device-lenovo-j606f-nt36523w`; всё, кроме панели и тача, у ревизий общее.

## Какая у вас ревизия
В стоковом Android под root: `cat /proc/cmdline | tr ' ' '\n' | grep dsi_display0`
- `qcom,mdss_dsi_nt36523w_boe_2k_video` — эта инструкция;
- `qcom,mdss_dsi_himax83102p_boe_2k_video` — основная инструкция в README (device `lenovo-j606f`).

## Что ожидается
| | |
|---|---|
| Дисплей, подсветка | драйвер панели есть в mainline (Linaro проверяли именно на NT36523W) |
| GPU, Wi-Fi, Bluetooth, батарея, зарядник (статус), кнопки, датчики | общие с HX83102P, должны работать |
| **Тач** | **нет**: Novatek NT36523 по SPI (CS1) ещё не портирован (исходник: ядро Lenovo, `drivers/input/touchscreen/NT36523W`) |
| USB OTG | общий с HX83102P (FUSB302 + буст gpio38, патч 0008), должен работать |

Без тача нужны Bluetooth-мышь/клавиатура (сопрягаются по SSH через `bluetoothctl`) или SSH по USB.

## 1. Разблокировка загрузчика (стирает все данные)
1. Настройки → О планшете → 7 раз «Номер сборки»; Для разработчиков → «Заводская разблокировка» и «Отладка по USB».
2. `adb reboot bootloader`, затем `fastboot flashing unlock` и подтвердить кнопками громкости. Планшет сбросится к заводским настройкам.
3. Снова пройти первичную настройку Android и включить «Отладку по USB».

## 2. Временный root (без прошивки boot)
1. Взять **точно такой же** `boot.img`, как установлен (версия сборки в «О планшете»): прошивка из Lenovo Rescue and Smart Assistant
   (LMSA) для вашего серийника, файл `boot.img` из архива.
2. Поставить приложение Magisk, «Установить → Выбрать и пропатчить файл» → получить `magisk_patched-….img`.
3. `adb reboot bootloader`, затем `fastboot boot magisk_patched-….img` (только загрузка, раздел boot не меняется).
   `fastboot boot` в этом загрузчике срабатывает **один раз** за сессию; если ошибка — `fastboot reboot bootloader` и повторить.
4. В Android: `adb shell su -c id` → на экране разрешить root для Shell.

## 3. Бэкап и прошивки (только чтение)
Из каталога репозитория, планшет подключён по USB:
```bash
bash scripts/backup_partitions.sh        # все разделы, кроме userdata, со сверкой sha256 (~13 ГБ) → BACKUP/partitions/
bash scripts/collect_firmware.sh         # прошивки Lenovo → FIRMWARE/<дата>/*.tar
```
Бэкап (`BACKUP/`) храните у себя: это единственный способ вернуть modem/persist/EFS. `FIRMWARE/` — проприетарные файлы вашего устройства:
передавайте только тому, кто собирает вам образ, и не публикуйте.

## 4. Образ
Собирается pmbootstrap с pmaports из этого репозитория (`pmaports/device/testing/`): ядро `linux-lenovo-j606f`,
`device-lenovo-j606f-nt36523w`, `firmware-lenovo-j606f` (тарбол из ваших файлов: раскладка в его APKBUILD).
```bash
pmbootstrap init        # device: lenovo-j606f-nt36523w
pmbootstrap install --password <временный пароль>
pmbootstrap export      # lenovo-j606f-nt36523w.img (rootfs, sparse) и boot.img
```

## 5. Установка (слот b, Android-загрузчик слота a не трогаем)
```bash
fastboot boot boot.img                         # проба без записи; в rootfs он пока не попадёт — ждём только картинку/USB-сеть
fastboot reboot bootloader
fastboot flash userdata lenovo-j606f-nt36523w.img   # sparse-образ: только fastboot, не dd
fastboot flash boot_b boot.img
fastboot erase dtbo_b                          # иначе загрузчик наложит стоковый оверлей и ядро не стартует
fastboot --set-active=b
fastboot reboot
```
Первый вход: USB-сеть `ssh user@172.16.42.1` (пароль из `pmbootstrap install`), сразу `passwd`.
Android после этого не загрузится (userdata занят); вернуть сток: `fastboot --set-active=a` + сброс через recovery, либо LMSA.

## 6. Обновления через apk-репозиторий
С device-lenovo-j606f-nt36523w r8 адрес репозитория и ключ приходят в самом device-пакете
(`/usr/lib/apk/repositories.d/j606f.list`, `/usr/lib/apk/keys/`): `sudo apk update && sudo apk upgrade && sudo reboot` — и всё.
Установке с device ≤ r7 нужен один переход (подробно — README, «Обновления через apk-репозиторий»):
```bash
echo "https://repo.yarnick.ru/j606f" | sudo tee -a /etc/apk/repositories
sudo apk update
sudo apk add linux-lenovo-j606f device-lenovo-j606f-nt36523w device-lenovo-j606f-nt36523w-nonfree-firmware
sudo /usr/lib/j606f/repo-migrate
sudo reboot
```
Не ставьте `device-lenovo-j606f` (это пакет ревизии HX83102P): оба device-пакета кладут свой deviceinfo и DTB, ставить их вместе нельзя.

## 7. Если что-то не так
- Чёрный экран, но USB-сеть есть — пришлите `dmesg` (`ssh user@172.16.42.1 sudo dmesg > dmesg.txt`).
- Ни экрана, ни USB-сети через ~1 мин — `Vol− + Power` в fastboot, `fastboot --set-active=a`, и пришлите, что было на экране.
