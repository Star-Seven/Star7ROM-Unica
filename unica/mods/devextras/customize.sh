#!/usr/bin/env bash
#
# Relocate Settings$Global out of the full logical DEX 3 before the dev-hide
# patch is applied.
#
# framework.jar smali_classes3 is at exactly 65,536 method_ids (zero headroom),
# so adding the hook's method references (ContentResolver.getPackageName,
# HideDeveloperStatusUtils.shouldHideDevStatus) pushes the first new index to
# 65,536, which smali cannot encode ("Unsigned short value out of range: 65536").
# Move the whole class to a DEX with room. Cross-DEX refs are fine: class refs
# encode a type index, not a method index.
#
# customise.sh runs before APPLY_SMALI_PATCHES in apply_modules.sh, so the move
# lands before 0001-Introduce-HideDeveloperStatusUtils.patch (which targets
# smali_classes6) is applied.

FRAMEWORK_DIR="$APKTOOL_DIR/system/framework/framework.jar"
SRC_SMALI="$FRAMEWORK_DIR/smali_classes3/android/provider/Settings\$Global.smali"
DEST_SMALI="$FRAMEWORK_DIR/smali_classes6/android/provider"

if [ ! -f "$SRC_SMALI" ]; then
    # Already moved (or a different decode layout); nothing to relocate.
    LOGW "Settings\$Global.smali not at smali_classes3; skipping relocation"
else
    if [ ! -d "$FRAMEWORK_DIR/smali_classes6" ]; then
        # Pick the highest-numbered smali_classesN above 3 that exists.
        DEST=""
        for d in $(find "$FRAMEWORK_DIR" -maxdepth 1 -type d -name 'smali_classes*' | sort -V -r); do
            n="${d##*smali_classes}"
            [ "$n" -gt 3 ] 2>/dev/null && DEST="$d" && break
        done
        if [ -z "$DEST" ]; then
            LOGE "no smali_classesN (>3) DEX to relocate Settings\$Global into"
            exit 1
        fi
        DEST_SMALI="$DEST/android/provider"
    fi

    LOG "- Relocating Settings\$Global.smali out of the full smali_classes3"
    mkdir -p "$DEST_SMALI"
    mv -f "$SRC_SMALI" "$DEST_SMALI/"
fi

# --- Hide developer status: the Settings UI half -----------------------------
#
# The framework half (smali/system/framework/framework.jar) intercepts
# Settings$Global.getString and hides adb_enabled / adb_wifi_enabled /
# development_settings_enabled from the apps listed in the Secure setting
# unica_hide_dev_list. On its own that list can only be set from adb, so this
# half ships the on-device UI: a "Hide developer status" row in
# Security and privacy -> More security and privacy, with a master switch and an
# app picker.
#
# The UI is ported from UN1CA (salvogiangri), pulled out of the disabled bulk
# settings-unica mod so it can be reviewed and verified on its own. Every class
# it references already ships in the S721B SecSettings decode (SeslAppPickerView,
# SettingsMainSwitchBar, LoadingViewController, SecSwitchPreferenceScreen, ...)
# and it reuses stock resources, so no new layout/drawable is needed.
#
# The entry is a plain <Preference android:fragment="...">. Clicking it launches
# SubSettings (a SettingsActivity), so the fragment's SettingsActivity.mMainSwitch
# cast is valid without a manifest activity.

LOG_STEP_IN "- Adding Hide developer status UI"

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"

SS_DIR="$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk"

# Add the new smali classes, and patch the existing xml/values files. Same
# convention as unica/mods/settings-unica: a file that already exists is patched
# using its first line as the sed instruction, a new file is copied verbatim.
while IFS= read -r f; do
    f="${f//$MODPATH\/SecSettings.apk\//}"

    if [ ! -f "$SS_DIR/$f" ] || [[ "$f" != *".xml" ]]; then
        LOG "- Adding \"$f\" to /system/system/priv-app/SecSettings.apk"
        EVAL "mkdir -p \"$(dirname "$SS_DIR/$f")\""
        EVAL "cp -a \"$MODPATH/SecSettings.apk/${f//\$/\\$}\" \"$SS_DIR/${f//\$/\\$}\""
    else
        LOG "- Patching \"$f\" in /system/system/priv-app/SecSettings.apk"
        if [[ "$f" == *"res/values"* ]]; then
            PATCH_INST="/<\/resources>/i"
            CONTENT="$(sed -e "/?xml/d" -e "/resources>/d" "$MODPATH/SecSettings.apk/$f")"
        else
            PATCH_INST="$(head -n 1 "$MODPATH/SecSettings.apk/$f")"
            CONTENT="$(tail -n +2 "$MODPATH/SecSettings.apk/$f")"
        fi
        CONTENT="$(sed -e "s/\"/\\\\\"/g" -e "s/\\$/\\\\$/g" -e "s/ /\\\ /g" -e "s/\\\\n/\\\\\\\\\n/g" <<< "$CONTENT")"
        CONTENT="$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' <<< "$CONTENT")"
        EVAL "sed -i \"$PATCH_INST $CONTENT\" \"$SS_DIR/$f\""
    fi
done < <(find "$MODPATH/SecSettings.apk" -type f)

unset PATCH_INST CONTENT

LOG_STEP_OUT
