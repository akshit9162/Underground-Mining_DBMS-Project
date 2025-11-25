import os
import sqlite3
from datetime import datetime, timedelta
from functools import wraps
import traceback

from flask import Flask, render_template, request, jsonify, flash, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func, desc, text
import json

# Initialize Flask App
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mining_database.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = 'mining_secret_key_123'

db = SQLAlchemy(app)

# ============================================================================
# DATABASE MODELS (Converted from Oracle to SQLAlchemy)
# ============================================================================

class Department(db.Model):
    __tablename__ = 'Department'
    DepartmentID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    DeptName = db.Column(db.String(50), unique=True, nullable=False)
    Location = db.Column(db.String(100))
    HeadSupervisor = db.Column(db.Integer)
    SafetyBudget = db.Column(db.Float)

class Supervisor(db.Model):
    __tablename__ = 'Supervisor'
    SupervisorID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Name = db.Column(db.String(50), nullable=False)
    Contact = db.Column(db.String(20))
    Department = db.Column(db.String(50))
    DepartmentID = db.Column(db.Integer, db.ForeignKey('Department.DepartmentID'))
    YearsExperience = db.Column(db.Integer)
    Certification = db.Column(db.String(100))

class Worker(db.Model):
    __tablename__ = 'Worker'
    WorkerID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Name = db.Column(db.String(50), nullable=False)
    Age = db.Column(db.Integer)
    Role = db.Column(db.String(30))
    Contact = db.Column(db.String(20))
    S_ID = db.Column(db.Integer, db.ForeignKey('Supervisor.SupervisorID'))
    DepartmentID = db.Column(db.Integer, db.ForeignKey('Department.DepartmentID'))
    HireDate = db.Column(db.Date)
    Salary = db.Column(db.Float)
    EmploymentStatus = db.Column(db.String(20), default='Active')

class SafetyGear(db.Model):
    __tablename__ = 'Safety_Gear'
    GearID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    GearType = db.Column(db.String(50), nullable=False)
    Description = db.Column(db.String(200))
    IssuedDate = db.Column(db.Date, default=datetime.now)
    ExpiryDate = db.Column(db.Date)
    Status = db.Column(db.String(20), default='Available')

class Equipment(db.Model):
    __tablename__ = 'Equipment'
    EquipmentID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Type = db.Column(db.String(30))
    Model = db.Column(db.String(30))
    Status = db.Column(db.String(20), default='Available')
    OperatedBy = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'))
    PurchaseDate = db.Column(db.Date)
    MaintenanceSchedule = db.Column(db.String(50))
    LastMaintenance = db.Column(db.Date)
    DepreciationValue = db.Column(db.Float)

class Shift(db.Model):
    __tablename__ = 'Shift'
    ShiftID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ShiftDate = db.Column(db.Date, nullable=False)
    ShiftTime = db.Column(db.String(20))
    Duration = db.Column(db.Integer)
    Location = db.Column(db.String(50))
    MaxWorkers = db.Column(db.Integer)
    ShiftType = db.Column(db.String(20), default='Regular')

class AssignedShift(db.Model):
    __tablename__ = 'Assigned_Shift'
    WorkerID = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'), primary_key=True)
    ShiftID = db.Column(db.Integer, db.ForeignKey('Shift.ShiftID'), primary_key=True)
    AssignmentDate = db.Column(db.Date, default=datetime.now)
    AssignedBy = db.Column(db.Integer, db.ForeignKey('Supervisor.SupervisorID'))

class UsageRecord(db.Model):
    __tablename__ = 'Usage_Record'
    UsageID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    WorkerID = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'))
    EquipmentID = db.Column(db.Integer, db.ForeignKey('Equipment.EquipmentID'))
    ShiftID = db.Column(db.Integer, db.ForeignKey('Shift.ShiftID'))
    UsageTrack = db.Column(db.String(100))
    StartTime = db.Column(db.DateTime)
    EndTime = db.Column(db.DateTime)
    HoursUsed = db.Column(db.Float)
    Outcome = db.Column(db.String(50), default='Normal')

class MaintenanceRecord(db.Model):
    __tablename__ = 'Maintenance_Record'
    MaintenanceID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    EquipmentID = db.Column(db.Integer, db.ForeignKey('Equipment.EquipmentID'), nullable=False)
    MaintDate = db.Column(db.Date, default=datetime.now)
    PerformedBy = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'))
    MaintenanceType = db.Column(db.String(50))
    Notes = db.Column(db.String(400))
    Cost = db.Column(db.Float)
    NextDueDate = db.Column(db.Date)

class EquipmentTransfer(db.Model):
    __tablename__ = 'Equipment_Transfer'
    TransferID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    EquipmentID = db.Column(db.Integer, db.ForeignKey('Equipment.EquipmentID'), nullable=False)
    FromWorkerID = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'))
    ToWorkerID = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'), nullable=False)
    TransferDate = db.Column(db.Date, default=datetime.now)
    Notes = db.Column(db.String(400))
    TransferReason = db.Column(db.String(50))

class TrainingRecord(db.Model):
    __tablename__ = 'Training_Record'
    TrainingID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    WorkerID = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'), nullable=False)
    TrainingDate = db.Column(db.Date, default=datetime.now)
    Course = db.Column(db.String(100))
    ValidUntil = db.Column(db.Date)
    TrainingStatus = db.Column(db.String(20), default='Completed')
    TrainingLevel = db.Column(db.String(30))
    Certified_By = db.Column(db.Integer, db.ForeignKey('Supervisor.SupervisorID'))

class SafetyIncident(db.Model):
    __tablename__ = 'Safety_Incident'
    IncidentID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    IncidentDate = db.Column(db.Date, nullable=False)
    Location = db.Column(db.String(50))
    Severity = db.Column(db.Integer)
    IncidentType = db.Column(db.String(50))
    Description = db.Column(db.String(400))
    ReportedBy = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'))
    InvestigationRequired = db.Column(db.String(1), default='N')
    ResolutionStatus = db.Column(db.String(20), default='Open')

class IncidentWorker(db.Model):
    __tablename__ = 'Incident_Worker'
    IncidentID = db.Column(db.Integer, db.ForeignKey('Safety_Incident.IncidentID'), primary_key=True)
    WorkerID = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'), primary_key=True)
    Role_In_Incident = db.Column(db.String(50))

class IncidentEquipment(db.Model):
    __tablename__ = 'Incident_Equipment'
    IncidentID = db.Column(db.Integer, db.ForeignKey('Safety_Incident.IncidentID'), primary_key=True)
    EquipmentID = db.Column(db.Integer, db.ForeignKey('Equipment.EquipmentID'), primary_key=True)
    EquipmentRole = db.Column(db.String(50))

class WorkerGear(db.Model):
    __tablename__ = 'Worker_Gear'
    WorkerID = db.Column(db.Integer, db.ForeignKey('Worker.WorkerID'), primary_key=True)
    GearID = db.Column(db.Integer, db.ForeignKey('Safety_Gear.GearID'), primary_key=True)
    AssignedDate = db.Column(db.Date, primary_key=True, default=datetime.now)
    ReturnedDate = db.Column(db.Date)
    Condition = db.Column(db.String(20), default='Good')

# ============================================================================
# ERROR HANDLING DECORATOR
# ============================================================================

def handle_errors(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            print(f"Error: {str(e)}")
            print(traceback.format_exc())
            flash(f"Error: {str(e)}", "error")
            return redirect(url_for('index'))
    return decorated_function

# ============================================================================
# HELPER FUNCTIONS FOR TEMPLATES
# ============================================================================

@app.context_processor
def inject_helpers():
    def get_worker(worker_id):
        return Worker.query.get(worker_id) if worker_id else None
    
    def get_equipment(equip_id):
        return Equipment.query.get(equip_id) if equip_id else None
    
    return dict(get_worker=get_worker, get_equipment=get_equipment)

# ============================================================================
# ROUTES - HOME & NAVIGATION
# ============================================================================

@app.route('/')
def index():
    """Main dashboard"""
    try:
        # Overall metrics
        total_workers = Worker.query.filter_by(EmploymentStatus='Active').count()
        total_incidents = SafetyIncident.query.count()
        critical_incidents = SafetyIncident.query.filter(SafetyIncident.Severity >= 4).count()
        available_equipment = Equipment.query.filter_by(Status='Available').count()
        
        # Calculate average severity
        avg_severity = db.session.query(func.avg(SafetyIncident.Severity)).scalar() or 0
        
        return render_template('index.html',
                             total_workers=total_workers,
                             total_incidents=total_incidents,
                             critical_incidents=critical_incidents,
                             avg_severity=round(float(avg_severity), 2),
                             available_equipment=available_equipment)
    except Exception as e:
        flash(f"Error loading dashboard: {str(e)}", "error")
        return render_template('index.html', error=str(e))

@app.route('/workers')
@handle_errors
def workers_list():
    """List all workers with filters"""
    page = request.args.get('page', 1, type=int)
    status_filter = request.args.get('status', 'All')
    
    query = Worker.query
    if status_filter != 'All':
        query = query.filter_by(EmploymentStatus=status_filter)
    
    workers = query.paginate(page=page, per_page=10)
    statuses = ['Active', 'On Leave', 'Inactive']
    
    return render_template('workers.html', workers=workers.items, pagination=workers, statuses=statuses, selected_status=status_filter)

@app.route('/equipment')
@handle_errors
def equipment_list():
    """List all equipment"""
    page = request.args.get('page', 1, type=int)
    status_filter = request.args.get('status', 'All')
    
    query = Equipment.query
    if status_filter != 'All':
        query = query.filter_by(Status=status_filter)
    
    equipment = query.paginate(page=page, per_page=10)
    statuses = ['Available', 'In Use', 'Maintenance', 'Damaged']
    
    return render_template('equipment.html', equipment=equipment.items, pagination=equipment, statuses=statuses, selected_status=status_filter)

@app.route('/incidents')
@handle_errors
def incidents_list():
    """List all safety incidents"""
    page = request.args.get('page', 1, type=int)
    
    incidents = SafetyIncident.query.order_by(desc(SafetyIncident.IncidentDate)).paginate(page=page, per_page=10)
    
    return render_template('incidents.html', incidents=incidents.items, pagination=incidents)

@app.route('/departments')
@handle_errors
def departments_list():
    """List all departments"""
    departments = Department.query.all()
    return render_template('departments.html', departments=departments)

# ============================================================================
# ROUTES - COMPLEX QUERIES & ANALYTICS
# ============================================================================

@app.route('/analytics/safety-dashboard')
@handle_errors
def safety_dashboard():
    """Executive safety dashboard"""
    # High-risk incidents
    high_risk_incidents = SafetyIncident.query.filter(SafetyIncident.Severity >= 4).order_by(desc(SafetyIncident.IncidentDate)).limit(10).all()
    
    # Worker safety profiles
    worker_incidents = db.session.query(
        Worker.WorkerID,
        Worker.Name,
        Worker.Role,
        func.count(IncidentWorker.IncidentID).label('incident_count'),
        func.avg(SafetyIncident.Severity).label('avg_severity')
    ).outerjoin(IncidentWorker).outerjoin(SafetyIncident).group_by(Worker.WorkerID, Worker.Name, Worker.Role).order_by(desc(func.count(IncidentWorker.IncidentID))).limit(10).all()
    
    # Incident hotspots
    hotspots = db.session.query(
        SafetyIncident.Location,
        func.count(SafetyIncident.IncidentID).label('total_incidents'),
        func.avg(SafetyIncident.Severity).label('avg_severity')
    ).group_by(SafetyIncident.Location).order_by(desc(func.avg(SafetyIncident.Severity))).all()
    
    return render_template('safety_dashboard.html',
                         high_risk_incidents=high_risk_incidents,
                         worker_incidents=worker_incidents,
                         hotspots=hotspots)

@app.route('/analytics/equipment-performance')
@handle_errors
def equipment_performance():
    """Equipment reliability analysis"""
    # Equipment with issues
    problem_equipment = db.session.query(
        Equipment.EquipmentID,
        Equipment.Type,
        Equipment.Model,
        func.count(UsageRecord.UsageID).label('usage_count'),
        func.sum(db.case((UsageRecord.Outcome != 'Normal', 1), else_=0)).label('issue_count'),
        func.count(MaintenanceRecord.MaintenanceID).label('maint_count'),
        func.sum(MaintenanceRecord.Cost).label('total_maint_cost')
    ).outerjoin(UsageRecord).outerjoin(MaintenanceRecord).group_by(Equipment.EquipmentID, Equipment.Type, Equipment.Model).all()
    
    # Maintenance due
    maintenance_due = MaintenanceRecord.query.filter(MaintenanceRecord.NextDueDate < datetime.now()).all()
    
    return render_template('equipment_performance.html',
                         problem_equipment=problem_equipment,
                         maintenance_due=maintenance_due)

@app.route('/analytics/worker-utilization')
@handle_errors
def worker_utilization():
    """Worker productivity and utilization analysis"""
    workers_util = db.session.query(
        Worker.WorkerID,
        Worker.Name,
        Worker.Role,
        func.count(distinct=AssignedShift.ShiftID).label('assigned_shifts'),
        func.sum(UsageRecord.HoursUsed).label('actual_hours'),
        func.count(distinct=UsageRecord.EquipmentID).label('equipment_types'),
        func.count(distinct=IncidentWorker.IncidentID).label('incident_count')
    ).outerjoin(AssignedShift).outerjoin(UsageRecord).outerjoin(IncidentWorker).where(
        Worker.EmploymentStatus == 'Active'
    ).group_by(Worker.WorkerID, Worker.Name, Worker.Role).order_by(desc(func.sum(UsageRecord.HoursUsed))).all()
    
    return render_template('worker_utilization.html', workers_util=workers_util)

@app.route('/analytics/training-compliance')
@handle_errors
def training_compliance():
    """Training and certification tracking"""
    training_data = db.session.query(
        Worker.WorkerID,
        Worker.Name,
        Worker.Role,
        func.count(TrainingRecord.TrainingID).label('total_trainings'),
        func.sum(db.case((TrainingRecord.TrainingStatus == 'Completed', 1), else_=0)).label('completed'),
        func.sum(db.case((TrainingRecord.ValidUntil < datetime.now(), 1), else_=0)).label('expired')
    ).outerjoin(TrainingRecord).group_by(Worker.WorkerID, Worker.Name, Worker.Role).order_by(desc(func.count(TrainingRecord.TrainingID))).all()
    
    return render_template('training_compliance.html', training_data=training_data)

@app.route('/analytics/shift-utilization')
@handle_errors
def shift_utilization():
    """Shift utilization and worker distribution"""
    shifts = db.session.query(
        Shift.ShiftID,
        Shift.ShiftDate,
        Shift.ShiftTime,
        Shift.Location,
        Shift.MaxWorkers,
        func.count(AssignedShift.WorkerID).label('assigned_count'),
        func.count(distinct=UsageRecord.EquipmentID).label('equipment_in_use'),
        func.count(distinct=SafetyIncident.IncidentID).label('incidents')
    ).outerjoin(AssignedShift).outerjoin(UsageRecord).outerjoin(SafetyIncident).group_by(
        Shift.ShiftID, Shift.ShiftDate, Shift.ShiftTime, Shift.Location, Shift.MaxWorkers
    ).order_by(desc(Shift.ShiftDate)).all()
    
    return render_template('shift_utilization.html', shifts=shifts)

@app.route('/analytics/risk-assessment')
@handle_errors
def risk_assessment():
    """Worker risk scoring and classification"""
    risk_data = db.session.query(
        Worker.WorkerID,
        Worker.Name,
        Worker.Role,
        Department.DeptName,
        func.count(distinct=IncidentWorker.IncidentID).label('incident_count'),
        func.avg(SafetyIncident.Severity).label('avg_severity'),
        func.count(distinct=AssignedShift.ShiftID).label('shift_count')
    ).outerjoin(IncidentWorker).outerjoin(SafetyIncident).outerjoin(AssignedShift).outerjoin(Department).where(
        Worker.EmploymentStatus == 'Active'
    ).group_by(Worker.WorkerID, Worker.Name, Worker.Role, Department.DeptName).order_by(
        desc(func.count(distinct=IncidentWorker.IncidentID))
    ).all()
    
    # Calculate risk scores
    enriched_data = []
    for row in risk_data:
        incident_count = row.incident_count or 0
        avg_severity = row.avg_severity or 0
        shift_count = row.shift_count or 0
        risk_score = (incident_count * 2) + (avg_severity * 3) + (shift_count * 0.1)
        
        if risk_score > 15:
            risk_category = 'CRITICAL RISK'
        elif risk_score > 10:
            risk_category = 'HIGH RISK'
        elif risk_score > 5:
            risk_category = 'MEDIUM RISK'
        else:
            risk_category = 'LOW RISK'
        
        enriched_data.append({
            'worker_id': row.WorkerID,
            'name': row.Name,
            'role': row.Role,
            'dept': row.DeptName,
            'incidents': incident_count,
            'avg_severity': round(float(avg_severity), 2),
            'shifts': shift_count,
            'risk_score': round(risk_score, 2),
            'risk_category': risk_category
        })
    
    return render_template('risk_assessment.html', risk_data=enriched_data)

@app.route('/analytics/department-scorecard')
@handle_errors
def department_scorecard():
    """Department performance scorecard"""
    depts = db.session.query(
        Department.DepartmentID,
        Department.DeptName,
        Department.Location,
        func.count(distinct=Worker.WorkerID).label('worker_count'),
        func.sum(db.case((Worker.EmploymentStatus == 'Active', 1), else_=0)).label('active_workers'),
        func.count(distinct=SafetyIncident.IncidentID).label('incident_count'),
        func.avg(SafetyIncident.Severity).label('avg_severity'),
        func.count(distinct=MaintenanceRecord.MaintenanceID).label('maint_count'),
        func.sum(MaintenanceRecord.Cost).label('maint_cost')
    ).outerjoin(Worker).outerjoin(IncidentWorker).outerjoin(SafetyIncident).outerjoin(
        MaintenanceRecord
    ).group_by(Department.DepartmentID, Department.DeptName, Department.Location).all()
    
    return render_template('department_scorecard.html', departments=depts)

# ============================================================================
# ROUTES - ADVANCED COMPLEX QUERIES (3A, 3B, 3C, 1D)
# ============================================================================

@app.route('/analytics/query-1d-hotspots')
@handle_errors
def query_1d_hotspots():
    """Query 1D: Incident hotspots - locations with highest severity concentration"""
    hotspots = db.session.query(
        SafetyIncident.Location,
        func.count(SafetyIncident.IncidentID).label('total_incidents'),
        func.avg(SafetyIncident.Severity).label('avg_severity'),
        func.sum(db.case((SafetyIncident.Severity >= 4, 1), else_=0)).label('critical_incidents'),
        func.min(SafetyIncident.IncidentDate).label('first_incident'),
        func.max(SafetyIncident.IncidentDate).label('last_incident')
    ).group_by(SafetyIncident.Location).order_by(desc(func.avg(SafetyIncident.Severity))).all()
    
    # Enrich data
    enriched_hotspots = []
    for spot in hotspots:
        total = spot.total_incidents or 0
        critical = spot.critical_incidents or 0
        critical_pct = (critical * 100 / total) if total > 0 else 0
        
        if spot.first_incident and spot.last_incident:
            days_span = (spot.last_incident - spot.first_incident).days
        else:
            days_span = 0
        
        enriched_hotspots.append({
            'location': spot.Location,
            'total_incidents': total,
            'avg_severity': round(float(spot.avg_severity or 0), 2),
            'critical_incidents': critical,
            'critical_pct': round(critical_pct, 1),
            'first_incident': spot.first_incident,
            'last_incident': spot.last_incident,
            'days_span': days_span,
            'severity_rank': 'CRITICAL' if (spot.avg_severity or 0) >= 4 else 'HIGH' if (spot.avg_severity or 0) >= 3 else 'MEDIUM'
        })
    
    return render_template('query_1d_hotspots.html', hotspots=enriched_hotspots)

@app.route('/analytics/query-3a-utilization')
@handle_errors
def query_3a_utilization():
    """Query 3A: Worker utilization matrix with multi-dimensional analysis"""
    workers_util = db.session.query(
        Worker.WorkerID,
        Worker.Name,
        Worker.Role,
        Department.DeptName,
        func.count(distinct=AssignedShift.ShiftID).label('assigned_shifts'),
        func.sum(Shift.Duration).label('total_hours'),
        func.count(distinct=UsageRecord.EquipmentID).label('equipment_types'),
        func.sum(UsageRecord.HoursUsed).label('actual_hours'),
        func.count(distinct=IncidentWorker.IncidentID).label('incident_count')
    ).outerjoin(AssignedShift).outerjoin(Shift).outerjoin(UsageRecord).outerjoin(IncidentWorker).outerjoin(Department).where(
        Worker.EmploymentStatus == 'Active'
    ).group_by(Worker.WorkerID, Worker.Name, Worker.Role, Department.DeptName).order_by(
        desc(func.sum(UsageRecord.HoursUsed))
    ).all()
    
    # Enrich data
    enriched_util = []
    for idx, row in enumerate(workers_util, 1):
        assigned_hrs = row.total_hours or 0
        actual_hrs = row.actual_hours or 0
        utilization_pct = (actual_hrs / assigned_hrs * 100) if assigned_hrs > 0 else 0
        assigned_shifts = row.assigned_shifts or 0
        incident_rate = (row.incident_count * 100 / assigned_shifts) if assigned_shifts > 0 else 0
        
        enriched_util.append({
            'worker_id': row.WorkerID,
            'name': row.Name,
            'role': row.Role,
            'dept': row.DeptName,
            'assigned_shifts': assigned_shifts,
            'total_assigned_hours': round(float(assigned_hrs), 2),
            'equipment_types': row.equipment_types or 0,
            'actual_hours': round(float(actual_hrs), 2),
            'utilization_pct': round(utilization_pct, 1),
            'incidents': row.incident_count or 0,
            'incident_rate': round(incident_rate, 1),
            'productivity_rank': idx,
            'performance_level': 'EXCELLENT' if utilization_pct >= 80 else 'GOOD' if utilization_pct >= 60 else 'FAIR' if utilization_pct >= 40 else 'LOW'
        })
    
    return render_template('query_3a_utilization.html', workers=enriched_util)

@app.route('/analytics/query-3b-training')
@handle_errors
def query_3b_training():
    """Query 3B: Training and certification compliance tracking"""
    workers_training = db.session.query(
        Worker.WorkerID,
        Worker.Name,
        Worker.Role,
        func.count(distinct=TrainingRecord.TrainingID).label('total_trainings'),
        func.sum(db.case((TrainingRecord.TrainingStatus == 'Completed', 1), else_=0)).label('completed'),
        func.sum(db.case((TrainingRecord.TrainingStatus == 'Expired', 1), else_=0)).label('expired')
    ).outerjoin(TrainingRecord).group_by(Worker.WorkerID, Worker.Name, Worker.Role).order_by(
        desc(func.sum(db.case((TrainingRecord.TrainingStatus == 'Completed', 1), else_=0)))
    ).all()
    
    # Enrich data and get certifications
    enriched_training = []
    for row in workers_training:
        total = row.total_trainings or 0
        completed = row.completed or 0
        expired = row.expired or 0
        
        # Get actual certifications
        certs = TrainingRecord.query.filter_by(WorkerID=row.WorkerID, TrainingStatus='Completed').all()
        cert_list = [c.Course for c in certs] if certs else []
        
        if total == 0:
            cert_status = 'NO CERTIFICATIONS'
        elif completed >= 3:
            cert_status = 'HIGHLY CERTIFIED'
        elif completed >= 1:
            cert_status = 'CERTIFIED'
        else:
            cert_status = 'IN PROGRESS'
        
        enriched_training.append({
            'worker_id': row.WorkerID,
            'name': row.Name,
            'role': row.Role,
            'total_trainings': total,
            'completed': completed,
            'expired': expired,
            'certifications': ', '.join(cert_list) if cert_list else 'None',
            'cert_status': cert_status,
            'completion_rate': round((completed / total * 100) if total > 0 else 0, 1)
        })
    
    return render_template('query_3b_training.html', workers=enriched_training)

@app.route('/analytics/query-3c-gear')
@handle_errors
def query_3c_gear():
    """Query 3C: Worker safety gear compliance and assignment tracking"""
    workers_gear = db.session.query(
        Worker.WorkerID,
        Worker.Name,
        Worker.Role,
        func.count(distinct=WorkerGear.GearID).label('assigned_gear_types'),
        func.sum(db.case((WorkerGear.Condition == 'Good', 1), else_=0)).label('good_condition'),
        func.sum(db.case((WorkerGear.Condition.in_(['Fair', 'Poor', 'Damaged']), 1), else_=0)).label('damaged_gear'),
        func.sum(db.case((WorkerGear.ReturnedDate == None, 1), else_=0)).label('currently_holding')
    ).outerjoin(WorkerGear).group_by(Worker.WorkerID, Worker.Name, Worker.Role).all()
    
    # Enrich data
    enriched_gear = []
    for row in workers_gear:
        assigned = row.assigned_gear_types or 0
        good = row.good_condition or 0
        damaged = row.damaged_gear or 0
        holding = row.currently_holding or 0
        
        quality_pct = (good * 100 / assigned) if assigned > 0 else 0
        
        if assigned == 0:
            gear_status = 'NO GEAR ASSIGNED'
        elif quality_pct < 70:
            gear_status = 'REPLACE GEAR'
        else:
            gear_status = 'COMPLIANT'
        
        # Get gear types assigned
        gear_records = WorkerGear.query.filter_by(WorkerID=row.WorkerID).all()
        gear_types = []
        for g in gear_records:
            sg = SafetyGear.query.get(g.GearID)
            if sg:
                gear_types.append(sg.GearType)
        
        enriched_gear.append({
            'worker_id': row.WorkerID,
            'name': row.Name,
            'role': row.Role,
            'assigned_gear': assigned,
            'good_condition': good,
            'damaged_gear': damaged,
            'currently_holding': holding,
            'quality_pct': round(quality_pct, 1),
            'gear_types': ', '.join(gear_types) if gear_types else 'None',
            'gear_status': gear_status
        })
    
    return render_template('query_3c_gear.html', workers=enriched_gear)

# ============================================================================
# ROUTES - INDIVIDUAL DETAILS
# ============================================================================

@app.route('/worker/<int:worker_id>')
@handle_errors
def worker_detail(worker_id):
    """Worker detail page"""
    worker = Worker.query.get_or_404(worker_id)
    incidents = db.session.query(SafetyIncident).join(IncidentWorker).filter(IncidentWorker.WorkerID == worker_id).all()
    trainings = TrainingRecord.query.filter_by(WorkerID=worker_id).all()
    equipment_used = db.session.query(Equipment).join(UsageRecord).filter(UsageRecord.WorkerID == worker_id).distinct().all()
    
    return render_template('worker_detail.html',
                         worker=worker,
                         incidents=incidents,
                         trainings=trainings,
                         equipment_used=equipment_used)

@app.route('/equipment/<int:equip_id>')
@handle_errors
def equipment_detail(equip_id):
    """Equipment detail page"""
    equipment = Equipment.query.get_or_404(equip_id)
    operator = Worker.query.get(equipment.OperatedBy) if equipment.OperatedBy else None
    usage_records = UsageRecord.query.filter_by(EquipmentID=equip_id).order_by(desc(UsageRecord.StartTime)).limit(20).all()
    maintenance_records = MaintenanceRecord.query.filter_by(EquipmentID=equip_id).order_by(desc(MaintenanceRecord.MaintDate)).all()
    transfers = EquipmentTransfer.query.filter_by(EquipmentID=equip_id).order_by(desc(EquipmentTransfer.TransferDate)).all()
    
    return render_template('equipment_detail.html',
                         equipment=equipment,
                         operator=operator,
                         usage_records=usage_records,
                         maintenance_records=maintenance_records,
                         transfers=transfers)

@app.route('/incident/<int:incident_id>')
@handle_errors
def incident_detail(incident_id):
    """Incident detail page"""
    incident = SafetyIncident.query.get_or_404(incident_id)
    involved_workers = db.session.query(Worker, IncidentWorker.Role_In_Incident).join(IncidentWorker).filter(IncidentWorker.IncidentID == incident_id).all()
    involved_equipment = db.session.query(Equipment, IncidentEquipment.EquipmentRole).join(IncidentEquipment).filter(IncidentEquipment.IncidentID == incident_id).all()
    
    return render_template('incident_detail.html',
                         incident=incident,
                         involved_workers=involved_workers,
                         involved_equipment=involved_equipment)

@app.route('/department/<int:dept_id>')
@handle_errors
def department_detail(dept_id):
    """Department detail page"""
    dept = Department.query.get_or_404(dept_id)
    workers = Worker.query.filter_by(DepartmentID=dept_id).all()
    incidents = db.session.query(SafetyIncident).join(IncidentWorker).join(Worker).filter(Worker.DepartmentID == dept_id).distinct().all()
    
    return render_template('department_detail.html',
                         dept=dept,
                         workers=workers,
                         incidents=incidents)

# ============================================================================
# ROUTES - CRUD OPERATIONS (SUPERVISORS, WORKERS, EQUIPMENT)
# ============================================================================

@app.route('/supervisors')
@handle_errors
def supervisors_list():
    """List all supervisors"""
    supervisors = Supervisor.query.all()
    
    # Fix missing department names by fetching from DepartmentID
    for supervisor in supervisors:
        if (not supervisor.Department or supervisor.Department == 'Unknown') and supervisor.DepartmentID:
            dept = Department.query.get(supervisor.DepartmentID)
            if dept:
                supervisor.Department = dept.DeptName
                # Update the database so it persists
                db.session.commit()
    
    return render_template('supervisors.html', supervisors=supervisors)

@app.route('/supervisor/add', methods=['GET', 'POST'])
@handle_errors
def add_supervisor():
    """Add a new supervisor"""
    if request.method == 'POST':
        try:
            name = request.form.get('name')
            contact = request.form.get('contact')
            department_id = request.form.get('department_id')
            years_exp = request.form.get('years_exp', type=int)
            certification = request.form.get('certification')
            
            if not name or not department_id:
                flash('Name and Department are required!', 'error')
                return redirect(url_for('add_supervisor'))
            
            # Get department name
            dept = Department.query.get(department_id)
            dept_name = dept.DeptName if dept else 'Unknown'
            
            supervisor = Supervisor(
                Name=name,
                Contact=contact,
                Department=dept_name,
                DepartmentID=department_id,
                YearsExperience=years_exp,
                Certification=certification
            )
            db.session.add(supervisor)
            db.session.commit()
            flash(f'Supervisor {name} added successfully!', 'success')
            return redirect(url_for('supervisors_list'))
        except Exception as e:
            db.session.rollback()
            flash(f'Error adding supervisor: {str(e)}', 'error')
            return redirect(url_for('add_supervisor'))
    
    departments = Department.query.all()
    return render_template('add_supervisor.html', departments=departments)

@app.route('/supervisor/delete/<int:supervisor_id>', methods=['POST'])
@handle_errors
def delete_supervisor(supervisor_id):
    """Delete a supervisor"""
    try:
        supervisor = Supervisor.query.get_or_404(supervisor_id)
        name = supervisor.Name
        
        # Check if any workers are assigned to this supervisor
        workers = Worker.query.filter_by(S_ID=supervisor_id).count()
        if workers > 0:
            flash(f'Cannot delete supervisor with {workers} assigned workers. Please reassign them first.', 'error')
            return redirect(url_for('supervisors_list'))
        
        db.session.delete(supervisor)
        db.session.commit()
        flash(f'Supervisor {name} deleted successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error deleting supervisor: {str(e)}', 'error')
    
    return redirect(url_for('supervisors_list'))

@app.route('/worker/add', methods=['GET', 'POST'])
@handle_errors
def add_worker():
    """Add a new worker"""
    if request.method == 'POST':
        try:
            name = request.form.get('name')
            age = request.form.get('age', type=int)
            role = request.form.get('role')
            contact = request.form.get('contact')
            supervisor_id = request.form.get('supervisor_id')
            department_id = request.form.get('department_id')
            salary = request.form.get('salary', type=float)
            
            if not name or not age or not department_id:
                flash('Name, Age, and Department are required!', 'error')
                return redirect(url_for('add_worker'))
            
            if age < 18:
                flash('Worker must be at least 18 years old!', 'error')
                return redirect(url_for('add_worker'))
            
            worker = Worker(
                Name=name,
                Age=age,
                Role=role,
                Contact=contact,
                S_ID=supervisor_id if supervisor_id else None,
                DepartmentID=department_id,
                HireDate=datetime.now().date(),
                Salary=salary,
                EmploymentStatus='Active'
            )
            db.session.add(worker)
            db.session.commit()
            flash(f'Worker {name} added successfully!', 'success')
            return redirect(url_for('workers_list'))
        except Exception as e:
            db.session.rollback()
            flash(f'Error adding worker: {str(e)}', 'error')
            return redirect(url_for('add_worker'))
    
    supervisors = Supervisor.query.all()
    departments = Department.query.all()
    return render_template('add_worker.html', supervisors=supervisors, departments=departments)

@app.route('/worker/delete/<int:worker_id>', methods=['POST'])
@handle_errors
def delete_worker(worker_id):
    """Delete a worker"""
    try:
        worker = Worker.query.get_or_404(worker_id)
        name = worker.Name
        
        # Delete related records
        IncidentWorker.query.filter_by(WorkerID=worker_id).delete()
        UsageRecord.query.filter_by(WorkerID=worker_id).delete()
        AssignedShift.query.filter_by(WorkerID=worker_id).delete()
        TrainingRecord.query.filter_by(WorkerID=worker_id).delete()
        EquipmentTransfer.query.filter_by(FromWorkerID=worker_id).delete()
        EquipmentTransfer.query.filter_by(ToWorkerID=worker_id).delete()
        
        db.session.delete(worker)
        db.session.commit()
        flash(f'Worker {name} and related records deleted successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error deleting worker: {str(e)}', 'error')
    
    return redirect(url_for('workers_list'))

@app.route('/equipment/add', methods=['GET', 'POST'])
@handle_errors
def add_equipment():
    """Add new equipment"""
    if request.method == 'POST':
        try:
            equip_type = request.form.get('type')
            model = request.form.get('model')
            operator_id = request.form.get('operator_id')
            maint_schedule = request.form.get('maint_schedule')
            depreciation = request.form.get('depreciation', type=float)
            
            if not equip_type or not model:
                flash('Type and Model are required!', 'error')
                return redirect(url_for('add_equipment'))
            
            equipment = Equipment(
                Type=equip_type,
                Model=model,
                Status='Available',
                OperatedBy=operator_id if operator_id else None,
                PurchaseDate=datetime.now().date(),
                MaintenanceSchedule=maint_schedule,
                LastMaintenance=datetime.now().date(),
                DepreciationValue=depreciation
            )
            db.session.add(equipment)
            db.session.commit()
            flash(f'Equipment {model} added successfully!', 'success')
            return redirect(url_for('equipment_list'))
        except Exception as e:
            db.session.rollback()
            flash(f'Error adding equipment: {str(e)}', 'error')
            return redirect(url_for('add_equipment'))
    
    workers = Worker.query.filter_by(EmploymentStatus='Active').all()
    return render_template('add_equipment.html', workers=workers)

@app.route('/equipment/delete/<int:equipment_id>', methods=['POST'])
@handle_errors
def delete_equipment(equipment_id):
    """Delete equipment"""
    try:
        equipment = Equipment.query.get_or_404(equipment_id)
        model = equipment.Model
        
        # Delete related records
        UsageRecord.query.filter_by(EquipmentID=equipment_id).delete()
        MaintenanceRecord.query.filter_by(EquipmentID=equipment_id).delete()
        IncidentEquipment.query.filter_by(EquipmentID=equipment_id).delete()
        EquipmentTransfer.query.filter_by(EquipmentID=equipment_id).delete()
        
        db.session.delete(equipment)
        db.session.commit()
        flash(f'Equipment {model} and related records deleted successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error deleting equipment: {str(e)}', 'error')
    
    return redirect(url_for('equipment_list'))

# ============================================================================
# ROUTES - SAMPLE DATA
# ============================================================================

@app.route('/init-db', methods=['GET', 'POST'])
def init_database():
    """Initialize database with sample data"""
    try:
        # Drop all tables
        db.drop_all()
        # Create all tables
        db.create_all()
        
        # Insert Departments
        dept1 = Department(DeptName='Underground Operations', Location='Mine Level 1', SafetyBudget=500000)
        dept2 = Department(DeptName='Maintenance Division', Location='Surface', SafetyBudget=300000)
        dept3 = Department(DeptName='Safety & Compliance', Location='Administrative', SafetyBudget=200000)
        db.session.add_all([dept1, dept2, dept3])
        db.session.commit()
        
        # Insert Supervisors
        sup1 = Supervisor(Name='Arun Mehta', Contact='9876543210', DepartmentID=dept1.DepartmentID, YearsExperience=15, Certification='Mining Supervisor')
        sup2 = Supervisor(Name='Priya Sharma', Contact='9123456780', DepartmentID=dept2.DepartmentID, YearsExperience=12, Certification='Maintenance Specialist')
        sup3 = Supervisor(Name='Rajesh Kumar', Contact='9988776655', DepartmentID=dept3.DepartmentID, YearsExperience=20, Certification='Safety Manager')
        db.session.add_all([sup1, sup2, sup3])
        db.session.commit()
        
        # Insert Workers
        workers = [
            Worker(Name='Rohan Kumar', Age=28, Role='Operator', Contact='9000010001', S_ID=sup1.SupervisorID, DepartmentID=dept1.DepartmentID, HireDate=datetime(2020, 3, 15), Salary=45000, EmploymentStatus='Active'),
            Worker(Name='Aisha Verma', Age=26, Role='Technician', Contact='9000010002', S_ID=sup1.SupervisorID, DepartmentID=dept1.DepartmentID, HireDate=datetime(2021, 7, 20), Salary=40000, EmploymentStatus='Active'),
            Worker(Name='Sameer Khan', Age=32, Role='Operator', Contact='9000010003', S_ID=sup2.SupervisorID, DepartmentID=dept2.DepartmentID, HireDate=datetime(2019, 1, 10), Salary=50000, EmploymentStatus='Active'),
            Worker(Name='Neha Singh', Age=24, Role='Helper', Contact='9000010004', S_ID=sup2.SupervisorID, DepartmentID=dept2.DepartmentID, HireDate=datetime(2023, 5, 1), Salary=25000, EmploymentStatus='Active'),
            Worker(Name='Vikram Patel', Age=35, Role='Senior Operator', Contact='9000010005', S_ID=sup1.SupervisorID, DepartmentID=dept1.DepartmentID, HireDate=datetime(2018, 9, 12), Salary=60000, EmploymentStatus='Active'),
            Worker(Name='Priya Das', Age=29, Role='Coordinator', Contact='9000010006', S_ID=sup3.SupervisorID, DepartmentID=dept3.DepartmentID, HireDate=datetime(2020, 6, 1), Salary=38000, EmploymentStatus='Active'),
            Worker(Name='Arjun Singh', Age=31, Role='Technician', Contact='9000010007', S_ID=sup2.SupervisorID, DepartmentID=dept2.DepartmentID, HireDate=datetime(2019, 11, 15), Salary=42000, EmploymentStatus='Active'),
            Worker(Name='Divya Kapoor', Age=27, Role='Helper', Contact='9000010008', S_ID=sup1.SupervisorID, DepartmentID=dept1.DepartmentID, HireDate=datetime(2021, 2, 20), Salary=28000, EmploymentStatus='Active'),
        ]
        db.session.add_all(workers)
        db.session.commit()
        
        # Insert Safety Gear
        gears = [
            SafetyGear(GearType='Hard Hat', Description='Yellow protective helmet', ExpiryDate=datetime.now() + timedelta(days=730), Status='Available'),
            SafetyGear(GearType='Safety Vest', Description='Reflective safety vest', ExpiryDate=datetime.now() + timedelta(days=730), Status='Available'),
            SafetyGear(GearType='Safety Gloves', Description='Cut-resistant gloves', ExpiryDate=datetime.now() + timedelta(days=365), Status='Available'),
            SafetyGear(GearType='Respirator', Description='HEPA filter respirator', ExpiryDate=datetime.now() + timedelta(days=365), Status='In Use'),
        ]
        db.session.add_all(gears)
        db.session.commit()
        
        # Insert Equipment
        equipment = [
            Equipment(Type='Forklift', Model='CAT-100', Status='Available', OperatedBy=workers[0].WorkerID, PurchaseDate=datetime(2019, 5, 10), MaintenanceSchedule='Monthly', DepreciationValue=35000),
            Equipment(Type='Welding Machine', Model='WM-200', Status='Available', OperatedBy=workers[1].WorkerID, PurchaseDate=datetime(2020, 12, 1), MaintenanceSchedule='Quarterly', DepreciationValue=15000),
            Equipment(Type='Crane', Model='CR-450', Status='Available', OperatedBy=workers[2].WorkerID, PurchaseDate=datetime(2018, 3, 15), MaintenanceSchedule='Monthly', DepreciationValue=55000),
            Equipment(Type='Pneumatic Drill', Model='PD-300', Status='Available', OperatedBy=workers[3].WorkerID, PurchaseDate=datetime(2021, 8, 22), MaintenanceSchedule='Semi-Annual', DepreciationValue=12000),
            Equipment(Type='Hydraulic Press', Model='HP-500', Status='Available', OperatedBy=workers[4].WorkerID, PurchaseDate=datetime(2020, 1, 10), MaintenanceSchedule='Quarterly', DepreciationValue=28000),
        ]
        db.session.add_all(equipment)
        db.session.commit()
        
        # Insert Shifts
        shifts = [
            Shift(ShiftDate=datetime.now(), ShiftTime='08:00-16:00', Duration=8, Location='Main Shaft', MaxWorkers=10, ShiftType='Regular'),
            Shift(ShiftDate=datetime.now(), ShiftTime='16:00-00:00', Duration=8, Location='East Wing', MaxWorkers=8, ShiftType='Regular'),
            Shift(ShiftDate=datetime.now() + timedelta(days=1), ShiftTime='08:00-16:00', Duration=8, Location='Main Shaft', MaxWorkers=10, ShiftType='Regular'),
            Shift(ShiftDate=datetime.now() + timedelta(days=1), ShiftTime='00:00-08:00', Duration=8, Location='Maintenance Area', MaxWorkers=5, ShiftType='Maintenance'),
        ]
        db.session.add_all(shifts)
        db.session.commit()
        
        # Assign workers to shifts
        assignments = [
            AssignedShift(WorkerID=workers[0].WorkerID, ShiftID=shifts[0].ShiftID, AssignedBy=sup1.SupervisorID),
            AssignedShift(WorkerID=workers[1].WorkerID, ShiftID=shifts[0].ShiftID, AssignedBy=sup1.SupervisorID),
            AssignedShift(WorkerID=workers[2].WorkerID, ShiftID=shifts[1].ShiftID, AssignedBy=sup2.SupervisorID),
            AssignedShift(WorkerID=workers[0].WorkerID, ShiftID=shifts[2].ShiftID, AssignedBy=sup1.SupervisorID),
            AssignedShift(WorkerID=workers[3].WorkerID, ShiftID=shifts[2].ShiftID, AssignedBy=sup1.SupervisorID),
        ]
        db.session.add_all(assignments)
        db.session.commit()
        
        # Insert Usage Records
        usage_records = [
            UsageRecord(WorkerID=workers[0].WorkerID, EquipmentID=equipment[0].EquipmentID, ShiftID=shifts[0].ShiftID, UsageTrack='Loaded materials', StartTime=datetime.now(), EndTime=datetime.now() + timedelta(hours=6.5), HoursUsed=6.5, Outcome='Normal'),
            UsageRecord(WorkerID=workers[1].WorkerID, EquipmentID=equipment[1].EquipmentID, ShiftID=shifts[0].ShiftID, UsageTrack='Welding operation', StartTime=datetime.now() + timedelta(minutes=15), EndTime=datetime.now() + timedelta(hours=5.75), HoursUsed=5.75, Outcome='Normal'),
            UsageRecord(WorkerID=workers[2].WorkerID, EquipmentID=equipment[2].EquipmentID, ShiftID=shifts[1].ShiftID, UsageTrack='Crane lifting', StartTime=datetime.now() + timedelta(hours=16), EndTime=datetime.now() + timedelta(hours=23.25), HoursUsed=7.25, Outcome='Minor Issue'),
            UsageRecord(WorkerID=workers[0].WorkerID, EquipmentID=equipment[0].EquipmentID, ShiftID=shifts[2].ShiftID, UsageTrack='Transporting goods', StartTime=datetime.now() + timedelta(days=1), EndTime=datetime.now() + timedelta(days=1, hours=7.5), HoursUsed=7.5, Outcome='Normal'),
        ]
        db.session.add_all(usage_records)
        db.session.commit()
        
        # Insert Training Records
        trainings = [
            TrainingRecord(WorkerID=workers[0].WorkerID, TrainingDate=datetime(2025, 3, 10), Course='Forklift Operation Level 1', ValidUntil=datetime(2026, 3, 10), TrainingLevel='Basic', Certified_By=sup1.SupervisorID),
            TrainingRecord(WorkerID=workers[1].WorkerID, TrainingDate=datetime(2025, 2, 20), Course='Welding Basics', ValidUntil=datetime(2027, 2, 20), TrainingLevel='Advanced', Certified_By=sup1.SupervisorID),
            TrainingRecord(WorkerID=workers[2].WorkerID, TrainingDate=datetime(2025, 4, 15), Course='Crane Operation Advanced', ValidUntil=datetime(2026, 4, 15), TrainingLevel='Expert', Certified_By=sup2.SupervisorID),
            TrainingRecord(WorkerID=workers[4].WorkerID, TrainingDate=datetime(2025, 1, 10), Course='Safety Management', ValidUntil=datetime(2027, 1, 10), TrainingLevel='Advanced', Certified_By=sup3.SupervisorID),
        ]
        db.session.add_all(trainings)
        db.session.commit()
        
        # Insert Maintenance Records
        maintenance = [
            MaintenanceRecord(EquipmentID=equipment[2].EquipmentID, MaintDate=datetime(2025, 10, 25), PerformedBy=workers[1].WorkerID, MaintenanceType='Routine', Notes='Crane inspection and lubrication', Cost=2500, NextDueDate=datetime(2025, 11, 25)),
            MaintenanceRecord(EquipmentID=equipment[0].EquipmentID, MaintDate=datetime(2025, 10, 20), PerformedBy=workers[0].WorkerID, MaintenanceType='Preventive', Notes='Forklift brake inspection', Cost=1500, NextDueDate=datetime(2025, 11, 20)),
            MaintenanceRecord(EquipmentID=equipment[1].EquipmentID, MaintDate=datetime(2025, 9, 15), PerformedBy=workers[1].WorkerID, MaintenanceType='Corrective', Notes='Welding machine valve replacement', Cost=3000, NextDueDate=datetime(2025, 12, 15)),
        ]
        db.session.add_all(maintenance)
        db.session.commit()
        
        # Insert Worker-Gear assignments
        gear_assignments = [
            WorkerGear(WorkerID=workers[0].WorkerID, GearID=gears[0].GearID, Condition='Good'),
            WorkerGear(WorkerID=workers[0].WorkerID, GearID=gears[2].GearID, Condition='Good'),
            WorkerGear(WorkerID=workers[1].WorkerID, GearID=gears[0].GearID, Condition='Fair'),
            WorkerGear(WorkerID=workers[2].WorkerID, GearID=gears[1].GearID, Condition='Good'),
            WorkerGear(WorkerID=workers[3].WorkerID, GearID=gears[3].GearID, Condition='Good'),
        ]
        db.session.add_all(gear_assignments)
        db.session.commit()
        
        # Insert Safety Incidents
        incidents = [
            SafetyIncident(IncidentDate=datetime.now(), Location='Main Shaft', Severity=3, IncidentType='Near Miss', Description='Minor slip near the welding area', ReportedBy=workers[1].WorkerID, ResolutionStatus='Open'),
            SafetyIncident(IncidentDate=datetime.now() + timedelta(days=1), Location='East Wing', Severity=5, IncidentType='Equipment Failure', Description='Crane malfunction during lifting', ReportedBy=workers[2].WorkerID, InvestigationRequired='Y', ResolutionStatus='In Progress'),
            SafetyIncident(IncidentDate=datetime.now() - timedelta(days=3), Location='Main Shaft', Severity=2, IncidentType='Near Miss', Description='Low-severity near-miss event', ReportedBy=workers[3].WorkerID, ResolutionStatus='Resolved'),
            SafetyIncident(IncidentDate=datetime.now() - timedelta(days=5), Location='Maintenance Area', Severity=4, IncidentType='Injury', Description='Worker injured while handling equipment', ReportedBy=workers[4].WorkerID, InvestigationRequired='Y', ResolutionStatus='In Progress'),
        ]
        db.session.add_all(incidents)
        db.session.commit()
        
        # Insert Incident-Worker links
        incident_workers = [
            IncidentWorker(IncidentID=incidents[0].IncidentID, WorkerID=workers[1].WorkerID, Role_In_Incident='Primary'),
            IncidentWorker(IncidentID=incidents[1].IncidentID, WorkerID=workers[2].WorkerID, Role_In_Incident='Primary'),
            IncidentWorker(IncidentID=incidents[1].IncidentID, WorkerID=workers[0].WorkerID, Role_In_Incident='Witness'),
            IncidentWorker(IncidentID=incidents[3].IncidentID, WorkerID=workers[4].WorkerID, Role_In_Incident='Affected'),
        ]
        db.session.add_all(incident_workers)
        db.session.commit()
        
        # Insert Incident-Equipment links
        incident_equipment = [
            IncidentEquipment(IncidentID=incidents[0].IncidentID, EquipmentID=equipment[1].EquipmentID, EquipmentRole='Contributed'),
            IncidentEquipment(IncidentID=incidents[1].IncidentID, EquipmentID=equipment[2].EquipmentID, EquipmentRole='Direct Cause'),
            IncidentEquipment(IncidentID=incidents[3].IncidentID, EquipmentID=equipment[4].EquipmentID, EquipmentRole='Direct Cause'),
        ]
        db.session.add_all(incident_equipment)
        db.session.commit()
        
        # Insert Equipment Transfers
        transfers = [
            EquipmentTransfer(EquipmentID=equipment[0].EquipmentID, FromWorkerID=workers[0].WorkerID, ToWorkerID=workers[4].WorkerID, Notes='Transferred to senior operator', TransferReason='Promotion'),
        ]
        db.session.add_all(transfers)
        db.session.commit()
        
        flash('Database initialized successfully with sample data!', 'success')
        return redirect(url_for('index'))
    
    except Exception as e:
        db.session.rollback()
        print(f"Error: {str(e)}")
        print(traceback.format_exc())
        flash(f"Error initializing database: {str(e)}", "error")
        return redirect(url_for('index'))

# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.errorhandler(404)
def page_not_found(error):
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return render_template('500.html'), 500

# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
