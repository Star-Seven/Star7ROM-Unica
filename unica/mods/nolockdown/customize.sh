# One UI's global actions (power) menu shows four items: Power off, Restart,
# Emergency call and Medical info. Setting a pattern/PIN lock screen makes the
# stock framework append a fifth, Lockdown mode, which breaks the 2x2 grid
# (three on the left, two on the right).
#
# The entry is added by com.samsung.android.globalactions.features
# .LockdownModeStrategy.onCreateActions, which Samsung's one-UI feature factory
# always registers. It only gates the add on
#   IS_LOCK_DOWN_IN_POWER_MENU && IS_CURRENT_USER_SECURE &&
#   IS_STRONG_AUTH_FOR_LOCK_DOWN
# In this port's framework SystemConditionChecker makes
# IS_LOCK_DOWN_IN_POWER_MENU (switch case 28) an unconditional "return true",
# so the strategy fires whenever a secure lock exists - it does not read the
# Secure.LockdownInPowerMenu setting that the stock Settings toggle writes.
# Locking the method to a void return keeps the ROM at the four stock items.
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali_classes6/com/samsung/android/globalactions/features/LockdownModeStrategy.smali" "null" \
    "onCreateActions(Lcom/samsung/android/globalactions/presentation/SamsungGlobalActions;)V"
