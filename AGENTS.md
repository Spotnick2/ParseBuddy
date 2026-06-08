# ParseBuddy Agent Instructions

## Project

ParseBuddy is a World of Warcraft addon written in WoW-compatible Lua 5.1 for TBC Anniversary. Its goal is to become a compact, efficient boss-debuff monitor for parse-minded raiders.

Tagline: "Your wingman for cleaner raid parses."

## Non-Negotiable Rules

- Keep the MVP dependency-free.
- Do not add Ace3, DBM, Details, MRT, WeakAuras, LibSharedMedia, or other dependencies unless explicitly requested.
- Do not add external web calls, Warcraft Logs API calls, scraping, uploading, or other network integration.
- Keep the addon combat-safe and lightweight.
- Prefer event-driven behavior.
- Use numeric spell ID lookups in combat paths.
- Avoid repeated string matching during combat.
- Avoid per-frame scanning and raid-wide scans during combat.
- Avoid expensive work inside `COMBAT_LOG_EVENT_UNFILTERED`.
- Future CLEU handlers must return immediately unless the subevent is tracked, the numeric spell ID is tracked, and the destination GUID is an active boss GUID.
- Boss aura scans must be opportunistic only: encounter start, boss unit appearance, a relevant CLEU event, an explicit debug command, or test mode when appropriate.
- A future 0.2-second ticker may update visible timers, colors, and row visibility only. It must not scan auras.
- Track debuff groups rather than rendering every spell as a separate row.
- Equivalent effects satisfy the same group. For example, Sunder Armor and Expose Armor both satisfy Major Armor.
- If an equivalent effect is active, display it. If none are active, display the alternatives as missing.
- Do not claim talent improvements such as Improved Faerie Fire, Improved Thunder Clap, Improved Demoralizing Shout, or Malediction without reliable evidence. The MVP tracks actual boss auras only.
- CLEU will be the primary source for aura lifecycle and source-player information.
- Aura scans will supplement CLEU only for duration, expiration, stack confirmation, and late-load recovery.

## Development Workflow

- Build incrementally by milestone.
- Do not implement multiple milestones in one run unless explicitly requested.
- Prefer small, reviewable diffs.
- Stop after each requested milestone and summarize what changed, what remains intentionally unimplemented, and what needs in-game testing.
- Commit and push every completed implementation iteration after verification.
- Review this file, `README.md`, and `VERSIONING.md` every iteration. Update them in the same commit when architecture, workflow, compatibility, commands, or milestone status changes.
- Keep the current behavior and milestone status in documentation accurate.
- Do not silently change established project rules.
- Keep `Reference/` local and untracked. It contains research material, not ParseBuddy source.

## Milestones

1. Addon skeleton, TOC, namespace, saved variables, and slash commands.
2. Movable/lockable UI frame and `/pb test` fake rows.
3. Debuff library and deterministic group evaluator.
4. Encounter detection and boss GUID tracking.
5. CLEU aura tracking for the six MVP debuff groups.
6. Opportunistic boss aura resync and timer expiration.
7. Debug tools, polish, and in-game acceptance testing.

Do not implement more than the requested milestone. The first priorities are addon loading, slash commands, saved variables, then frame movement and `/pb test`.

## Lua And Module Style

- Preserve WoW Lua/Lua 5.1 compatibility. Do not use modern Lua syntax unavailable in WoW.
- Keep global pollution minimal. Use the shared `ParseBuddy` namespace; WoW-required saved-variable and slash-command globals are the only expected exceptions.
- Use account-wide saved variables named `ParseBuddyDB`.
- Maintain clear module boundaries and small functions with descriptive names.
- Avoid clever abstractions and premature framework design.
- Optimize obvious combat paths, but do not prematurely optimize unrelated code.
- Prefer readable Lua tables for static data.
- Comment WoW API behavior when it is non-obvious.
- Avoid excessively large files when practical.
- Do not silently swallow initialization errors.
- Debug output must be conditional except for actionable startup failures.

## Module Responsibilities

- `Core.lua`: namespace, lifecycle, saved-variable bootstrap, slash commands.
- `Defaults.lua`: defaults and saved-variable merge helpers.
- `Debug.lua`: addon-prefixed and conditional debug output.
- `UI.lua`: frame, rows, movement, lock state, and test mode.
- `DebuffLibrary.lua`: static group definitions and spell-ID lookup tables.
- `State.lua`: encounter candidate state and deterministic group evaluation.
- `Encounter.lua`: encounter lifecycle and boss GUID/unit-token tracking.
- `Events.lua`: event registration and lightweight CLEU dispatch.
- `Config.lua`: profile/settings access and configuration UI.

## Versioning

Use Chromium-style `MAJOR.MINOR.BUILD.PATCH` versions as documented in `VERSIONING.md`. The authoritative version is the `Version` field in `ParseBuddy.toc`; runtime code should read addon metadata rather than duplicating it.

Verify the TOC Interface against the installed TBC Anniversary client before releases and after client updates. Do not assume an old value remains valid.
