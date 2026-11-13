#!/usr/bin/env bash
# Enable the KnoxPatchHooks (Samsung Health) port.
#
# Steps, in order:
#
#   1. Install the KnoxPatchHooks class into smali_classes6. It is shipped as a
#      raw file (framework.jar/smali_classes6/...) rather than created by the
#      unified patch, so it is present even if the SystemProperties patch is
#      skipped for drift. A missing class behind a live Instrumentation hook is
#      what wedged system_server on the previous attempt.
#
#   2. Relocate android/os/SystemProperties.smali out of the full logical DEX 3.
#      smali_classes3 ships at exactly 65,536 method_ids (zero headroom), so the
#      invoke-static the framework patch appends cannot be encoded there. Move
#      the whole class into smali_classes6, which has headroom; cross-DEX
#      references are fine because a class reference encodes a type index, not a
#      method index. Same relocation devextras uses for Settings$Global.
#
#   3. Hook KnoxPatchHooks.init() into Instrumentation's app-attach path. init()
#      records the package name and decides whether to spoof the keystore
#      keytype property. Guarded: the hook is only added when the class file is
#      present in the decoded tree.

FRAMEWORK_DIR="$APKTOOL_DIR/system/framework/framework.jar"
INSTR="$FRAMEWORK_DIR/smali/android/app/Instrumentation.smali"
HOOK_CLASS_REL="smali_classes6/io/mesalabs/unica/KnoxPatchHooks.smali"

DECODE_APK "system" "system/framework/framework.jar"

# --- 1. Install the hook class ----------------------------------------------
if [ -f "$MODPATH/framework.jar/$HOOK_CLASS_REL" ]; then
    LOG "- Installing KnoxPatchHooks.smali into $FRAMEWORK_DIR"
    EVAL "mkdir -p \"$(dirname "$FRAMEWORK_DIR/$HOOK_CLASS_REL")\""
    EVAL "cp -a \"$MODPATH/framework.jar/$HOOK_CLASS_REL\" \"$FRAMEWORK_DIR/$HOOK_CLASS_REL\""
else
    LOGE "missing $MODPATH/framework.jar/$HOOK_CLASS_REL; cannot install the hook class"
    exit 1
fi

# --- 2. Relocate SystemProperties out of the full logical DEX 3 --------------
SRC_SMALI="$FRAMEWORK_DIR/smali_classes3/android/os/SystemProperties.smali"

if [ -f "$SRC_SMALI" ]; then
    DEST_DIR="$FRAMEWORK_DIR/smali_classes6/android/os"
    if [ ! -d "$FRAMEWORK_DIR/smali_classes6" ]; then
        # Pick the highest-numbered smali_classesN above 3 that exists.
        DEST=""
        for d in $(find "$FRAMEWORK_DIR" -maxdepth 1 -type d -name 'smali_classes*' | sort -V -r); do
            n="${d##*smali_classes}"
            [ "$n" -gt 3 ] 2>/dev/null && DEST="$d" && break
        done
        if [ -z "$DEST" ]; then
            LOGE "no smali_classesN (>3) DEX to relocate SystemProperties into"
            exit 1
        fi
        DEST_DIR="$DEST/android/os"
    fi

    LOG "- Relocating SystemProperties.smali out of the full smali_classes3"
    mkdir -p "$DEST_DIR"
    mv -f "$SRC_SMALI" "$DEST_DIR/"
else
    LOGW "SystemProperties.smali not at smali_classes3; skipping relocation"
fi

# --- 3. Instrumentation.newApplication hook ---------------------------------
# Both the Application receiver and the Context register names differ between
# One UI revisions (older builds keep the Application in v0), so read the real
# attach line out of the decoded method body instead of hard-coding either
# register. If the line cannot be found the hook is skipped with a drift warning
# (PATCH_DRIFT_POLICY=skip keeps the artifact at stock) rather than aborting the
# build - a missing hook only leaves Samsung Health unfixed, it does not wedge
# boot.
HOOK_NEWAPPLICATION()
{
    local SIGNATURE="$1"
    local ANCHOR
    local CTX_REG

    ANCHOR="$(awk -v FN="$SIGNATURE" '
        /^\.method/ && index($0, FN) { inside = 1 }
        inside && /invoke-virtual \{[^}]*\}, Landroid\/app\/Application;->attach\(Landroid\/content\/Context;\)V/ { print; exit }
        inside && /^\.end method/ { inside = 0 }
    ' "$INSTR" 2>/dev/null)"

    if [ -z "$ANCHOR" ]; then
        LOGW "no Application.attach call in $SIGNATURE; skipping hook"
        return 0
    fi
    CTX_REG="$(sed -E 's/.*\{[^,]+, *([pv][0-9]+)\},.*/\1/' <<< "$ANCHOR")"

    LOG "- Hooking KnoxPatchHooks.init into $SIGNATURE (context $CTX_REG)"
    SMALI_PATCH "system" "system/framework/framework.jar" \
        "smali/android/app/Instrumentation.smali" "replace" \
        "$SIGNATURE" \
        "$ANCHOR" \
        "$ANCHOR\n\n    invoke-static {$CTX_REG}, Lio/mesalabs/unica/KnoxPatchHooks;->init(Landroid/content/Context;)V"
}

if [ ! -f "$FRAMEWORK_DIR/$HOOK_CLASS_REL" ]; then
    LOGE "KnoxPatchHooks.smali is not in the decoded tree; refusing to add the hook"
    exit 1
fi

if [ -f "$INSTR" ]; then
    HOOK_NEWAPPLICATION \
        'newApplication(Ljava/lang/Class;Landroid/content/Context;)Landroid/app/Application;'
    HOOK_NEWAPPLICATION \
        'newApplication(Ljava/lang/ClassLoader;Ljava/lang/String;Landroid/content/Context;)Landroid/app/Application;'
else
    LOGW "Instrumentation.smali not found in the decoded framework.jar; skipping hook"
fi
