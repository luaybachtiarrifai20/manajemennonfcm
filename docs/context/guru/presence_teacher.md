# Presence (Attendance) Screen (Teacher) Documentation

**File:** `lib/screen/guru/presence_teacher.dart`

## 1. Summary / Context
The `PresencePage` is the teacher's primary interface for recording student attendance. It features dual modes (Input and Results), auto-detection of current schedule, batch actions, and comprehensive attendance history viewing.

## 2. Features
-   **Dual Mode Interface:**
    -   **Input Mode:** Record new attendance for current/selected class
    -   **Results Mode:** View historical attendance summaries
-   **Smart Schedule Detection:**
    -   Auto-detects current teaching schedule based on time
    -   Pre-selects subject, class, and date automatically
    -   Manual override available
-   **Attendance Input:**
    -   Student list with checkboxes for each status (Present, Absent, Sick, Permission)
    -   Quick Actions: "Mark All Present", "Mark All Absent", etc.
    -   Search students by name
    -   Filter students by status
    -   Bulk save with validation
-   **Attendance Summaries:**
    -   View past attendance by date/subject/class
    -   Displays: Date, Subject, Class, Present/Absent counts, Percentage
    -   Filter summaries by date range, subject, class
    -   Animated summary cards
-   **Excel Export:**
    -   Export attendance summaries to Excel
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard or Teaching Schedule (Teacher role)
-   Can receive schedule parameters for pre-filling

### Outgoing
-   **None:** All interactions within screen

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `get('/jadwal-mengajar')`: Fetches teacher schedules
    -   `get('/absensi-summary')`: Fetches attendance summaries
    -   `post('/absensi-batch', data)`: Saves attendance batch
    -   `get('/siswa?kelas_id={id}')`: Fetches students by class
-   **`ApiScheduleService`**, **`ApiSubjectService`**, **`ApiClassService`**:
    -   For dropdown data (schedules, subjects, classes)
-   **`ExcelPresenceService`**:
    -   Excel export functionality

### Local State
-   **`_mode`**: 'input' or 'result'
-   **`_studentStatuses`**: Map of student ID to status
-   **`_absensiSummaryList`**: List of attendance summaries
-   **`_currentSchedule`**: Auto-detected schedule
-   **`_selectedMataPelajaran`, `_selectedKelas`, `_selectedDate`**: Input form state

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Mode switcher toggle
-   Status color coding (Green=Present, Red=Absent, Orange=Sick, Blue=Permission)
-   Quick action sheet for batch operations
-   Smart auto-fill based on current time
-   Filter chips for both modes
-   Search and filter capabilities
