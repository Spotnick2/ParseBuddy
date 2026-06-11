# ParseBuddy

**Your wingman for cleaner raid parses.**

ParseBuddy is an early-MVP World of Warcraft addon for TBC Anniversary. It is not raid-ready yet.

## Core Concept

ParseBuddy will provide a compact, real-time display of important boss debuff groups. It will help raiders notice missing, expiring, partial, or active effects during a pull without performing post-fight analytics or relying on external services.

Equivalent effects will share one row. For example, Sunder Armor and Expose Armor both satisfy the Major Armor Reduction group.

## Planned MVP

- Spell Vulnerability
- Major Armor Reduction
- Faerie Fire
- Judgement
- Attack Power Reduction
- Attack Speed Slow
- Full List and Problems Only display modes
- Boss encounter display with visible-boss preference and a combat-log fallback when no boss unit is exposed
- Source player, stack, and timer information when available
- Dependency-free, event-driven combat handling

## Commands

Milestones 4 through 6 add encounter lifecycle, boss tracking, CLEU-driven live debuff rows, known-duration expiration, and opportunistic visible-boss aura resync. Missing groups remain gray during the pull grace period and turn red afterward. Active effects update immediately from combat-log aura events. If the client does not expose `boss1` through `boss5`, ParseBuddy can learn a provisional hostile NPC target from the first tracked non-removal aura event. A later destination whose localized name exactly matches the encounter name can replace that provisional target. Previously visible or encounter-matched bosses take precedence over newly discovered adds and can reclaim the display from their combat-log activity. `/pb test` is blocked during active encounters so fake rows cannot replace live data.

- `/pb` or `/parsebuddy`: show help
- `/pb help`: show help
- `/pb test`: show the deterministic test frame
- `/pb dump`: print the current encounter, visible boss map, tracked candidates, and visible evaluations
- `/pb debugscan`: rescan tracked debuffs on currently visible `boss1` through `boss5` units
- `/pb lock`: lock the frame position
- `/pb unlock`: allow the frame to be dragged
- `/pb reset`: reset the frame to screen center and scale `1.00`
- `/pb scale`: show the current frame scale
- `/pb scale 0.6` through `/pb scale 1.4`: resize and persist the frame scale
- `/pb debug`: toggle persisted debug output

## Development Milestones

1. Addon skeleton, TOC, namespace, saved variables, and slash commands
2. Movable/lockable UI frame and deterministic `/pb test` rows
3. Debuff library and deterministic group evaluator
4. Encounter detection and boss GUID tracking
5. CLEU aura tracking for six MVP groups
6. Complete: opportunistic boss aura resync and timer expiration
7. **Current:** Debug tools, polish, and in-game acceptance testing

## Non-Goals

- Warcraft Logs integration or external web access
- Post-fight parsing or scoring
- Sounds, raid warnings, or whispers
- Assignments or import/export
- External addon or framework dependencies

## MVP In-Game Checks

- ParseBuddy appears in the addon list.
- The addon loads without Lua errors.
- `/pb` and `/parsebuddy` both show help.
- `/pb test` shows six green, yellow, red, and gray preview rows.
- The frame can be dragged while unlocked.
- `/pb lock` prevents dragging and `/pb unlock` restores it.
- Frame position and lock state persist after `/reload`.
- `/pb reset` returns the frame to screen center at scale `1.00`.
- `/pb scale 0.6` and `/pb scale 1.4` resize the compact frame and persist after `/reload`.
- The close button hides the test frame.
- `/pb test` still shows the same six scenarios after the data/evaluator refactor.
- Starting a supported encounter shows the primary boss and all six live group rows. Visible `bossN` units are preferred, but a tracked combat-log boss target can seed the display when no unit is exposed.
- Missing groups are gray during pull grace and red afterward.
- Applying, refreshing, stacking, or removing a tracked boss debuff updates its group row immediately.
- Known-duration rows count down, turn yellow at the warning threshold, and become missing after expiration without requiring a removal event.
- `/pb debugscan` reports the number of visible boss units scanned and tracked auras found.
- A boss unit appearing with existing debuffs, or a missed earlier CLEU application, can recover tracked auras through a visible-unit scan.
- Expose Armor uses the client-reported timer when the boss is visible and does not invent a fixed duration otherwise.
- A boss disappearing from `boss1` through `boss5` is hidden without ending encounter state; a later tracked aura event on that known boss can reclaim the display.
- Encounter end hides the encounter frame.

Known-duration effects expire locally even if CLEU removal is missed. Visible boss auras are rescanned only when a boss unit appears, after relevant CLEU activity, or through `/pb debugscan`. The 0.2-second display ticker updates timers and expiration state only; it never scans auras. Variable-duration effects such as Expose Armor rely on client aura expiration data when a visible boss unit is available.

For local development, verified runtime files may be deployed directly to the TBC Anniversary `Interface\\AddOns\\ParseBuddy` directory. Reload the UI after Lua, TOC, or UI changes.
