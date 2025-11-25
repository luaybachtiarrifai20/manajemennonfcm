# Staff Inventaris (Inventory) Screen Documentation

**File:** `lib/screen/staff/inventaris.dart`

## 1. Summary / Context
The `InventarisScreen` displays school inventory items. Currently uses dummy data for demonstration purposes with a placeholder floating action button.

## 2. Features
-   **Inventory List:**
    -   Displays all inventory items
    -   Shows: Item name, Quantity, Condition
    -   Color-coded condition badges (Green=Good, Orange=Needs Repair)
-   **Add Button:**
    -   Floating action button (no functionality yet)

## 3. Routing
### Incoming
-   **Route:** Via Staff Dashboard

### Outgoing
-   **None:** No navigation implemented

## 4. Data Resources
### API Services
-   **None:** Currently uses `DataDummy.inventaris`

### Local State
-   **None:** Stateless widget using dummy data

## 5. UI/UX Details
-   List view with cards
-   Inventory icon for each item
-   Color-coded condition badges
-   Floating action button for adding items

> [!NOTE]
> This screen currently uses dummy data. Future implementation should include CRUD operations for inventory management.
