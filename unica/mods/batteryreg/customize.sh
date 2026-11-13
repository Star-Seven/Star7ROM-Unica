# Battery information: show the regulatory rows (Battery health / Battery cycle
# count / Manufacture date / First use date) on Settings -> About phone ->
# Battery information.
#
# The page and its rows already exist in the S721B One-SecSettings base
# (SecBatteryInfoFragment / sec_battery_info_settings.xml), but the regulatory
# rows inherit BatteryRegulatoryPreferenceController.getAvailabilityStatus(),
# which returns "unsupported" unless ALL of:
#
#   semGetValueAsBoolean(0x6a)  [battery IC authentication] AND
#     ( CSC CscFeature_Setting_ConfigAboutDeviceItems contains "ecoDesign"
#       OR SEC_FLOATING_FEATURE_SETTINGS_ENABLE_EU_BATTERY_REGULATORY  [all regions]
#       OR (SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS / _SBP_INFO_SETTINGS
#           AND region is EUR/TR) )
#
# The Exynos 9825 Note10 has no authenticating battery IC, so the 0x6a gate is
# false on every CSC and the rows stay hidden no matter which flag is set. Force
# getAvailabilityStatus() to AVAILABLE (0); the "first use date" controller
# defers to this same class via super, so all four rows appear. Row values come
# from the device (BatteryManager semGetValuesAsLong(0x6b) and
# /efs/FactoryApp/batt_*).
#
# SEC_FLOATING_FEATURE_SETTINGS_ENABLE_EU_BATTERY_REGULATORY is kept set as the
# region-independent switch, so the feature stays coherent if the gate is ever
# restored.
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SETTINGS_ENABLE_EU_BATTERY_REGULATORY" "TRUE"

SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes5/com/samsung/android/settings/deviceinfo/batteryinfo/BatteryRegulatoryPreferenceController.smali" \
    "return" \
    'getAvailabilityStatus()I' \
    '0'

# Battery life is gated on Rune.isJapanModel() (unsupported on every other CSC).
# Drop that region check so the value-based gate decides instead: it still needs
# a positive /sys/class/power_supply/battery/fg_asoc reading, so the row only
# appears where the fuel gauge exposes it.
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes5/com/samsung/android/settings/deviceinfo/batteryinfo/BatteryLifePreferenceController.smali" \
    "replace" \
    'getAvailabilityStatus()I' \
    'const/4 p0, 0x3' \
    'goto :cond_0'
