# unica/patches/miscs/vendor.prop repoints the default alerts at the S25 Ultra
# "ACH_*" names (ro.config.ringtone=ACH_Galaxy_Bells.ogg, alarm_alert=
# ACH_Morning_Xylophone.ogg, notification_sound=ACH_Brightline.ogg, ...). Those
# names only exist in the pa3qxxx SoundTheme set; the S24 FE source ships the
# plain-named set instead (Galaxy_Bells.ogg, Spaceline.ogg, ...). Without this
# import RingtoneManager.computeDefaultRingtoneUri() finds no MediaStore row for
# the _display_name the prop names, so every default alert resolves to nothing.
#
# This is the Sounds block that used to live in unica/mods/paradigm, which is
# disabled (its Android 15 SmartSuggestions APK is not API 36-safe), so the
# import had silently stopped running.
#
# Additive on purpose: the source set stays selectable, and ui/ is deliberately
# NOT touched so bootsound's PowerOn.ogg and the source PowerOff/shutdown sounds
# survive (pa3qxxx ui/ ships neither).
ADD_TO_WORK_DIR "pa3qxxx" "system" "system/media/audio/ringtones"
ADD_TO_WORK_DIR "pa3qxxx" "system" "system/media/audio/notifications"
