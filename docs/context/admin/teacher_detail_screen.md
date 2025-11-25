# Teacher Detail Screen Documentation

**File:** `lib/screen/admin/teacher_detail_screen.dart`

## 1. Summary / Context
The `TeacherDetailScreen` displays comprehensive information about a specific teacher. Accessed from the Teacher Administration screen, it shows personal details, contact information, subjects taught, and assigned classes.

## 2. Features
-   **Teacher Information:**
    -   Personal details: Name, NIP, Gender, Date of Birth
    -   Contact: Email, Phone number, Address
    -   Professional: Subjects taught, Classes assigned
    -   Status information
-   **Information Display:**
    -   Organized sections with icons
    -   Formatted layout for readability
    -   Icon-based labeling for each field
-   **Data Loading:**
    -   Fetches teacher details from API
    -   Loading state indicator
    -   Error handling

## 3. Routing
### Incoming
-   **Route:** From Teacher Administration screen
-   Receives `teacherId` parameter

### Outgoing
-   **None:** Detail view only

## 4. Data Resources
### API Services
-   **`ApiTeacherService`**:
    -   `getTeacherById(teacherId)`: Fetches teacher details

### Local State
-   **`_teacherData`**: Teacher information
-   **`_isLoading`**: Loading state

## 5. UI/UX Details
-   Admin role-based primary color
-   Organized information sections
-   Icon-label pairs for each field
-   Multi-line support for addresses
-   Professional detail layout
-   Loading and error states
