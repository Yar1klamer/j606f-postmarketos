# GPU (Adreno 610)

- Mesa freedreno FD610 (GLES 3.2), Vulkan turnip (`mesa-vulkan-freedreno`). devfreq 320–950 МГц (simple_ondemand).
- ★ 2026-10-30: в sm6115.dtsi у gpu@5900000 нет `interconnects` и `opp-peak-kBps` → нет голосования за DDR. Признаки: glmark2-es2-wayland 277
  (terrain 12, refract 21), vkmark 87 («clear» 130 fps при 800×600) при GPU 950 МГц. Сток kgsl: ib по уровням 320/465/600/745/820/900–980 МГц =
  3608000/6144000/8136000/10824000/12440000/14432000 КБ/с. Патч 0009 (common.dtsi): gfx-mem = bimc MASTER_GRAPHICS_3D → SLAVE_EBI_CH0 (RPM_ALWAYS_TAG) +
  opp-peak-kBps. После: glmark2 694 (terrain 46, refract 100, jellyfish 517), vkmark 599 («clear» 587). interconnect_summary: ebi ← 5900000.gpu 10.8 ГБ/с при 745 МГц.
- Видео (Venus, аппаратный H.264/HEVC): патч 0011 добавляет DT-узел SM6115 (QCM2290/AR50 Lite fallback), `HW_CTRL_TRIGGER` для vcodec0,
  ресурс с допустимой стоковой firmware v6.0.33 и dummy EOS allocation для firmware <=6.0.53. firmware-lenovo-j606f r2 содержит per-device venus.mbn.
  Проверено на ядре r115: /dev/video0 + /dev/video1; mpv `hwdec=v4l2m2m-copy`, H.264 1080p30 (240 кадров) и HEVC 1080p30 (150 кадров), RC=0,
  `Using hardware decoding (v4l2m2m-copy)`, нормальный `Exiting... (End of file)`, без POLLERR/exception. В `~/.config/mpv/mpv.conf` включён `hwdec=v4l2m2m-copy`.
  `hwdec=auto-copy-safe` на этой системе выбирает h264-vulkan-copy, поэтому для Venus задаём v4l2m2m-copy явно. Firefox/VA-API не проверялся.
- Ранее: mpv с profile=fast тянет 1080p, со шейдерным масштабированием по умолчанию (до исправления DDR) терял ~40% кадров.
