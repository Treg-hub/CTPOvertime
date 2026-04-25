# Active Context

## Current Work Focus
- Prototype complete; preparing for production. Added new features: settings menu, dedicated list screens, dashboard filters, form improvements, visual analysis, enhanced calendar.

## Recent Changes
- Added Approval as 6th bottom nav tab (before Settings), making 7 tabs total.
- Updated calendar_view_screen.dart: Improved tooltips (employee clock-name-dept, max 20), enhanced markers (larger pills, horizontal bar for hours).
- Created overtime_entries_list_screen.dart: DataTable with inline edit/delete, added Date Entered and Entered By columns.
- Created jobs_list_screen.dart: Similar for jobs.
- Created approval_screen.dart: Pending OT approval/rejection with manager features (split-screen layout, bulk approve, email to wages).
- Updated dashboard: date range filter (All/Prev Week/Month/Custom), per-person breakdown.
- Updated overtime_form.dart: clock dropdown autofill name, shift/ot above dates, reason chips + add, fixed Autocomplete controller issues, added department normalization, auto-set audit fields, default press to None, department moved below clock number, auto-update end date based on shift type when start date selected.
- Updated overtime_screen.dart: responsive Row/Column, status darker bg in list, fixed form population on entry selection, added initialEntry parameter for editing from lists, sorted overtime list from newest to oldest (100 most recent entries).
- Updated settings_screen.dart: compact approval queue table with abbreviated headers, always-visible Approve/Reject buttons (optimized sizing to prevent overflow), collapsible sections, row tap opens edit dialog, optimized loading (only pending entries), full browser width expansion with LayoutBuilder and ConstrainedBox.
- Updated DataService: added getPendingOvertime() for efficient approval queue loading, added getRecentOvertime() and getRecentOvertimeStream() with 25-entry limit for fast loading, sorted by startTime descending.
- Updated overtime_entries_list_screen.dart: switched to StreamBuilder for real-time updates, no manual reload needed after delete operations.
- Updated overtime_entries_list_screen.dart: compact table with abbreviated headers, always-visible Edit/Delete buttons, removed inline editing mode, row tap opens edit dialog.
- Updated jobs_screen.dart: added duplicate button.
- Updated job_analysis_screen.dart: visual timeline for overlaps, grouped by dept in ExpansionTiles (with totals), right column jobs list with total overlap hours (sorted descending).
- Updated settings_screen.dart: added approval queue section with approve/reject functionality.
- Added authentication system: LoginScreen, UserProvider, User model, logout in app bar.
- Added audit fields to OvertimeEntry: dateEntered (serverTimestamp), enteredBy (current user).
- Added delete methods to DataService, getEmployees, copyWith to models.
- Fixed overtime sorting by changing FutureBuilder to StreamBuilder with limit 50, ordered by startTime desc.
- Removed console freeze by removing print in OvertimeList.
- Fixed reason chips duplicates by adding unique and sort.
- Added department filter with dynamic depts from entries.
- Removed seed data reference from package.json.
- Added hiddenReasons to User model, persist remove via Firestore arrayUnion.
- Clear form after save.
- Fixed null reason error in _loadUsedReasons.
- Put department and press side by side.
- Load 135 employees for autocomplete.

## Active Decisions and Considerations
- Provider for theme; async data loading everywhere.
- Inline edit uses copyWith for immutability.
- Responsive layouts for small screens.
- Permissions for approval later.

## Important Patterns and Preferences
- Split-screen UI for entry/list; Firebase for persistence.
- DataTable for lists with edit/delete.
- Chips for presets, dropdowns for enums.

## Learnings and Project Insights
- Flutter web responsive; Firestore real-time effective.
- TableCalendar markers customizable for visual indicators.
- LayoutBuilder for responsive design.
