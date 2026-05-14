# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CTP Gravure Overtime Tracker** is a Flutter Web application for managing overtime entries and job scheduling. Built with Firebase backend, it features manager authentication, split-screen data entry, and job overlap analysis.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run web app (development, hot reload enabled)
flutter run -d chrome

# Build for web production
flutter build web

# Run tests
flutter test

# Format code
dart format lib/

# Static analysis
flutter analyze
```

## Key Architecture

### Authentication & Role-Based Access

**Manager-Only Access Pattern:**
- Firebase Auth handles email/password authentication
- `UserProvider` (in `main.dart`) manages auth state and loads manager profiles from Firestore
- `AuthWrapper` redirects unauthenticated users to `LoginScreen`
- Upon login, app queries `employees` collection for matching UID with `position == "Manager"`
- Only managers with matching Firestore profiles can access the app; non-managers are signed out with error

**Department-Based Filtering:**
- Each manager's department is loaded from their employee profile
- `OvertimeScreen` restricts edits: managers can only edit entries from their own department
- Read-only viewing of other departments' entries is supported (detected via `_isReadOnly` flag in `OvertimeFormPanel`)

### Data Layer

**Collections Structure:**
- `employees`: User profiles (name, clockNo, department, email, uid, position)
- `overtime_entries`: Overtime records with full audit trail (clockNum, employeeName, press, date, startTime, endTime, department, reason, status, dateEntered, enteredBy, overtimeNumber)
- `jobs`: Job schedules (duNumber, jobName, startDateTime, endDateTime, press)
- `reasons`: Overtime reason templates (reason, createdBy, createdAt)
- `counters`: Auto-incrementing counters (used for `overtime_entries` numbering via transaction)

**Data Models:**
- `User` (id, name, clockNum, department, email, isManager, hiddenReasons)
- `OvertimeEntry` (id, duNumber, clockNum, employeeName, press, date, shiftType, overtimeType, startTime, endTime, department, reason, description, status, dateEntered, enteredBy, overtimeNumber)
- `Job` (id, duNumber, jobName, startDateTime, endDateTime, press)

### State Management

**Provider Pattern:**
- `ThemeProvider`: Dark/light mode toggle
- `UserProvider`: Current logged-in user, auth errors, loading state
- Both wrapped in `MultiProvider` at app root (`main.dart`)

**Data Fetching:**
- `DataService` (static class) handles all Firestore operations
- Supports both `Future` (one-time fetch) and `Stream` (real-time updates) patterns
- `OvertimeScreen` uses `getFilteredOvertimeStream()` for real-time list updates filtered by department and status
- `DashboardScreen` uses `FutureBuilder` for one-time data loads with date range filtering

### UI Architecture

**Split-Screen Layouts (Responsive):**
- `OvertimeScreen` and `JobsScreen` use `LayoutBuilder` to switch between `Row` (wide) and `Column` (mobile) layouts
- Breakpoint: 800px width threshold
- Form on left, list on right (when wide); form stacked on top (when narrow)

**Navigation:**
- `MainNavigation` stateful widget with 7 bottom tabs
- Lazy-loaded screens: Dashboard, Overtime, Jobs, Job Analysis, Calendar, Approval, Settings

**Key Screens:**
- **Dashboard**: Summary stats (total hours, people count, pending approvals) with employee breakdown by department
- **Overtime**: Split-screen form + list with department/status filtering; supports add new, edit, duplicate, and cancel (never delete—audit trail)
- **Jobs**: Job entry form + list for job scheduling
- **Job Analysis**: Shows overtime entries overlapping with selected job (by press or DU number); calculates overlap hours
- **Approval**: Manager approval workflow for pending overtime entries; bulk approve; reject moves to Cancelled status
- **Calendar & Settings**: Placeholder screens for future expansion

### Key Business Logic

**Overlap Calculation:**
- `DataService.getOverlappingOvertime(Job job)` finds all overtime entries overlapping with a job
- Match logic: press match OR job DU number match (not both required)
- Returns list of overlaps with overlap duration, start/end times, and match type

**Overtime Status Workflow:**
- Pending → Approved (via Approval screen)
- Pending → Cancelled (user cancel or rejection)
- Status field drives UI filtering (e.g., Overtime list defaults to "Pending" only)

**Department Access Control:**
- Managers see only their department's entries by default
- In `OvertimeListPanel`, `currentUserDept` from `UserProvider` is always used for stream filter (not a dropdown)
- Form read-only when editing entries from other departments

### Firebase Configuration

- Project ID: `ctp-job-cards`
- Auth domain: `ctp-job-cards.firebaseapp.com`
- API key and other credentials in `firebase_options.dart`
- Web platform only (currently)

## Theme & Styling

**AppTheme** (in `theme/app_theme.dart`):
- Primary orange: `Color(0xFFFF6B35)` / `Colors.orange`
- Badenia green accent: `Color(0xFF4CAF50)`
- Wifag yellow accent: `Color(0xFFFF9800)`
- Aurora blue accent: `Color(0xFF2196F3)`
- Supports light and dark themes with Material 3 color scheme

## Dependencies

- **Provider**: State management
- **Firebase Core, Auth, Firestore**: Backend and authentication
- **UUID**: Unique ID generation for entries and jobs
- **Table Calendar**: Calendar widgets
- **FL Chart**: Charts and graphs
- **Intl**: Date/time formatting

## Common Workflows

**Adding an Overtime Entry:**
1. User selects date, employee, times, shift/OT type in form (`OvertimeForm` widget)
2. Clicks save → calls `DataService.addOvertime()` → creates Firestore doc
3. Auto-generates `overtimeNumber` via `getNextOvertimeNumber()` transaction
4. Entry appears in list stream immediately (real-time update)

**Approving Overtime:**
1. Manager navigates to Approval screen
2. Views pending entries in table (filtered by `status == 'Pending'`)
3. Clicks Approve → updates entry status to "Approved" in Firestore
4. Bulk approve via "Approve All" button

**Analyzing Job Overlaps:**
1. Select job from dropdown on Job Analysis screen
2. App calculates overlapping overtime entries (same press OR same DU)
3. Displays grouped by department with overlap hours

## Development Notes

- **No deletion**: Overtime and job entries are never hard-deleted; cancelled entries retain audit history
- **Reason management**: Overtime reasons are loaded real-time from `reasons` collection via `getReasonsStream()`
- **Server-side filtering**: `getFilteredOvertimeStream()` pushes department/status filters to Firestore query (more efficient than client-side filtering)
- **Firestore limits**: All queries capped (e.g., `limit(1000)` for entries, `limit(50)` for approval stream) to avoid excessive data transfer; consider pagination for production scale
- **Error handling**: Login screen shows Firebase Auth exceptions with user-friendly messages; DataService methods throw exceptions that bubble to UI FutureBuilder/StreamBuilder error handlers
- **Dark mode**: Toggle in AppBar persists to `ThemeProvider` during session (no persistent storage yet)

## Next Steps (Not Yet Implemented)

- Approve & email to wages (Cloud Functions integration)
- CSV/PDF export
- Production Firebase Hosting deployment
- Employee vs Manager role distinction beyond auth
- Calendar view implementation
- Settings screen features

