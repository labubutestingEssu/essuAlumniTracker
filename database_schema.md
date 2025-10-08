# ESSU Alumni Tracker Database Schema (Firestore)

## 1. Users Collection
**Document ID:** Firebase Auth UID (automatically generated)

**Fields:**
- `email` - String (from Firebase Auth)
- `firstName` - String (required)
- `lastName` - String (required) 
- `middleName` - String (optional)
- `suffix` - String (optional) - e.g., Jr., Sr., III
- `batchYear` - String
- `course` - String
- `studentId` - String (unique) - For alumni: Student ID, For admin: Faculty ID
- `college` - String
- `profileImageUrl` - String (optional)
- `currentOccupation` - String (optional)
- `company` - String (optional)
- `location` - String (optional)
- `bio` - String (optional)
- `phone` - String (optional)
- `facebookUrl` - String (optional)
- `instagramUrl` - String (optional)
- `role` - String (enum: "admin", "alumni", "super_admin")
- `hasCompletedSurvey` - Boolean (default: false)
- `surveyCompletedAt` - Timestamp (optional)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)
- `lastLogin` - Timestamp (optional)

**Note:** The full name is dynamically constructed from `firstName`, `middleName` (if present), `lastName`, and `suffix` (if present).

## 2. Events Collection
**Document ID:** Auto-generated

**Fields:**
- `title` - String
- `description` - String
- `date` - Timestamp
- `time` - String (e.g., "14:30")
- `location` - String
- `type` - String (e.g., "Homecoming", "Career Fair", "Workshop")
- `maxAttendees` - Integer (optional)
- `createdBy` - String (Firebase Auth UID of the creator)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

## 3. Event_Attendees Collection
**Document ID:** Auto-generated

**Fields:**
- `eventId` - String (Firestore Document ID of the event)
- `userId` - String (Firebase Auth UID of the attendee)
- `status` - String (e.g., "Going", "Maybe", "Not Going")
- `createdAt` - Timestamp (server-generated)

## 4. Jobs Collection
**Document ID:** Auto-generated

**Fields:**
- `title` - String
- `company` - String
- `location` - String
- `type` - String (e.g., "Full-time", "Part-time", "Contract")
- `description` - String
- `requirements` - String
- `benefits` - String (optional)
- `salaryRange` - String (optional)
- `postedBy` - String (Firebase Auth UID of the poster)
- `postedDate` - Timestamp (server-generated)
- `deadline` - Timestamp (optional)
- `status` - String (e.g., "Open", "Closed", "Draft")
- `externalLink` - String (optional, URL to external job posting)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

## 5. Job_Applications Collection
**Document ID:** Auto-generated

**Fields:**
- `jobId` - String (Firestore Document ID of the job)
- `userId` - String (Firebase Auth UID of the applicant)
- `status` - String (e.g., "Applied", "Under Review", "Accepted", "Rejected")
- `resumeUrl` - String (optional)
- `coverLetter` - String (optional)
- `contactNumber` - String (required, applicant's contact number)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

## 6. News Collection
**Document ID:** Auto-generated

**Fields:**
- `title` - String
- `content` - String
- `category` - String (e.g., "Academic", "Research", "Student Achievement", "Events", "Alumni")
- `imageUrl` - String (optional, Cloudinary URL)
- `author` - String (optional, author name)
- `authorId` - String (Firebase Auth UID of the author)
- `publishedAt` - Timestamp
- `status` - String (e.g., "Published", "Draft", "Archived")
- `likeCount` - Integer (default: 0)
- `shareCount` - Integer (default: 0)
- `viewCount` - Integer (default: 0)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

## 7. News_Interactions Collection
**Document ID:** Composite ID (`${userId}_${newsId}`)

**Fields:**
- `userId` - String (Firebase Auth UID of the user)
- `newsId` - String (Firestore Document ID of the news)
- `liked` - Boolean (default: false)
- `saved` - Boolean (default: false)
- `viewCount` - Integer (default: 0)
- `shareCount` - Integer (default: 0)
- `lastViewed` - Timestamp (optional)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

## 8. User_Settings Collection
**Document ID:** Firebase Auth UID (same as the user)

**Fields:**
- `userId` - String (reference to user)
- `darkMode` - Boolean (default: false)
- `privacyLevel` - String (e.g., "public", "alumni-only", "private")
- `fieldVisibility` - Map<String, Boolean> {
  - `fullName` - Boolean (always true - not configurable)
  - `email` - Boolean (default: false)
  - `studentId` - Boolean (default: false)
  - `phone` - Boolean (default: false)
  - `bio` - Boolean (default: true)
  - `course` - Boolean (default: true)
  - `batchYear` - Boolean (default: true)
  - `company` - Boolean (default: true)
  - `currentOccupation` - Boolean (default: true)
  - `location` - Boolean (default: true)
- }
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

## 9. User_Connections Collection
**Document ID:** Auto-generated

**Fields:**
- `userId` - String (Firebase Auth UID of the user)
- `connectedUserId` - String (Firebase Auth UID of the connected user)
- `status` - String (e.g., "Pending", "Accepted", "Rejected", "Blocked")
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)

## 10. Courses Collection
**Document ID:** Auto-generated

**Fields:**
- `name` - String (course name)
- `code` - String (course code/abbreviation)
- `department` - String (department the course belongs to)
- `description` - String (optional, course description)
- `active` - Boolean (default: true, indicates if course is active/available)
- `createdBy` - String (Firebase Auth UID of admin who created the course)
- `createdAt` - Timestamp (server-generated)
- `updatedAt` - Timestamp (server-generated)
- `updatedBy` - String (optional, Firebase Auth UID of admin who last updated the course)

## Notes

1. All timestamp fields use server-generated timestamps.
2. Soft delete pattern can be implemented by adding a `deletedAt` Timestamp field.
3. Document IDs are either auto-generated by Firestore or set to the Firebase Auth UID for user-related documents.
4. Foreign key relationships are maintained using the Firebase Auth UID or Firestore Document ID as a string field.
5. Indexes will be created in Firestore based on query patterns.
6. Data validation and sanitization should be implemented at the application level.
7. Backup and recovery procedures are handled by Firebase.
8. Audit logging can be implemented using Firestore triggers or Cloud Functions.
9. For Android 12+ compatibility, notification permissions are requested at runtime and the AndroidManifest.xml is properly configured with exported attributes for notification components. 