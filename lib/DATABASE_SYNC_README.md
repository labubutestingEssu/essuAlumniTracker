# Database Sync System

This system automatically creates and maintains separate role-based tables (`alumni`, `college_admin`, `admin`) that mirror your main `users` table data, organized by user roles.

## How It Works

### 1. Automatic Initialization
- The sync system runs automatically when the app starts (in `main.dart`)
- It also runs when the Alumni Directory screen loads
- **NEW**: It now automatically syncs whenever user data is updated anywhere in the app
- No manual intervention required

### 2. Data Synchronization
- **Step 1**: Reads all users from the main `users` table
- **Step 2**: Creates/updates separate tables based on user roles:
  - `alumni` table: Contains all users with `alumni` role
  - `college_admin` table: Contains all users with `admin` role  
  - `admin` table: Contains all users with `super_admin` role
- **Step 3**: Cross-references and updates existing data
- **Step 4**: Removes users from role tables if they no longer exist in main table

### 3. Data Structure
Each role table contains:
- All original user data from the `users` table
- `originalUserId`: Reference to the original user document
- `lastSynced`: Timestamp of last sync
- `roleTable`: Which role table this belongs to

## Files Created

1. **`lib/services/database_sync_service.dart`** - Core sync functionality
2. **`lib/services/database_initialization_service.dart`** - Initialization wrapper
3. **`lib/utils/database_sync_utils.dart`** - Utility functions for debugging

## Integration Points

- **`lib/main.dart`**: Runs sync on app startup
- **`lib/screens/alumni/alumni_directory_screen.dart`**: Runs sync when screen loads + debug button
- **`lib/services/user_service.dart`**: Automatically syncs after any user data update
- **`lib/services/auth_service.dart`**: Automatically syncs after user registration

## Debug Features

### Debug Button (Development Only)
- Added to Alumni Directory screen (only visible in debug mode)
- Allows manual sync triggering
- Shows sync status in console

### Console Logging
The system provides detailed console output:
- `🔄 Starting database sync process...`
- `📊 Found X users to sync`
- `➕ Created [role] user: [userId]`
- `🔄 Updated [role] user: [userId]`
- `✅ Database sync completed successfully`
- `🔄 Triggering specific user sync for: [userId]` (NEW - for individual updates)
- `✅ Specific user sync completed: [userId]` (NEW - for individual updates)

## Usage for Your Professor

### For Alumni Table
```dart
// Query alumni table
final alumniSnapshot = await FirebaseFirestore.instance
    .collection('alumni')
    .get();
```

### For College Admin Table
```dart
// Query college admin table
final collegeAdminSnapshot = await FirebaseFirestore.instance
    .collection('college_admin')
    .get();
```

### For Admin Table
```dart
// Query admin table
final adminSnapshot = await FirebaseFirestore.instance
    .collection('admin')
    .get();
```

## Benefits

1. **Non-Intrusive**: Your existing system continues to work unchanged
2. **Automatic**: No manual maintenance required
3. **Real-time**: Data stays in sync automatically
4. **Role-Based**: Clean separation of users by role
5. **Complete Data**: All user information is preserved in role tables
6. **Efficient**: Uses specific user sync for individual updates (NEW)
7. **Comprehensive**: Syncs on all user operations (create, update, delete, role change) (NEW)

## Error Handling

- If sync fails, the app continues to work normally
- Errors are logged to console but don't crash the app
- The main `users` table remains the source of truth

## Performance

- Sync runs in background
- Only syncs when needed (not on every app start)
- Uses batch operations for efficiency
- Minimal impact on app performance

## Maintenance

- No manual maintenance required
- System automatically handles:
  - New users
  - Role changes
  - User deletions
  - Data updates

This system provides your professor with the separate role-based tables they requested while keeping your existing system fully functional.
