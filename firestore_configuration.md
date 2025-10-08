# Firestore Configuration Guide for ESSU Alumni Tracker

This document provides detailed information about the Firestore security rules and indexes setup for the ESSU Alumni Tracker application.

## Security Rules

### Overview

Firestore security rules control who can read from or write to your database. Our rules are structured around these key principles:

1. **Authentication required**: Nearly all operations require the user to be signed in
2. **Resource ownership**: Users can only modify their own data unless they have administrative privileges
3. **Role-based access**: Administrators have elevated permissions to manage most collections
4. **Field-level security**: Some collections implement field-level access control

### Helper Functions

```javascript
// Helper functions
function isSignedIn() {
  return request.auth != null;
}

function isAdmin() {
  return isSignedIn() && 
         exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

function isOwnResource(userId) {
  return isSignedIn() && request.auth.uid == userId;
}
```

### Collection-Specific Rules

#### Users Collection

```javascript
match /users/{userId} {
  allow read: if isSignedIn();
  allow create: if isSignedIn() && request.auth.uid == userId;
  allow update: if isOwnResource(userId) || isAdmin();
  allow delete: if isAdmin();
  
  // Allow users to access their own notifications subcollection
  match /notifications/{notificationId} {
    allow read, write: if isOwnResource(userId) || isAdmin();
  }
}
```

#### Global Notifications Collection

```javascript
match /notifications/{notificationId} {
  allow read: if isSignedIn();
  allow create, update, delete: if isAdmin();
}
```

#### News Collections

```javascript
// News rules
match /news/{newsId} {
  // Allow any authenticated user to read news
  allow read: if isSignedIn();
  // Only admins can create, update, delete news
  allow create, update, delete: if isAdmin();
}

// News interactions
match /news_interactions/{interactionId} {
  // Users can read their own interactions, admins can read all
  allow read: if isOwnResource(resource.data.userId) || isAdmin();
  // Users can create and update their own interactions
  allow create, update: if isSignedIn() && request.resource.data.userId == request.auth.uid;
  // Only admins can delete
  allow delete: if isAdmin();
}
```

#### Events and Jobs Collections

```javascript
// Events rules
match /events/{eventId} {
  allow read: if true;
  allow create, update, delete: if isAdmin();
}

// Event registrations
match /event_registrations/{registrationId} {
  allow read: if isOwnResource(resource.data.userId) || isAdmin();
  allow create, update: if isSignedIn() && request.resource.data.userId == request.auth.uid;
  allow delete: if isOwnResource(resource.data.userId) || isAdmin();
}

// Jobs rules
match /jobs/{jobId} {
  allow read: if true;
  allow create, update, delete: if isAdmin();
}

// Job applications
match /job_applications/{applicationId} {
  allow read: if isOwnResource(resource.data.userId) || isAdmin();
  allow create, update: if isSignedIn() && request.resource.data.userId == request.auth.uid;
  allow delete: if isOwnResource(resource.data.userId) || isAdmin();
}
```

### Catchall Rule

```javascript
// Any other collection
match /{document=**} {
  allow read, write: if isAdmin();
}
```

## Firestore Indexes

### Purpose of Indexes

Firestore indexes enable efficient querying and sorting of data. Without proper indexes, certain queries will fail with a "requires an index" error.

### Composite Indexes

Our application uses several composite indexes for optimized queries:

#### Notifications Index

```json
{
  "collectionGroup": "notifications",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "isAllUsers",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "createdAt",
      "order": "DESCENDING"
    }
  ]
}
```

This index supports queries that:
- Filter notifications by whether they are meant for all users (`isAllUsers`)
- Sort notifications by creation date (newest first)

#### News Index

```json
{
  "collectionGroup": "news",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "status",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "publishedAt",
      "order": "DESCENDING"
    }
  ]
}
```

This index supports queries that:
- Filter news by status (e.g., "published", "draft")
- Sort news by publication date (newest first)

#### Jobs Indexes

```json
{
  "collectionGroup": "jobs",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "status",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "postedDate",
      "order": "DESCENDING"
    }
  ]
},
{
  "collectionGroup": "jobs",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "type",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "postedDate",
      "order": "DESCENDING"
    }
  ]
},
{
  "collectionGroup": "jobs",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "status",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "type",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "postedDate",
      "order": "DESCENDING"
    }
  ]
}
```

These indexes support:
- Filtering by status and sorting by posted date
- Filtering by job type and sorting by posted date
- Combined filtering by both status and type, sorted by posted date

## Maintaining Rules and Indexes

### Deploying Rules

After modifying the `firestore.rules` file, deploy using:

```bash
firebase deploy --only firestore:rules
```

### Deploying Indexes

After updating the `firestore.indexes.json` file, deploy using:

```bash
firebase deploy --only firestore:indexes
```

### Index Creation from Error Messages

When an "index required" error occurs:

1. Click the provided link in the error message to create the index directly in the Firebase Console
2. Alternatively, add the index configuration to `firestore.indexes.json` manually
3. Wait for the index to build (may take a few minutes)

## Security Considerations

1. **Validate data**: Always validate data in rules for write operations
2. **Least privilege**: Grant the minimum permissions needed
3. **Error handling**: Implement fallback client-side logic for index-related errors
4. **Regular audits**: Periodically review and update security rules
5. **Testing**: Test rules against different user roles and scenarios

## Common Issues and Solutions

### "Missing or insufficient permissions"

- Check if user is authenticated
- Verify they have the correct role
- Ensure they are accessing their own resources
- Check for nested subcollection permission issues

### "The query requires an index"

- Use the provided link to create the index
- Add the index to `firestore.indexes.json`
- Implement client-side fallback while index builds

### "Invalid rule"

- Syntax error in security rules
- Function calling convention issue
- Path reference error in get() or exists() functions 