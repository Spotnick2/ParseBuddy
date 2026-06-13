# ParseBuddy Configuration UX

## Discovery Findings

### Client API

The installed TBC Anniversary client and multiple installed addons expose the modern canvas API:

- `Settings.RegisterCanvasLayoutCategory`
- `Settings.RegisterAddOnCategory`
- `Settings.OpenToCategory`

ParseBuddy should prefer that path. It should retain `InterfaceOptions_AddCategory` and `InterfaceOptionsFrame_OpenToCategory` as a legacy fallback because Priestly, Apotheca, and other installed addons already use this compatible dual path.

### Priestly

Priestly uses a custom three-tab panel with separate scroll frames, globally named widgets, long vertical forms, explanatory copy inline with controls, and large instance checkbox matrices.

Reusable ideas:

- dual modern/legacy registration and opening
- standard Blizzard checkbox, radio, slider, and button templates
- a lazily built canvas

Patterns not to copy:

- tabs inside the AddOns settings canvas
- multiple nested scroll containers
- controls organized around storage or expansion rather than user tasks
- globally named widgets when anonymous frames are sufficient
- long descriptions consuming the primary visual hierarchy

### Apotheca

Apotheca uses four custom tabs, one scroll frame per tab, repeated tinted boxes, a mutable vertical cursor, and immediate SavedVariables writes from widget callbacks.

Reusable ideas:

- lazy content construction
- compact helper functions for repeated controls
- subordinate controls that visually disable with a master toggle

Patterns not to copy:

- a tab strip competing with Blizzard's settings navigation
- excessive section bars and nested background boxes
- a dropdown for small two- or three-choice sets
- every control triggering broad addon layout updates
- settings state, widget rendering, and live behavior tightly coupled in one file

## Information Architecture

The panel is one scrollable task-oriented page beneath a fixed header.

1. Display
2. Debuff Groups
3. Alerts
4. Summary
5. Diagnostics, collapsed by default

The header always shows the addon version, active settings scope, and an explicit `Changes apply immediately` notice.

## Textual Wireframe

```text
ParseBuddy                                         v0.1.x
Changes apply immediately
Scope: [ Global ] [ Personal ]
-----------------------------------------------------------
Display
Mode:  [ Problems Only ] [ Full List ]
[ ] Show unavailable   [x] Lock frame
Scale  [-----o---] 0.80     Opacity [------o--] 0.90
[ Test Frame ] [ Reset Position ]

Debuff Groups
Group                     Enabled   Requirement     Availability
Spell Vulnerability        [x]      [Required][Optional] Available
...

Alerts
[ ] Enable broadcasts
Destination: [ Party ] [ Raid ] [ Leader ]
Delay: [---o------] 3 sec              [ Test Alert ]

Summary
[ ] Print encounter summary automatically

> Diagnostics
  [ Validate Spell IDs ] [ Roster ] [ Debug Scan ] [ Dump ]
  [ ] Debug output
```

## Control Behavior

- Scoped values use `ParseBuddyDB.settings` or `ParseBuddyCharDB.settings` through `ParseBuddy.Config`.
- Global/Personal switches the live scope. First use of Personal copies current Global settings; later switching preserves both stores.
- Frame lock, scale, opacity, and position remain account-wide in `ParseBuddyDB.frame`.
- Summary automatic output and debug output remain account-wide.
- Problems Only/Full List and Party/Raid/Leader use the same selected/unselected segmented styling rather than dropdowns.
- Each group uses one compact `Required` checkbox; unchecked means Optional.
- Scale, opacity, and alert delay use custom dependency-free tracks with visible fill, thumb, and numeric value.
- Group rows use alternating subtle backgrounds and availability text is green, gray, or yellow.
- Availability reads the existing roster cache and repaints after cache refresh events; panel rendering never scans roster units.
- Alert destination, delay, and test controls are disabled when alerts are off.
- Diagnostics are collapsed by default and visually secondary.
- Action buttons call the same guarded module APIs as their slash-command equivalents.
- No Save or Apply button is present.
- `/pb` opens the panel. `/pb help` remains the command reference.

## Acceptance Checklist

- The panel appears under Options -> AddOns -> ParseBuddy.
- Modern registration is preferred; legacy registration remains functional.
- `/pb` opens the registered category.
- The active scope and immediate-apply notice remain visible while scrolling.
- The page uses one scroll container and no custom tabs.
- Display choices and every group row update the active settings scope immediately.
- Alert subordinate controls disable when alerts are off.
- Diagnostics start collapsed and can be expanded without rebuilding the panel.
- Account-wide and personal values persist in their documented SavedVariables stores.
- Existing explicit slash commands and panel controls remain behaviorally equivalent.

## Screenshot Review And Polish

The first in-game prototype proved the API and layout architecture, but exposed several visual problems:

- Blizzard red button templates made both selected and unselected choices look active.
- `OptionsSliderTemplate` rendered a thumb without a readable track in this client.
- Paired Required/Optional buttons overwhelmed the group table.
- Disabled Alerts controls were too dim to read.
- The large red Diagnostics button looked like a primary or destructive action.

The polished prototype replaces those patterns with explicit gold/dark segments, custom sliders, one Required checkbox, readable disabled styling, alternating compact rows, colored availability, and a low-emphasis disclosure row.

The second in-game review showed that the game world remained too visible through the settings surface, disabled alert choices lost too much contrast, and the default scroll thumb and diagnostic action buttons still competed with the settings hierarchy. The follow-up uses a darker reading surface, a visible gold scroll thumb, stronger disabled styling, and neutral diagnostic actions.

Standalone segmented actions must apply their neutral style when created. They must not render with an uninitialized white backdrop until first interaction.
