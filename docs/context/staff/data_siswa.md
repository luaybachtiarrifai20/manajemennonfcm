# Staff Data Siswa (Student Data) Screen Documentation

**File:** `lib/screen/staff/data_siswa.dart`

## 1. Summary / Context
The `DataSiswaScreen` displays student information for staff members. Currently uses dummy data for demonstration purposes.

## 2. Features
-   **Student List:**
    -   Displays all students
    -   Shows: Name, NIS, Class, Parent name, Address
    -   Avatar with first letter of name
-   **Detail View:**
    -   Detail dialog showing complete student information
    -   Includes: NIS, Class, Address, Parent name, Phone number

## 3. Routing
### Incoming
-   **Route:** Via Staff Dashboard

### Outgoing
-   **None:** Detail dialog only

## 4. Data Resources
### API Services
-   **None:** Currently uses `DataDummy.siswa`

### Local State
-   **None:** Stateless widget using dummy data

## 5. UI/UX Details
-   List view with cards
-   Student avatars
-   Info button for details
-   Dialog-based detail view

> [!NOTE]
> This screen currently uses dummy data. Future implementation should connect to actual student API services.
