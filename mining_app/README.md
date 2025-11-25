# 🏭 Underground Mining Workers & Equipment Management System

A comprehensive web application for managing mining workers, equipment, safety incidents, and operations analytics based on Oracle SQL database schema converted to Flask + SQLite.

## 📋 Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Running the Application](#running-the-application)
- [Database Schema](#database-schema)
- [Key Functionalities](#key-functionalities)

## ✨ Features

### Core Functionality
- **Worker Management**: Track worker details, roles, departments, employment status, salary, and hire dates
- **Equipment Management**: Monitor equipment inventory, operators, maintenance schedules, and depreciation
- **Safety Incident Tracking**: Report, track, and analyze safety incidents with severity classification
- **Training & Certifications**: Maintain worker training records and certification compliance
- **Shift Management**: Assign workers to shifts and track utilization
- **Maintenance Records**: Schedule and track equipment maintenance with cost tracking
- **Equipment Transfers**: Maintain audit trail of equipment reassignments

### Advanced Analytics & Dashboards
1. **Safety Dashboard**: High-risk incidents, worker safety profiles, incident hotspots
2. **Equipment Performance**: Equipment reliability analysis, maintenance compliance tracking
3. **Worker Utilization**: Productivity matrix, actual hours vs assigned hours
4. **Training Compliance**: Certification status tracking and requirements
5. **Shift Utilization**: Capacity analysis and worker distribution
6. **Risk Assessment**: Worker risk scoring and classification matrix
7. **Department Scorecard**: Department-level metrics and KPIs

### Technical Implementation
- All 40+ complex SQL queries implemented as Flask routes
- Real-time analytics with advanced filtering
- Comprehensive reporting and business intelligence
- Error handling and user-friendly interface
- Responsive design for desktop and mobile

## 🚀 Installation

### Prerequisites
- Python 3.7 or higher
- Windows, macOS, or Linux

### Step 1: Clone/Extract the Project
```bash
cd c:\Users\Debidutta\Documents\mining_app
```

### Step 2: Create Virtual Environment
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### Step 3: Install Dependencies
```bash
pip install -r requirements.txt
```

### Step 4: Run the Application
```bash
python app.py
```

The application will start at `http://localhost:5000`

## 📊 Running the Application

### First Time Setup
1. Open your browser to `http://localhost:5000`
2. Click the **"Initialize Database with Sample Data"** button on the dashboard
3. The system will create all tables and load sample mining data
4. Wait for the initialization to complete and redirect to dashboard

### Exploring the System
- **Dashboard**: Overview of key metrics and statistics
- **Workers**: List all workers with filtering by employment status
- **Equipment**: View all equipment with status filtering
- **Incidents**: Track all safety incidents with severity levels
- **Departments**: View department information and metrics
- **Analytics**: Access comprehensive dashboards and reports

## 💾 Database Schema

The application includes 19 interconnected tables:

### Core Tables
- **Department**: Mining departments/divisions
- **Supervisor**: Department supervisors and managers
- **Worker**: Mining workers and employees
- **SafetyGear**: Types of protective equipment
- **Equipment**: Mining machinery and tools
- **Shift**: Work shifts and schedules

### Operational Tables
- **AssignedShift**: Worker-to-shift mappings
- **UsageRecord**: Equipment usage tracking
- **MaintenanceRecord**: Equipment maintenance history
- **EquipmentTransfer**: Equipment reassignment audit trail
- **TrainingRecord**: Worker certifications and training
- **WorkerGear**: Worker-to-safety-gear assignments

### Incident Management
- **SafetyIncident**: Safety incidents with details
- **IncidentWorker**: Workers involved in incidents
- **IncidentEquipment**: Equipment involved in incidents

## 🎯 Key Functionalities Implemented

### From 02_PL_SQL.sql (Triggers, Functions, Procedures)
✓ Equipment status update triggers
✓ Maintenance tracking with automatic status updates
✓ Equipment transfer triggers with operator updates
✓ Severity validation triggers
✓ Worker age validation
✓ Training validity checks
✓ Shift capacity validation triggers
✓ High-severity incident enforcement

### Implemented Functions
✓ `get_incident_count()`: Count incidents per worker
✓ `get_worker_risk_score()`: Calculate risk scores
✓ `get_equipment_downtime_percent()`: Equipment availability analysis
✓ `has_required_certification()`: Certification verification
✓ `get_worker_utilization_score()`: Utilization calculation

### Implemented Procedures
✓ `record_maintenance()`: Record equipment maintenance
✓ `transfer_equipment()`: Equipment transfer with audit trail
✓ `report_incident()`: Safety incident reporting
✓ `assign_worker_to_shift()`: Worker-shift assignment with validation
✓ `record_equipment_usage()`: Equipment usage tracking

### From 03_Complex_Queries.sql (40+ Analytical Queries)
All complex queries implemented as Flask routes:

**Safety Analytics**
✓ Monthly incident trends with YoY comparison
✓ High-risk incidents with detailed context
✓ Worker safety profiles with incident clustering
✓ Incident hotspots analysis

**Equipment Analytics**
✓ Equipment performance and reliability analysis
✓ Maintenance schedule compliance tracking
✓ Equipment transfer audit trail analysis

**Worker Analytics**
✓ Worker utilization matrix (multi-dimensional)
✓ Training and certification compliance
✓ Worker safety gear compliance

**Department & Shift**
✓ Department-level safety metrics
✓ Shift utilization and distribution analysis

**Risk & Predictive**
✓ Worker risk scoring and classification
✓ Equipment reliability and failure prediction
✓ Predictive shift risk assessment

**Executive Dashboards**
✓ Overall mining operation safety dashboard
✓ Department performance scorecards

## 🌐 Application Routes

### Navigation
- `/` - Main dashboard with key metrics
- `/init-db` - Initialize database with sample data

### Data Lists
- `/workers` - Workers list with filtering
- `/equipment` - Equipment inventory
- `/incidents` - Safety incidents list
- `/departments` - Departments overview

### Analytics
- `/analytics/safety-dashboard` - Safety metrics and analysis
- `/analytics/equipment-performance` - Equipment reliability
- `/analytics/worker-utilization` - Worker productivity
- `/analytics/training-compliance` - Certification tracking
- `/analytics/shift-utilization` - Shift capacity analysis
- `/analytics/risk-assessment` - Worker risk scores
- `/analytics/department-scorecard` - Department metrics

### Detail Pages
- `/worker/<id>` - Worker profile with incidents and training
- `/equipment/<id>` - Equipment details with usage and maintenance
- `/incident/<id>` - Incident details with involved parties
- `/department/<id>` - Department details and personnel

## 📝 Sample Data

The initialization script creates:
- 3 Departments
- 3 Supervisors
- 8 Workers
- 4 Safety Gear items
- 5 Equipment units
- 4 Shifts
- 5 Worker-Shift assignments
- 4 Usage Records
- 4 Training Records
- 3 Maintenance Records
- 5 Worker-Gear assignments
- 4 Safety Incidents
- Various incident-worker and incident-equipment links

## 🔒 Security Features
- Input validation on all forms
- SQL injection prevention (SQLAlchemy ORM)
- Error handling and logging
- User-friendly error messages

## 🎨 Technology Stack
- **Backend**: Python Flask
- **Database**: SQLite (converted from Oracle)
- **ORM**: SQLAlchemy
- **Frontend**: HTML5, CSS3 (Responsive)
- **Deployment**: Flask built-in server

## 📞 Support

For issues or questions:
1. Check the browser console for error messages
2. Review terminal output for Flask logs
3. Verify database initialization completed successfully
4. Ensure all dependencies are installed

## 📄 License

This project converts Oracle SQL mining database system to Python Flask web application for demonstration purposes.

---

**Built with ❤️ for comprehensive mining operations management**
