# System Patterns

## System Architecture
- Provider state management (ThemeProvider, UserProvider).
- Models: Job, OvertimeEntry, User (with hiddenReasons).
- Services: data_service.dart (Firebase CRUD).
- Screens: Self-contained with widgets (e.g., overtime_form, job_list).
- BottomNavigationBar routing.

## Key Technical Decisions
- Firebase for backend; no local storage yet.
- Async data loading with loading states.
- UUID for unique IDs.

## Design Patterns in Use
- Provider for global state (theme).
- Split-screen layout for CRUD operations.

## Component Relationships
- Screens use widgets for forms/lists.
- data_service handles all Firebase interactions.

## Critical Implementation Paths
- Firebase init in main.dart; data loading in screens.