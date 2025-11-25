# Teaching Schedule Screen (Teacher) Documentation

**File:** `lib/screen/guru/teaching_schedule.dart`

## 1. Summary / Context
The `TeachingScheduleScreen` allows teachers to view their personal teaching schedules with filtering and viewing options. It provides both table and card views, integrates with academic periods, and offers quick access to related activities (presence, materials, RPP).

## 2. Features
-   **Schedule Viewing:**
    -   Displays teacher's assigned teaching schedules
    -   Shows: Day, Time, Subject, Class, Room
    -   Auto-detects current academic year and semester
-   **View Modes:**
    -   **Table View:** Timetable grid by day and time slot
    -   **Card View:** List of schedule cards with details
    -   Toggle between views
-   **Academic Period:**
    -   Automatic detection of current year/semester
    -   Dropdown to switch between academic years
    -   Dropdown to switch between semesters
-   **Filtering:**
    -   Filter by day of week
    -   Filter by class
    -   Active filter chips with remove option
-   **Quick Actions (from schedule cards):**
    -   Navigate to **Presence** input for that class/subject
    -   Navigate to **Materi** (teaching materials) for that subject
    -   Navigate to **RPP** for that subject/class
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Teacher role)

### Outgoing
-   **Presence Input:** `PresencePage` with schedule params
-   **Teaching Materials:** `MateriPage` with teacher/subject params
-   **RPP:** `RppScreen` with teacher params

## 4. Data Resources
### API Services
-   **`ApiScheduleService`**:
    -   `getSchedulesByTeacher(teacherId, semester, tahunAjaran)`: Fetches teacher's schedules
    -   `getSemester()`: Fetches semester list
-   **`SharedPreferences`**:
    -   Stores user data (teacher ID)

### Local State
-   **`_jadwalList`**: Teacher's schedules
-   **`_selectedSemester`, `_selectedTahunAjaran`**: Current academic period
-   **`_selectedDayFilter`, `_selectedClassFilter`**: Active filters
-   **`_isCardView`**: ViewMode toggle

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Dual view modes for different preferences
-   Day-based color coding
-   Animated card transitions
-   Integrated quick actions for workflow efficiency
