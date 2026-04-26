# Active Context

## Current Work Focus
- Prototype complete; preparing for production. Added new features: settings menu, dedicated list screens, dashboard filters, form improvements, visual analysis, enhanced calendar.

## Recent Changes
- Added "Save & Duplicate" button in overtime form panel header. Saves current entry, creates duplicate with all fields copied, loads duplicate into form for quick entry of multiple employees same day.
- Added multi-select employee support in overtime form: Chips for selected employees, autocomplete filtered by overtime list dept selection. Save creates one entry per selected employee with identical details.
- Updated overtime_form.dart: Made OvertimeFormState public, added validateForm() and getCurrentEntry() methods for panel access.
- Updated overtime_screen.dart: Added GlobalKey for form state, _saveAndDuplicate method, and button with loading state.
- Added Approval as 6th bottom nav tab (before Settings), making 7 tabs total.
- Updated calendar_view_screen.dart: Improved tooltips (employee clock-name-dept, max 20), enhanced markers (larger pills, horizontal bar for hours).
- Created overtime_entries_list_screen.dart: DataTable with inline edit/delete, added Date Entered and Entered By columns.
- Created jobs_list_screen.dart: Similar for jobs.
- Created approval_screen.dart: Pending OT approval/rejection with manager features (split-screen layout, bulk approve, email to wages).
- Updated dashboard: date range filter (All/Prev Week/Month/Custom), per-person breakdown.
- Updated overtime_form.dart: clock dropdown autofill name, shift/ot above dates, reason chips + add, fixed Autocomplete controller issues, added department normalization, auto-set audit fields, default press to None, department moved below clock number, auto-update end date based on shift type when start date selected.
- Made Overtime Entry form significantly more compact: Replaced 4 separate date/time fields with 2 combined DateTime fields using native showDatePicker + showTimePicker in sequence (beautiful dialogs), reduced Description to maxLines: 3, reduced vertical spacing from 16 to 12, reduced panel padding from 24 to 16.
- Further compacted Overtime Entry form: Put Start/End DateTime side-by-side in one row, replaced Reason Category TextField with dropdown + [+] button opening dialog for category+description input, removed suggestion chips and add new row, repositioned Description field to bottom above save buttons, custom DateTime picker dialog with CalendarDatePicker left and hour/minute dropdowns right.
- Updated employee selection in overtime form: Replaced Autocomplete with dropdown-style field opening dialog with search TextField and CheckboxListTile for multi-select, filtered by department selected in overtime list screen. Made clock number search case-insensitive.
- Updated [+] button next to Reason Category: Now directly adds the typed reason to suggestions without dialog, brought back reason chips below for quick selection. Added SnackBar feedback for empty input, login required, already exists, success, or failure.
- Improved DateTime picker dialog: Changed to vertical layout with date picker at top, time picker below, clean padding. Moved hour and minute dropdowns horizontal (side-by-side).
- Added delete button to overtime list entries: IconButton with confirmation dialog for deleting entries.
- Updated overtime_screen.dart: responsive Row/Column, status darker bg in list, fixed form population on entry selection, added initialEntry parameter for editing from lists, sorted overtime list from newest to oldest (100 most recent entries).
- Updated settings_screen.dart: compact approval queue table with abbreviated headers, always-visible Approve/Reject buttons (optimized sizing to prevent overflow), collapsible sections, row tap opens edit dialog, optimized loading (only pending entries), full browser width expansion with LayoutBuilder and ConstrainedBox.
- Updated DataService: added getPendingOvertime() for efficient approval queue loading, added getRecentOvertime() and getRecentOvertimeStream() with 25-entry limit for fast loading, sorted by startTime descending.
- Updated overtime_entries_list_screen.dart: switched to StreamBuilder for real-time updates, no manual reload needed after delete operations.
- Updated overtime_entries_list_screen.dart: compact table with abbreviated headers, always-visible Edit/Delete buttons, removed inline editing mode, row tap opens edit dialog.
- Updated jobs_screen.dart: added duplicate button.
- Updated job_analysis_screen.dart: visual timeline for overlaps, grouped by dept in ExpansionTiles (with totals), right column jobs list with total overlap hours (sorted descending).
- Updated settings_screen.dart: added approval queue section with approve/reject functionality.
- Added authentication system: LoginScreen, UserProvider, User model, logout in app bar.
- Fixed Firebase Auth integration: resolved User name conflicts with alias, improved AuthWrapper for persistent login with auto-profile fetch from employees collection, updated login flow to use firebase email, added error handling for invalid managers.
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
