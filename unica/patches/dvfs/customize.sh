# Only targets that opted in (TARGET_DVFSAPP_CONFIG_* set in
# target/<codename>/config.sh) run this module. The source side is now derived
# unconditionally for every donor, so without this a target that never opted in
# would compare a real source policy against its empty target value, see a
# difference, and try to patch to "".
if [ -z "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" ] && \
        [ -z "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" ]; then
    LOG "\033[0;33m! Nothing to do\033[0m"
    return 0
fi

if [[ "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" == "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" ]] && \
    [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" == "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" ]]; then
    LOG "\033[0;33m! Nothing to do\033[0m"
    return 0
fi

# A missing SIOP/DVFS policy in the donor is drift, not a build error: keep the
# artifact at stock and let apktool.sh's no-op gate leave it original. Aborting
# here (the upstream behaviour when DEBUG=false) would block a first boot on a
# source whose SDHMS layout the inherited patch set was not authored against.
_LOG() { LOGW "$1"; }

# The SDHMS classes this module edits are obfuscated, so the upstream literal
# paths (smali/r1/c, smali/z1/e, smali/U1/w) are donor-specific. On a rebased
# donor those paths no longer exist, the guard below bails, and the whole module
# silently becomes a no-op - apktool.sh then reports it as
# "Unchanged after decode, keeping original ...SamsungDeviceHealthManagerService.apk".
# Resolve each class by the policy-name const-string it holds instead of by its
# obfuscated path, falling back to the literal path only when the content search
# finds nothing. If none resolves, keep the whole module at stock rather than
# shipping a half-applied policy; the untouched APK and ssrm.jar are then left
# original by apktool.sh's no-op gate.
DECODE_APK "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"
SDHMS_DIR="$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"

# An APK decodes to one smali dir per dex (smali, smali_classes2, ...). Samsung
# APKs are routinely multi-dex (SamsungCamera here has four), so a search
# confined to smali/ misses any class that did not land in classes.dex. Cover
# every dex dir; SMALI_PATCH resolves a class by basename across dex dirs too.
SDHMS_SMALI_DIRS="$(find "$SDHMS_DIR" -maxdepth 1 -type d -name 'smali*' 2> /dev/null)"
[ "$SDHMS_SMALI_DIRS" ] || SDHMS_SMALI_DIRS="$SDHMS_DIR/smali"

# Which method of a smali file encloses a given const-string, e.g. "<clinit>"
# or "<init>". The obfuscated class names carry no clue, but the method that
# holds the policy name does: PerformanceFeature holds the DVFS name in
# <clinit>, PerformanceProperties holds the same string in
# <init>(Landroid/content/Context;)V.
SDHMS_METHOD_OF()
{
    awk -v needle="$2" '
        /^\.method / { m=$0 }
        index($0, "const-string") && index($0, needle) { print m; exit }
    ' "$1"
}

# performance/PerformanceProperties keeps the DVFS policy name in <init>, while
# performance/PerformanceFeature holds it in <clinit>. Tell them apart by the
# enclosing method, not by a MethodHandles probe: on the S721B donor neither
# class uses MethodHandles at all, so a MethodHandles heuristic resolves neither
# and both fall back to the literal paths - which do not exist on this donor,
# so the whole module bailed and the APK stayed stock.
if [ "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" ]; then
    for SDHMS_HIT in $(grep -rl -- "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" $SDHMS_SMALI_DIRS 2> /dev/null); do
        case "$(SDHMS_METHOD_OF "$SDHMS_HIT" "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME")" in
            *"<init>"*) [ "$SDHMS_PROPS" ] || SDHMS_PROPS="$SDHMS_HIT" ;;
            *"<clinit>"*) [ "$SDHMS_FEATURE" ] || SDHMS_FEATURE="$SDHMS_HIT" ;;
        esac
    done
fi
[ "$SDHMS_PROPS" ] || SDHMS_PROPS="$SDHMS_DIR/smali/z1/e.smali"
[ "$SDHMS_FEATURE" ] || SDHMS_FEATURE="$SDHMS_DIR/smali/r1/c.smali"
# util/Feature holds the SSRM/SIOP policy name.
if [ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" ]; then
    SDHMS_SSRM="$(grep -rl -- "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" $SDHMS_SMALI_DIRS 2> /dev/null | head -n 1)"
fi
[ "$SDHMS_SSRM" ] || SDHMS_SSRM="$SDHMS_DIR/smali/U1/w.smali"

for SDHMS_REQUIRED in "$SDHMS_PROPS" "$SDHMS_FEATURE" "$SDHMS_SSRM"; do
    if [ ! -f "$SDHMS_REQUIRED" ]; then
        _LOG "SDHMS layout not recognised (no class holds '${SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME}'/'${SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME}'); keeping the DVFS module at stock"
        unset -f _LOG
        return 0
    fi
done

# SMALI_PATCH takes paths relative to the decode root.
SDHMS_PROPS="${SDHMS_PROPS#"$SDHMS_DIR"/}"
SDHMS_FEATURE="${SDHMS_FEATURE#"$SDHMS_DIR"/}"
SDHMS_SSRM="${SDHMS_SSRM#"$SDHMS_DIR"/}"
unset SDHMS_SMALI_DIRS SDHMS_DIR SDHMS_METHOD_OF


# SEC_PRODUCT_FEATURE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME
if [[ "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" != "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" ]]; then
    SMALI_PATCH "system" "system/framework/ssrm.jar" \
        "smali/com/android/server/ssrm/Feature.smali" "replace" \
        "<clinit>()V" \
        "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME"

    DECODE_APK "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"

    if [ -f "$SRC_DIR/target/$TARGET_CODENAME/dvfs/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml" ]; then
        LOG "- Adding /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/res/raw/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml"
        EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/dvfs/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml\" \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/res/raw/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml\""
    elif [ ! -f "$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/res/raw/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml" ]; then
        _LOG "\"$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME\" does not exist in SDHMS app"
    fi

    # com/sec/android/sdhms/performance/PerformanceFeature
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "$SDHMS_FEATURE" "replace" \
        "<clinit>()V" \
        "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME"
    # com/sec/android/sdhms/performance/settings/PerformanceProperties
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "$SDHMS_PROPS" "replace" \
        "<init>(Landroid/content/Context;)V" \
        "$SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME"
fi

# SEC_PRODUCT_FEATURE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME
if [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" ]]; then
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"

    SMALI_PATCH "system" "system/framework/ssrm.jar" \
        "smali/com/android/server/ssrm/Feature.smali" "replace" \
        "<clinit>()V" \
        "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"

    DECODE_APK "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"

    if [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "ssrm_default" ]] && \
            [[ "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" == "ssrm_default" ]]; then
        LOG "- Deleting /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default"
        EVAL "rm \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default\""
        LOG "- Deleting /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_model"
        EVAL "rm \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_model\""
        LOG "- Deleting /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default"
        EVAL "rm \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default\""
        LOG "- Adding /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default.xml"
        EVAL "cp -a \"$MODPATH/assets/siop_default.xml\" \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default.xml\""
        LOG "- Adding /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default.xml"
        EVAL "cp -a \"$MODPATH/assets/siop_default.xml\" \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default.xml\""
    fi

    # com/sec/android/sdhms/util/Feature
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "$SDHMS_SSRM" "replace" \
        "<clinit>()V" \
        "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" \
        "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"
fi

if [ -f "$SRC_DIR/target/$TARGET_CODENAME/dvfs/siop_model.xml" ]; then
    DECODE_APK "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"

    LOG "- Deleting /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default"
    EVAL "rm \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default\""
    LOG "- Deleting /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_model"
    EVAL "rm \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_model\""
    LOG "- Deleting /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default"
    EVAL "rm \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default\""

    LOG "- Adding /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default.xml"
    EVAL "cp -a \"$MODPATH/assets/siop_default.xml\" \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default.xml\""
    LOG "- Adding /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME.xml"
    EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/dvfs/siop_model.xml\" \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME.xml\""
    LOG "- Adding /system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default.xml"
    EVAL "cp -a \"$MODPATH/assets/siop_default.xml\" \"$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/ssrm_default.xml\""
else
    if [[ "$SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" ]] && \
            [[ "$TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME" != "ssrm_default" ]]; then
        _LOG "File not found: $SRC_DIR/target/$TARGET_CODENAME/dvfs/siop_model.xml"
    fi
fi

unset -f _LOG
