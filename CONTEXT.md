# Domain language

The words this addon's code uses, and what they mean here. Written down because
several of them look interchangeable in plain English but are load-bearing
distinctions in `src/intake.lua`.

## Casts and events

**Event** — a raw `UNIT_SPELLCAST_*` notification from the client. Noisy: one
button press produces several, and the game fires them for spells the player
never cast.

**Cast** — one entry on the timeline; what the player experiences as "I pressed
a button and something happened". Many events collapse into one cast.

**Press** — an event the player caused, identified by a leading `3` in the cast
GUID's type field. Contrast **triggered**, which reports `13` or `15`: an effect
the game fired on the player's behalf.

**Strike** — one of several events from a single press, each with a *different*
spellID but the same display name. Fury warrior's Rampage fires five. They
arrive across the ability's animation, up to ~1.3s.

**Tick** — a periodic event from an effect that is still running. Bladestorm
ticks ten times over ~5s, every tick reporting the *same* spellID. Distinguished
from a re-press by arriving faster than the GCD, and by being triggered rather
than pressed.

**Internal spell** — a spell the game fires on the player that no one cast:
zone, quest and scenario machinery like `[DNT] Player Inside WMO`, `NoCho`,
`Med'jai's Protection`. Identified by having no tooltip description at all.
Deliberately *not* identified by castability — proc-granted abilities such as
Rogue's Coup de Grace are real casts that report as unknown spells.

**Window** — the span of recent time the timeline shows, in seconds. Casts older
than the window are pruned.

## Modules

**Cast intake** (`src/intake.lua`) — turns the event stream into the cast list.
Owns every collapse rule above. One entry point: `Observe(event, guid, spellID)`.

**Environment** (`env` in intake) — everything the collapse rules need from
outside themselves: the clock, the GCD, spell lookups. Injected, so the same
rules run against the live client or a recorded log.

**Replay** (`src/replay.lua`) — the second environment. Feeds a recorded event
log back through the rules and reports casts produced per spell, as a regression
check on the collapse rules. Run with `/ch replay`.

**Probe** (`src/probe.lua`) — sweeps every spell seen in the debug log and
records what the API says about each, so filters can be designed against
observed data instead of guesses. Run with `/ch probe`.

**GCD reference** (`src/gcd.lua`) — the player's current global cooldown. Owns
the haste read, the Secret Values guard, the cache and change notification. Used
both to space the timeline's reference markers and to tell a tick from a press.

**Settings schema** (`src/settings.lua`) — the single declaration of every
user-facing setting. Three surfaces render from it: saved-variable defaults, the
Edit Mode selection dialog, and the `/ch config` panel.

**Layout** — a Blizzard Edit Mode HUD profile. The frame's position is stored
per layout, so switching HUD profiles moves the timeline with them.
