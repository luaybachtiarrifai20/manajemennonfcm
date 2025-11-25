# Admin Class Activity Screen Documentation

**File:** `lib/screen/admin/admin_class_activity.dart`

## 1. Summary / Context
The `AdminClassActivityScreen` allows administrators to monitor and review class activities submitted by teachers. It provides a teacher-centric view where admin can browse teachers and then drill down to see their specific class activities.

## 2. Features
-   **Two-Level Navigation:**
    -   **Level 1:** List of all teachers (searchable)
    -   **Level 2:** Activities for selected teacher
-   **Teacher List:**
    -   Displays all teachers with activity counts
    -   Search by teacher name
    -   Animated teacher cards
-   **Activity List (Per Teacher):**
    -   Shows all class activities from selected teacher
    -   Displays: Activity title, subject, class, date, day, description
    -   Search within activities
    -   Color-coded by day of week
-   **Detail View:**
    -   Comprehensive activity detail dialog
    -   Shows: Subject, class, date, time, activity description, goals
-   **Excel Export:**
    -   Export activities for selected teacher to Excel
-   **Localization:**
    -   Full English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Admin role)

### Outgoing
-   **None:** All interactions within screen and dialogs

## 4. Data Resources
### API Services
-   **`ApiTeacherService`**:
    -   `getTeacher()`: Fetches all teachers
-   **`ApiService`**:
    -   `get('/aktivitas-kelas?teacher_id={id}')`: Fetches activities for specific teacher
-   **`ExcelActivityService`**:
    -   `exportToExcel(...)`: Excel export for activities

### Local State
-   **`_teacherList`**: List of all teachers
-   **`_activityList`**: Activities for selected teacher
-   **`_selectedTeacher`**: Currently selected teacher (for Level 2 view)

## 5. UI/UX Details
-   Admin primary color theme
-   Two-stage navigation pattern
-   Day-based color coding for activities
-   Animated card transitions
-   Search functionality at both levels
