# Vulkan renderer toggle (opt-in).
#
# Ported from UN1CA's settings mod, which predicates this on
# persist.sys.unica.vulkan and drives debug.hwui.renderer=skiavk at
# zygote-start. On exynos9825 the Mali driver defaults to the GL renderer;
# switching is a device-specific experiment, so the property is seeded
# false and left off. Flip STAR7_VULKAN=true in config.sh to enable.
#
# Upstream also stages prebuilts/samsung/r11sxxx/system/lib*/libvulkan.so.
# That is an S21 (r11s) blob; d2xks already ships its own vendor Vulkan
# driver, so no libvulkan.so is imported here.
LOG_STEP_IN "- Vulkan renderer property hook"

if ${STAR7_VULKAN:-false}; then
    SET_PROP "system" "persist.sys.unica.vulkan" "true"
    LOG "- Seeded persist.sys.unica.vulkan=true (debug.hwui.renderer=skiavk at boot)"
else
    SET_PROP "system" "persist.sys.unica.vulkan" "false"
    LOG "- Vulkan renderer stays off (STAR7_VULKAN not set)"
fi

LOG_STEP_OUT
