# Tests

Automated evaluator tests run under Lua 5.1 without WoW APIs:

```powershell
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_state.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_encounter.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_events.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_dump.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_ui.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_integration.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_resync.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_core.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_validation.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_snapshot.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_config.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_summary.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_targets.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_roster.lua
```

The first test target will be the debuff group evaluator, kept independent from the game client. Normalized fixtures derived from archived combat logs may be used to validate aura event shapes and stack transitions without uploading or bundling the original logs.

The tests use no external dependencies. Future integration tests may mock the small subset of WoW APIs used by ParseBuddy.
