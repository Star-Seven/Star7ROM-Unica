# UN1CA settings core (disabled)

This is the upstream UN1CA `settings` mod (vendored from Project-Berkyt `sixteen`
V3.9.0, One UI 8.5, SM-S926B), the carrier for every "UN1CA-exclusive" toggle.
It is **not active**: the `disable` marker keeps `apply_modules.sh` from
processing it, and `settings/module.prop` (the id) is distinct so there is no id
collision with the `unica/mods/settings` mod.

## Why it is not wired in yet

Adopting it is not a file copy — the framework side has to be reconciled first,
or the toggles render but do nothing:

1. **Flag mismatch (must fix).** The UI controllers write **SystemProperties**
   flags (`unica_allow_downgrade`, `unica_allow_sdkbypass`, `unica_ss_detection`,
   `unica_secure_ss`, `persist.sys.unica.asks`, ...). The existing
   `unica/mods/settings` services.jar patches are **unconditional**
   (e.g. `isDowngradePermitted` returns `const/4 v0, 0x1`, targetSdk uses
   `goto :goto_12`, secure screenshot guts `WindowState.isSecureLocked()`), so
   the toggles would be inert. Either switch the patches to upstream's
   property-driven form, or rewire the controllers to the existing behaviour and
   drop those toggles.
2. **framework.jar DEX ceiling.** `0002-SamsungPropsHooks`, `0003-FloatingFeature
   Hooks`, `0004-HideDeveloperStatusUtils`, and the Google-Photos patch inject
   into `smali_classes6` / `smali_classes3`. Logical 3 is full, so a whole class
   must be moved rather than edited in place. Any injected class must be planned
   against the free slots and ship `dex_allowed_additions`/`removals` rows.
3. **Three-way Instrumentation hook.** The tree already carries a `.disabled`
   `oscin4ever/spoof/SamsungPropsHooks` pair; UN1CA's `SamsungPropsHooks` is the
   shared `newApplication` hook that `pif`/`gamesprops` append to. Only one may
   own `@return-object p0`; compose in a fixed order.
4. **SecSettings re-sign / Format Data.** Enabling it decodes, overlays
   (`SecSettings.apk/**`: ~60 `io.mesalabs.unica.*` controllers, 5 `res/xml`,
   12 manifest activities), rebuilds and re-signs SecSettings → clean flash
   required.

## To activate (one sub-phase at a time)

1. Remove this `disable` marker.
2. Reconcile `smali/system/framework/services.jar/*` against `unica/mods/settings`
   (`0001`-`0005`) as above.
3. Import the `framework.jar` hooks with DEX-allowlist rows.
4. Drop the redundant sub-features (Vulkan also ships as `unica/mods/vulkan`;
   ASKS/hide-hidden are already handled).
5. Build + clean-flash device test on the workstation.

