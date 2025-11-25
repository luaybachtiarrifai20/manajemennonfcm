# Staff Surat Menyurat (Correspondence) Screen Documentation

**File:** `lib/screen/staff/surat.dart`

## 1. Summary / Context
The `SuratMenyuratScreen` displays incoming and outgoing correspondence/letters. Currently uses hardcoded sample data with a placeholder add button.

## 2. Features
-   **Letter List:**
    -   Displays all correspondence
    -   Shows: Title, Date, Status, Type (Incoming/Outgoing)
    -   Icon-based type indicators (Mail=Incoming, Send=Outgoing)
    -   Color-coded status chips
-   **Add Button:**
    -   Floating action button (no functionality yet)

## 3. Routing
### Incoming
-   **Route:** Via Staff Dashboard or Administration menu

### Outgoing
-   **None:** No navigation implemented

## 4. Data Resources
### API Services
-   **None:** Currently uses hardcoded sample data

### Local State
-   **Hardcoded data:** List of sample letters in widget

## 5. UI/UX Details
-   List view with cards
-   Type icons: Green (Incoming), Blue (Outgoing)
-   Status chips with color coding
-   Floating action button for adding letters

> [!NOTE]
> This screen currently uses hardcoded data. Future implementation should connect to correspondence management API with full CRUD operations.
