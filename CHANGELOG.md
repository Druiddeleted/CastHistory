# Changelog

## 0.1.7-alpha1

- Collapse periodic abilities to a single icon per press. Bladestorm ticks around ten times over its duration and every tick reports the same spell ID, so one press was drawing ten icons in a row. Ticks now fold into the cast you actually pressed, as do paired secondary events like Execute's, while genuine re-presses still show separately.
- Hide the internal system spells the game fires on you without you casting anything. Zone, quest and scenario machinery — "Disable ALL Mounts", "NoCho", "Med'jai's Protection", "[DNT] Player Inside WMO" and friends — was appearing on the timeline as casts you never made. Proc-granted abilities are unaffected: Rogue's Coup de Grace reports as an unknown spell but is still a real cast, so the filter keys on whether a spell has a tooltip rather than on whether you could cast it. Turn it off with "Hide internal/system spells you didn't cast" in `/ch config` or the Edit Mode dialog if you'd rather see everything — note that tooltip-less vehicle and scenario abilities are hidden too.
- Config panel: the GCD marker checkboxes now take effect immediately instead of waiting for another setting to change. Settings are also declared in one place internally, so the Edit Mode dialog and the config panel can no longer drift apart.
- New `/ch replay`: re-runs the recorded debug log through the cast-collapse rules and reports how many icons each spell produces. This is the regression check for the rules above — a change that quietly swallows real casts shows up as a spell whose count dropped.
- New `/ch probe`: records what the game's API knows about every spell seen in the debug log, so filters can be built from observed data instead of guesses.
- Restructured internally: all the rules deciding "which events are one cast" now live in a single module, the GCD/haste handling moved out of the cast timeline, and event registration no longer carries any logic of its own.

## 0.1.6

- Collapse multi-strike abilities to a single icon per button press. Melee abilities that hit with both weapons or strike several times — Fury warrior's Rampage, Odyn's Fury, Whirlwind, Raging Blow, and Execute, plus off-GCD ones like Charge and Heroic Leap — each fire several `UNIT_SPELLCAST_SUCCEEDED` events, so one press was showing up as several icons. CastHistory now folds the extra strikes into the cast you actually pressed, while still showing genuine re-presses separately.

## 0.1.5

- Remember the timeline's position per Edit Mode layout, so switching HUD profiles now moves CastHistory to wherever you placed it in that layout. Existing positions are preserved — a layout only diverges once you reposition the frame while it's active. "Reset position" now resets only the active layout.
- Stop erroring on haste reads now that `UnitSpellHaste` can return a protected (Secret) value in Patch 12.0; the haste-adjusted GCD markers keep their last known spacing instead.
- Skip per-frame work when the timeline is empty and reuse layout scratch state, to cut idle CPU and garbage collection.

## 0.1.4

- Fix channeled spells (Spinning Crane Kick, etc.) occasionally showing a late tick after the channel ended.
- Allow free-cast spells during a channel (Vivify / Enveloping Mist / Sheilun's Gift during Soothing Mist) to show up on the timeline instead of being filtered out as channel ticks.
- Force Skyriding abilities (Skyward Ascent, Surge Forward, Whirling Surge, Take to the Skies, Bronze Timelock, Land) onto the main row even though the spell DB flags them as off-GCD.

## 0.1.3

- Split the timeline into two rows: on-GCD casts stay on the main row, off-GCD abilities (trinkets, racials, Anti-Magic Shell, etc.) stack one row above so they never sit on the GCD line.
- Use `GetSpellBaseCooldown` to classify on/off-GCD — this reads the spell DB directly, so it's not fooled by latency, cast time, or haste-scaled GCD durations.
- Treat cast-time spells (mounts, hardcasts) as on-GCD even if the spell DB marks them off-GCD, since they visually belong on the main row.
- Collapse channeled spells (Spinning Crane Kick, etc.) to a single icon per channel instead of one per tick.

## 0.1.2

- Suppress the flood of passive/equipment cast events (tabards, profession gear, trinkets) that WoW replays for ~1 second after every `PLAYER_ENTERING_WORLD`. These were filling the timeline with gear icons on every login and zone change.
- Broaden the DNT placeholder filter to catch spells with a `(DNT)` suffix in addition to the `[DNT]` prefix.

## 0.1.1

- Filter out Blizzard's internal `[DNT]` placeholder spells. These fire as `UNIT_SPELLCAST_SUCCEEDED` on the player unit inside delves (altar auto-collect, material drops, exit sequences) but aren't real player-initiated casts and were flooding the timeline.

## 0.1.0

- Initial release.

## 0.1.0-alpha1

- Initial alpha release.
- Horizontal/vertical timeline of `UNIT_SPELLCAST_SUCCEEDED` events.
- Base 1.5s GCD reference markers and haste-adjusted GCD markers.
- Configurable growth direction (Right/Left/Up/Down).
- Overlapping near-simultaneous casts stack vertically.
- Optional diagonal spell-name labels under icons.
- Configurable frame strata.
- LibEditMode integration: drag in `/editmode`, snap to Edit Mode grid, all key settings exposed in the right-click selection dialog.
- Slash commands: `/casthistory`, `/ch`, `/ch show|hide|toggle|clear|config`.
