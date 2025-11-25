# Teacher Admin Screen Documentation

**File:** `lib/screen/admin/teacher_admin.dart`

## 1. Summary / Context
The `TeacherAdminScreen` is a comprehensive administrative interface for managing teacher records. It allows administrators to view, create, update, and delete teacher profiles. The screen supports advanced features such as pagination, real-time search, filtering by homeroom status, and Excel integration for bulk operations. It also manages the assignment of subjects and classes to teachers.

## 2. Features
-   **Teacher List:**
    -   Displays a paginated list of teachers with infinite scrolling.
    -   Shows key details: Name, NIP, Email, and Homeroom status.
    -   Visual indicators for Homeroom Teachers.
    -   Animated entry for list items.
-   **Search & Filter:**
    -   **Search:** Real-time search by teacher name or NIP (debounced).
    -   **Filters:**
        -   **Status:** Filter by "Homeroom Teacher" (Wali Kelas) or "Regular Teacher" (Guru Biasa).
    -   **Filter UI:** Bottom sheet with chips for selection and a summary of active filters on the main screen.
-   **CRUD Operations:**
    -   **Add Teacher:** Dialog form to input teacher details (Name, Email, NIP, Class assignment, Homeroom status) and assign subjects.
    -   **Edit Teacher:** Pre-filled dialog form to update existing profiles and modify subject assignments.
    -   **Delete Teacher:** Confirmation dialog before permanent deletion.
    -   **View Detail:** Navigates to `TeacherDetailScreen` for a comprehensive view.
-   **Subject Management:**
    -   Assign multiple subjects to a teacher during creation or editing.
    -   Dynamically updates the `teacher_subjects` relation in the backend.
-   **Excel Integration:**
    -   **Export:** Download current teacher list to Excel.
    -   **Import:** Bulk add teachers by uploading an Excel file.
    -   **Template:** Download a standardized Excel template for bulk imports.
-   **Localization:**
    -   Full support for English and Indonesian languages via `LanguageProvider`.

## 3. Routing
### Incoming
-   **Route:** Accessed via the **Dashboard** (Admin role).
-   **Navigation:** `Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherAdminScreen()))`

### Outgoing
-   **Teacher Detail:** Navigates to `TeacherDetailScreen` when a teacher card is tapped.
    -   `Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherDetailScreen(teacher: teacher)))`

## 4. Data Resources
### API Services
-   **`ApiTeacherService`**:
    -   `getTeachersPaginated(...)`: Fetches the list of teachers with pagination, search, and filter parameters.
    -   `getTeacherFilterOptions()`: Retrieves available options for filters (classes).
    -   `addTeacher(data)`: Creates a new teacher profile.
    -   `updateTeacher(id, data)`: Updates an existing teacher profile.
    -   `deleteTeacher(id)`: Deletes a teacher profile.
    -   `getSubjectByTeacher(id)`: Fetches subjects assigned to a specific teacher.
    -   `addSubjectToTeacher(teacherId, subjectId)`: Assigns a subject to a teacher.
    -   `removeSubjectFromTeacher(teacherId, subjectId)`: Removes a subject assignment.
    -   `importTeachersFromExcel(file)`: Uploads an Excel file for bulk import.
-   **`ApiClassService`**:
    -   `getClass()`: Fetches the list of classes for dropdowns (assigning homeroom class).
-   **`ApiSubjectService`**:
    -   `getSubject()`: Fetches the list of all subjects for assignment.
-   **`ExcelTeacherService`**:
    -   `exportTeachersToExcel(...)`: Handles the logic for generating and downloading the Excel file.
    -   `downloadTemplate(context)`: Downloads the Excel template.

### Local State
-   **`_teachers`**: List of loaded teacher objects.
-   **`_subjects`**: List of all available subjects (for assignment dialog).
-   **`_classes`**: List of all available classes (for homeroom assignment).
-   **`_paginationMeta`**: Stores current page, total pages, and total items.
-   **`_searchController`**: Manages the search input text.
-   **`_selectedHomeroomFilter`**: Stores the active filter state for homeroom status.

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
    -   Modern card layout with role-based color accents and icons.
    -   Gradient headers for dialogs.
