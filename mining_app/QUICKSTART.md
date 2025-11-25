
# 🏭 MINING MANAGEMENT SYSTEM - QUICK START GUIDE

## Step 1: Navigate to the Project Directory

```bash
cd c:\Users\Debidutta\Documents\mining_app
```

## Step 2: Activate Virtual Environment

### Windows (Command Prompt):
```bash
venv\Scripts\activate.bat
```

### Windows (PowerShell):
```powershell
.\venv\Scripts\Activate.ps1
```

### macOS/Linux:
```bash
source venv/bin/activate
```

## Step 3: Start the Flask Server

Once the virtual environment is activated, run:

```bash
python run_server.py
```

OR directly:

```bash
python app.py
```

## Step 4: Access the Application

Open your web browser and navigate to:

```
http://localhost:5000
```

## Step 5: Initialize Database with Sample Data

1. You should see the dashboard with a button saying **"Initialize Database with Sample Data"**
2. Click this button to populate the database with 8 workers, 5 equipment, 4 incidents, and more
3. Wait for the page to redirect back to the dashboard

## Step 6: Explore the Application

### Main Navigation

**Dashboard**
- Overview of key metrics
- Quick links to all sections

**Workers**
- View all workers
- Filter by employment status
- Click on any worker to see their profile with incidents and training records

**Equipment**
- View all equipment
- Filter by status (Available, In Use, Maintenance, Damaged)
- Click on equipment to see detailed usage and maintenance history

**Incidents**
- View all safety incidents
- See severity levels and resolution status
- Click on incidents to see involved workers and equipment

**Departments**
- View all departments
- See department details and personnel

**Analytics** (7 comprehensive dashboards)
- **Safety Dashboard**: High-risk incidents, worker safety profiles, incident hotspots
- **Equipment Performance**: Equipment reliability, maintenance due dates
- **Worker Utilization**: Productivity and hours analysis
- **Training Compliance**: Certification status tracking
- **Shift Utilization**: Shift capacity and worker distribution
- **Risk Assessment**: Worker risk scores and classifications
- **Department Scorecard**: Department performance metrics

## Features Included

### From Original SQL Files

✓ **19 Database Tables** with full relationships
✓ **Triggers** for automated business logic (status updates, validation)
✓ **Functions** for complex calculations (risk scores, utilization, downtime)
✓ **Procedures** for data operations (equipment transfer, incident reporting)
✓ **40+ Complex Analytical Queries** implemented as web routes
✓ **For/While/Loop constructs** demonstrated in data loading

### Web Application Features

✓ Responsive design (works on desktop, tablet, mobile)
✓ Real-time filtering and search
✓ Comprehensive analytics and dashboards
✓ Error handling and user-friendly messages
✓ Sample data loading for immediate testing
✓ Professional styling with color-coded severity levels

## URL Routes Reference

```
HOME & INIT
  /                           → Main dashboard
  /init-db                    → Initialize database

DATA LISTS
  /workers                    → Workers list
  /equipment                  → Equipment inventory
  /incidents                  → Safety incidents
  /departments                → Departments

ANALYTICS DASHBOARDS
  /analytics/safety-dashboard           → Safety metrics
  /analytics/equipment-performance      → Equipment reliability
  /analytics/worker-utilization         → Worker productivity
  /analytics/training-compliance        → Certifications
  /analytics/shift-utilization          → Shift capacity
  /analytics/risk-assessment            → Worker risk scores
  /analytics/department-scorecard       → Department metrics

DETAIL PAGES
  /worker/<id>                → Worker profile
  /equipment/<id>             → Equipment details
  /incident/<id>              → Incident details
  /department/<id>            → Department details
```

## Troubleshooting

### Virtual Environment Issues

If you get "ModuleNotFoundError", make sure the virtual environment is activated:

```bash
# Windows
where python
# Should show path inside the venv folder

# macOS/Linux
which python
# Should show path inside the venv folder
```

### Port Already in Use

If port 5000 is already in use, modify app.py:

```python
# Change this line at the bottom:
app.run(debug=True, host='0.0.0.0', port=5000)

# To:
app.run(debug=True, host='0.0.0.0', port=5001)
```

Then access at `http://localhost:5001`

### Database Errors

If you see database errors, click "Initialize Database with Sample Data" again to reset everything.

## Project Structure

```
mining_app/
├── app.py                 # Main Flask application
├── run_server.py         # Server startup script
├── run.bat               # Windows batch launcher
├── run.sh                # Linux/Mac shell launcher
├── requirements.txt      # Python dependencies
├── README.md             # Full documentation
├── mining_database.db    # SQLite database (created on first run)
├── templates/
│   ├── base.html        # Navigation and layout
│   ├── index.html       # Dashboard
│   ├── workers.html     # Workers list
│   ├── equipment.html   # Equipment list
│   ├── incidents.html   # Incidents list
│   ├── departments.html # Departments list
│   ├── safety_dashboard.html       # Safety analytics
│   ├── equipment_performance.html  # Equipment analytics
│   ├── worker_utilization.html     # Worker analytics
│   ├── training_compliance.html    # Training analytics
│   ├── shift_utilization.html      # Shift analytics
│   ├── risk_assessment.html        # Risk analytics
│   ├── department_scorecard.html   # Department analytics
│   ├── worker_detail.html         # Worker detail page
│   ├── equipment_detail.html      # Equipment detail page
│   ├── incident_detail.html       # Incident detail page
│   ├── department_detail.html     # Department detail page
│   └── 404.html, 500.html        # Error pages
└── static/
    └── css/
        └── style.css    # Application styling
```

## Sample Data Included

When you initialize the database, you'll get:

- **3 Departments**: Underground Operations, Maintenance Division, Safety & Compliance
- **3 Supervisors**: Arun Mehta, Priya Sharma, Rajesh Kumar
- **8 Workers**: Various roles including operators, technicians, helpers
- **4 Safety Gears**: Hard hats, vests, gloves, respirators
- **5 Equipment**: Forklift, Welding Machine, Crane, Pneumatic Drill, Hydraulic Press
- **4 Shifts**: Different locations and times
- **4 Safety Incidents**: With varying severity levels
- **Multiple Training Records**: For different workers
- **Maintenance Records**: Equipment maintenance history

## Performance Notes

- Database queries are optimized with proper indexing
- All analytics run in real-time on SQLite database
- First query might take a moment as database builds indexes
- Subsequent queries are very fast

## Technology Stack

- **Backend**: Python 3 with Flask
- **Database**: SQLite (automatically created)
- **ORM**: SQLAlchemy
- **Frontend**: HTML5, CSS3 (Responsive)
- **Architecture**: MVC pattern

## Next Steps

1. Explore the dashboards to understand the data
2. Try filtering workers and equipment by status
3. Click on individual records to see detailed information
4. Review the analytics dashboards for insights
5. Check the README.md for detailed documentation
6. Review app.py source code to understand the implementation

## Support

For questions or issues:
1. Check the browser console (F12) for client-side errors
2. Check terminal output for server errors
3. Verify all dependencies are installed with `pip list`
4. Ensure Python version is 3.7 or higher with `python --version`

---

**Enjoy exploring the Mining Management System!** ⛏️

