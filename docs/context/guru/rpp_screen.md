# RPP (Lesson Plan) Screen (Teacher) Documentation

**File:** `lib/screen/guru/rpp_screen.dart`

## 1. Summary / Context
The `RppScreen` allows teachers to create and manage their lesson plans (RPP - Rencana Pelaksanaan Pembelajaran). Teachers can create RPPs from scratch or templates, track approval status, and export to various formats.

## 2. Features
-   **RPP List:**
    -   Displays teacher's RPPs
    -   Shows: Title, subject, class, date, status (Draft/Submitted/Approved/Rejected)
    -   Status badges with color coding
-   **CRUD Operations:**
    -   **Create:** Add new RPP with comprehensive form
    -   **Edit:** Update draft/rejected RPPs
    -   **Delete:** Remove RPPs
    -   **Submit:** Send RPPs for admin approval
-   **RPP Form Fields:**
    -   Subject, Class, Grade level
    -   Learning objectives (Kompetensi Dasar)
    -   Materials and methods
    -   Assessment criteria
    -   Time allocation
-   **Export Features:**
    -   Export to PDF
    -   Export to Word/DOCX
    -   Print functionality
-   **Filtering:**
    -   Filter by status (Draft, Submitted, Approved, Rejected)
    -   Filter by subject
    -   Search by title
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard or Teaching Schedule
-   Receives `teacherId` and `teacherName` parameters

### Outgoing
-   **RPP Detail:** `RppDetailScreen` for viewing full RPP
-   **RPP Generate:** `RppGenerateScreen` for AI-assisted creation

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `getRPP(teacherId)`: Fetches teacher's RPPs
    -   `tambahRPP(data)`: Creates new RPP
    -   `updateRPP(id, data)`: Updates RPP
    -   `deleteRPP(id)`: Deletes RPP
    -   `submitRPP(id)`: Submits for approval
-   **`RppExportService`**:
    -   `exportToPDF(...)`: PDF export
    -   `exportToWord(...)`: DOCX export

### Local State
-   **`_rppList`**: List of teacher's RPPs
-   **`_selectedStatusFilter`, `_selectedSubjectFilter`**: Active filters
-   **`_searchQuery`**: Search term

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Status badges: Green (Approved), Orange (Submitted), Blue (Draft), Red (Rejected)
-   Comprehensive form with multiple sections
-   Export action buttons
-   Animated card transitions
-   Filter and search UI
