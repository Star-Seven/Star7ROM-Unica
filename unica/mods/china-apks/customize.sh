SKIPUNZIP=1

# China (CHC) APK set. SKIPUNZIP so apply_modules.sh does not blind-copy the tree:
# HoneyBoard.apk ships split (90 MB parts) and must go through ADD_TO_WORK_DIR, which
# reassembles "<file>.00"/"<file>.01" into "<file>".

# Swap the Google compressed permission apex for the Samsung China one.
# com.samsung.android.permission.chn.capex must be supplied from a China (CHC)
# system image (the SM-S9260 bundle ships only apps/OMC, not the apex). While it
# is absent the Google apex is kept, so the build still completes instead of
# aborting on a missing zipalign source.
CHN_CAPEX="system/apex/com.samsung.android.permission.chn.capex"
if [ -e "$MODPATH/system/$CHN_CAPEX" ]; then
    LOG "- Installing the China (CHC) permission apex"
    DELETE_FROM_WORK_DIR "system" "system/apex/com.google.android.permission_compressed.apex"
    ADD_TO_WORK_DIR "$MODPATH" "system" "$CHN_CAPEX" 0 0 644 "u:object_r:system_file:s0"
else
    LOGW "China permission apex not supplied ($CHN_CAPEX); keeping the Google apex"
fi

LOG "- Installing China (CHC) APKs"

while IFS= read -r dir; do
    ADD_TO_WORK_DIR "$MODPATH" "system" "system/${dir#"$MODPATH/system/system/"}" 0 0 755 "u:object_r:system_file:s0"
done < <(find "$MODPATH/system/system/app" "$MODPATH/system/system/priv-app" \
    -mindepth 1 -maxdepth 1 -type d ! -name HoneyBoard | sort)

while IFS= read -r f; do
    ADD_TO_WORK_DIR "$MODPATH" "system" "system/${f#"$MODPATH/system/system/"}" 0 0 644 "u:object_r:system_file:s0"
done < <(find "$MODPATH/system/system/etc" -type f | sort)

ADD_TO_WORK_DIR "$MODPATH" "system" "system/app/HoneyBoard/HoneyBoard.apk" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$MODPATH" "system" "system/app/HoneyBoard/HoneyBoard.apk.prof" 0 0 644 "u:object_r:system_file:s0"
