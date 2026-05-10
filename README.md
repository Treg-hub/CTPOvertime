# CTP Gravure Overtime Tracker

**Browser-first Flutter Web app** for managing overtime with smart job overlap analysis.

## Features
- Split-screen Overtime Entry + List (Add New / Duplicate / Edit on click)
- Same split pattern for Jobs management
- Job Overtime Analysis with automatic overlap calculation (press match first, then job number)
- Full support for custom start/end times
- Light + Dark mode toggle
- Matches your existing CTP job cards colour scheme (Badenia green, Wifag orange, Aurora blue)
- **Secure Firebase Authentication** for Manager logins (added April 2026)

## Setup (on your machine)

1. Make sure you have Flutter installed (https://flutter.dev)
2. Run these commands:

```bash
cd ctp_overtime_tracker
flutter pub get
flutter run -d chrome
```

## Data & Backend
- **Firebase Firestore Integration**: Real-time data storage for jobs and overtime entries.
- **Firebase Authentication**: Secure email/password login for managers only. Profiles synced from `employees` collection.
- **Async Data Loading**: All screens load data asynchronously with loading states.

## Production Setup Notes
1. **Firebase Console**:
   - Enable Email/Password sign-in method in Authentication.
   - Create manager accounts in Authentication > Users (email + password).
   - In Firestore, ensure matching documents in `employees` collection with:
     - `email` matching the Auth email
     - `position`: "Manager"
     - Other fields: name, clockNo, department, etc.
2. **Security**: Passwords are now handled securely by Firebase Auth (no plain-text passwords in Firestore).

## Next Steps (Production)
- Implement "Approve & Email to Wages" (Cloud Functions + email)
- Add export to CSV/PDF
- Deploy to Firebase Hosting or your web server
- Add role-based access (e.g., Employee vs Manager views)

## Current Status
Fully functional app with Firebase backend, and secure authentication. All core screens and logic implemented exactly as per your final mockups. Ready for production deployment.

**Recent Update (April 25, 2026)**: Integrated Firebase Authentication for secure manager login, replacing insecure plain-password check. App now persists login sessions and uses proper auth state management.

Built with ❤️ for CTP Gravure
