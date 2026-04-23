# Active Context

## Current Work Focus
- Prototype complete; preparing for production. Added new features: settings menu, dedicated list screens, dashboard filters, form improvements, visual analysis, enhanced calendar.

## Recent Changes
- Added 6th bottom nav tab: Settings, with navigation to new list screens (overtime entries, jobs, approval).
- Created overtime_entries_list_screen.dart: DataTable with inline edit/delete.
- Created jobs_list_screen.dart: Similar for jobs.
- Created approval_screen.dart: Pending OT approval/rejection.
- Updated dashboard: date range filter (All/Prev Week/Month/Custom), per-person breakdown.
- Updated overtime_form.dart: clock dropdown autofill name, shift/ot above dates, reason chips + add.
- Updated overtime_screen.dart: responsive Row/Column, status darker bg in list.
- Updated jobs_screen.dart: added duplicate button.
- Updated job_analysis_screen.dart: visual timeline for overlaps + reason below.
- Updated calendar_view_screen.dart: improved pill visibility, added total people count.
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
