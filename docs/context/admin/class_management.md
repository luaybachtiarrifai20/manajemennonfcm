# Class Management Screen Documentation

**File:** `lib/screen/admin/admin_class_management.dart`

## 1. Summary / Context
The `ClassManagementScreen` is an administrative interface for managing school classes. It allows administrators to view, create, update, and delete class records. The screen supports features such as pagination, real-time search, filtering by grade level, and Excel integration for bulk operations. It also manages the assignment of homeroom teachers (Wali Kelas) to classes.

## 2. Features
-   **Class List:**
    -   Displays a paginated list of classes with infinite scrolling.
    -   Shows key details: Class Name, Grade Level, Student Count, and Homeroom Teacher.
    -   Animated entry for list items.
-   **Search & Filter:**
    -   **Search:** Real-time search by class name (debounced).
    -   **Filters:**
        -   **Grade Level:** Filter by specific grade (1-12).
    -   **Filter UI:** Bottom sheet with chips for grade selection and a summary of active filters on the main screen.
-   **CRUD Operations:**
    -   **Add Class:** Dialog form to input class details (Name, Grade Level, Homeroom Teacher).
    -   **Edit Class:** Pre-filled dialog form to update existing class details.
    -   **Delete Class:** Confirmation dialog before permanent deletion.
    -   **View Detail:** Dialog showing full class information including student count and homeroom teacher.
-   **Homeroom Teacher Assignment:**
    -   Assign a teacher as a "Wali Kelas" (Homeroom Teacher) during class creation or editing.
    -   Dropdown list populated with available teachers.
-   **Excel Integration:**
    -   **Export:** Download current class list to Excel.
    -   **Import:** Bulk add classes by uploading an Excel file.
    -   **Template:** Download a standardized Excel template for bulk imports.
-   **Localization:**
    -   Full support for English and Indonesian languages via `LanguageProvider`.

## 3. Routing
### Incoming
-   **Route:** Accessed via the **Dashboard** (Admin role).
-   **Navigation:** `Navigator.push(context, MaterialPageRoute(builder: (context) => ClassManagementScreen()))`

### Outgoing
-   **None:** This screen uses dialogs for details and editing, so there are no outgoing full-screen routes.

## 4. Data Resources
### API Services
-   **`ApiClassService`**:
    -   `getClassPaginated(...)`: Fetches the list of classes with pagination, search, and filter parameters.
    -   `getClassFilterOptions()`: Retrieves available options for filters (grade levels).
    -   `addClass(data)`: Creates a new class.
    -   `updateClass(id, data)`: Updates an existing class.
    -   `deleteClass(id)`: Deletes a class.
    -   `importClassesFromExcel(file)`: Uploads an Excel file for bulk import.
-   **`ApiTeacherService`**:
    -   `getTeacher()`: Fetches the list of teachers to populate the Homeroom Teacher dropdown.
-   **`ExcelClassService`**:
    -   `exportClassesToExcel(...)`: Handles the logic for generating and downloading the Excel file.
    -   `downloadTemplate(context)`: Downloads the Excel template.

### Local State
-   **`_classes`**: List of loaded class objects.
-   **`_teachers`**: List of all available teachers (for homeroom assignment).
-   **`_paginationMeta`**: Stores current page, total pages, and total items.
-   **`_searchController`**: Manages the search input text.
-   **`_selectedGradeFilter`**: Stores the active filter state for grade level.

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
