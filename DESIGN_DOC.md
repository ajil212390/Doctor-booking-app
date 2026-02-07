# Design Document: DiaPredict 2.0

## 1. Project Overview
**DiaPredict 2.0** is a comprehensive health management and diabetes prediction system. It leverages machine learning (specifically XGBoost) to provide users with risk assessments based on their clinical data. Beyond prediction, the system facilitates doctor-patient interactions, appointment booking, and medical history tracking.

### 2. Objectives
- Provide accurate diabetes risk assessment using modern ML techniques.
- Bridge the gap between patients and specialized doctors.
- Enable users to maintain a digital record of their health parameters and medical history.
- Provide doctors with tools to manage their availability and patient appointments.

## 3. Technology Stack

### Frontend
- **Framework**: Flutter
- **State Management**: (Currently using standard StatefulWidget/setState, potentially moving to Provider/Bloc)
- **UI Components**: Material 3
- **Network**: HTTP package for API communication

### Backend
- **Framework**: Django REST Framework (DRF)
- **Language**: Python
- **Database**: PostgreSQL (Production) / SQLite (Development)
- **Authentication**: JWT (JSON Web Tokens)

### Machine Learning
- **Model**: XGBoost Classifier
- **Preprocessing**: StandardScaler / LabelEncoder (Implied)
- **Deployment**: Integrated within the Django backend service

## 4. System Architecture
The system follows a typical Client-Server architecture:
1.  **Client (Flutter App)**: Handles UI/UX, user input, and requests data from the backend.
2.  **API Gateway (Dev Tunnels/Localhost)**: Traverses NAT/Firewall for local development.
3.  **Backend (Django)**: Processes business logic, manages authentication, and serves as an interface for the DB and ML model.
4.  **Database**: Stores persistent data (Users, Doctors, Appointments, History).

## 5. Key Features

### 5.1 User Roles
- **Patient**: Can predict risk, view history, find doctors, and book appointments.
- **Doctor**: Can set availability, view/manage appointments, and view patient feedback.

### 5.2 Prediction Engine
- **Input Parameters**:
    - Gender
    - Age
    - Hypertension (0/1)
    - Heart Disease (0/1)
    - Smoking History
    - BMI
    - HbA1c Level
    - Blood Glucose Level
- **Output**: Real-time probability/classification of diabetes risk.

### 5.3 Appointment System
- **Doctor Discovery**: Patients can see a list of approved and available doctors.
- **Booking**: Interactive slot selection based on doctor's scheduled availability.
- **Management**: Both parties can track upcoming appointments.

### 5.4 Medical History
- Users can log past medical events and track their health parameters over time.

## 6. API Design (Endpoints)

| Category | Endpoint | Method | Description |
| :--- | :--- | :--- | :--- |
| **Auth** | `/auth/login/` | POST | Login and receive JWT tokens |
| | `/auth/register/` | POST | Patient registration |
| | `/auth/register/doctor/` | POST | Doctor registration |
| **User** | `/user/profile/` | GET/PUT | Manage user profile |
| | `/user/doctors/` | GET | List approved doctors |
| | `/user/predict/xgboost/` | POST | Perform XGBoost prediction |
| | `/user/appointments/` | GET/POST | View/Book appointments |
| **Doctor** | `/doctor/availability/` | GET/POST | Manage working hours |
| | `/doctor/appointments/` | GET | View assigned appointments |

## 7. Roadmap & Future Improvements
- **Security**: Implement refresh token logic more robustly.
- **Offline Mode**: Cache prediction results for offline viewing.
- **Advanced UI**: Add data visualization for health parameter trends.
- **Notification**: Integrate Firebase Cloud Messaging (FCM) for appointment reminders.
- **Multi-Model**: Add more ML models for comparison (Random Forest, SVM).

## 8. UX/UI Guidelines
- **Accessibility**: Ensure high contrast for medical data readability.
- **Feedback**: Provide immediate visual feedback for loading and error states.
- **Design Language**: Follow Material 3 principles with a clean, medical-themed color palette (Blues/Teals).
