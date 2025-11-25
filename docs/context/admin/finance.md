# Finance Screen Documentation

**File:** `lib/screen/admin/finance.dart`

## 1. Summary / Context
The `FinanceScreen` is a comprehensive financial management interface for school billing and payment tracking. It provides multi-tab views for billing types, billing generation with granular student selection, payment tracking, class-based financial reports, and dashboard statistics. This is one of the most complex admin screens with extensive state management and data coordination.

## 2. Features
-   **Multi-Tab Interface:**
    -   **Tab 1:** Billing Types (Jenis Pembayaran) management
    -   **Tab 2:** Billing(Tagihan) list and pending payments
    -   **Tab 3:** Class-based financial reports
-   **Billing Type Management:**
    -   Create, edit, and delete billing types (Monthly, Yearly, One-time)
    -   Define billing name, amount, period, and status (Active/Inactive)
    -   Target Selection: Choose specific classes/students or all students
    -   Multi-level student selection interface with class grouping
-   **Billing (Tagihan) Management:**
    -   Display paginated list of all billings with infinite scrolling
    -   Shows: Student name, billing type, amount, status, due date
    -   Search by student name or billing type (debounced)
    -   Filters: Status (Active/Inactive), Period (Monthly/Yearly)
    -   Generate billings from billing types with one-click
    -   CRUD operations for individual billings
-   **Pending Payments:**
    -   Dedicated section showing unpaid/partially paid billings
    -   Visual indicators for payment status
    -   Quick payment verification and update
-   **Class Financial Reports:**
    -   Class-by-class breakdown of student billings
    -   Expandable class cards showing all students
    -   Payment status summary per class (Paid/Unpaid/Partially Paid)
    -   Visual status indicators with color coding
    -   Drill-down to individual student billing details
-   **Dashboard Statistics:**
    -   Total revenue, pending payments, paid bills
    -   Quick financial overview metrics
-   **Student Selection Modal:**
    -   Advanced multi-select interface for targeting billings
    -   Class-based grouping with expand/collapse
    -   "Select All Classes" and "Clear All" quick actions
    -   Real-time search within selection modal
    -   Visual summary of selected students/classes
-   **Localization:**
    -   Full English and Indonesian language support

## 3. Routing
### Incoming
-   **Route:** Accessed via the **Dashboard** (Admin role)
-   **Navigation:** `Navigator.push(context, MaterialPageRoute(builder: (context) => FinanceScreen()))`

### Outgoing
-   **None:** All interactions happen within dialogs and the multi-tab interface

## 4. Data Resources
### API Services
-   **`ApiService`** (General):
    -   `get('/jenis-pembayaran')`: Fetches billing types
    -   `post('/jenis-pembayaran', data)`: Creates new billing type
    -   `put('/jenis-pembayaran/{id}', data)`: Updates billing type
    -   `delete('/jenis-pembayaran/{id}')`: Deletes billing type
    -   `get('/tagihan')`: Fetches billings with pagination
    -   `get('/tagihan?siswa_id={id}')`: Fetches billings for specific student
    -   `post('/tagihan', data)`: Creates billing
    -   `put('/tagihan/{id}', data)`: Updates billing
    -   `delete('/tagihan/{id}')`: Deletes billing
    -   `get('/pembayaran-pending')`: Fetches pending payments
    -   `get('/kelas')`: Fetches class list
    -   `get('/siswa')`: Fetches student list
    -   `get('/dashboard-keuangan')`: Fetches financial dashboard statistics

### Local State
-   **`_jenisPembayaranList`**: List of billing types
-   **`_tagihanList`**: List of billings (paginated)
-   **`_pembayaranPendingList`**: List of pending payments
-   **`_kelasList`**, **`_siswaList`**: Class and student lists for selection
-   **`_siswaByKelas`**: Map of students grouped by class ID
-   **`_tagihanBySiswa`**: Map of billings grouped by student ID
-   **`_dashboardData`**: Financial statistics
-   **`_currentTabIndex`**: Active tab (0-2)
-   **`_selectedStatusFilter`**, **`_selectedPeriodeFilter`**: Active filter states
-   **`_selectedKelas`**, **`_selectedSiswaByKelas`**: Student selection state for billing generation

## 5. UI/UX Details
-   **Animations:** Uses `AnimationController` for smooth transitions
-   **Loading States:**
    -   `LoadingScreen`: Full-screen loader
    -   `CircularProgressIndicator`: Pagination loader
-   **Error Handling:**
    -   `ErrorScreen`: For critical errors
    -   `SnackBar`: For operation feedback
-   **Design:**
    -   Admin role-based primary color theme
    -   Modern tabbed interface
    -   Color-coded payment status (Green=Paid, Orange=Partial, Red=Unpaid)
    -   Expandable class cards for reports
    -   Professional selection modal with search and quick actions
    -   Visual summary cards for statistics
