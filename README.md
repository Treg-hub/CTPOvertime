# CTP Gravure Overtime Tracker

**Browser-first Flutter Web app** for managing overtime with smart job overlap analysis.

## Features
- Split-screen Overtime Entry + List (Add New / Duplicate / Edit on click)
- Same split pattern for Jobs management
- Job Overtime Analysis with automatic overlap calculation (press match first, then job number)
- Full support for custom start/end times
- Light + Dark mode toggle
- Matches your existing CTP job cards colour scheme (Badenia green, Wifag orange, Aurora blue)

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
- **Async Data Loading**: All screens load data asynchronously with loading states.

## Next Steps (Production)
- Add user authentication (Firebase Auth)
- Implement "Approve & Email to Wages" (Cloud Functions + email)
- Add export to CSV/PDF
- Deploy to Firebase Hosting or your web server

## Current Status
Fully functional app with Firebase backend and seeded test data. All core screens and logic implemented exactly as per your final mockups. Ready for production deployment.

Built with ❤️ for CTP Gravure
