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

Milestone 2 provides a movable test frame with deterministic preview rows. Combat data is not connected yet.

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
2. **Current:** movable/lockable UI frame and deterministic `/pb test` rows
3. Debuff library and deterministic group evaluator
4. Encounter detection and boss GUID tracking
5. CLEU aura tracking for six MVP groups
6. Opportunistic boss aura resync and timer expiration
7. Debug tools, polish, and in-game acceptance testing

## Non-Goals

- Warcraft Logs integration or external web access
- Post-fight parsing or scoring
- Sounds, raid warnings, or whispers
- Assignments or import/export
- External addon or framework dependencies

## Milestone 2 In-Game Checks

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

Encounter handling, combat events, boss tracking, aura scanning, and real debuff evaluation are intentionally not implemented yet.

For local development, verified runtime files may be deployed directly to the TBC Anniversary `Interface\\AddOns\\ParseBuddy` directory. Reload the UI after Lua, TOC, or UI changes.
