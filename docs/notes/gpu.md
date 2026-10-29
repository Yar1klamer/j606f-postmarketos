# GPU (Adreno 610)

- Mesa freedreno FD610 (GLES 3.2), Vulkan turnip (`mesa-vulkan-freedreno`). devfreq 320–950 МГц (simple_ondemand).
- ★ 2026-10-30: в sm6115.dtsi у gpu@5900000 нет `interconnects` и `opp-peak-kBps` → нет голосования за DDR. Признаки: glmark2-es2-wayland 277
  (terrain 12, refract 21), vkmark 87 («clear» 130 fps при 800×600) при GPU 950 МГц. Сток kgsl: ib по уровням 320/465/600/745/820/900–980 МГц =
  3608000/6144000/8136000/10824000/12440000/14432000 КБ/с. Патч 0009 (common.dtsi): gfx-mem = bimc MASTER_GRAPHICS_3D → SLAVE_EBI_CH0 (RPM_ALWAYS_TAG) +
  opp-peak-kBps. После: glmark2 694 (terrain 46, refract 100, jellyfish 517), vkmark 599 («clear» 587). interconnect_summary: ebi ← 5900000.gpu 10.8 ГБ/с при 745 МГц.
- Видео: декодер venus для SM6115 в 7.2 не описан (есть только qcm2290); Firefox умеет только VA-API — видео декодирует CPU. mpv с profile=fast тянет 1080p,
  со шейдерным масштабированием по умолчанию (до исправления DDR) терял ~40% кадров.
