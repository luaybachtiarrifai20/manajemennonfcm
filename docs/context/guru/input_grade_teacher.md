# Input Grade (Teacher) Screen Documentation

**File:** `lib/screen/guru/input_grade_teacher.dart`

## 1. Summary / Context
The `GradePage` enables teachers to input and manage student grades for their subjects. It features multi-level navigation (Subject → Class → Student Grades) with pagination and Excel export capabilities.

## 2. Features
-   **Three-Level Navigation:**
    -   **Level 1:** Subject list (teacher's subjects) with pagination
    -   **Level 2:** Class selection for chosen subject
    -   **Level 3:** Grade book table for students
-   **Subject List (Paginated):**
    -   Displays teacher's assigned subjects
    -   10 items per page with infinite scroll
    -   Search by subject name
-   **Class Selection:**
    -   Shows classes for selected subject
    -   Student count per class
    -   Search and filter by grade level
-   **Grade Book:**
    -   Spreadsheet-like interface for grade input
    -   Multiple grade components (Quiz, Midterm, Final, etc.)
    -   Auto-calculation of final grades
    -   Bulk save functionality
-   **Excel Export:**
    -   Export grades to Excel
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Teacher role)

### Outgoing
-   **Grade Book:** `GradeBookPage` with subject/class params

## 4. Data Resources
### API Services
-   **`ApiTeacherService`**:
    -   `getSubjectByTeacher(teacherId)`: Fetches teacher's subjects (paginated)
-   **`ApiClassService`**:
    -   `getClassesBySubject(subjectId)`: Fetches classes for subject
-   **`ApiService`**:
    -   `get('/nilai')`: Fetches grades
    -   `post('/nilai-batch', data)`: Saves grades in batch
-   **`ExcelService`**:
    -   Excel export functionality

### Local State
-   **`_subjectList`**: Paginated subject list
-   **`_classList`**: Classes for selected subject
-   **`_gradeData`**: Student grades for selected class
-   **`_currentPage`, `_hasMoreData`**: Pagination state

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Multi-level breadcrumb navigation
-   Table/grid interface for grade input
-   Auto-save with validation
-   Search and filter at each level
