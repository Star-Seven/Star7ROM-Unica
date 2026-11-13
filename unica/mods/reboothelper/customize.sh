SKIPUNZIP=1

# RebootHelper calls PowerManager.reboot("recovery"), so it needs the privileged
# REBOOT/RECOVERY permissions declared in the XML next to it. It is added
# explicitly rather than through the automatic system/ walk so the SELinux label
# and mode are pinned instead of defaulted.
ADD_TO_WORK_DIR "$MODPATH" "system" "system/priv-app/RebootHelper" \
    0 0 755 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$MODPATH" "system" \
    "system/etc/permissions/privapp-permissions-com.tools.corsicanu.xml" \
    0 0 644 "u:object_r:system_file:s0"

# Samsung's PackageManager skips any priv-app whose package is not listed in
# /system/etc/sysconfig/allowed-system-preload-apps.xml (PMRune
# PM_ALLOWED_SYSTEM_PRELOAD_APPS + SCAN_AS_SYSTEM_PRELOAD). RebootHelper is not
# part of the donor image, so InstallPackageHelper.processParseResult() logs
# "Package is not in allowed list : com.tools.corsicanu" and returns before
# addForInitLI(), leaving the APK unscanned and RecoveryActivity unregistered.
# The privapp-permissions XML is never reached in that case.
#
# SystemConfig reads every XML under /system/etc/sysconfig, so a standalone file
# is enough and avoids depending on the donor file's structure.
ADD_TO_WORK_DIR "$MODPATH" "system" \
    "system/etc/sysconfig/allowed-system-preload-apps-com.tools.corsicanu.xml" \
    0 0 644 "u:object_r:system_file:s0"

# APPLY_PATCH decodes the artifact itself; the smali/ tree below is not walked
# because the patch directory is keyed by the artifact it targets.
APPLY_PATCH "system" "system/framework/framework.jar" \
    "$MODPATH/0001-Long-press-restart-to-boot-into-recovery.patch"
