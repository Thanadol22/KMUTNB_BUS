# kmutnb_bus

## Project Structure and Rules

**🚨 AI Assistant & Developer Rules:**
1. **Always read this project structure before modifying or adding files.**
2. **Follow the designed architecture strictly.** Do not place files outside of their designated domains.
3. **Use the predefined services and models** instead of creating redundant ones.

```text
lib/
├── core/                     # Shared across the whole project
│   ├── constants/            # Constants (Colors, Fonts, API Keys)
│   ├── theme/                # Theme management (Light/Dark mode)
│   ├── utils/                # Helper functions (e.g., Time formatting)
│   └── services/             # External connections
│       ├── firebase_auth.dart       # Login/Registration
│       ├── firebase_database.dart   # Realtime Database for ESP coordinates
│       └── location_service.dart    # GPS permissions and usage
│
├── features/                 # Core app features
│   ├── auth/                 # Authentication
│   │   ├── screens/          # Login, Register pages
│   │   └── widgets/          # Forms, Buttons
│   ├── student/              # Student features
│   │   ├── map/              # Realtime Map & ETA
│   │   ├── schedule/         # Bus schedules
│   │   └── report/           # Issue reporting
│   ├── driver/               # Driver features
│   │   ├── status/           # Bus status (Ready, Maintenance)
│   │   ├── tickets/          # Ticket reporting
│   │   └── notifications/    # 15-min alerts
│   └── settings/             # Settings and Account management
│       └── screens/          # Profiles, Change Language
│
├── models/                   # Data Models
│   ├── user_model.dart       # User data and Roles (Student/Driver)
│   ├── bus_model.dart        # Bus status and coordinates
│   └── ticket_report.dart    # Ticket report data
│
├── routes/                   # Navigation/Routing
│   └── app_router.dart       
│
├── app.dart                  # Main app wrapper (MaterialApp)
└── main.dart                 # Entry point (Firebase.initializeApp)
```
