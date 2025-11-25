# Admin Announcement Management Screen Documentation

**File:** `lib/screen/admin/admin_announcement.dart`

## 1. Summary / Context
The `AnnouncementManagementScreen` provides comprehensive announcement (Pengumuman) management for administrators. Announcements can be targeted to specific roles or classes with priority levels and date ranges.

## 2. Features
-   **Announcement List (Paginated):**
    -   Displays all announcements with infinite scrolling
    -   Shows: Title, content preview, target audience, priority, dates
    -   10 items per page
    -   Animated card entries
-   **CRUD Operations:**
    -   **Create:** Add new announcement with form dialog
    -   **Edit:** Update existing announcements
    -   **Delete:** Remove announcements with confirmation
-   **Targeting Options:**
    -   **Role-based:** Target Guru (Teachers), Wali Murid (Parents), or All
    -   **Class-based:** Target specific classes
    -   Visual indicators showing target audience
-   **Priority Levels:**
    -   High, Medium, Low priority with color coding
    -   Priority badges on announcement cards
-   **Date Management:**
    -   Start date and end date for announcements
    -   Automatic visibility control based on dates
-   **Filtering & Search:**
    -   **Priority Filter:** High/Medium/Low
    -   **Target Filter:** By role or class
    -   Search by title or content (debounced)
    -   Filter chips with active filter summary
-   **Detail View:**
    -   Full announcement detail dialog
    -   Shows all fields including target, dates, priority
    -   Formatted date display
-   **Localization:**
    -   Full English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Admin role)

### Outgoing
-   **None:** All interactions within dialogs

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `getAnnouncementsPaginated(...)`: Fetches paginated announcements with filters
    -   `post('/pengumuman', data)`: Creates newannouncement
    -   `put('/pengumuman/{id}', data)`: Updates announcement
    -   `delete('/pengumuman/{id}')`: Deletes announcement
-   **`ApiClassService`**:
    -   `getClass()`: Fetches class list for targeting

### Local State
-   **`_announcementList`**: Paginated announcement list
-   **`_classList`**: Available classes for targeting
-   **`_selectedPriority`, `_selectedTarget`**: Active filters
-   **`_currentPage`, `_hasMoreData`**: Pagination state

## 5. UI/UX Details
-   Admin primary color theme
-   Priority badges: Red (High), Orange (Medium), Blue (Low)
-   Target audience indicators
-   Date range display
-   Rich text content preview
-   Animated card transitions
-   Professional dialog forms
