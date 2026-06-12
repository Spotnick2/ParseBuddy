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
- Future CLEU handlers must return immediately unless the subevent is tracked, the numeric spell ID is tracked, and the destination GUID is an active boss GUID or can be learned as the encounter target when no visible boss unit is available.
- Boss aura scans must be opportunistic only: encounter start, boss unit appearance, a relevant CLEU event, an explicit debug command, or test mode when appropriate. Combat-log fallback discovery is allowed when no visible boss unit is present.
- Combat-log fallback discovery selects one provisional GUID per encounter. A later GUID whose localized destination name exactly matches the localized encounter name may replace that provisional target once; unrelated adds must not replace it.
- A future 0.2-second ticker may update visible timers, colors, and row visibility only. It must not scan auras.
- Track debuff groups rather than rendering every spell as a separate row.
- Equivalent effects satisfy the same group. For example, Sunder Armor and Expose Armor both satisfy Major Armor.
- If an equivalent effect is active, display it. If none are active, display the alternatives as missing.
- Do not claim talent improvements such as Improved Faerie Fire, Improved Thunder Clap, Improved Demoralizing Shout, or Malediction without reliable evidence. The MVP tracks actual boss auras only.
- CLEU will be the primary source for aura lifecycle and source-player information.
- Aura scans will supplement CLEU only for duration, expiration, stack confirmation, and late-load recovery.
- Completed diagnostic snapshots preserve final raw candidates separately from one bounded last-meaningful live evaluation view. Terminal aura-removal cleanup must not overwrite that retained live view.
- Live display filtering is a UI concern. Problems Only hides healthy active rows and shows required missing/grace, partial, expiring, and unknown-source rows; Full List shows every enabled group. Test mode and diagnostics remain unfiltered.
- Roster capability is class-based and cached only on `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, and encounter start. Never scan roster units from CLEU, the display ticker, evaluation, or UI rendering. A complete roster with no baseline provider yields `notAvailable`; incomplete data yields `unknown`; observed active effects always take precedence.
- Do not infer talents, specs, improved effects, learned ranks, assignments, or responsibility from class presence. `NOT AVAILABLE` is informational and hidden by default in Problems Only through a scoped setting; Full List always shows enabled unavailable groups.
- Missing-debuff broadcasts are opt-in and frozen at encounter start. Only enabled, required, roster-available groups may alert after grace plus delay. Alerts are transition-based, re-arm only after satisfaction, and use separate deferred callbacks with global and per-group cooldowns. Never send chat directly from CLEU, aura scans, UI rendering, or the display ticker.
- Broadcast destinations are explicit party, raid, or cached group leader. If the selected destination is unavailable, suppress the alert and emit only conditional local debug output. Never fall back to another public channel or include roster member names in automatic broadcast text.
- The AddOns settings panel is currently a static UX prototype. Its state must remain isolated in `ParseBuddy.ConfigPrototype`, must reset on reload, and must never read or write either SavedVariables table until real settings wiring is explicitly requested.
- Prefer the modern Blizzard canvas settings API with the legacy Interface Options fallback. Keep one fixed header and one scrollable task-oriented page; do not reintroduce custom tabs, nested scroll frames, excessive bordered boxes, or a Save/Apply workflow.
- Global settings use `ParseBuddyDB.settings`; per-character personal settings use `ParseBuddyCharDB.settings`, selected by `ParseBuddyCharDB.activeScope`. Frame position, scale, opacity, and lock state remain account-wide in `ParseBuddyDB.frame`.
- Personal settings are copied from current global settings only on first selection. Scope switching must preserve both stores without merging or overwriting later edits.
- The encounter summary is group-level, single-primary, and memory-only. It accrues satisfied, partial, and missing intervals after grace from evaluator transitions; it must not retain raw CLEU history, score players, scan auras, or persist summaries across reloads.
- Freeze summary scope, display mode, enabled flags, and required flags at encounter start. Mid-fight settings changes must not alter the active summary.
- Configured multi-boss encounters use numeric NPC IDs parsed from Creature/Vehicle GUIDs. Registry entries accept all configured targets without deleting prior candidate state and reject arbitrary CLEU adds; unconfigured encounters preserve generic fallback behavior.
- Primary selection precedence is visible `boss1`, first visible registered boss, most recently relevant registered boss, then previous authoritative boss. Continue rendering one boss section until multi-boss UI is explicitly requested.
- Combat-log fallback discovery may learn non-friendly NPC destinations, including neutral encounter targets such as Midnight, and never from a full aura-removal event. Continue rejecting players, pets, guardians, and friendly NPCs.
- A boss previously exposed through `boss1`-`boss5`, or matching the encounter name, takes precedence over newly discovered fallback adds. Relevant activity from a known hidden boss may reclaim the single-boss display.

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
- After successful verification, deploy the addon when useful to `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\ParseBuddy`.
- Deploy runtime files only: `ParseBuddy.toc` and the Lua files listed by the TOC. Do not deploy documentation, tests, Git metadata, references, logs, or scratch files.
- Preserve the same relative paths used by the TOC when future runtime subdirectories are added.
- After deployment, tell the user whether `/reload` is sufficient or whether a logout/client restart is required. Lua, TOC, and ordinary UI changes normally require `/reload`; testing saved variables written at logout may require logging out and back in.

## Milestones

1. Complete: addon skeleton, TOC, namespace, saved variables, and slash commands.
2. Complete: movable/lockable/scalable UI frame and `/pb test` fake rows.
3. Complete: debuff library and deterministic group evaluator.
4. Complete: encounter detection and boss GUID tracking.
5. Complete: CLEU aura tracking for the six MVP debuff groups.
6. Complete: opportunistic boss aura resync and timer expiration.
7. Complete: debug tools, polish, and in-game acceptance checklist.

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
- `Debug.lua`: addon-prefixed and conditional debug output, including dump helpers.
- `UI.lua`: frame, compact row rendering, display-mode filtering, movement, lock state, and test mode.
- `DebuffLibrary.lua`: static group definitions and spell-ID lookup tables.
- `CapabilityLibrary.lua`: static group-to-baseline-provider-class mappings only.
- `Roster.lua`: low-frequency solo/party/raid roster cache, capability evaluation, and `/pb roster` diagnostics.
- `EncounterTargets.lua`: static encounter-ID to NPC-ID target registry and Lua 5.1-compatible Creature/Vehicle GUID parsing.
- `State.lua`: encounter candidate state, deterministic group evaluation, known-duration expiry, and injectable single-unit aura resync.
- `Summary.lua`: frozen encounter settings and in-memory group-level uptime interval accounting and output.
- `Broadcast.lua`: frozen opt-in alert settings, pending transition state, bounded deferred delivery, cooldowns, and chat routing.
- `Encounter.lua`: encounter lifecycle, boss GUID/unit-token tracking, opportunistic scan triggers, and the display-only ticker.
- `Events.lua`: event registration and lightweight CLEU dispatch.
- `Config.lua`: global/personal scope selection, scoped display/group settings, and slash-command settings access. The static prototype must not call it.
- `ConfigPrototype.lua`: deterministic, memory-only fake settings used exclusively by the static configuration UX prototype.
- `ConfigPanel.lua`: dependency-free Blizzard settings registration, opening, and static prototype rendering.

## Versioning

Use Chromium-style `MAJOR.MINOR.BUILD.PATCH` versions as documented in `VERSIONING.md`. The authoritative version is the `Version` field in `ParseBuddy.toc`; runtime code should read addon metadata rather than duplicating it.

Verify the TOC Interface against the installed TBC Anniversary client before releases and after client updates. Do not assume an old value remains valid.

## MVP Diagnostic Commands

- `/pb dump` prints current encounter identity, boss mappings, cumulative event/refresh/scan metrics, candidates, expiration sources, and visible evaluations.
- `/pb debugscan` performs an explicit aura scan of currently visible boss units only.
- `/pb validate` checks configured numeric spell IDs through client spell APIs. It is user-triggered debug work and must never run automatically in combat.
- `/pb opacity 0.2-1.0` changes the persisted alpha of the whole frame; `/pb reset` restores opacity to `1.0` with position and scale.
- `/pb mode problems|full` changes the persisted live encounter display mode. `/pb test` must remain deterministic and unfiltered.
- `/pb profile global|personal`, `/pb groups`, and `/pb group <key> ...` manage scoped settings. Stable group keys are part of the command contract.
- `/pb unavailable show|hide` controls the scoped Problems Only visibility of `NOT AVAILABLE` rows; `/pb roster` prints the cache and must not refresh it.
- `/pb broadcast on|off`, `/pb broadcast channel party|raid|leader`, and `/pb broadcast delay 0-60` manage scoped next-encounter alert settings. `/pb broadcast test` is explicit, deterministic, local-only, and blocked in combat.
- `/pb` opens the static configuration prototype; `/pb help` remains the slash-command reference. Explicit commands continue to operate normally outside the prototype.
- `/pb snapshot` prints the automatically captured diagnostic snapshot from the most recently completed encounter.
- `/pb clear` clears both `ParseBuddy.lastEncounterSnapshot` and `ParseBuddyDB.lastEncounterSnapshot`.
- `/pb summary` prints the latest in-memory summary; `/pb summary auto on|off` controls account-wide automatic output, off by default. `/pb clear` also clears the completed summary without stopping an active accumulator.
- `/pb targets` prints active target-registry diagnostics and selection reason. It must remain debug-path-only and must not scan units or auras.

## Diagnostic Snapshot Lifecycle

- Capture the snapshot immediately before encounter state is reset on `ENCOUNTER_END`.
- Keep exactly one snapshot in memory and in `ParseBuddyDB`; use only scalar values, plain tables, and formatted strings safe for SavedVariables serialization.
- Retain the previous completed snapshot when a new encounter starts. Replace it only when the new encounter ends.
- Out of combat, `/pb dump` may fall back to the latest snapshot. `/pb snapshot` always prints the latest completed snapshot.
- The snapshot is diagnostic evidence, not the uptime summary. Do not add scoring, historical accumulation, or raw CLEU event storage.

## Deferred Optional Features

- Multiple boss UI sections, multi-boss summary aggregation, a graphical summary window, historical summaries, and persistence remain deferred. Do not turn summaries into player scoring, blame, ranking, or a full post-raid parser.
- Sounds, assignments, provider whispers, talent/spec inspection, additional groups, import/export, a configuration window, and player scoring remain deferred.
