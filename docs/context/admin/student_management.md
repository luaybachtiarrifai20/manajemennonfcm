# Student Management Screen Documentation

**File:** `lib/screen/admin/student_management.dart`

## 1. Summary / Context
The `StudentManagementScreen` is an administrative interface for managing student records. It provides comprehensive CRUD (Create, Read, Update, Delete) functionality, along with advanced features like pagination, filtering, searching, and Excel integration (import/export).

## 2. Features
-   **Student List:**
    -   Displays a list of students with infinite scrolling (pagination).
    -   Shows key details: Name, NIS, Class, Gender, and Status.
    -   Animated entry for list items.
-   **Search & Filter:**
    -   **Search:** Real-time search by student name (debounced).
    -   **Filters:**
        -   **Status:** Active / Inactive.
        -   **Class:** Filter by specific class(es).
        -   **Gender:** Male / Female.
        -   **Grade Level:** Filter by grade level.
    -   **Filter UI:** Bottom sheet with chips for selection and a summary of active filters on the main screen.
-   **CRUD Operations:**
    -   **Add Student:** Dialog form to input student details (Name, NIS, Class, Address, Birth Date, Gender) and Parent details (Name, Email, Phone).
    -   **Edit Student:** Pre-filled dialog form to update existing records.
    -   **Delete Student:** Confirmation dialog before permanent deletion.
    -   **View Detail:** Read-only dialog showing full student and parent information.
-   **Excel Integration:**
    -   **Export:** Download current student list to Excel.
    -   **Import:** Bulk add students by uploading an Excel file.
    -   **Template:** Download a standardized Excel template for bulk imports.
-   **Localization:**
    -   Full support for English and Indonesian languages via `LanguageProvider`.

## 3. Routing
### Incoming
-   **Route:** Accessed via the **Dashboard** (Admin role).
-   **Navigation:** `Navigator.push(context, MaterialPageRoute(builder: (context) => StudentManagementScreen()))`

### Outgoing
-   **None:** This screen is a terminal node in the navigation tree; it uses dialogs and bottom sheets for interactions rather than navigating to new screens.

## 4. Data Resources
### API Services
-   **`ApiStudentService`**:
    -   `getStudentPaginated(...)`: Fetches the list of students with pagination, search, and filter parameters.
    -   `getStudentFilterOptions()`: Retrieves available options for filters (grades, classes, gender).
    -   `addStudent(data)`: Sends a POST request to create a new student.
    -   `updateStudent(id, data)`: Sends a PUT/POST request to update a student.
    -   `deleteStudent(id)`: Sends a DELETE request to remove a student.
    -   `importStudentsFromExcel(file)`: Uploads an Excel file for bulk import.
-   **`ApiClassService`**:
    -   `getClass()`: Fetches the list of classes for dropdowns and filters.
-   **`ExcelService`**:
    -   `exportStudentsToExcel(...)`: Handles the logic for generating and downloading the Excel file.
    -   `downloadTemplate(context)`: Downloads the Excel template.

### Local State
-   **`_students`**: List of loaded student objects.
-   **`_paginationMeta`**: Stores current page, total pages, and total items.
-   **`_searchController`**: Manages the search input text.
-   **`_selectedClassIds`, `_selectedGradeLevel`, `_selectedGenderFilter`, `_selectedStatusFilter`**: Store active filter states.

## 5. UI/UX Details
-   **Animations:** Uses `AnimationController` for fade and slide effects when loading the list.
-   **Loading States:**
    -   `LoadingScreen`: Full-screen loader for initial data fetch.
    -   `CircularProgressIndicator`: Bottom loader for pagination.
-   **Error Handling:**
    -   `ErrorScreen`: Displayed when initial data load fails.
    -   `SnackBar`: Used for success/error messages during CRUD operations and imports.
-   **Design:**
    -   Uses a primary color theme based on the 'admin' role.
    -   Modern card layout for student items with role-based color accents.
    -   Gradient headers for dialogs.
