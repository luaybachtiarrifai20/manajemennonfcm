# Dashboard Screen Documentation

**File:** `lib/screen/dashboard.dart`

## 1. Summary / Context
The `Dashboard` screen is the main hub of the application for authenticated users. It adapts its layout and available features based on the user's role (Admin, Guru, Staff, or Wali). It provides a quick overview of relevant statistics, access to primary features via a grid menu, and manages user session settings like school switching, role switching, and language preferences.

## 2. Features
-   **Role-Based UI:**
    -   Dynamically renders content and menu items based on the `role` parameter.
    -   Supported roles: `admin`, `guru`, `staff`, `wali`.
-   **Statistics Overview:**
    -   **Guru:** Total students, total classes, classes today, RPP status.
    -   **Admin:** Total students, teachers, classes, and subjects.
    -   **Wali:** Latest announcements, registered children.
-   **Navigation & Menu:**
    -   Animated grid menu with role-specific access control.
    -   Modern search bar (UI only currently).
-   **User Management:**
    -   **School Switching:** Allows users with access to multiple schools to switch contexts.
    -   **Role Switching:** Allows users with multiple roles to switch interfaces.
    -   **Profile Info:** Displays user name, email, and current school.
    -   **Logout:** Securely clears session data and redirects to login.
-   **Localization:**
    -   In-app language switcher (Indonesian/English).

## 3. Routing
### Incoming
-   **Routes:** `/admin`, `/guru`, `/staff`, `/wali`
-   **Navigation Source:** Typically navigated to from `LoginScreen` or `main.dart` (auto-login).

### Outgoing (Menu Items)
The dashboard navigates to various feature screens based on the user's selection.

#### Admin Role
-   **Student Management:** `StudentManagementScreen`
-   **Teacher Management:** `TeacherAdminScreen`
-   **Class Management:** `ClassManagementScreen`
-   **Subject Management:** `SubjectManagementScreen`
-   **Announcements:** `AnnouncementManagementScreen`
-   **Teaching Schedule:** `TeachingScheduleManagementScreen`
-   **RPP Management:** `AdminRppScreen`
-   **Presence Report:** `AdminPresenceReportScreen`
-   **Class Activity:** `AdminClassActivityScreen`
-   **Finance:** `KeuanganScreen`
-   **Input Grades:** `GradePage`

#### Guru Role
-   **Announcements:** `PengumumanScreen`
-   **Student Attendance:** `PresencePage`
-   **Input Grades:** `GradePage`
-   **Teaching Schedule:** `TeachingScheduleScreen`
-   **Class Activities:** `ClassActifityScreen`
-   **Learning Materials:** `MateriPage`
-   **My RPP:** `RppScreen`

#### Wali Role
-   **Announcements:** `PengumumanScreen`
-   **Student Attendance:** `PresenceParentPage` (includes student selection dialog if multiple children)
-   **Class Activities:** `ParentClassActivityScreen`
-   **Finance:** `TagihanWaliScreen`

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `getUserRoles()`: Fetches available roles for the user.
    -   `getUserSchools()`: Fetches available schools for the user.
    -   `switchRole(role)`: Switches the active role.
    -   `switchSchool(schoolId)`: Switches the active school.
    -   `getRPP()`: Fetches RPP data for stats.
    -   `get('/pengumuman')`: Fetches announcements.
-   **`ApiScheduleService`**:
    -   `getCurrentUserSchedule()`: Fetches teacher's schedule for stats.
-   **`ApiSubjectService`**:
    -   `getMateri()`: Fetches learning materials count.
    -   `getSubject()`: Fetches total subjects (Admin).
-   **`ApiStudentService`**:
    -   `getStudent()`: Fetches student data for stats and parent association.
-   **`ApiTeacherService`**:
    -   `getTeacher()`: Fetches total teachers (Admin).
-   **`ApiClassService`**:
    -   `getClass()`: Fetches total classes (Admin).
    -   `getStudentsByClassId()`: Used to calculate total students taught by a teacher.
    -   `getClassById()`: Fetches class details.

### Local Storage (`SharedPreferences`)
-   **`user`**: Stores and retrieves user profile, current role, and school information.
-   **`token`**: Updates token upon role/school switch.

## 5. State Management
-   **`_userData`**: Holds current user profile data.
-   **`_stats`**: Stores the calculated statistics for the dashboard cards.
-   **`_accessibleSchools`**: List of schools the user can switch to.
-   **`_availableRoles`**: List of roles the user can switch to.
-   **Animations**: Uses `AnimationController` for fade and scale effects on load.
