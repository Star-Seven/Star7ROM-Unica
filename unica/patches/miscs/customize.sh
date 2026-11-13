MODEL=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 1)
REGION=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 2)

# Set build ID
# You are not allowed to remove this part and distribute it
ROM_STATUS=""
$ROM_IS_OFFICIAL || ROM_STATUS=" UNOFFICIAL"
# The build number identifies the port source firmware, not the target device.
SOURCE_BUILD="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.build.display.id")"
SOURCE_PDA="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.build.PDA")"
[ -n "$SOURCE_PDA" ] || SOURCE_PDA="$SOURCE_BUILD"
[ -n "$SOURCE_PDA" ] || SOURCE_PDA="$SOURCE_CODENAME"
# Append the short commit to the displayed build number so a flashed ROM is
# traceable without adb. Strip ROM_COMMIT's leading '@' and trailing '-dirty'.
DISPLAY_COMMIT="${ROM_COMMIT#@}"
DISPLAY_COMMIT="${DISPLAY_COMMIT%-dirty}"
DISPLAY_ID="Star7ROM_${SOURCE_PDA}_${ROM_VERSION}_$(date +%Y%m%d)_${DISPLAY_COMMIT}"
SET_PROP "system" "ro.build.display.id" "$DISPLAY_ID"
# Software information reads the product build.prop value, so set it there too.
SET_PROP "product" "ro.build.display.id" "$DISPLAY_ID"
unset DISPLAY_ID DISPLAY_COMMIT

# Report the ROM as official regardless of the signing key in use.
SET_PROP "system" "ro.star7rom.official" "true"
SET_PROP "system" "ro.star7rom.version" "$ROM_VERSION"
SET_PROP "system" "ro.star7rom.base" "$SOURCE_BUILD"
# Build provenance, readable on-device via getprop.
SET_PROP "system" "ro.star7rom.commit" "$ROM_COMMIT"
SET_PROP "system" "ro.star7rom.build_timestamp" "$ROM_BUILD_TIMESTAMP"

# Disable FRP
SET_PROP "product" "ro.frp.pst" ""
# N10 doesn't have product partition on stock so this prop was moved to vendor 
# and needs to be patched
SET_PROP "vendor" "ro.frp.pst" ""

# Set Edge Lighting model
MODEL=$(echo "$TARGET_FIRMWARE" | sed -E 's/^([^/]+)\/.*/\1/')
SET_PROP "system" "ro.factory.model" "$MODEL"

# Fix portrait mode
SET_PROP "system" "ro.build.flavor" "$(GET_PROP "$FW_DIR/${MODEL}_${REGION}/system/system/build.prop" "ro.build.flavor")"

if [[ -f "$FW_DIR/${MODEL}_${REGION}/vendor/lib64/liblivefocus_capture_engine.so" ]]; then
    if grep -q "ro.product.name" "$FW_DIR/${MODEL}_${REGION}/vendor/lib64/liblivefocus_capture_engine.so"; then
        # For devices with this lib in system instead of vendor (e.g. S22 and up)
        # we will need to sed this in system lib after replacing with stock blob
        # in a platform patch.
        if [[ -f "$FW_DIR/${MODEL}_${REGION}/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" ]]; then
            sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib/libDualCamBokehCapture.camera.samsung.so"
            sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib64/libDualCamBokehCapture.camera.samsung.so"
        fi
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib/liblivefocus_capture_engine.so"
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib/liblivefocus_preview_engine.so"
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib64/liblivefocus_capture_engine.so"
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib64/liblivefocus_preview_engine.so"
        echo -e "\nro.unica.camera u:object_r:build_prop:s0 exact string" >> "$WORK_DIR/system/system/etc/selinux/plat_property_contexts"
        SET_PROP "system" "ro.unica.camera" "$(GET_PROP "$FW_DIR/${MODEL}_${REGION}/system/system/build.prop" "ro.product.system.name")"
    fi
fi

