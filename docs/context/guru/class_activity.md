# Class Activity Screen (Teacher) Documentation

**File:** `lib/screen/guru/class_activity.dart`

## 1. Summary /Context
The `ClassActifityScreen` allows teachers to create and manage class activities linked to their teaching schedules. Teachers can document what happened in class, including materials covered, homework assigned, and general activities.

## 2. Features
-   **Activity Types:**
    -   **Teaching Activity:** Regular class instruction
    -   **Homework:** Assignments given to students
    -   **Other:** General activities
-   **CRUD Operations:**
    -   Create, edit, delete class activities
    -   Link activities to specific schedule/subject/class
-   **Schedule Integration:**
    -   Loads teacher's schedules
    -   Activities linked to schedule entries
-   **Material Linking:**
    -   Select teaching materials (Materi) for activity
    -   Link to sub-chapters
-   **Filtering:**
    -   Filter by date range
    -   Filter by activity type
    -   Search activities
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Teacher role)

### Outgoing
-   **None:** All interactions within screen

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `get('/aktivitas-kelas')`: Fetches activities
    -   `post('/aktivitas-kelas', data)`: Creates activity
    -   `put('/aktivitas-kelas/{id}', data)`: Updates activity
    -   `delete('/aktivitas-kelas/{id}')`: Deletes activity
-   **`ApiScheduleService`**, **`ApiSubjectService`**:
    -   For schedule and material data

### Local State
-   **`_activityList`**: List of class activities
-   **`_scheduleList`**: Teacher's schedules
-   **`_selectedDateFilter`, `_selectedTypeFilter`**: Active filters

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Type selection dialog
-   Activity cards with day color coding
-   Material linking interface
-   Search and filter capabilities
