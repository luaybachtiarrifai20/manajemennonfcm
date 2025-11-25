# RPP Generate Screen Documentation

**File:** `lib/screen/guru/rpp_generate_screen.dart`

## 1. Summary / Context
The `RPPGeneratePage` provides AI-assisted lesson plan generation for teachers. Teachers select topics/materials and the system generates a complete RPP (Rencana Pelaksanaan Pembelajaran) with learning objectives, methods, and assessments.

##2. Features
-   **Material Selection:**
    -   Select from available teaching materials (Bab/Sub-Bab)
    -   Multiple topic selection support
    -   Auto-generated title based on selected topics
-   **RPP Generation:**
    -   AI/template-based RPP creation
    -   Generates: Learning objectives, teaching methods, assessment criteria, time allocation
    -   Customizable fields with checkboxes to enable/disable auto-generation
-   **Form Customization:**
    -   Edit generated fields before saving
    -   Override auto-generated content
    -   Checkbox controls for each section
-   **Progress Indicator:**
    -   Shows generation progress
    -   Loading states during AI processing
-   **Preview \u0026 Save:**
    -   Preview generated RPP
    -   Navigate to RPP detail for final review
    -   Save to RPP list
-   **Localization:**
    -   English and Indonesian support

## 3. Routing
### Incoming
-   **Route:** From RPP Screen (Teacher role)
-   Receives subject and teacher parameters

### Outgoing
-   **RPP Detail:** `RppDetailScreen` with generated RPP data

## 4. Data Resources
### API Services
-   **`ApiSubjectService`**:
    -   `getMateri(...)`: Fetches available materials/topics
-   **`RppService`**:
    -   `generateRPP(params)`: Calls AI/template service to generate RPP content
-   **`ApiService`**:
    -   `post('/rpp', data)`: Saves generated RPP

### Local State
-   **`_selectedTopics`**: Selected materials for RPP
-   **`_isGenerating`**: Generation progress state
-   **`_generatedContent`**: AI-generated RPP fields
-   **`_enabledFields`**: Map of which fields to auto-generate

## 5. UI/UX Details
-   Teacher role-based primary color (green)
-   Material selection interface
-   Checkbox/toggle controls for each field
-   Progress indicators during generation
-   Editable text fields for customization
-   Preview mode before saving
