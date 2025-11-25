# Parent Class Activity Screen Documentation

**File:** `lib/screen/walimurid/parent_class_activity.dart`

## 1. Summary / Context
The `ParentClassActivityScreen` allows parents to view class activities for their children. Parents can see what was taught in class, homework assignments, and general class activities.

## 2. Features
-   **Student Selection:**
    -   Select from parent's children
    -   View activities per student/class
-   **Activity List:**
    -   Displays all class activities for student's classes
    -   Shows: Activity title, subject, date, description
    -   Activity types: Teaching, Homework, Other
-   **Filtering:**
    -   Filter by date range
    -   Filter by subject
    -   Filter by activity type
    -   Search activities
-   **Detail View:**
    -   Comprehensive activity details
    -   Materials covered
    -   Homework assignments if applicable
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
###Incoming
-   **Route:** Via Dashboard (Parent role)

### Outgoing
-   **None:** View-only screen

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `get('/aktivitas-kelas?kelas_id={id}')`: Fetches activities for student's class
-   **`ApiStudentService`**:
    -   `getStudentsByParent(parentId)`: Fetches parent's children

### Local State
-   **`_selectedStudent`**: Currently selected child
-   **`_activityList`**: Class activities
-   **`_selectedDateFilter`, `_selectedTypeFilter`**: Active filters

## 5. UI/UX Details
-   Parent role-based primary color (blue)
-   Student selector dropdown
-   Activity cards with type badges
-   Day color coding
-   Filter and search capabilities
-   Detail dialog for full activity view
