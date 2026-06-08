# Versioning

ParseBuddy uses Chromium-style four-part versions:

`MAJOR.MINOR.BUILD.PATCH`

- **MAJOR** changes for incompatible product or saved-data changes.
- **MINOR** changes for a new release line or materially expanded scope.
- **BUILD** increments for each completed development milestone.
- **PATCH** increments for fixes or follow-up iterations within the current milestone.

The first milestone is `0.1.1.0`. Planned MVP milestone versions are `0.1.2.0` through `0.1.7.0`. A fix after Milestone 2 would use `0.1.2.1`.

`ParseBuddy.toc` is the authoritative version source. Lua code should read the version using addon metadata instead of maintaining a second constant.
