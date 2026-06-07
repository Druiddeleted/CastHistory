# Changelog

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
