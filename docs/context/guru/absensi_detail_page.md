# Absensi Detail Page Documentation

**File:** `lib/screen/guru/absensi_detail_page.dart`

## 1. Summary / Context
The `AbsensiDetailPage` provides a detailed interface for editing attendance records for a specific class session. Teachers can view and modify individual student attendance statuses with a clean, searchable interface.

## 2. Features
-   **Student List:**
    -   All students for selected class
    -   Avatar with initials
    -   Current attendance status for each student
-   **Status Selection:**
    -   Dropdown for each student: Present, Absent, Sick, Permission
    -   Real-time status updates
    -   Color-coded status indicators
-   **Search:**
    -   Search students by name
    -   Filtered list display
-   **Save:**
    -   Save all attendance changes
    -   API batch update
    -   Success/error feedback

## 3. Routing
### Incoming
-   **Route:** From Presence (Attendance) screen
-   Receives: `mataPelajaranId`, `kelasId`, `tanggal` parameters

### Outgoing
-   **None:** Dialog-based, closes after save

## 4. Data Resources
### API Services
-   **`ApiStudentService`**:
    -   `getStudentsByClass(kelasId)`: Fetches students
-   **`ApiService`**:
    -   `get('/absensi')`: Fetches existing attendance
    -   `post('/absensi-batch', data)`: Saves attendance updates

### Local State
-   **`_siswaList`**: List of students
-   **`_studentStatuses`**: Map of student ID to status
-   **`_searchQuery`**: Search filter

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Status color coding (Green=Present, Red=Absent, Orange=Sick, Blue=Permission)
-   Avatar with auto-generated colors based on name
-   Search bar at top
-   Dropdown status selectors
-   Save button in app bar
