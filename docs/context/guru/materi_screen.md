# Materi (Teaching Materials) Screen Documentation

**File:** `lib/screen/guru/materi_screen.dart`

## 1. Summary / Context
The `MateriPage` enables teachers to manage teaching materials for their assigned subjects. Teachers can create, edit, delete materials and track student progress through uploaded content and descriptions.

## 2. Features
-   **Material List:**
    -   Displays all teaching materials for teacher's subjects
    -   Shows: Material title, subject, description, upload date
    -   Organized by subject
-   **CRUD Operations:**
    -   **Create:** Add new teaching material with form
    -   **Edit:** Update existing materials
    -   **Delete:** Remove materials with confirmation
-   **Material Details:**
    -   Title, description, subject
    -   File upload support (PDF, images, documents)
    -   Progress tracking per material
-   **Filtering:**
    -   Filter by subject
    -   Search by material title
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard or Teaching Schedule
-   Receives `teacher` parameter with teacher ID

### Outgoing
-   **None:** All interactions within dialogs

## 4. Data Resources
### API Services
-   **`ApiSubjectService`**:
    -   `getMateri(teacherId, subjectId)`: Fetches materials
    -   `getSubjectByTeacher(teacherId)`: Fetches teacher's subjects
-   **`ApiService`**:
    -   `post('/materi', data)`: Creates material
    -   `put('/materi/{id}', data)`: Updates material
    -   `delete('/materi/{id}')`: Deletes material

### Local State
-   **`_materiList`**: List of teaching materials
-   **`_subjectList`**: Teacher's assigned subjects
-   **`_selectedSubjectFilter`**: Active subject filter

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Material cards with subject badges
-   Form dialogs for CRUD operations
-   File upload support
-   Progress tracking indicators
