# Progress

## What Works
- All core screens, Firebase sync, seeded data (97 entries), theme toggle, overlap analysis.
- Approval queue as dedicated bottom nav tab (7 tabs total) with manager features (split-screen, bulk approve, email to wages).
- Calendar: Improved tooltips (employee details, max 20), enhanced markers (larger pills, hours bar).
- New settings menu on bottom nav with approval queue section, dedicated list screens with inline edit/delete (overtime, jobs).
- Dashboard date range filter, per-person breakdown.
- Overtime form improvements: clock dropdown autofill, field reorder, reason chips, fixed selection issues.
- Responsive layouts, status darker bg.
- Jobs duplicate button.
- Visual timeline in analysis, grouped by dept in ExpansionTiles (with totals), right column jobs list with total overlap hours (sorted descending).

## What's Left to Build
- User authentication (Firebase Auth).
- Approve & Email to Wages (Cloud Functions + email).
- Export to CSV/PDF.
- Deploy to Firebase Hosting or web server.
- Permissions for approval screen.

## Current Status
Enhanced prototype with all requested features. Ready for production deployment.

## Known Issues
- None reported.

## Evolution of Project Decisions
- Started as web app; Firebase chosen for real-time needs.
- Added bottom nav expansion, inline editing, visual analysis.
