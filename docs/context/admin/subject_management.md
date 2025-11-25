# Subject Management Screen Documentation

**File:** `lib/screen/admin/subject_management.dart`

## 1. Summary / Context
The `SubjectManagementScreen` is a comprehensive administrative interface for managing academic subjects (Mata Pelajaran). It provides CRUD functionality with advanced filtering, search, pagination, and Excel integration. The screen also enables navigation to class assignment management for each subject.

## 2. Features
-   **Subject List:**
    -   Displays a paginated list of subjects with infinite scrolling.
    -   Shows key details: Code, Name, Category, Class Count, and Class Names.
    -   Animated entry for list items.
-   **Search & Filter:**
    -   **Search:** Real-time search by subject name or code (debounced).
    -   **Advanced Filters:**
        -   **Category:** Utama (Core), Tambahan (Additional), Ekstrakurikuler (Extracurricular).
        -   **Class Status:** Has Classes / No Classes.
        -   **Grade Level:** Filter by grade 1-12.
        -   **Class Name:** Dynamic filter based on available class names (e.g., 7A, 7B).
    -   **Filter UI:** Bottom sheet with chips for multi-criteria selection and active filter summary.
-   **CRUD Operations:**
    -   **Add Subject:** Dialog form to input subject details (Code, Name, Description).
    -   **Edit Subject:** Pre-filled dialog form to update existing subjects.
    -   **Delete Subject:** Confirmation dialog before permanent deletion.
-   **Class Assignment:**
    -   Navigate to `SubjectClassManagementPage` to assign/manage classes for each subject.
    -   View class count and names directly in the list.
-   **Excel Integration:**
    -   **Export:** Download current subject list to Excel.
    -   **Import:** Bulk add subjects by uploading an Excel file.
    -   **Template:** Download a standardized Excel template for bulk imports.
-   **Localization:**
    -   Full support for English and Indonesian languages via `LanguageProvider`.

## 3. Routing
### Incoming
-   **Route:** Accessed via the **Dashboard** (Admin role).
-   **Navigation:** `Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectManagementScreen()))`

### Outgoing
-   **Subject Class Management:** Navigates to `SubjectClassManagementPage` to manage class assignments for a specific subject.
    -   `Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectClassManagementPage(subject: subject)))`

## 4. Data Resources
### API Services
-   **`ApiSubjectService`**:
    -   `getSubjectsPaginated(...)`: Fetches the list of subjects with pagination, search, and filter parameters.
    -   `getSubjectFilterOptions()`: Retrieves available filter options (status, categories).
    -   `importSubjectFromExcel(file)`: Uploads an Excel file for bulk import.
-   **`ApiService`**:
    -   `post('/mata-pelajaran', data)`: Creates a new subject.
    -   `put('/mata-pelajaran/{id}', data)`: Updates an existing subject.
    -   `delete('/mata-pelajaran/{id}')`: Deletes a subject.
-   **`ExcelSubjectService`**:
    -   `exportSubjectsToExcel(...)`: Handles the logic for generating and downloading the Excel file.
    -   `downloadTemplate(context)`: Downloads the Excel template.

### Local State
-   **`_subjectList`**: List of loaded subject objects.
-   **`_paginationMeta`**: Stores current page, total pages, and total items.
-   **`_searchController`**: Manages the search input text.
-   **`_selectedKategoriFilter`, `_selectedKelasStatusFilter`, `_selectedGradeLevelFilter`, `_selectedClassNameFilter`**: Store active filter states.
-   **`_availableClassNames`, `_availableGradeLevels`**: Dynamic lists extracted from subject data for filter options.

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
    -   Modern card layout with role-based color accents.
    -   Enhanced search bar component for better UX.
    -   Gradient headers for dialogs.
