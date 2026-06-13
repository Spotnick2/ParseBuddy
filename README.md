# ParseBuddy

**Your wingman for cleaner raid parses.**

ParseBuddy is an MVP World of Warcraft addon for TBC Anniversary. The implementation milestones are complete; supervised in-game acceptance is still required before treating it as raid-ready.

The AddOns settings entry currently presents a static UX prototype. Its controls use deterministic in-memory values and intentionally do not change or persist live addon settings yet.

The polished prototype uses explicit selected segments, visible custom sliders, compact alternating group rows, one Required checkbox per group, colored availability, readable disabled controls, a dark reading surface, a visible scrollbar, and a secondary Diagnostics disclosure row.

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
- Curse of Recklessness armor support
- Full List and Problems Only display modes
- Cached solo, party, and raid class capability checks for `NOT AVAILABLE` rows
- Optional transition-based missing-debuff broadcasts with conservative cooldowns
- Boss encounter display with visible-boss preference and a combat-log fallback when no boss unit is exposed
- Source player, stack, and timer information when available
- Dependency-free, event-driven combat handling

## Commands

Milestones 4 through 6 add encounter lifecycle, boss tracking, CLEU-driven live debuff rows, known-duration expiration, and opportunistic visible-boss aura resync. Missing groups remain gray during the pull grace period and turn red afterward. Active effects update immediately from combat-log aura events. If the client does not expose `boss1` through `boss5`, ParseBuddy can learn a provisional non-friendly NPC target from the first tracked non-removal aura event. This includes neutral encounter targets such as Midnight while continuing to reject players, pets, guardians, and friendly NPCs. A later destination whose localized name exactly matches the encounter name can replace that provisional target. Previously visible or encounter-matched bosses take precedence over newly discovered adds and can reclaim the display from their combat-log activity. `/pb test` is blocked during active encounters so fake rows cannot replace live data.

- `/pb` or `/parsebuddy`: open the static configuration prototype
- `/pb help`: show help
- `/pb test`: show the deterministic test frame
- `/pb mode problems`: use Problems Only during live encounters
- `/pb mode full`: use Full List during live encounters
- `/pb mode`: show the current display mode
- `/pb unavailable`: show whether Problems Only displays non-actionable `NOT AVAILABLE` rows
- `/pb unavailable show`: show `NOT AVAILABLE` rows in Problems Only for the active settings scope
- `/pb unavailable hide`: hide `NOT AVAILABLE` rows in Problems Only; this is the default
- `/pb broadcast`: show the active-scope settings used by the next encounter
- `/pb broadcast on|off`: enable or disable broadcasts for the active scope; off by default
- `/pb broadcast channel party|raid|leader`: select the exact destination
- `/pb broadcast delay <0-60>`: set the delay after pull grace before a missing group may alert
- `/pb broadcast test`: print a deterministic local-only test message out of combat
- `/pb profile`: show whether this character uses global or personal settings
- `/pb profile global`: use account-wide display and group settings
- `/pb profile personal`: use this character's settings; the first selection copies current global settings
- `/pb groups`: list every stable group key and its active-scope settings
- `/pb group <key>`: show one group's active-scope settings
- `/pb group <key> enable|disable`: change whether a group is evaluated and displayed
- `/pb group <key> required|optional`: change whether missing/grace is a problem in Problems Only
- `/pb summary`: print the most recently completed encounter's in-memory uptime summary
- `/pb summary auto on`: automatically print the summary when an encounter ends
- `/pb summary auto off`: disable automatic summary output; this is the account-wide default
- `/pb targets`: print configured encounter NPC IDs, accepted GUIDs, current primary, and selection reason
- `/pb roster`: print the cached roster members/classes and capability result for each group
- `/pb dump`: print explicitly labeled live diagnostics, or the completed snapshot when no encounter is active
- `/pb snapshot`: print the automatically captured diagnostic snapshot from the most recently completed encounter
- `/pb clear`: clear the in-memory and persisted diagnostic snapshot
- `/pb debugscan`: rescan tracked debuffs on currently visible `boss1` through `boss5` units
- `/pb validate`: verify every configured spell ID with the current client spell APIs
- Title-bar lock icon: toggle between movable and locked states
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
8. Complete: configuration UX discovery and static Blizzard settings prototype

## Non-Goals

- Warcraft Logs integration or external web access
- Post-fight parsing or scoring
- Sounds or raid-warning output
- Assignments or import/export
- External addon or framework dependencies

## Not Yet Implemented

- Wiring the configuration prototype to real global/personal settings and live addon behavior
- Named profiles beyond the implemented global account scope and personal per-character scope
- Additional optional debuff groups beyond Curse of Recklessness and boss-specific profiles
- Multi-boss display sections
- Sounds, raid-warning output, assignments, and import/export
- Multiple simultaneous boss UI sections, multi-boss uptime aggregation, and a graphical summary window
- Provider-specific whispers, assignments, talent/spec inference, and player responsibility tracking

## MVP In-Game Checks

- ParseBuddy appears in the addon list.
- The addon loads without Lua errors.
- `/pb` and `/parsebuddy` both show help.
- `/pb validate` reports the configured spell-ID total and identifies any IDs unavailable in the current client.
- ParseBuddy appears under Game Menu -> Options -> AddOns. `/pb` opens the same category while `/pb help` still prints commands.
- The configuration page clearly says `PROTOTYPE`, keeps version/scope visible above one scroll area, and has no custom tabs or Save/Apply button.
- Prototype controls update deterministic local values only. They reset after `/reload` and do not modify `ParseBuddyDB`, `ParseBuddyCharDB`, the encounter frame, or live combat behavior.
- Alert destination/delay/test controls visibly disable while prototype alerts are off, and Diagnostics starts collapsed.
- Selected scope/mode/destination choices are visually distinct from unselected choices. Scale, opacity, and delay sliders show a track, fill, thumb, and numeric value.
- Group rows are compact and aligned; Required checked means required, unchecked means optional. Availability is green, gray, or yellow for Available, Not Available, or Unknown.
- `/pb test` shows seven deterministic green, yellow, red, and gray preview rows.
- The frame can be dragged while unlocked.
- The title-bar lock icon changes between locked and unlocked images and toggles dragging; `/pb lock` and `/pb unlock` provide the same behavior.
- Frame position and lock state persist after `/reload`.
- `/pb reset` returns the frame to screen center at scale and opacity `1.00`.
- `/pb scale 0.6` and `/pb scale 1.4` resize the compact frame and persist after `/reload`.
- `/pb opacity 0.5` makes the frame translucent and persists after `/reload`.
- The close button hides the test frame.
- `/pb test` renders all seven monitored groups from deterministic evaluator state.
- Problems Only is the persisted default and hides healthy active rows while showing required missing/grace, partial, expiring, and unknown-source rows.
- Full List shows every enabled group, including healthy active rows.
- Roster availability is cached only on entering the world, roster changes, and encounter start. CLEU, the display ticker, and UI rendering never scan the roster.
- Missing or grace rows become gray `NOT AVAILABLE` when a complete cached roster has no baseline provider class. Incomplete roster information remains `unknown` and preserves normal missing/grace behavior.
- Active, partial, and expiring rows remain authoritative regardless of cached capability. ParseBuddy does not infer talents, specs, learned ranks, assignments, or player responsibility.
- Problems Only hides `NOT AVAILABLE` by default; `/pb unavailable show|hide` is scoped with global/personal settings. Full List always shows enabled unavailable rows.
- Broadcast settings are global/personal scoped and frozen at pull. They default off and apply only to enabled, required groups whose frozen roster capability is `available`.
- Broadcasts wait for pull grace plus the configured delay, announce once per missing period, and re-arm only after the group becomes active or expiring. Partial, optional, disabled, unavailable, unknown-roster, grace, active, and expiring rows never alert.
- Party, raid, and cached-leader routes never fall back to another channel. Unavailable routes are suppressed with conditional local debug output. Automatic messages contain group/effect text only, not roster member names.
- The display ticker and CLEU path never send chat. State-changing evaluations schedule a separate deferred callback, with a 30-second per-group cooldown and 5-second global spacing.
- `/pb mode problems` and `/pb mode full` switch immediately during an encounter and persist after `/reload`.
- Filtered rows compact without gaps, unused row slots stay hidden, and the frame height follows the visible row count.
- Global display/group settings live in `ParseBuddyDB`; personal display/group settings live in `ParseBuddyCharDB`.
- The first `/pb profile personal` copies the current global settings once. Later scope switching preserves independent edits in both stores.
- Frame position, scale, opacity, and lock state remain account-wide regardless of active profile scope.
- All groups default enabled. Curse of Recklessness defaults optional; the six original groups default required.
- Disabled groups are absent from both display modes. Optional missing/grace rows are hidden in Problems Only, while optional partial, expiring, and unknown-source rows remain visible.
- Encounter summaries track group-level satisfied, partial, and missing intervals after the pull grace period. Active and expiring count as satisfied; equivalent effects share one group timeline without false gaps.
- Summary settings are frozen at encounter start, including scope, display mode, enabled flags, and required flags. Mid-fight configuration changes do not rewrite the active summary.
- Summaries are single-primary-boss and memory-only. The latest summary is cleared by `/pb clear`, a new encounter, or `/reload`; diagnostic snapshots remain separately persisted.
- Automatic summary output is account-wide, off by default, and does not send raid messages.
- Encounter `655` Opera Hall uses a numeric target registry verified from the June 11, 2026 local combat log: Romulo NPC `17533` and Julianne NPC `17534`.
- Configured encounters accept registered NPC IDs and visible `boss1` through `boss5` GUIDs while rejecting arbitrary combat-log adds. Unconfigured encounters retain the generic fallback behavior.
- The single displayed primary is selected deterministically: visible `boss1`, first visible registered boss, most recently relevant registered boss, then the previous authoritative target. Registered target switches retain each boss's candidate state.
- Uptime remains single-primary in this version. Primary switches are retained as summary metadata but are not aggregated into a multi-boss result.
- Starting a supported encounter shows the primary boss and all seven live group rows. Visible `bossN` units are preferred, but a tracked combat-log boss target can seed the display when no unit is exposed.
- Missing groups are gray during pull grace and red afterward.
- Applying, refreshing, stacking, or removing a tracked boss debuff updates its group row immediately.
- Known-duration rows count down, turn yellow at the warning threshold, and become missing after expiration without requiring a removal event.
- `/pb debugscan` reports the number of visible boss units scanned and tracked auras found.
- A boss unit appearing with existing debuffs, or a missed earlier CLEU application, can recover tracked auras through a visible-unit scan.
- Expose Armor uses the client-reported timer when the boss is visible and does not invent a fixed duration otherwise.
- A boss disappearing from `boss1` through `boss5` is hidden without ending encounter state; a later tracked aura event on that known boss can reclaim the display.
- Encounter end hides the encounter frame.
- Encounter end automatically captures final raw candidates, final evaluations, and the last meaningful live evaluations before cleanup.
- Live dumps are labeled `LIVE`; out-of-combat dumps and `/pb snapshot` are labeled `COMPLETED SNAPSHOT` and report `active=no`.
- A short removal-batch debounce prevents terminal same-frame aura cleanup from replacing the retained live evaluation state. Ordinary removals settle after the batch delay while the encounter remains active.
- The snapshot survives `/reload`, remains available during the next pull, and is replaced only when another encounter ends or `/pb clear` is used.

## Live Acceptance Procedure

Run these checks after `/reload` with Lua errors enabled:

1. Run `/pb validate`. Record any missing IDs; expected client-specific failures must be investigated before the row is trusted.
2. Run `/pb test` in both saved display modes. Verify all seven deterministic rows remain visible because test mode deliberately bypasses live filtering, including the gray `NOT AVAILABLE` example.
3. Verify unlock, drag, lock, scale, `/pb reset`, and persistence across another `/reload`.
4. Run `/pb profile`, `/pb groups`, and `/pb group recklessness`. Verify the default is global and Recklessness is enabled/optional.
5. Set a distinctive global mode/group combination, switch to personal, and verify it was copied. Change the personal settings, switch back to global, and confirm the global values were preserved. Reload and verify the selected scope and both settings stores persist.
6. On a normal `boss1` encounter, use `/pb mode full` and verify every enabled row, source names, Sunder stacks, warning colors, and countdowns.
7. Disable a group and verify it disappears from both modes. Mark another group optional and verify its missing/grace row disappears only in Problems Only while partial, expiring, or unknown-source states remain visible.
8. Use `/pb mode problems`. Verify healthy green rows disappear; required missing/grace, partial, expiring, and unknown-source rows remain; unavailable rows are hidden by default; and the frame compacts without stale rows. Toggle `/pb unavailable show` and verify gray unavailable rows appear without affecting Full List.
9. Apply and remove each available tracked debuff. Confirm CLEU changes appear immediately and known timers expire without requiring a removal event.
10. Run `/pb debugscan` while the boss is visible. Confirm the boss count and tracked-aura count match the frame.
11. Run `/pb dump`. Confirm the primary GUID, scan reason, candidate expiration source, and visible evaluations match the boss.
12. Retest Magtheridon: a channeler may seed the provisional display, but Magtheridon must replace it when identified and CoE must remain active in that event tick.
13. On a phase transition, verify an unrelated add cannot replace a previously visible boss and relevant activity can reclaim the known boss.
14. End or wipe the encounter. Confirm the ticker stops and the frame hides without stale test or encounter rows.
15. After combat, run `/pb snapshot` and `/pb dump`. Confirm both show `COMPLETED SNAPSHOT`, `active=no`, final raw candidates, final evaluations, and the retained last meaningful live evaluations. Reload once and confirm the snapshot remains available, then clear it with `/pb clear`.
16. Run `/pb summary`. Confirm total duration, grace-excluded measured duration, frozen scope/mode, and per-enabled-group satisfied/partial/missing seconds and percentages.
17. Verify Sunder partial-to-five-stack and Sunder-to-Expose handoffs produce the expected group totals without a false missing gap. Let a known-duration effect expire without a removal event and confirm missing time begins at expiration.
18. Enable `/pb summary auto on`, complete or wipe an encounter, and confirm automatic output. Disable it afterward and verify `/pb clear` clears both the diagnostic snapshot and completed summary.
19. On Opera Hall encounter `655`, run `/pb targets`. Confirm configured NPC IDs `17533` and `17534`, accepted Romulo/Julianne GUIDs, current primary, and selection reason.
20. Apply a tracked debuff to each Opera boss. Confirm relevant activity can switch the single-primary display when no higher-priority visible target exists, both bosses retain independent candidates, and tracked effects on unregistered adds do not change the primary.
21. Run `/pb roster` while solo, in a party, and in a raid. Confirm cached members/classes and group capabilities match the roster. Remove the only provider for a group, wait for `GROUP_ROSTER_UPDATE`, and verify its missing/grace row becomes `NOT AVAILABLE` without any repeated roster scanning during combat.
22. Run `/pb broadcast` and confirm it is off by default. Configure a personal or global channel and delay, switch scopes, and verify both settings stores remain independent.
23. Out of combat, run `/pb broadcast test` and confirm it prints a clearly marked local-only message. Run it during combat and confirm it is blocked.
24. Enable broadcasts for a supervised pull. Verify a required, roster-available missing group alerts once after grace plus delay; optional, disabled, partial, `NOT AVAILABLE`, and unknown-capability groups do not alert. Apply the effect, remove it again, and verify re-alerting respects the 30-second group cooldown and 5-second global spacing.
25. Test party, raid, and leader routes. Confirm an unavailable requested destination is suppressed without falling back, and `/pb dump` shows frozen broadcast state and pending groups without exposing player names in automatic messages.

`/pb dump` metrics are cumulative for the current encounter. `cleu` counts accepted tracked aura events, `refreshes` counts display evaluations, `ticker` counts 0.2-second ticks, and `scans` is split by boss appearance, CLEU, and manual debug scans. A growing ticker count must not increase scan counts by itself.

The persisted diagnostic snapshot is separate from the in-memory uptime summary. The snapshot stores one bounded final raw view and one bounded last-meaningful live evaluation view plus encounter metadata in `ParseBuddyDB`. The uptime summary stores only interval totals for the latest completed encounter and is intentionally not written to SavedVariables. WoW writes snapshot SavedVariables during a clean `/reload`, logout, or client exit; an abrupt client crash may still lose the latest persisted copy.

Known-duration effects expire locally even if CLEU removal is missed. Visible boss auras are rescanned only when a boss unit appears, after relevant CLEU activity, or through `/pb debugscan`. The 0.2-second display ticker updates timers and expiration state only; it never scans auras. Variable-duration effects such as Expose Armor rely on client aura expiration data when a visible boss unit is available.

For local development, verified runtime files may be deployed directly to the TBC Anniversary `Interface\\AddOns\\ParseBuddy` directory. Reload the UI after Lua, TOC, or UI changes.
