# No sepolicy edit. The boot sound ships as data only (the Ogg, the init trigger
# and the system.prop switch); apply_modules.sh copies the module's system/ tree,
# and that is all this mod needs.
#
# Earlier revisions appended
#   (allow samsungpowersoundplay audio_service (service_manager (find)))
# to system_ext_sepolicy.cil, on the theory that AudioSystem::get_audio_policy_service()
# looks the policy up under the service name "audio" (labeled audio_service) and
# the find was denied, so getSettingVolume() resolved to 0 and the track played
# silently. That theory was never device-verified and is empirically wrong: a
# device flash WITHOUT the rule boots normally and plays the boot sound.
#
# The rule is actively harmful. Editing system_ext_sepolicy.cil invalidates
# precompiled_sepolicy (it is covered by
# precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256), so init is forced
# to recompile the policy at boot. That recompile delays the boot past the
# samsungpowersoundplay window (its main only plays while dev.bootcomplete=0), so
# the sound is missed, and it shows up on the device as the first screen
# restarting twice before the boot proceeds. Do not re-add this rule.
#
# If the boot sound is ever genuinely silent, prove it with on-device evidence
# before touching sepolicy again: a post-boot
# `setprop service.media.powersnd 1` is NOT a valid test, because main
# rejects it once dev.bootcomplete is 1.

LOG "- Boot sound ships as data only (no sepolicy edit)"
