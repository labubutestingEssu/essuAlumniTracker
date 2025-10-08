# ESSU Alumni Tracker

An alumni tracking and analytics application for Eastern Samar State University.

## User Roles & Capabilities

**Alumni User Capabilities**

• Register/Login – Sign up or log in using credentials validated by the system.
• Update Profile – Input and maintain personal information, current employment, location, and educational background.
• Answer Alumni Survey – Fill out the ESSU Alumni Tracer Survey to provide data on employment and skill usage.

**College/Program Admin Capabilities**

• Create Default Alumni Account – Generate default system accounts for newly graduating or existing alumni of their college.
• View Alumni Data – Access detailed lists and profiles of alumni from their college/program.
• Generate College Reports – Create program-specific analytics reports (e.g., graduate employment rates, tracer survey completion, skills feedback).
• Review Survey Responses – Track and analyze ESSU Alumni Tracer Survey submissions from their alumni.
• Export Alumni Data – Export filtered data sets (e.g., by year, degree) for planning or curriculum review.

**Super Admin Capabilities**

• Office of Alumni Affairs Oversight – Acts as the centralized authority managing all alumni tracking activities and ensuring alignment with university goals.
• Oversee Full Alumni Database – Access and manage all alumni records across departments and programs.
• Access Global Analytics Dashboards – View university-wide employment statistics, engagement metrics, and tracer survey analytics.

*Note: Super Admin is a planned or backend role and may not be visible in the current UI.*

## Main Features
- **Profile Management**: Update and manage your alumni profile.
- **Alumni Directory**: Search and view alumni profiles (with privacy controls).
- **Alumni Survey**: Complete the official ESSU Alumni Tracer Survey.
- **College Reports** (Admin): Generate analytics and reports for your college/program.
- **Survey Results** (Admin): Review and analyze survey submissions.
- **Export Data** (Admin): Export alumni and survey data for planning and review.
- **Settings**: Manage your account preferences and privacy settings.

---

## Setup Instructions

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure Firebase using the Firebase CLI
4. Run the app with `flutter run`

## Deployment

- **Web:**
  - Build: `flutter build web --release`
  - Deploy: `firebase deploy --only hosting`
  - Hosting URL: https://essu-alumni-tracker-9ded3.web.app

- **Android:**
  - Build: `flutter build apk --release`

## Firestore Database Schema (Excerpt)

Each department will have an admin account automatically created when the app starts, with the default password ESSU2024!

### 1. Users Collection
**Document ID:** Firebase Auth UID (automatically generated)

**Fields:**
- `email` - String (from Firebase Auth)
- `firstName` - String
- `lastName` - String
- `fullName` - String (generated from firstName + lastName)
- `batchYear` - String
- `course` - String
- `studentId` - String (unique)
- `profileImageUrl` - String (optional)
- `currentOccupation` - String (optional)
- `company` - String (optional)
- `location` - String (optional)
- `bio` - String (optional)
- `phone` - String (optional)
- `role` - String (enum: "admin", "alumni", "super_admin")
- `isActive` - Boolean (default: true)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)
- `lastLogin` - Timestamp (optional)
- `hasCompletedSurvey` - Boolean (default: false)
- `surveyCompletedAt` - Timestamp (optional)

### 2. Surveys Collection
**Document ID:** Auto-generated

**Fields:**
- `userId` - String (reference to user)
- `fullName` - String
- `college` - String
- `course` - String
- `batchYear` - String
- `userUid` - String (Firebase Auth UID)
- `isCurrentlyEmployed` - Boolean
- `currentOccupation` - String (optional)
- `company` - String (optional)
- `industry` - String (optional)
- `jobLevel` - String (optional)
- `monthlyIncome` - String (optional)
- `employmentType` - String (optional)
- `yearsOfExperience` - String (optional)
- `skillsUsed` - Array<String> (skills acquired from ESSU used in current job)
- `additionalSkills` - Array<String> (skills needed but not acquired from ESSU)
- `furtherEducation` - String (optional)
- `degreeObtained` - String (optional)
- `jobSearchDuration` - String (optional)
- `jobSearchMethods` - Array<String>
- `firstJobIndustry` - String (optional)
- `curriculumRelevance` - Integer (1-5 rating)
- `teachingQuality` - Integer (1-5 rating)
- `facilitiesRating` - Integer (1-5 rating)
- `suggestions` - String (optional)
- `completedAt` - Timestamp
- `updatedAt` - Timestamp (optional)

### 3. User_Settings Collection
**Document ID:** Firebase Auth UID (same as the user)

**Fields:**
- `userId` - String (reference to user)
- `emailNotifications` - Boolean (default: true)
- `pushNotifications` - Boolean (default: true)
- `privacyLevel` - String (e.g., "public", "alumni-only", "private")
- `fieldVisibility` - Map<String, Boolean> (controls visibility of profile fields)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

---

## License

This project is proprietary and for use by Eastern Samar State University only.
