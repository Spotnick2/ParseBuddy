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

Milestone 1 provides the command shell; UI commands are placeholders until Milestone 2.

- `/pb` or `/parsebuddy`: show help
- `/pb help`: show help
- `/pb test`: placeholder for test mode
- `/pb lock`: placeholder for locking the frame
- `/pb unlock`: placeholder for unlocking the frame
- `/pb reset`: placeholder for resetting frame position
- `/pb debug`: toggle persisted debug output

## Development Milestones

1. **Current:** addon skeleton, TOC, namespace, saved variables, and slash commands
2. Movable/lockable UI frame and deterministic `/pb test` rows
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

## Milestone 1 In-Game Checks

- ParseBuddy appears in the addon list.
- The addon loads without Lua errors.
- `/pb` and `/parsebuddy` both show help.
- `ParseBuddyDB` is created in account-wide saved variables.
- `/pb debug` persists its value after `/reload`.
- Test, lock, unlock, and reset commands print clear placeholder messages.

The frame, fake rows, encounter handling, and combat features are intentionally not implemented yet.
