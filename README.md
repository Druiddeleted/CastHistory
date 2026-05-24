# CastTimeline

A horizontal timeline of your recent casts with GCD reference markers. Inspired by the cast-history view in the Details! Streamer plugin.

## Features

- Live timeline of every spell you successfully cast — newest at the "now" edge, scrolling away as it ages out of the configurable time window.
- Reference markers for the base 1.5s GCD and your current haste-adjusted GCD, so you can see at a glance how tight your cast cadence is.
- Configurable growth direction: timeline can grow Left, Right, Up, or Down.
- Overlapping casts (e.g. an off-GCD ability fired right after a GCD spell) stack vertically so both icons stay visible.
- Optional diagonal spell-name labels under each icon.
- Full Blizzard Edit Mode integration via [LibEditMode](https://github.com/p3lim-wow/LibEditMode):
  - Drag to reposition from inside `/editmode`
  - Snaps to the Edit Mode grid when "Enable Snap" is on
  - All key settings (time window, icon size, max icons, alpha, growth direction, frame strata, GCD markers, spell names, background) live in the right-click selection dialog
- Configurable frame strata so the timeline can render above or below other UI.

## Slash commands

- `/casttimeline` or `/ct` — open the config panel
- `/ct show` / `/ct hide` / `/ct toggle` — show, hide, or toggle the timeline
- `/ct clear` — clear the on-screen history
- `/ct config` — open the options panel

To move the frame: open `/editmode`, click CastTimeline, drag.

## Known limitations

WoW patch 12.0 ("Midnight") restricted addon access to `COMBAT_LOG_EVENT_UNFILTERED`, so auto-attack swings cannot be tracked. CastTimeline shows only spells/abilities that fire `UNIT_SPELLCAST_SUCCEEDED` — which is everything the Details Streamer cast-history reference relied on anyway.

## License

MIT. See LICENSE.
