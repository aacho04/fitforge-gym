# 🏋️‍♂️ FitForge — Elite Gym Management & Trainee Performance Portal

[![Vite](https://img.shields.io/badge/Vite-6.0+-646CFF?style=flat&logo=vite&logoColor=white)](https://vitejs.dev/)
[![JavaScript](https://img.shields.io/badge/JavaScript-ES6+-F7DF1E?style=flat&logo=javascript&logoColor=black)](https://developer.mozilla.org/en-US/docs/Web/JavaScript)
[![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Auth-3ECF8E?style=flat&logo=supabase&logoColor=white)](https://supabase.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A modern, high-performance web application designed for comprehensive gym administration, certified trainer coaching, and member/trainee fitness transformation. FitForge features role-based access control, interactive class reservations, dynamic Indian nutrition protocols, workout volume logging, body measurement trackers, and an intelligent gym AI assistant.

---

## 📑 Table of Contents

- [✨ Core Features](#-core-features)
- [🔑 Roles & Login Credentials](#-roles--login-credentials)
- [🚀 Quick Start (Running Locally)](#-quick-start-running-locally)
- [📦 Technology Stack](#-technology-stack)
- [🗄️ Database & Cloud Integration (Supabase)](#️-database--cloud-integration-supabase)
- [📁 Project Structure](#-project-structure)
- [💡 Demonstration Walkthrough](#-demonstration-walkthrough)

---

## ✨ Core Features

### 1. 🛡️ Role-Based Access Control (RBAC)
- **Three distinct secure portals**: Member / Trainee, Certified Trainer, and Gym Administrator.
- **1-Click Quick Demo Login**: Built-in credential autofill on the login modal for instant testing of all 3 user roles.

### 2. 🏋️ Member & Trainee Experience
- **Workout Routine & Volume Logger**: Log sets, repetitions, and weights; automatically calculates total lifting volume in kilograms.
- **Body Metric & Progress Tracking**: Record date-stamped weight, waist, chest, and hip measurements to track physical transformations over time.
- **Interactive Class Reservations**: View schedules, difficulty levels, trainer assignments, and open seat capacities for HIIT, Strength, Hypertrophy, Zumba, and Yoga.
- **Dynamic Indian Nutrition Protocols**: Tailored meal plans based on goal (Weight Loss, Muscle Hypertrophy, Maintenance), dietary preference (*Vegetarian*, *Eggetarian*, *Non-Vegetarian*), and budget tier (*Budget*, *Standard*, *Premium*).
- **In-App AI Fitness Coach**: Interactive chatbot trained to answer questions on exercise form, macronutrient splits, recovery, and program adjustments.
- **Attendance & Check-in Tracker**: Quick digital check-in to verify gym visits and active membership streak.

### 3. 🎯 Trainer & Coach Portal
- **Trainee Roster Management**: Inspect assigned gym members, their active plan, and contact information.
- **Workout Routine Assignment**: Build and assign tailored workout splits (Push-Pull-Legs, Upper-Lower, Full Body) directly to members' portals.
- **Transformation Monitoring**: Review real-time member workout logs and body measurement logs to fine-tune training intensity.

### 4. ⚙️ Administrator Command Center
- **Live KPI Dashboard**: Monitor active trainees, total members, active group classes, monthly revenue, and pending membership requests.
- **Membership Request Management**: One-click approval/rejection for tier upgrades (Basic, Pro, Elite) and automatic date synchronization.
- **Walk-in Customer Registration**: Quickly enroll offline gym members without requiring an online account.
- **Class & Schedule Management**: Create, edit, and deactivate classes with live capacity caps and pricing.
- **Financial & Transaction Auditing**: Real-time payment logs across UPI, Credit/Debit cards, Net Banking, and cash at reception.
- **Customer Inquiry Desk**: Review customer support inquiries and send direct responses.

---

## 🔑 Roles & Login Credentials

FitForge comes pre-configured with ready-to-test accounts for every role. You can also click the **"1-Click Quick Demo Login"** buttons directly inside the app's login dialog.

### 👑 1. Gym Administrator
Administrators have full administrative authority over the database, memberships, class schedules, and financial records.

| Field | Detail |
| :--- | :--- |
| **Email** | `admin@fitforge.com` *(or `admin@powerfit.com`, `admin@example.com`)* |
| **Password** | `admin123` *(or `admin`, `password`)* |
| **Role Tab in UI** | **Admin** |
| **Access** | Admin Dashboard (`/admin`), Member CRM, Revenue, Class Creation, Inquiry Inbox |

---

### 🥊 2. Certified Trainers & Coaches
Trainers can view their assigned trainees, monitor lifting volume, and prescribe customized workout splits.

| Trainer Name | Specialization | Email | Password | UI Role Tab |
| :--- | :--- | :--- | :--- | :--- |
| **Ali Raza** | Head Strength & Powerlifting Coach | `ali.raza@fitforge.com` | `trainer123` | **Trainer** |
| **Sara Ahmed** | Yoga & Athletic Mobility Instructor | `sara.ahmed@fitforge.com` | `trainer123` | **Trainer** |
| **Bilal Khan** | HIIT & Metabolic Conditioning Specialist | `bilal.khan@fitforge.com` | `trainer123` | **Trainer** |

---

### 🏃 3. Gym Members & Trainees
Enrolled members who book classes, track their diets, log lifting sessions, and use the AI Coach.

| Member Name | Current Plan | Primary Fitness Goal | Email | Password | UI Role Tab |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Aryan Sharma** | **Pro** | Weight Loss & Toning | `member@fitforge.com` | `member123` | **Member** |
| **Rohit Verma** | **Elite** | Muscle Hypertrophy & Bulk | `rohit@gmail.com` | `rohit123` | **Member** |
| **New Trainee** | — | Any | *Self-register on site* | *Custom* | **Member** |

> 💡 **Tip:** You can also click **"Register"** in the navigation bar to create a brand-new trainee account at any time!

---

## 🚀 Quick Start (Running Locally)

### Prerequisites
- [Node.js](https://nodejs.org/) (Version 18.x or later recommended)
- [npm](https://www.npmjs.com/) (bundled with Node.js)

### Step 1: Clone the Repository
```bash
git clone https://github.com/aacho04/fitforge-gym.git
cd fitforge-gym/gym-website
```

### Step 2: Install Dependencies
```bash
npm install
```

### Step 3: Run Development Server
```bash
npm run dev
```

The terminal will provide a local URL (typically `http://localhost:5173/`). Open this link in your web browser to launch FitForge.

### Step 4: Building for Production (Optional)
To test an optimized production build:
```bash
npm run build
npm run preview
```

---

## 📦 Technology Stack

- **Frontend Core**: Vanilla JavaScript (ES6+), HTML5, CSS3 with responsive glassmorphism aesthetic and dark mode palette.
- **Build Tool & Bundler**: [Vite](https://vitejs.dev/) for ultra-fast Hot Module Replacement (HMR).
- **Backend / Database**: [Supabase](https://supabase.com/) (PostgreSQL with Row Level Security & Auth triggers).
- **Local Fallback Storage**: HTML5 LocalStorage architecture enabling full offline and demo testing without requiring active cloud credentials.
- **Icons & Media**: Custom SVG asset pipeline and high-resolution fitness imagery.

---

## 🗄️ Database & Cloud Integration (Supabase)

FitForge is pre-configured to run out-of-the-box in **Local Demo Mode**. If you wish to connect your own Supabase cloud database:

1. **Create a Supabase Project** at [supabase.com](https://supabase.com/).
2. **Configure Environment Variables**:
   Create a `.env` file inside `gym-website/` (refer to `.env.example`):
   ```env
   VITE_SUPABASE_URL=https://your-project-ref.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
   ```
3. **Execute SQL Schema**:
   In the Supabase SQL Editor, open and run [`supabase/schema.sql`](./gym-website/supabase/schema.sql). This will:
   - Create tables for `gym_members`, `gym_classes`, `gym_bookings`, `gym_trainer_requests`, `gym_inquiries`, `gym_payments`, `gym_attendance`, `gym_plans`, `gym_workouts`, `gym_workout_logs`, and `gym_progress_records`.
   - Configure PostgreSQL Row Level Security (RLS) policies.
   - Set up automated Auth triggers to synchronize user profiles with members.
4. **Grant Admin Privileges** to any Supabase Auth user:
   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
     || '{"role":"gym_admin"}'::jsonb
   where email = 'your-admin-email@example.com';
   ```

---

## 📁 Project Structure

```text
fitforge-gym/
├── gym-website/
│   ├── index.html               # Main application entry point
│   ├── package.json             # NPM project manifest & scripts
│   ├── vite.config.js           # Vite development server configuration
│   ├── .env.example             # Environment variable template
│   ├── .gitignore               # Git ignored assets (node_modules, .env, dist)
│   ├── public/                  # Static assets, SVG icons, video files
│   │   ├── favicon.svg
│   │   └── icons.svg
│   ├── src/                     # Core application source
│   │   ├── third.html           # Full FitForge application engine & UI views
│   │   ├── supabase-init.js     # Supabase client initializer & offline detector
│   │   ├── index.css            # Global design tokens and animations
│   │   └── assets/              # Branding visuals and graphics
│   └── supabase/
│       └── schema.sql           # Complete PostgreSQL DDL, functions, and RLS policies
└── README.md                    # Project documentation
```

---

## 💡 Demonstration Walkthrough

1. **Member Workflow**:
   - Log in as `member@fitforge.com` (password: `member123`).
   - Head to the **Nutrition** tab to inspect personalized calorie and macro breakdowns tailored for Indian cuisines.
   - Navigate to **Classes**, select **HIIT Training** or **Strength Training**, and reserve a slot.
   - Open the **AI Coach** floating chatbot to request customized workout advice.
2. **Trainer Workflow**:
   - Log in as `ali.raza@fitforge.com` (password: `trainer123`).
   - View assigned trainees and write routine feedback.
3. **Admin Workflow**:
   - Log in as `admin@fitforge.com` (password: `admin123`).
   - Open **Admin Dashboard** to review monthly metrics, assign packages, add walk-ins, and inspect payment transactions.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
