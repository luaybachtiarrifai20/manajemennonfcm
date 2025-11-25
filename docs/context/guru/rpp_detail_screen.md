# RPP Detail Screen Documentation

**File:** `lib/screen/guru/rpp_detail_screen.dart`

## 1. Summary / Context
The `RPPDetailPage` displays a comprehensive view of a lesson plan (RPP) with formatted content, editing capabilities, and export options to various formats including PDF, Word, and text.

## 2. Features
-   **RPP Display:**
    -   Formatted lesson plan content
    -   Structured sections (objectives, materials, methods, assessment)
    -   Table rendering for structured data
    -   Preview and edit modes
-   **Edit Mode:**
    -   Toggle between view and edit
    -   Text editor for content modification
    -   Format toolbar (bold, italic, headings, lists)
    -   Real-time preview
-   **Export Options:**
    -   **Export to Word:** DOCX format with HTML formatting
    -   **Export to PDF:** PDF generation
    -   **Export to Text:** Plain text format
    -   **Copy to Clipboard:** Copy formatted content
-   **Save Functionality:**
    -   Save edits to database
    -   Success/error feedback

## 3. Routing
### Incoming
-   **Route:** From RPP list or RPP Generate screen
-   Receives RPP data as parameter

### Outgoing
-   **None:** Detail/export screen

## 4. Data Resources
### API Services
-   **`ApiSubjectService`**:
    -   `updateRPP(id, data)`: Saves RPP edits

### Export Services
-   **Syncfusion PDF**: PDF generation
-   **File system**: Word/Text export
-   **path_provider**: File storage
-   **open_file**: File opening

### Local State
-   **`_rppContent`**: Formatted RPP content
-   **`_isEditMode`**: Edit/view toggle
-   **`_contentController`**: Text editing controller

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Dual-mode interface (View/Edit)
-   Rich text formatting display
-   Format toolbar in edit mode
-   Export action buttons in app bar
-   Formatted table rendering
-   Copy to clipboard functionality
