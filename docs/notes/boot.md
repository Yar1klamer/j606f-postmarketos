# Загрузка: формат boot.img, ABL, отладка

## Стоковый boot.img (S120184_210520_ROW), из scripts/bootimg_info.py
- header_version 2, page_size 4096
- base 0x00000000, kernel_offset 0x8000, ramdisk_offset 0x01000000, second_offset 0x00f00000, tags_offset 0x100, dtb_offset 0x01f00000
- ядро: gzip (Image.gz), 31.8 МБ распакованное
- dtb в отдельной секции (header v2), несколько склеенных DTB (1.5 МБ), ABL выбирает по msm-id/board-id: `androidboot.dtb_idx=1`
- dtbo раздел: `androidboot.dtbo_idx=9`, ABL накладывает overlay (вопрос для mainline: не помешает ли)
- cmdline в образе: console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 ... buildvariant=user
- os_version 10.0, patch 2021-05
- SoC: soc_id 445 (SM6115P), revision 1.0, hw_platform IDP. В mainline DTS qcom,msm-id = <445 0x10000>, <420 0x10000>; qcom,board-id = <34 3>. Сверено с DT стока (live.dtb): msm-id <0x1BD 0x10000 0x1A4 0x10000>, board-id <0x22 0x3>. Совпадает.

## Для deviceinfo (черновик)
deviceinfo_flash_offset_base="0x00000000"
deviceinfo_flash_offset_kernel="0x00008000"
deviceinfo_flash_offset_ramdisk="0x01000000"
deviceinfo_flash_offset_second="0x00f00000"
deviceinfo_flash_offset_tags="0x00000100"
deviceinfo_flash_offset_dtb="0x01f00000"
deviceinfo_flash_pagesize="4096"
deviceinfo_header_version="2"
deviceinfo_bootimg_qcdt="false"
deviceinfo_append_dtb="false"

## Отладка без UART
- ramoops в mainline DTS @0xffc00000 (1 МиБ, console 256 КиБ). Проверить, сохраняется ли эта область после горячей перезагрузки и видит ли её стоковый Android (/sys/fs/pstore).
- USB-сеть из initramfs pmOS (pmos.debug-shell / telnet).

## ★ ABL + dtbo: почему mainline не грузился и как обойти (2026-10-29, подтверждено)
- `fastboot boot` в ABL этого планшета работает **один раз за сессию bootloader**. Второй вызов в той же сессии даёт
  `FAILED (remote: 'Failed to load/authenticate boot image: Load Error')` даже для стокового образа. Перед каждой попыткой: `fastboot reboot bootloader`.
- ABL **всегда** накладывает оверлей из раздела dtbo (запись [9] «Lenovo P11 WIFI PVT», msm-id 445/420, board-id <34 3>, 45 фрагментов, 138 меток в __fixups__).
  В mainline DTB нет `__symbols__` → наложение падает → ABL отвечает `Booting OKAY`, но ядро не запускает и через ~9 с возвращается в fastboot.
  (Header v2 с секцией dtb и header v0 с приклеенным DTB ведут себя одинаково.)
- **Обход без записи на устройство**: scripts/dtb_add_abl_sink.py добавляет в DTB `/abl-sink` (status=disabled, без compatible) с узлом-phandle
  на каждую метку из стоковых оверлеев и `/__symbols__`, где метка указывает на `/abl-sink/<метка>`. ABL накладывает оверлей, весь мусор оседает
  в /abl-sink, ядро его не трогает (of_platform_populate не заходит в узлы корня без compatible).
  Побочный эффект: ABL ставит /model = «Lenovo P11 WIFI PVT» (корень оверлея). Безвредно.
- Результат: ядро linux-nura-qcom-sm61x5 7.2.3 (бинарный пакет) + этот DTB загрузились через `fastboot boot`, USB-гаджет поднялся через ~9 с после «Booting OKAY».
- Альтернатива для постоянной установки: прошить пустой или «нейтральный» dtbo в dtbo_a. Это ЗАПИСЬ, только с согласия пользователя.
  Плюс подхода с «отстойником»: стоковый Android на слоте a продолжает работать без изменений.
- ABL правит cmdline: «rdinit=/init» превращается в «rd_nit=/init» (ABL ищет и портит подстроку «init=»?). Дефолт rdinit и так /init, на работу не влияет.
- В dmesg: «[Firmware Bug]: Kernel image misaligned at boot» (ABL кладёт ядро по 0x8000, не по 2 МиБ). Только предупреждение.
- `psci: failed to set PC mode: -3`. Предупреждение.

## Отладочная среда (scripts/make_debug_bootimg.py + scripts/debug-initramfs/)
- Гаджет ECM + ACM (18d1:d001). На macOS появляются en2 (ECM) и /dev/cu.usbmodemj606f_debug3 (ACM shell).
- В Alpine busybox-static НЕТ udhcpd/httpd/telnetd (они в busybox-extras), поэтому DHCP не работает. Mac сам берёт link-local 169.254.x.x.
  На устройстве: `ip addr add 169.254.42.1/16 dev usb0` (через ACM: scripts/acm_run.py), дальше `nc -lk -p 9100 -e /bin/sh` и scripts/tcp_run.sh.
- Страховка: если за 300 с не было обращения к CGI (/tmp/keepalive), то `reboot -f`. Без httpd CGI нет, поэтому keepalive надо создать вручную через ACM.
