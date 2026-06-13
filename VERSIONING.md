# Versioning

ParseBuddy uses Chromium-style four-part versions:

`MAJOR.MINOR.BUILD.PATCH`

- **MAJOR** changes for incompatible product or saved-data changes.
- **MINOR** changes for a new release line or materially expanded scope.
- **BUILD** increments for each completed development milestone.
- **PATCH** increments for fixes or follow-up iterations within the current milestone.

The first milestone is `0.1.1.0`. Planned MVP milestone versions are `0.1.2.0` through `0.1.7.0`. A fix after Milestone 2 would use `0.1.2.1`.

The completed MVP implementation line is `0.1.7.0`. Follow-up acceptance fixes increment PATCH: persisted frame opacity shipped in `0.1.7.1`, the bounded hybrid diagnostic snapshot shipped in `0.1.7.2`, neutral encounter-target fallback support shipped in `0.1.7.3`, the lock control and Curse of Recklessness group shipped in `0.1.7.4`, completed-snapshot live-state preservation shipped in `0.1.7.5`, live display modes shipped in `0.1.7.6`, global/personal group settings shipped in `0.1.7.7`, in-memory encounter uptime summaries shipped in `0.1.7.8`, the numeric multi-boss target registry shipped in `0.1.7.9`, cached roster-aware debuff availability shipped in `0.1.7.10`, optional missing-debuff broadcasts shipped in `0.1.7.11`, the static configuration UX prototype shipped in `0.1.7.12`, screenshot-driven prototype UX polish shipped in `0.1.7.13`, and the second in-game contrast and hierarchy pass shipped in `0.1.7.14`.

`ParseBuddy.toc` is the authoritative version source. Lua code should read the version using addon metadata instead of maintaining a second constant.
