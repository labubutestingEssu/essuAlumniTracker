# Firebase Setup for Dynamic Survey System

## Overview
This guide will help you deploy the Firebase configuration changes needed for the dynamic survey system. The changes ensure that:

1. **Survey questions are stored in Firebase** and shared across all users
2. **Default questions are automatically initialized** from your initial survey
3. **Proper security rules** protect survey data
4. **Database indexes** optimize query performance

## Files Updated

### 1. Firestore Security Rules (`firestore.rules`)
**New collections added:**
- `survey_questions` - Stores dynamic survey questions (admin-only write, all users read)
- `survey_responses` - Stores user responses (user-own + admin read/write)

### 2. Firestore Indexes (`firestore.indexes.json`)
**New indexes for optimal performance:**
- Survey questions by active status and order
- Survey questions by type, active status, and order
- Survey responses by user and creation date
- Survey responses by college, completion status, and date
- Survey responses by batch year, completion status, and date

### 3. App Initialization (`lib/main.dart`)
**Automatic survey initialization:**
- Checks for existing survey questions on app startup
- Creates default questions if none exist
- Ensures consistent survey across all users

## Deployment Steps

### Step 1: Deploy Firestore Rules
```bash
# From your project root directory
firebase deploy --only firestore:rules
```

### Step 2: Deploy Firestore Indexes
```bash
# Deploy indexes (this may take several minutes)
firebase deploy --only firestore:indexes
```

### Step 3: Verify Deployment
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `essu-alumni-tracker-9ded3`
3. Navigate to **Firestore Database** > **Rules**
4. Verify the new survey rules are present
5. Navigate to **Firestore Database** > **Indexes**
6. Verify the new survey indexes are being built

### Step 4: Test the System
1. **Build and run your app**
2. **Check the logs** for initialization messages:
   ```
   Initializing app...
   Checking for existing survey questions...
   No survey questions found. Initializing default questions...
   Default survey questions initialized successfully (33 questions created).
   App initialization completed
   ```

3. **Verify in Firebase Console:**
   - Go to **Firestore Database** > **Data**
   - You should see a new `survey_questions` collection
   - It should contain ~33 questions from your initial survey

## Expected Database Structure

### survey_questions Collection
```
survey_questions/
├── {auto_generated_id_1}
│   ├── id: "consent"
│   ├── title: "Do you want to continue with the survey?"
│   ├── type: "QuestionType.singleChoice"
│   ├── options: ["Yes", "No"]
│   ├── isRequired: true
│   ├── order: 2
│   ├── isActive: true
│   └── createdAt: timestamp
├── {auto_generated_id_2}
│   ├── id: "last_name"
│   ├── title: "LAST NAME"
│   ├── type: "QuestionType.textInput"
│   ├── isRequired: true
│   ├── order: 4
│   └── ...
```

### survey_responses Collection (created when users respond)
```
survey_responses/
├── {response_id}
│   ├── userId: "user_uid"
│   ├── userUid: "user_uid"
│   ├── fullName: "John Doe"
│   ├── college: "College of Computing Studies"
│   ├── responses: {
│   │   "consent": "Yes",
│   │   "last_name": "Doe",
│   │   "first_name": "John",
│   │   "sex": "Male",
│   │   ...
│   │ }
│   ├── isCompleted: true
│   └── completedAt: timestamp
```

## Security Rules Summary

### Survey Questions (`survey_questions`)
- **Read**: All authenticated users
- **Write**: Admins and Super Admins only
- **Purpose**: Shared questions visible to all, manageable by admins

### Survey Responses (`survey_responses`)
- **Read**: Own responses + admins + super admins
- **Create**: Own responses only
- **Update**: Own responses + college admins + super admins
- **Delete**: Super admins only

## Troubleshooting

### If initialization fails:
1. **Check Firebase connection** in the app logs
2. **Verify user permissions** - the app must be able to write to Firestore
3. **Check security rules** - make sure they're deployed correctly

### If questions don't appear:
1. **Check Firestore Console** - verify questions were created
2. **Check app logs** for error messages
3. **Verify indexes** are built (not building)

### Manual initialization:
If automatic initialization fails, you can trigger it manually:

1. **From Admin Dashboard** (when implemented):
   - Go to Survey Question Management
   - Click "Initialize Default Questions"

2. **From Code** (temporary):
   ```dart
   await SurveyQuestionService().initializeDefaultQuestions();
   ```

## Post-Deployment Verification

### 1. Admin Features
- Admins can access Survey Question Management
- Questions can be added, edited, reordered
- Questions can be activated/deactivated

### 2. User Features  
- Users see dynamic survey based on active questions
- Responses are saved with question IDs as keys
- Progress is tracked and can be resumed

### 3. Data Export
- Export includes dynamic question columns
- Works with filtered data (college, batch year)
- Maintains compatibility with existing exports

## Migration Notes

### Existing Survey Data
- **Old surveys** (`surveys` collection) remain functional
- **New responses** will use `survey_responses` collection
- **Export function** supports both formats

### Gradual Migration
1. **Phase 1**: Deploy new system alongside old
2. **Phase 2**: Direct new users to dynamic survey
3. **Phase 3**: Migrate existing users (optional)
4. **Phase 4**: Remove old survey system

## Support

### Common Issues
1. **Permission denied** - Check security rules deployment
2. **Index errors** - Wait for indexes to finish building
3. **Initialization loops** - Check for duplicate initialization calls

### Debug Commands
```bash
# Check current Firestore rules
firebase firestore:rules:get

# List current indexes
firebase firestore:indexes

# View deployment history
firebase list
```

### Contact
For technical issues with this implementation, check:
1. Firebase Console error logs
2. App debug logs
3. Network connectivity
4. Security rule violations

The system is designed to be resilient - if initialization fails, the app will continue to work with existing functionality while logging the errors for troubleshooting. 