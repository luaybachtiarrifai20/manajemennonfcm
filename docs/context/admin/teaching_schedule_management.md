# Teaching Schedule Management Screen Documentation

**File:** `lib/screen/admin/teaching_schedule_management.dart`

## 1. Summary / Context
The `TeachingScheduleManagementScreen` is an advanced administrative interface for managing teaching schedules (Jadwal Mengajar). It provides comprehensive schedule CRUD functionality with intelligent academic period management, conflict detection and resolution, dual view modes (list and timetable grid), pagination, and Excel integration.

## 2. Features
-   **Academic Period Management:**
    -   **Automatic Detection:** Auto-detects current academic year (e.g., 2024/2025) and semester (Ganjil/Genap) based on current date.
    -   **Smart Defaults:** Academic year runs July-June; Semester 1 (Ganjil) is July-December, Semester 2 (Genap) is January-June.
    -   **Period Selection:** Dropdown selectors to switch between academic years and semesters.
    -   **Multi-Year Support:** Browse schedules across multiple academic years (current ±2 years).
-   **Schedule List:**
    -   Displays paginated list of schedules with infinite scrolling.
    -   Shows: Day, Time, Subject, Teacher, Class, and Semester information.
    -   Animated entry for list items.
-   **View Modes:**
    -   **List View:** Traditional card-based schedule list with details.
    -   **Table View:** Timetable grid using Syncfusion DataGrid component, organized by time slots, days, and classes.
-   **Search & Filter:**
    -   **Search:** Real-time search across schedule details (debounced).
    -   **Filters:**
        -   **Teacher:** Filter by specific teacher.
        -   **Class:** Filter by class.
        -   **Day:** Filter by day of the week.
        -   **Semester:** Override default semester.
        -   **AcademicYear:** Override default academic year.
        -   **Conflict Status:** Filter schedules with conflicts.
-   **CRUD Operations:**
    -   **Add Schedule:** Dialog form (`ScheduleFormDialog`) to create new schedules with teacher, subject, class, day, time slot, semester, and academic year.
    -   **Edit Schedule:** Pre-filled dialog to update existing schedules.
    -   **Delete Schedule:** Confirmation dialog before deletion.
    -   **Detail View:** Show comprehensive schedule details in a dialog.
-   **Conflict Management:**
    -   **Automatic Detection:** Detects scheduling conflicts (same class, day, time slot in same semester/academic year).
    -   **Resolution Dialog:** `ConflictResolutionDialog` presents conflicting schedules and allows admin to resolve by deleting conflicts before saving.
-   **Excel Integration:**
    -   **Export:** Download schedule list to Excel.
    -   **Import:** Bulk add schedules via Excel file upload.
    -   **Template:** Download standardized Excel template for bulk imports.
-   **Localization:**
    -   Full English and Indonesian language support via `LanguageProvider`.

## 3. Routing
### Incoming
-   **Route:** Accessed via the **Dashboard** (Admin role).
-   **Navigation:** `Navigator.push(context, MaterialPageRoute(builder: (context) => TeachingScheduleManagementScreen()))`

### Outgoing
-   **None:** This screen uses dialogs for all interactions (create, edit, detail, conflict resolution).

## 4. Data Resources
### API Services
-   **`ApiScheduleService`**:
    -   `getSchedulesPaginated(...)`: Fetches schedules with pagination and filters (teacher, class, day, semester, academic year, search).
    -   `getScheduleFilterOptions()`: Retrieves filter options (teachers, classes, days, semesters).
    -   `getHari()`: Fetches list of days.
    -   `getSemester()`: Fetches list of semesters.
    -   `getJamPelajaran()`: Fetches lesson time slots.
    -   `addSchedule(data)`: Creates a new schedule.
    -   `updateSchedule(id, data)`: Updates existing schedule.
    -   `deleteSchedule(id)`: Deletes a schedule.
    -   `getConflictingSchedules(...)`: Checks for scheduling conflicts.
    -   `importSchedulesFromExcel(file)`: Uploads Excel for bulk import.
-   **`ApiTeacherService`**:
    -   `getTeacher()`: Fetches teacher list for dropdowns.
-   **`ApiSubjectService`**:
    -   `getSubject()`: Fetches subject list for dropdowns.
-   **`ApiClassService`**:
    -   `getClass()`: Fetches class list for dropdowns.
-   **`ExcelScheduleService`**:
    -   `exportSchedulesToExcel(...)`: Handles Excel generation and download.
    -   `downloadTemplate(context)`: Downloads Excel template.

### Local State
-   **`_scheduleList`**: List of loaded schedule objects.
-   **`_teacherList`, `_subjectList`, `_classList`, `_hariList`, `_semesterList`, `_jamPelajaranList`**: Reference data for dropdowns.
-   **`_selectedSemester`, `_selectedAcademicYear`**: Current academic period (auto-detected or user-selected).
-   **`_selectedGuruId`, `_selectedClassId`, `_selectedHariId`**: Active filter states.
-   **`_gridData`, `_scheduleDataSource`**: Data for timetable grid view.
-   **`_showTableView`**: Toggle between list and table views.

## 5. UI/UX Details
-   **Animations:** Uses `AnimationController` for fade and slide effects.
-   **Loading States:**
    -   `LoadingScreen`: Full-screen loader for initial data fetch.
    -   `CircularProgressIndicator`: Bottom loader for pagination.
-   **Error Handling:**
    -   `SnackBar`: Success/error messages for all operations.
    -   Conflict detection prevents invalid schedules.
-   **Design:**
    -   Admin role-based primary color theme.
    -   Modern card layout with visual conflict indicators.
    -   Gradient headers for dialogs.
    -   Professional timetable grid view using Syncfusion component.
