# RPP Export Service Documentation

**File:** `lib/screen/guru/rpp_export_service.dart`

## 1. Summary / Context
The `RPPExportService` is a utility service (not a screen) that handles exporting lesson plans (RPP) to various document formats. It provides static methods for Word and PDF export with HTML formatting.

## 2. Features
-   **Export to Word:**
    -   Converts RPP content to HTML with styling
    -   Formats headings, tables, and lists
    -   Saves as .docx file
    -   Opens file automatically after export
-   **Export to PDF:**
    -   Converts RPP content to PDF format
    -   Currently uses text-based simulation
    -   Opens file automatically after export
-   **Content Formatting:**
    -   HTML formatting for structured content
    -   Table row formatting with borders
    -   Heading styles with colors
    -   List item formatting

## 3. Usage
This is a service class, not a screen. It's used by:
- `RPPDetailPage` for export functionality
- Other RPP-related screens

## 4. Methods
### Static Methods
-   **`exportToWord(content, fileName)`**:
    -   Formats content with HTML
    -   Saves to temporary directory
    -   Opens file with default app
-   **`exportToPDF(content, fileName)`**:
    -   Converts content to PDF
    -   Saves to temporary directory
    -   Opens file with default app

### Private Methods
-   **`_formatForWord(content)`**: Converts plain text to HTML with styling
-   **`_formatTableRow(line)`**: Formats pipe-delimited tables to HTML tables

## 5. Dependencies
-   **path_provider**: File system access
-   **open_file**: File opening functionality
-   **dart:io**: File operations

> [!NOTE]
> This is a utility service file, not a screen. The PDF export currently uses text simulation and should be enhanced with proper PDF generation libraries in production.
