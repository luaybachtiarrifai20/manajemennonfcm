# Login Screen Documentation

**File:** `lib/screen/login_screen.dart`

## 1. Summary / Context
The `LoginScreen` serves as the entry point for the application for unauthenticated users. It handles user authentication, including multi-step processes for users associated with multiple schools or having multiple roles. The screen manages the entire login flow from credential input to session initialization and navigation to the appropriate dashboard.

## 2. Features
-   **Authentication:**
    -   Email and Password input validation.
    -   Secure login via API.
    -   Handling of server connection status (`_checkServerConnection`).
-   **Multi-School Support:**
    -   Detects if a user is associated with multiple schools.
    -   Provides a UI for selecting a specific school (`_buildSchoolSelection`).
-   **Multi-Role Support:**
    -   Detects if a user has multiple roles (e.g., Admin, Guru, Wali).
    -   Provides a UI for selecting a specific role (`_buildRoleSelection`).
-   **Session Management:**
    -   Stores authentication token and user data in `SharedPreferences`.
    -   Handles token expiration and session validity.
    -   Integrates with `FCMService` to refresh and send FCM tokens upon login.
-   **Error Handling:**
    -   Displays snackbars for connection errors, invalid credentials, or server issues.
    -   Visual feedback for loading states.

## 3. Routing
### Incoming
-   **Initial Route:** `LoginScreen` is the default home widget in `main.dart` if the user is not authenticated.
-   **Redirects:** Users are redirected here from `main.dart` or `ApiService` if their session expires or they log out.
-   **Named Route:** `/login`

### Outgoing
Upon successful login, the user is navigated to a dashboard based on their role:
-   **Admin:** `Navigator.pushReplacementNamed(context, '/admin')`
-   **Guru:** `Navigator.pushReplacementNamed(context, '/guru')`
-   **Staff:** `Navigator.pushReplacementNamed(context, '/staff')`
-   **Wali:** `Navigator.pushReplacementNamed(context, '/wali')`

## 4. Data Resources
### API Services (`lib/services/api_services.dart`)
-   **`ApiService.checkHealth()`**: Verifies server connectivity on initialization.
-   **`ApiService.login(email, password, {schoolId, role})`**:
    -   Sends credentials to the backend.
    -   Returns a response that may indicate success (with token) or a requirement to select a school/role.
    -   **Endpoints Used:**
        -   `POST /login`

### Local Storage (`SharedPreferences`)
-   **`token`**: Stores the JWT authentication token.
-   **`user`**: Stores the user profile data (JSON encoded).
-   **`force_logout`**: Cleared upon successful login.

### External Services
-   **`FCMService`**: Used to force refresh the Firebase Cloud Messaging token and sync it with the backend after login.

## 5. State Management
-   **`_isLoading`**: Controls the loading indicator during API calls.
-   **`_serverConnected`**: Tracks the health status of the backend.
-   **`_showSchoolSelection`**: Toggles the view to the school selection list.
-   **`_showRoleSelection`**: Toggles the view to the role selection list.
-   **`_schoolList` & `_roleList`**: Stores available options returned by the initial login attempt.
