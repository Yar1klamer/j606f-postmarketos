# GPU (Adreno 610)

- Mesa freedreno FD610 (GLES 3.2), Vulkan turnip (`mesa-vulkan-freedreno`). devfreq 320–950 MHz (simple_ondemand).
- ★ 2026-10-30: gpu@5900000 in sm6115.dtsi has no `interconnects` and no `opp-peak-kBps` → no DDR bandwidth vote. Symptoms: glmark2-es2-wayland 277
  (terrain 12, refract 21), vkmark 87 ("clear" 130 fps at 800×600) with the GPU at 950 MHz. Stock kgsl: ib per level 320/465/600/745/820/900–980 MHz =
  3608000/6144000/8136000/10824000/12440000/14432000 KB/s. Patch 0009 (common.dtsi): gfx-mem = bimc MASTER_GRAPHICS_3D → SLAVE_EBI_CH0 (RPM_ALWAYS_TAG) +
  opp-peak-kBps. After it: glmark2 694 (terrain 46, refract 100, jellyfish 517), vkmark 599 ("clear" 587). interconnect_summary: ebi ← 5900000.gpu 10.8 GB/s at 745 MHz.
- Video (Venus, hardware H.264/HEVC): patch 0011 adds the SM6115 DT node (QCM2290/AR50 Lite fallback), `HW_CTRL_TRIGGER` for vcodec0,
  a resource that accepts the stock firmware v6.0.33 and the dummy EOS allocation for firmware <=6.0.53. firmware-lenovo-j606f r2 contains the per-device venus.mbn.
  Tested on kernel r115: /dev/video0 + /dev/video1; mpv `hwdec=v4l2m2m-copy`, H.264 1080p30 (240 frames) and HEVC 1080p30 (150 frames), RC=0,
  `Using hardware decoding (v4l2m2m-copy)`, a clean `Exiting... (End of file)`, no POLLERR/exception. Back then `hwdec=v4l2m2m-copy` was enabled in `~/.config/mpv/mpv.conf`; since device r20 the default is `/etc/mpv/mpv.conf` (profile=fast, hwdec=no) — `v4l2m2m-copy` dropped frames on output (1080p30 ~180 of 360).
  `hwdec=auto-copy-safe` picks h264-vulkan-copy on this system, so v4l2m2m-copy is set explicitly for Venus. Firefox/VA-API not tested.
- Vulkan and vsync: in FIFO mode Vulkan applications get 48 fps instead of 60 (every 5th vblank is skipped; Mesa 26.2 + KWin 6.8, wp_fifo_v1), OpenGL gets an honest 60. The cause is not found.
- Earlier: mpv with profile=fast handles 1080p; with the default shader scaling (before the DDR fix) it dropped ~40% of frames.
