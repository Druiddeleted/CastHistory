# Changelog

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
