# Rafiq – Mobile Application

A cross-platform mobile application connecting people with disabilities and elderly users to verified caregivers, doctors, interpreters and accessible transport.

Note: This project is primarily designed for use in Egypt and may not be fully suitable for other regions due to localization, service availability and infrastructure differences.

**Features**

- User registration and login
- Personalized disability profiles
- Service browsing and booking (caregivers, doctors, interpreters, drivers)
- Community-driven accessibility map with user reviews
- Ratings and feedback system

**Tech Stack**

- Flutter / Dart
- PHP (backend API)
- PostgreSQL (pgAdmin)

## Getting Started

**Prerequisites**

Flutter SDK installed
PostgreSQL installed and running
A PHP server (e.g. XAMPP or WAMP) to host the backend API files

**Setup**

Step 1: Clone the repository

```git clone https://github.com/jomaanaa/rafiq-application.git```

Step 2: Install dependencies

```flutter pub get```

Step 3: Set up the database — import the provided SQL file into PostgreSQL to create all required tables and schema

```psql -U postgres -d rafiq -f database/rafiq_db.sql```

Step 4: Host the PHP files on your local PHP server and update the API base URL in the app to point to your server address, then run the app

```flutter run```
