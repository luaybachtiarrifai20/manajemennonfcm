# Parent Billing Screen Documentation

**File:** `lib/screen/walimurid/parent_billing.dart`

## 1. Summary / Context
The `ParentBillingScreen` allows parents to view their children's billing information, payment history, and outstanding balances. Parents can see all financial obligations for their students in one centralized view.

## 2. Features
-   **Student Selection:**
    -   Select from parent's children
    -   View billings per student
-   **Billing List:**
    -   Displays all billings for selected student
    -   Shows: Billing type, amount, due date, status
    -   Color-coded payment status (Paid/Unpaid/Partial)
-   **Payment Status:**
    -   Visual indicators for payment status
    -   Outstanding balance summary
    -   Payment history
-   **Billing Details:**
    -   Detailed view of each billing
    -   Payment instructions
    -   Due date reminders
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** Via Dashboard (Parent role)

### Outgoing
-   **None:** View-only screen

## 4. Data Resources
### API Services
-   **`ApiService`**:
    -   `get('/tagihan?siswa_id={id}')`: Fetches billings for student
    -   `get('/siswa?parent_id={id}')`: Fetches parent's children

### Local State
-   **`_selectedStudent`**: Currently selected child
-   **`_billingList`**: Billings for selected student
-   **`_studentList`**: List of parent's children

## 5. UI/UX Details
-   Parent role-based primary color (blue)
-   Student selector dropdown
-   Status badges: Green (Paid), Red (Unpaid), Orange (Partial)
-   Summary cards for total outstanding
-   List view with detailed billing cards
