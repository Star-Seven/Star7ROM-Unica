SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes5/com/samsung/android/settings/display/SecDisplayUtils.smali" "return" \
    'isInvalidFont(Landroid/content/Context;Ljava/lang/String;)Z' \
    'false'

# The font APK is prebuilt and already signed with the ROM platform key
# (security/aosp_platform.* - matching the release cert, since no star7 key is
# present). It is copied verbatim by apply_modules.sh (no SKIPUNZIP), so there
# is no per-build decode/rebuild/re-sign step.
