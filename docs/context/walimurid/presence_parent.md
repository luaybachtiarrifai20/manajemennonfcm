# Parent Presence (Attendance) Screen Documentation

**File:** `lib/screen/walimurid/presence_parent.dart`

## 1. Summary / Context
The `PresenceParentScreen` allows parents to monitor their children's attendance records. Parents can view attendance summaries, filter by date range, and see detailed attendance status for each class session.

## 2. Features
-   **Student Selection:**
    -   Select from parent's children
    -   View attendance per student
-   **Attendance Summaries:**
    -   View attendance by date/subject/class
    -   Displays: Present, Absent, Sick, Permission counts
    -   Attendance percentage
-   **Filtering:**
    -   Filter by date range (Today, Week, Month)
    -   Filter by subject
    -   Search by date
-   **Detail View:**
    -   See specific attendance entries
    -   Status details (Present/Absent/Sick/Permission)
    -   Teacher notes if available
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Parent role)

### Outgoing
-   **None:** View-only screen

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `get('/absensi?siswa_id={id}')`: Fetches attendance for student
    -   `get('/absensi-summary?siswa_id={id}')`: Fetches attendance summaries
-   **`ApiStudentService`**:
    -   `getStudentsByParent(parentId)`: Fetches parent's children

### Local State
-   **`_selectedStudent`**: Currently selected child
-   **`_attendanceList`**: Attendance records
-   **`_selectedDateFilter`, `_selectedSubjectFilter`**: Active filters

## 5. UI/UX Details
-   Parent role-based primary color (blue)
-   Student selector dropdown
-   Status color coding (Green=Present, Red=Absent, Orange=Sick, Blue=Permission)
-   Summary cards with statistics
-   Filter chips for active filters
-   Calendar view option
