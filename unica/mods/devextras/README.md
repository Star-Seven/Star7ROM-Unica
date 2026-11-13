# devextras — Hide developer status (ACTIVE)

The dev-options pain point: some apps refuse to run when they can see that
developer options / ADB are enabled. UN1CA's `HideDeveloperStatusUtils` fixes
this cleanly — it intercepts `Settings$Global.getString` for the three keys
`adb_enabled`, `adb_wifi_enabled`, `development_settings_enabled` and returns
`"0"` (off) to apps on a per-app list (`unica_hide_dev_list`, a comma-separated
Set in `Settings.Secure`), while the real values stay on for the user.

This mod carries both halves of the feature:

- the framework side
  (`smali/system/framework/framework.jar/0001-Introduce-HideDeveloperStatusUtils.patch`); and
- the Settings UI (`SecSettings.apk/`), a **Hide developer status** row in
  Security and privacy -> More security and privacy, with a master switch
  (`unica_hide_dev`, `Settings.System`) and an app picker.

The UI is the UN1CA `HideDeveloperStatusFragment` / `HideDeveloperStatusPreferenceController`
pair, pulled out of the disabled bulk `settings-unica` mod so the feature can be
reviewed and verified on its own. Every class it references already ships in the
S721B SecSettings decode (`SeslAppPickerView`, `SettingsMainSwitchBar`,
`LoadingViewController`, `SecSwitchPreferenceScreen`, `Utils.getResourceId`, ...),
and it reuses stock resources, so no new layout, drawable or string is required
beyond the row title. The row is a plain `<Preference android:fragment="...">`:
clicking it launches `SubSettings`, a `SettingsActivity`, so the fragment's
`SettingsActivity.mMainSwitch` cast is valid without a manifest activity.

Default behaviour: the master switch is off and the list is empty, so nothing is
hidden until the user turns it on and picks apps.

The ported `smali_classes4` classes are assembled into logical DEX 4 (SecSettings
`classes4.dex`, ~12k methods — plenty of room); the build's DEX inventory gate
auto-derives the `dex_allowed_additions` rows, which are committed under
`scripts/internal/dex_allowed_additions/system/system/priv-app/SecSettings/SecSettings.apk.tsv`.

## DEX relocation — required, and the reason for `customize.sh`

`framework.jar` logical DEX 3 (`smali_classes3`) is at **exactly 65,536
method_ids** (zero headroom). Editing `Settings$Global` in place adds method
references (`ContentResolver.getPackageName`, `HideDeveloperStatusUtils.
shouldHideDevStatus`), pushing the first new index to 65,536 — which smali
cannot encode, aborting the whole DEX with
`Unsigned short value out of range: 65536` reported against an unrelated method
(`Landroid/os/BaseBundle;->deepCopyValue`). This is the failure that the
`framework.jar` logical DEX 3 65,536-method ceiling predicts.

Fix: `customize.sh` moves `Settings$Global.smali` out of `smali_classes3` into
`smali_classes6` (65,074 stock methods, ~462 free) **before** the patch runs, and
`0001-Introduce-HideDeveloperStatusUtils.patch` targets
`smali_classes6/android/provider/Settings$Global.smali`. `customize.sh` is
sourced before `APPLY_SMALI_PATCHES` in `apply_modules.sh`, so the move lands
first. Cross-DEX references are fine (class refs encode a type index, not a
method index). Verified in a clean build: without the move the patch reports
`No file to patch`, with it, `patch -p1 --fuzz=0` returns 0.

The relocation is exactly one `dex_allowed_removals` row set for logical 3 plus
`dex_allowed_additions` rows for logical 6; `apktool.sh`'s `GENERATE_DEX_ALLOWLIST`
auto-generates both on the first build — commit them with the patch, or
`VERIFY_DEX_INVENTORIES` fails the rebuild.

## Gate: dex_allowed_additions

`smali_classes6` gains two new classes
(`io/mesalabs/unica/HideDeveloperStatusUtils` + `$Action`), the relocated
`Settings$Global` members, and the hook methods; `smali_classes3` loses
`Settings$Global`. The build's `GENERATE_DEX_ALLOWLIST` writes the rows to
`scripts/internal/dex_allowed_additions|removals/system/system/framework/framework.jar.tsv`
for review; commit them (the DEX inventory gate).

### The scary `ERROR: DEX allowed-members mismatch ... logical 3` line is benign

On the first build after this mod, `apktool.sh` prints a long
`ERROR: DEX allowed-members mismatch ... removed=['Landroid/provider/Settings$Global;', ...]`
for logical 3. It is **not** a failure: the inventory gate compares the built
DEX against the committed allowlist, does not find the relocation, logs `ERROR`,
then takes the intended `GENERATE_DEX_ALLOWLIST` path and continues:

```
ERROR: DEX allowed-members mismatch for ... logical 3 (... removed=['Landroid/provider/Settings$Global;'] ...)
  - Recording the applied member changes for /system/system/framework/framework.jar
wrote 889 additions to scripts/internal/dex_allowed_additions/.../framework.jar.tsv
wrote 830 removals to scripts/internal/dex_allowed_removals/.../framework.jar.tsv
```

Commit both `.tsv` files. On the next build the same line prints with
non-empty `allowed-*` lists and the gate passes quietly. The removal of
`Settings$Global` from logical 3 also carries the class's own methods/fields
plus its incidental references (`SemFloatingFeature`), which is why the removals
list is large.

If the additions list is lost (e.g. a `git reset --hard` reverted the tracked
file before it was committed), the gate's `GENERATE_DEX_ALLOWLIST` will fail on
the next build - it needs the source artifact as a decode, and a standalone
`apktool.sh b` does not provide one - and the gate will keep `framework.jar` at
stock and delete its decode (`DEX_INVENTORY_DRIFT`). Recovery is simply another
full `scripts/make_rom.sh` run: it re-decodes framework.jar, re-applies the
patches with correct source paths, regenerates `889 additions / 830 removals`,
and you commit both TSVs. Do that before any further reset/rebase.

## Prerequisites

`scripts/internal/check_devextras_prereqs.sh` runs against the decoded
`apktool` tree:

- `ContentResolver;->getPackageName()Ljava/lang/String;` **present** in the
  stock decode → no resolver hook needed.
- `Settings$Global` has **27 methods**.

`scripts/internal/check_devextras_patch_apply.py` verifies the patch
*and* the relocation against a copy of the decoded tree (prints
`RESULT: APPLIES`).

## Behaviour

- `Settings.System unica_hide_dev` (int, default 1) = master on/off.
- `Settings.Secure unica_hide_dev_list` (comma-separated packages) = who is lied
  to. Empty list = nobody hidden.
- The hook also waits for `sys.boot_completed`, so early-boot readers are
  unaffected.
- User-facing list UI: the `HideDeveloperStatusPreferenceController` under the
  UN1CA Settings "Spoof settings" section. That UI piece needs *no*
  `SamsungPropsHooks`/`FloatingFeatureHooks`, so it can be enabled independently
  of the rest of the carrier (`unica/mods/settings-unica`, still off).

