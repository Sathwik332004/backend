# 🧠 Smart Site Task Manager

A hybrid task management application that uses **intelligent content analysis** to automatically classify and prioritize tasks.  
Built with a **Node.js backend** and a **Flutter mobile application**, designed for seamless and efficient workflows for site managers.

🔗 **Live Backend URL:**  
`[https://backend-352w.onrender.com]`  

---

## 📌 Project Overview

This project solves **manual task entry fatigue**.

Instead of filling multiple dropdowns for **Category** or **Priority**, users simply type a natural task description such as:

> _"Urgent meeting with Sarah about budget"_

The system automatically:

- 📂 Classifies the task (Finance, Scheduling, Safety, etc.)
- 🔥 Assigns priority (High / Medium / Low)
- 🧠 Extracts entities (People, Dates)
- 💡 Suggests relevant actions (e.g., *Generate Invoice*)

---

## 🛠️ Tech Stack

### Backend
- **Runtime:** Node.js
- **Framework:** Express.js
- **Database:** Supabase (PostgreSQL)
- **Testing:** Jest (Unit Testing)

### Mobile App
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Networking:** Dio
- **UI:** Material Design 3

---

## 📸 Screenshots


- Dashboard (Light Mode)
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/2a2349fb-097d-40b1-9f40-7c20a637b32a" />


- Dashboard (Dark Mode)
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/8e1656d6-f6f8-46b7-924b-be3f584fd1e1" />


- Task List with Filters
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/8b41fb49-a9e4-405f-9dd5-f7260f15151c" />
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/2df1f327-d857-4853-80fa-aa0112b91a00" />
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/fb0b807a-00b4-493f-a6ee-3d8379369884" />



- Create Task Wizard
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/dd298bab-03c7-4392-8ee1-ccd68beabc1a" />
  

- Delete Confirmation
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/4b1e3059-d789-4c9e-ba52-26587dbc2b84" />

- AI Auto-Classification Preview
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/14496825-ad2f-44de-a847-917653dd67f3" />

- Swipe-to-Delete Action
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/4201586d-1133-42c5-b506-22dcfb501c94" />

- Search Highighter Preview
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/1dbfdad4-cd70-464d-9c4d-71320581282a" />

- Menu Option
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/0de93838-550c-44e6-ba86-7629ada3ea8b" />

---
## ⚙️ Setup Instructions

### 🔧 Backend Setup
  ```shell
  cd backend
  npm install
  ```
- Create a .env file in the root directory:
  ```plaintext
  SUPABASE_URL=your_supabase_url
  SUPABASE_KEY=your_supabase_anon_key
  ```
- Run the server:
  ```shell
  npm run server
  ```
- Run Tests [Separate Terminal]:
  ```shell
  npm test
  ```
### 📱 Flutter App Setup
  ```shell
  cd task_manager_app
  flutter pub get
  ```
- Update BASE_URL in lib/main.dart:
  ```plaintext
  Emulator:        http://10.0.2.2:3000
  Physical Device: http://YOUR_PC_IP:3000
  Production:      Render Backend URL
  ```
- Run the app:
  ```shell
  flutter run
  ```
---
## 🗄️ Database Schema

### Table: `tasks`

Stores the core task data.

| Column              | Type  | Description |
|---------------------|-------|-------------|
| id                  | UUID  | Primary Key |
| title               | Text  | Task headline |
| description         | Text  | Full task details |
| category            | Text  | Auto-detected |
| priority            | Text  | Auto-detected |
| status              | Text  | pending / in_progress / completed |
| assigned_to         | Text  | Extracted person |
| extracted_entities  | JSONB | Dates, names, etc. |

---

### Table: `task_history`

Audit log for tracking task changes.

| Column     | Type  | Description |
|------------|-------|-------------|
| id         | UUID  | Primary Key |
| task_id    | UUID  | Foreign Key → tasks.id |
| action     | Text  | created / updated / deleted |
| old_value  | JSONB | Before change |
| new_value  | JSONB | After change |

---

## 🔌 API Documentation

### Get All Tasks
```http
GET /api/tasks
```
- Used to display all the tasks.
- Query Params: category, priority, status

### Create Task (Auto-Classify)
```http
POST /api/tasks
```
- Used to create task.
```json
{
  "title": "Fix server crash",
  "description": "Urgent issue on production",
  "assigned_to": "DevOps"
}
```
### Preview Classification
```http
POST /api/classify
```

- Used to preview AI output before saving.
```json
{
  "title": "...",
  "description": "..."
}
```

### Update Task
```http
PATCH /api/tasks/:id
```

- Used to update task status.
```json
{ "status": "completed" }
```

### Delete Task
```http
DELETE /api/tasks/:id
```

- Used to delete completed tasks
```json
{ "message": "Task deleted" }
```
---
## 🧩 Architecture Decisions

- **Separation of Concerns**  
  Classification logic is isolated in `classification.js`, enabling easy testing and independent maintenance.

- **Provider Pattern (Flutter)**  
  Ensures a clean separation between UI widgets and business logic with minimal boilerplate.

- **Optimistic UI**  
  Provides fast and smooth UI updates while handling network or backend errors gracefully.

- **Hybrid Classification Engine**  
  Uses keyword-based AI for instant, offline-capable predictions without external API cost.

---

## ✨ Bonus Features

- ✅ Dark Mode
- ✅ Search Highlighting
- ✅ CSV Export
- ✅ Offline Detection
- ✅ Smart Task Creation Wizard (Preview before save)

---

## 🚀 Future Improvements

- 🔐 JWT Authentication (Supabase Auth)
- 🔔 Push Notifications
- 🤖 LLM Integration (OpenAI / Gemini via LangChain)
- 📊 Analytics Dashboard















