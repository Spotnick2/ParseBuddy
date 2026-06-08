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
- Boss-only encounter display
- Source player, stack, and timer information when available
- Dependency-free, event-driven combat handling

## Commands

Milestones 4 and 5 add encounter lifecycle, visible boss tracking, and CLEU-driven live debuff rows. Missing groups remain gray during the pull grace period and turn red afterward. Active effects update immediately from combat-log aura events. `/pb test` remains available.

- `/pb` or `/parsebuddy`: show help
- `/pb help`: show help
- `/pb test`: show the deterministic test frame
- `/pb lock`: lock the frame position
- `/pb unlock`: allow the frame to be dragged
- `/pb reset`: reset the frame to screen center and scale `1.00`
- `/pb scale`: show the current frame scale
- `/pb scale 0.8` through `/pb scale 1.4`: resize and persist the frame scale
- `/pb debug`: toggle persisted debug output

## Development Milestones

1. Addon skeleton, TOC, namespace, saved variables, and slash commands
2. Movable/lockable UI frame and deterministic `/pb test` rows
3. Debuff library and deterministic group evaluator
4. Encounter detection and boss GUID tracking
5. **Current:** CLEU aura tracking for six MVP groups
6. Opportunistic boss aura resync and timer expiration
7. Debug tools, polish, and in-game acceptance testing

## Non-Goals

- Warcraft Logs integration or external web access
- Post-fight parsing or scoring
- Sounds, raid warnings, or whispers
- Assignments or import/export
- External addon or framework dependencies

## Milestones 4-5 In-Game Checks

- ParseBuddy appears in the addon list.
- The addon loads without Lua errors.
- `/pb` and `/parsebuddy` both show help.
- `/pb test` shows six green, yellow, red, and gray preview rows.
- The frame can be dragged while unlocked.
- `/pb lock` prevents dragging and `/pb unlock` restores it.
- Frame position and lock state persist after `/reload`.
- `/pb reset` returns the frame to screen center at scale `1.00`.
- `/pb scale 0.8` and `/pb scale 1.4` resize the frame and persist after `/reload`.
- The close button hides the test frame.
- `/pb test` still shows the same six scenarios after the data/evaluator refactor.
- Starting a supported encounter shows the primary visible boss and all six live group rows.
- Missing groups are gray during pull grace and red afterward.
- Applying, refreshing, stacking, or removing a tracked boss debuff updates its group row immediately.
- A boss disappearing from `boss1` through `boss5` is hidden from the display without ending the encounter state.
- Encounter end hides the encounter frame.

Boss aura scanning, duration recovery, repeating timer refreshes, and known-duration expiration are intentionally not implemented yet.

For local development, verified runtime files may be deployed directly to the TBC Anniversary `Interface\\AddOns\\ParseBuddy` directory. Reload the UI after Lua, TOC, or UI changes.
