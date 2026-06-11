# ParseBuddy

**Your wingman for cleaner raid parses.**

ParseBuddy is an MVP World of Warcraft addon for TBC Anniversary. The implementation milestones are complete; supervised in-game acceptance is still required before treating it as raid-ready.

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
- `/pb validate`: verify every configured spell ID with the current client spell APIs
- `/pb lock`: lock the frame position
- `/pb unlock`: allow the frame to be dragged
- `/pb reset`: reset the frame to screen center and scale `1.00`
- `/pb scale`: show the current frame scale
- `/pb scale 0.6` through `/pb scale 1.4`: resize and persist the frame scale
- `/pb opacity`: show the current frame opacity
- `/pb opacity 0.2` through `/pb opacity 1.0`: change and persist whole-frame opacity
- `/pb debug`: toggle persisted debug output

## Development Milestones

1. Addon skeleton, TOC, namespace, saved variables, and slash commands
2. Movable/lockable UI frame and deterministic `/pb test` rows
3. Debuff library and deterministic group evaluator
4. Encounter detection and boss GUID tracking
5. CLEU aura tracking for six MVP groups
6. Complete: opportunistic boss aura resync and timer expiration
7. Complete: debug tools, polish, and in-game acceptance checklist

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
- `/pb validate` reports the configured spell-ID total and identifies any IDs unavailable in the current client.
- `/pb test` shows six green, yellow, red, and gray preview rows.
- The frame can be dragged while unlocked.
- `/pb lock` prevents dragging and `/pb unlock` restores it.
- Frame position and lock state persist after `/reload`.
- `/pb reset` returns the frame to screen center at scale and opacity `1.00`.
- `/pb scale 0.6` and `/pb scale 1.4` resize the compact frame and persist after `/reload`.
- `/pb opacity 0.5` makes the frame translucent and persists after `/reload`.
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

## Live Acceptance Procedure

Run these checks after `/reload` with Lua errors enabled:

1. Run `/pb validate`. Record any missing IDs; expected client-specific failures must be investigated before the row is trusted.
2. Run `/pb test`, verify all six deterministic rows, then close and reopen it.
3. Verify unlock, drag, lock, scale, `/pb reset`, and persistence across another `/reload`.
4. On a normal `boss1` encounter, verify the title, grace period, all six rows, source names, Sunder stacks, warning colors, and countdowns.
5. Apply and remove each available tracked debuff. Confirm CLEU changes appear immediately and known timers expire without requiring a removal event.
6. Run `/pb debugscan` while the boss is visible. Confirm the boss count and tracked-aura count match the frame.
7. Run `/pb dump`. Confirm the primary GUID, scan reason, candidate expiration source, and visible evaluations match the boss.
8. Retest Magtheridon: a channeler may seed the provisional display, but Magtheridon must replace it when identified and CoE must remain active in that event tick.
9. On a phase transition, verify an unrelated add cannot replace a previously visible boss and relevant activity can reclaim the known boss.
10. End or wipe the encounter. Confirm the ticker stops and the frame hides without stale test or encounter rows.

`/pb dump` metrics are cumulative for the current encounter. `cleu` counts accepted tracked aura events, `refreshes` counts display evaluations, `ticker` counts 0.2-second ticks, and `scans` is split by boss appearance, CLEU, and manual debug scans. A growing ticker count must not increase scan counts by itself.

Known-duration effects expire locally even if CLEU removal is missed. Visible boss auras are rescanned only when a boss unit appears, after relevant CLEU activity, or through `/pb debugscan`. The 0.2-second display ticker updates timers and expiration state only; it never scans auras. Variable-duration effects such as Expose Armor rely on client aura expiration data when a visible boss unit is available.

For local development, verified runtime files may be deployed directly to the TBC Anniversary `Interface\\AddOns\\ParseBuddy` directory. Reload the UI after Lua, TOC, or UI changes.
