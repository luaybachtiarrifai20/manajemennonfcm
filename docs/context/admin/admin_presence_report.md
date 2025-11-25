# Admin Presence Report Screen Documentation

**File:** `lib/screen/admin/admin_presence_report.dart`

## 1. Summary / Context
The `AdminPresenceReportScreen` provides comprehensive attendance reporting and analysis for administrators. It displays attendance summaries grouped by subject, class, and date with pagination, advanced filtering, and drill-down capabilities to view detailed student-level attendance records. The screen also includes Excel export functionality for reporting purposes.

## 2. Features
-   **Attendance Summary View:**
    -   Paginated list of attendance records with infinite scrolling
    -   Displays: Subject, Class, Date, Total Students, Present/Absent counts, Attendance percentage
    -   Visual percentage indicators for quick status assessment
    -   Animated card entries for better UX
-   **Advanced Filtering:**
    -   **Date Range:** Filter by Today, This Week, This Month
    -   **Subject:** Multi-select subject filter
    -   **Class:** Multi-select class filter
    -   Filter chips showing active filters with remove option
    -   "Clear All Filters" quick action
-   **Detailed Attendance View:**
    -   Drill-down to see individual student attendance for specific subject/class/date
    -   Student list with status (Present, Absent, Sick, Permission)
    -   Color-coded status indicators (Green=Present, Red=Absent, Orange=Sick, Blue=Permission)
    -   Statistics summary (total present/absent/sick/permission)
    -   Excel export for detailed attendance records
-   **Excel Integration:**
    -   Export summary to Excel
    -   Export detailed student attendance to Excel
-   **Pagination:**
    -   Infinite scroll with 10 items per page
    -   Smooth loading indicators for additional data
-   **Localization:**
    -   Full English and Indonesian language support

## 3. Routing
### Incoming
-   **Route:** Accessed via the **Dashboard** (Admin role)
-   **Navigation:** `Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPresenceReportScreen()))`

### Outgoing
-   **Detailed Attendance:** Navigates to `AdminAbsensiDetailPage` showing student-level attendance
    -   `Navigator.push(context, MaterialPageRoute(builder: (context) => AdminAbsensiDetailPage(...)))`

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `getAbsensiSummaryPaginated(...)`: Fetches paginated attendance summaries with filters (date range, subject, class)
    -   Returns: List of attendance summaries grouped by subject/class/date with pagination metadata
-   **`ApiSubjectService`**:
    -   `getSubject()`: Fetches subject list for filter options
-   **`ApiClassService`**:
    -   `getClass()`: Fetches class list for filter options
-   **`ApiStudentService`**:
    -   Used in detail view to fetch student data
-   **`ExcelPresenceService`**:
    -   `exportToExcel(...)`: Handles Excel generation for attendance reports
    -   Used in both summary and detail views

### Local State
-   **`_absensiSummaryList`**: List of `AttendanceSummary` objects (paginated)
-   **`_subjectList`, `_classList`**: Lists for filter options
-   **`_selectedDateFilter`, **`_selectedSubjectIds`**, `_selectedClassIds`**: Active filter states
-   **`_currentPage`, `_hasMoreData`, `_isLoadingMore`**: Pagination state
-   **`_hasActiveFilter`**: Boolean indicating if any filters are applied

### Data Models
-   **`AttendanceSummary`**: Model for attendance summary records
    -   Fields: `subjectId`, `subjectName`, `date`, `totalStudents`, `present`, `absent`, `classId`, `className`

## 5. UI/UX Details
-   **Animations:** Uses `AnimationController` for fade and slide effects on list items
-   **Loading States:**
    -   `LoadingScreen`: Full-screen loader for initial load
    -   `CircularProgressIndicator`: Bottom pagination loader
-   **Error Handling:**
    -   Graceful error messages via console (debug mode)
    -   Empty state for no data
-   **Design:**
    -   Admin role-based primary color theme
    -   Modern card layout with accent strips
    -   Circular progress indicators for attendance percentage
    -   Color-coded status badges (Present=Green, Absent=Red, etc.)
    -   Professional filter bottom sheet with chips
    -   Responsive layout with proper spacing
