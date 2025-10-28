# Question Set Feature Guide

## Overview

The Question Set feature allows you to create and manage multiple independent sets of survey questions. This is useful when you want to:
- Create different survey versions for different time periods
- Test new questions without affecting the current survey
- Maintain separate question sets for different purposes

## Key Concepts

### Question Set
A question set is a collection of survey questions that are completely independent from other sets. Each set has:
- **Name**: A descriptive name (e.g., "Set 1 (Default)", "Alumni Survey 2024")
- **Description**: Optional details about the set
- **Active Status**: Only one set can be active at a time. The active set is what users see when taking the survey
- **Default Status**: The original set (Set 1) is marked as default and cannot be deleted
- **Question Count**: Number of questions in the set

### Set ID
Each question now has a `setId` field that determines which set it belongs to. Questions from different sets are completely separate.

## How to Use

### 1. Accessing Question Set Management

1. Log in as an admin
2. Navigate to "Survey Question Management"
3. You'll see a blue card at the top showing the current question set

### 2. Creating a New Question Set

#### Option A: Create an Empty Set
1. Click the **"New Set"** button (green button)
2. Enter a name for your set (e.g., "Set 2", "Alumni Survey 2025")
3. Optionally add a description
4. Leave "Copy questions from existing set" **unchecked**
5. Click **"Create"**

Result: A new empty set is created, and you'll be switched to it automatically.

#### Option B: Copy from Existing Set
1. Click the **"New Set"** button (green button)
2. Enter a name for your set
3. **Check** "Copy questions from existing set"
4. Select the source set from the dropdown
5. Click **"Create"**

Result: A new set is created with all questions from the source set copied over. You can now modify them independently.

### 3. Switching Between Sets

1. Click the **dropdown** in the blue "Question Set" card
2. Select the set you want to work with
3. The questions list will update to show only questions from that set

**Note**: When you switch sets:
- You'll see different questions
- If you're in batch edit mode, it will exit automatically
- The question count will update

### 4. Managing Questions in a Set

Once you've selected a set, all normal question operations work as before:
- **Add Question**: Creates a new question in the current set
- **Edit Question**: Only affects the current set
- **Delete Question**: Only removes from the current set
- **Batch Edit**: Only edits questions in the current set
- **Reorder**: Only reorders questions in the current set

### 5. Setting the Active Set

The **active set** is the one that users see when filling out the survey.

To change which set is active:
1. Click the **settings icon** (⚙️) next to "New Set"
2. Find the set you want to make active
3. Click the **check circle icon** (✓)
4. The set will be marked as "ACTIVE" with a green badge

**Important**: Only one set can be active at a time. When you activate a set, the previously active set becomes inactive.

### 6. Deleting a Question Set

To delete a set:
1. Click the **settings icon** (⚙️)
2. Find the set you want to delete
3. Click the **delete icon** (🗑️)
4. Confirm the deletion

**Warning**: 
- This permanently deletes the set AND all its questions
- The default set (Set 1) cannot be deleted
- This action cannot be undone

## Admin Dashboard Features

### Question Set Selector
Located at the top of the Question Management screen, shows:
- Current set name
- Active status (green "ACTIVE" badge)
- Default status (orange "DEFAULT" badge)
- Number of questions in each set

### Manage Sets Dialog
Access via the settings icon (⚙️):
- View all question sets
- See question counts for each set
- Set active status
- Delete non-default sets

## User Experience (Survey Takers)

When a user takes the survey:
1. The system automatically loads the **active question set**
2. Users only see questions from the active set
3. If no set is marked as active, they see questions from the default set (Set 1)
4. Users don't see any indication of question sets - it's seamless

## Best Practices

### 1. Planning Your Sets
- **Set 1 (Default)**: Keep as your original/baseline survey
- **Set 2+**: Use for new versions, testing, or different time periods

### 2. Testing New Questions
1. Create a new set by copying the current active set
2. Make your changes in the new set
3. Test thoroughly
4. When ready, make it the active set

### 3. Managing Versions by Year
Example naming:
- "Alumni Survey 2024"
- "Alumni Survey 2025"
- "Alumni Survey 2026"

### 4. Before Deleting
- Make sure the set you're deleting is NOT active
- Verify you have the correct set selected
- Consider exporting the questions first (if you might need them later)

### 5. Switching Active Sets
- Best done during low-traffic periods
- Communicate changes to users if the survey structure changes significantly
- Keep the previous active set for reference (don't delete immediately)

## Technical Details

### Database Structure

#### Question Sets Collection: `question_sets`
```
{
  id: auto-generated
  name: "Set 1 (Default)"
  description: "Default question set"
  isActive: true
  isDefault: true
  createdAt: timestamp
  updatedAt: timestamp
  questionCount: 50
}
```

#### Survey Questions Collection: `survey_questions`
Each question now has a `setId` field:
```
{
  id: auto-generated
  title: "What is your name?"
  type: "textInput"
  setId: "set_id_here"  // NEW FIELD
  sectionId: "section_personal"
  order: 1
  // ... other fields
}
```

### Firestore Queries
- Questions are filtered by `setId` when loading
- Indexes required:
  - `isActive + setId + order`
  - `setId + order`

## Migration Notes

### Existing Questions
All existing questions are automatically assigned `setId: 'set_1'` for backward compatibility.

### First-Time Setup
1. When you first access the updated system, a default question set is created automatically
2. All existing questions are associated with this default set
3. You can then create additional sets as needed

## Troubleshooting

### "No active question set found"
**Problem**: Users see this error when taking the survey.
**Solution**: 
1. Go to Survey Question Management
2. Click the settings icon
3. Set one of your sets as active

### Questions not showing up
**Problem**: After creating a new set, you don't see any questions.
**Solution**: This is expected! New sets are empty by default. Either:
- Create questions manually, or
- Create a new set with "Copy from existing set" checked

### Can't delete a set
**Problem**: Delete button is grayed out.
**Solution**: The default set (Set 1) cannot be deleted. This is intentional to prevent accidental data loss.

### Questions disappeared
**Problem**: Your questions are gone after switching sets.
**Solution**: Questions aren't gone - you're just viewing a different set. Switch back to the original set to see your questions.

## Support

If you encounter issues not covered here:
1. Check the console logs for error messages
2. Verify Firestore indexes are created
3. Ensure you have admin permissions
4. Contact system administrator

## Future Enhancements

Potential features for future versions:
- Export/Import question sets
- Clone sets with automatic naming
- Set scheduling (activate on specific date)
- Version history and rollback
- Set comparison view
- Bulk operations across sets

