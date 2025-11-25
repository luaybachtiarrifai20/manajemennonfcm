# Admin RPP Screen Documentation

**File:** `lib/screen/admin/admin_rpp_screen.dart`

## 1. Summary / Context
The `AdminRppScreen` provides administrative oversight of lesson plans (RPP - Rencana Pelaksanaan Pembelajaran) created by teachers. It enables viewing, filtering, status management, and exporting of all RPPs across the school with pagination support.

## 2. Features
-   **RPP List (Paginated):**
    -   Displays all RPPs from all teachers with infinite scrolling
    -   Shows: RPP title, teacher name, subject, class, grade, date, status
    -   10 items per page with automatic loading
-   **Filtering & Search:**
    -   **Status Filter:** Draft, Submitted, Approved, Rejected
    -   **Teacher Filter:** Filter by specific teacher
    -   **Subject Filter:** Filter by subject
    -   Searchbar for quick text search (debounced)
    -   Filter chips showing active filters
-   **Status Management:**
    -   Update RPP status (Approve/Reject)
    -   Status update dialog with reason/notes
    -   Color-coded status badges
-   **Detail View:**
    -   Comprehensive RPP detail page showing all fields
    -   Includes: Learning objectives, materials, methods, assessment
-   **Excel Export:**
    -   Export current RPP list to Excel
-   **Localization:**
    -   English and Indonesian language support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Admin role)

### Outgoing
-   **RPP Detail:** `RppAdminDetailPage` for viewing full RPP details

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `getRPPPaginated(...)`: Fetches paginated RPP list with filters
    -   `updateRPPStatus(rppId, status, notes)`: Updates RPP approval status
-   **`ExcelRppService`**:
    -   `exportToExcel(...)`: Excel export functionality

### Local State
-   **`_rppList`**: Paginated list of RPPs
-   **`_status`, `_teacherId`, `_subjectId`**: Active filters
-   **`_currentPage`, `_hasMoreData`**: Pagination state

## 5. UI/UX Details
-   Admin primary color theme
-   Status badges: Green (Approved), Orange (Submitted), Blue (Draft), Red (Rejected)
-   Animated card entry
-   Loading indicators for pagination
