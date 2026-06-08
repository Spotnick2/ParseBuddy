# Tests

Future automated tests will run under Lua 5.1 and mock the small subset of WoW APIs used by ParseBuddy.

The first test target will be the debuff group evaluator, kept independent from the game client. Normalized fixtures derived from archived combat logs may be used to validate aura event shapes and stack transitions without uploading or bundling the original logs.

Milestone 1 intentionally does not include a test runner or external test dependencies.
