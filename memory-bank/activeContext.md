# Active Context

## Current Work Focus
- Prototype complete; preparing for production. Added new features: settings menu, dedicated list screens, dashboard filters, form improvements, visual analysis, enhanced calendar.

## Recent Changes
- Added Approval as 6th bottom nav tab (before Settings), making 7 tabs total.
- Updated calendar_view_screen.dart: Improved tooltips (employee clock-name-dept, max 20), enhanced markers (larger pills, horizontal bar for hours).
- Created overtime_entries_list_screen.dart: DataTable with inline edit/delete.
- Created jobs_list_screen.dart: Similar for jobs.
- Created approval_screen.dart: Pending OT approval/rejection with manager features (split-screen layout, bulk approve, email to wages).
- Updated dashboard: date range filter (All/Prev Week/Month/Custom), per-person breakdown.
- Updated overtime_form.dart: clock dropdown autofill name, shift/ot above dates, reason chips + add, fixed Autocomplete controller issues, added department normalization.
- Updated overtime_screen.dart: responsive Row/Column, status darker bg in list, fixed form population on entry selection.
- Updated jobs_screen.dart: added duplicate button.
- Updated job_analysis_screen.dart: visual timeline for overlaps, grouped by dept in ExpansionTiles (with totals), right column jobs list with total overlap hours (sorted descending).
- Updated settings_screen.dart: added approval queue section with approve/reject functionality.
- Added delete methods to DataService, getEmployees, copyWith to models.

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
