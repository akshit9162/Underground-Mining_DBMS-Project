-- ============================================================================
-- UNDERGROUND MINING DATABASE - SCHEMA DEFINITION
-- Tables, Constraints, and Data Structures
-- ============================================================================

-- OPTIONAL: Drop existing tables if needed
-- DROP TABLE Incident_Equipment CASCADE CONSTRAINTS;
-- DROP TABLE Incident_Worker CASCADE CONSTRAINTS;
-- DROP TABLE Safety_Incident CASCADE CONSTRAINTS;
-- DROP TABLE Equipment_Transfer CASCADE CONSTRAINTS;
-- DROP TABLE Maintenance_Record CASCADE CONSTRAINTS;
-- DROP TABLE Training_Record CASCADE CONSTRAINTS;
-- DROP TABLE Usage_Record CASCADE CONSTRAINTS;
-- DROP TABLE Assigned_Shift CASCADE CONSTRAINTS;
-- DROP TABLE Shift CASCADE CONSTRAINTS;
-- DROP TABLE Equipment CASCADE CONSTRAINTS;
-- DROP TABLE Worker CASCADE CONSTRAINTS;
-- DROP TABLE Supervisor CASCADE CONSTRAINTS;
-- DROP TABLE Department CASCADE CONSTRAINTS;
-- DROP TABLE Safety_Gear CASCADE CONSTRAINTS;

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Department Table: Mining departments/divisions
CREATE TABLE Department (
    DepartmentID    NUMBER PRIMARY KEY,
    DeptName        VARCHAR2(50) NOT NULL UNIQUE,
    Location        VARCHAR2(100),
    HeadSupervisor  NUMBER,
    SafetyBudget    NUMBER(10,2)
);

-- Supervisor Table: Manages workers in a department
CREATE TABLE Supervisor (
    SupervisorID     NUMBER PRIMARY KEY,
    Name             VARCHAR2(50) NOT NULL,
    Contact          VARCHAR2(20),
    Department       VARCHAR2(50),
    DepartmentID     NUMBER,
    YearsExperience  NUMBER,
    Certification    VARCHAR2(100),
    FOREIGN KEY (DepartmentID) REFERENCES Department(DepartmentID)
        ON DELETE SET NULL
);

-- Worker Table: Mining workers/employees
CREATE TABLE Worker (
    WorkerID          NUMBER PRIMARY KEY,
    Name              VARCHAR2(50) NOT NULL,
    Age               NUMBER CHECK (Age >= 18),
    Role              VARCHAR2(30),
    Contact           VARCHAR2(20),
    S_ID              NUMBER,
    DepartmentID      NUMBER,
    HireDate          DATE,
    Salary            NUMBER(10,2),
    EmploymentStatus  VARCHAR2(20) DEFAULT 'Active' CHECK (EmploymentStatus IN ('Active', 'On Leave', 'Inactive')),
    FOREIGN KEY (S_ID) REFERENCES Supervisor(SupervisorID)
        ON DELETE SET NULL,
    FOREIGN KEY (DepartmentID) REFERENCES Department(DepartmentID)
        ON DELETE SET NULL
);

-- Safety Gear Table: Types of protective equipment
/*CREATE TABLE Safety_Gear (
    GearID          NUMBER PRIMARY KEY,
    GearType        VARCHAR2(50) NOT NULL,
    Description     VARCHAR2(200),
    IssuedDate      DATE DEFAULT SYSDATE,
    ExpiryDate      DATE,
    Status          VARCHAR2(20) DEFAULT 'Available' CHECK (Status IN ('Available', 'In Use', 'Damaged', 'Retired'))
);
*/
-- Equipment Table: Mining machinery and tools
CREATE TABLE Equipment (
    EquipmentID     NUMBER PRIMARY KEY,
    Type            VARCHAR2(30),
    Model           VARCHAR2(30),
    Status          VARCHAR2(20) DEFAULT 'Available',
    OperatedBy      NUMBER,
    PurchaseDate    DATE,
    MaintenanceSchedule VARCHAR2(50),
    LastMaintenance DATE,
    DepreciationValue NUMBER(10,2),
    FOREIGN KEY (OperatedBy) REFERENCES Worker(WorkerID)
        ON DELETE SET NULL
);
CREATE TABLE Safety_Incident (
    IncidentID      NUMBER PRIMARY KEY,
    IncidentDate    DATE NOT NULL,
    Location        VARCHAR2(50),
    Severity        NUMBER CHECK (Severity BETWEEN 1 AND 5),
    IncidentType    VARCHAR2(50) CHECK (IncidentType IN ('Injury', 'Equipment Failure', 'Environmental Hazard', 'Near Miss', 'Property Damage')),
    Description     VARCHAR2(400),
    ReportedBy      NUMBER,
    InvestigationRequired CHAR(1) DEFAULT 'N' CHECK (InvestigationRequired IN ('Y', 'N')),
    ResolutionStatus VARCHAR2(20) DEFAULT 'Open' CHECK (ResolutionStatus IN ('Open', 'In Progress', 'Resolved', 'Escalated')),
    FOREIGN KEY (ReportedBy) REFERENCES Worker(WorkerID)
);
-- Shift Table: Work shifts at different locations
CREATE TABLE Shift (
    ShiftID         NUMBER PRIMARY KEY,
    ShiftDate       DATE NOT NULL,
    ShiftTime       VARCHAR2(20),
    Duration        NUMBER,
    Location        VARCHAR2(50),
    MaxWorkers      NUMBER,
    ShiftType       VARCHAR2(20) DEFAULT 'Regular' CHECK (ShiftType IN ('Regular', 'Emergency', 'Maintenance', 'Training'))
);

CREATE TABLE Equipment_Transfer (
    TransferID      NUMBER PRIMARY KEY,
    EquipmentID     NUMBER NOT NULL,
    FromWorkerID    NUMBER,
    ToWorkerID      NUMBER NOT NULL,
    TransferDate    DATE DEFAULT SYSDATE,
    Notes           VARCHAR2(400),
    TransferReason  VARCHAR2(50) CHECK (TransferReason IN ('Promotion', 'Reassignment', 'Maintenance', 'Damage', 'Retirement')),
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON DELETE CASCADE,
    FOREIGN KEY (FromWorkerID) REFERENCES Worker(WorkerID),
    FOREIGN KEY (ToWorkerID) REFERENCES Worker(WorkerID)
);

-- Assigned_Shift Table: Maps workers to shifts (many-to-many)
CREATE TABLE Assigned_Shift (
    WorkerID        NUMBER,
    ShiftID         NUMBER,
    AssignmentDate  DATE DEFAULT SYSDATE,
    AssignedBy      NUMBER, -- SupervisorID
    PRIMARY KEY (WorkerID, ShiftID),
    FOREIGN KEY (WorkerID) REFERENCES Worker(WorkerID)
        ON DELETE CASCADE,
    FOREIGN KEY (ShiftID) REFERENCES Shift(ShiftID)
        ON DELETE CASCADE,
    FOREIGN KEY (AssignedBy) REFERENCES Supervisor(SupervisorID)
);

-- Usage_Record Table: Tracks equipment usage by workers
CREATE TABLE Usage_Record (
    WorkerID        NUMBER,
    EquipmentID     NUMBER,
    ShiftID         NUMBER,
    UsageTrack      VARCHAR2(100),
    StartTime       TIMESTAMP,
    EndTime         TIMESTAMP,
    HoursUsed       NUMBER(5,2),
    Outcome         VARCHAR2(50) DEFAULT 'Normal' CHECK (Outcome IN ('Normal', 'Minor Issue', 'Major Issue')),
    PRIMARY KEY (WorkerID, EquipmentID, ShiftID),
    FOREIGN KEY (WorkerID) REFERENCES Worker(WorkerID)
        ON DELETE CASCADE,
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON DELETE CASCADE,
    FOREIGN KEY (ShiftID) REFERENCES Shift(ShiftID)
        ON DELETE CASCADE
);

-- Maintenance_Record Table: Equipment maintenance history
CREATE TABLE Maintenance_Record (
    MaintenanceID   NUMBER PRIMARY KEY,
    EquipmentID     NUMBER NOT NULL,
    MaintDate       DATE DEFAULT SYSDATE,
    PerformedBy     NUMBER,
    MaintenanceType VARCHAR2(50) CHECK (MaintenanceType IN ('Routine', 'Preventive', 'Corrective', 'Emergency')),
    Notes           VARCHAR2(400),
    Cost            NUMBER(10,2),
    NextDueDate     DATE,
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON DELETE CASCADE,
    FOREIGN KEY (PerformedBy) REFERENCES Worker(WorkerID)
);

-- Equipment_Transfer Table: Audit trail for equipment reassignments


-- Training_Record Table: Worker certifications and training
CREATE TABLE Training_Record (
    TrainingID      NUMBER PRIMARY KEY,
    WorkerID        NUMBER NOT NULL,
    TrainingDate    DATE DEFAULT SYSDATE,
    Course          VARCHAR2(100),
    ValidUntil      DATE,
    TrainingStatus  VARCHAR2(20) DEFAULT 'Completed' CHECK (TrainingStatus IN ('In Progress', 'Completed', 'Failed', 'Expired')),
    TrainingLevel   VARCHAR2(30) CHECK (TrainingLevel IN ('Basic', 'Advanced', 'Expert')),
    Certified_By    NUMBER,
    FOREIGN KEY (WorkerID) REFERENCES Worker(WorkerID)
        ON DELETE CASCADE,
    FOREIGN KEY (Certified_By) REFERENCES Supervisor(SupervisorID)
);

-- Safety_Incident Table: Records all safety incidents with detailed classification


-- Incident_Worker Table: Links workers involved in incidents (many-to-many)
CREATE TABLE Incident_Worker (
    IncidentID      NUMBER,
    WorkerID        NUMBER,
    Role_In_Incident VARCHAR2(50), -- 'Primary', 'Witness', 'Affected', 'Reported'
    PRIMARY KEY (IncidentID, WorkerID),
    FOREIGN KEY (IncidentID) REFERENCES Safety_Incident(IncidentID)
        ON DELETE CASCADE,
    FOREIGN KEY (WorkerID) REFERENCES Worker(WorkerID)
        ON DELETE CASCADE
);

-- Incident_Equipment Table: Links equipment involved in incidents (many-to-many)
CREATE TABLE Incident_Equipment (
    IncidentID      NUMBER,
    EquipmentID     NUMBER,
    EquipmentRole   VARCHAR2(50), -- 'Direct Cause', 'Contributed', 'Affected'
    PRIMARY KEY (IncidentID, EquipmentID),
    FOREIGN KEY (IncidentID) REFERENCES Safety_Incident(IncidentID)
        ON DELETE CASCADE,
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON DELETE CASCADE
);

-- Worker_Gear Table: Maps workers to assigned safety gear (many-to-many)
CREATE TABLE Worker_Gear (
    WorkerID        NUMBER,
    GearID          NUMBER,
    AssignedDate    DATE DEFAULT SYSDATE,
    ReturnedDate    DATE,
    Condition       VARCHAR2(20) DEFAULT 'Good' CHECK (Condition IN ('Good', 'Fair', 'Poor', 'Damaged')),
    PRIMARY KEY (WorkerID, GearID, AssignedDate),
    FOREIGN KEY (WorkerID) REFERENCES Worker(WorkerID)
        ON DELETE CASCADE,
    FOREIGN KEY (GearID) REFERENCES Safety_Gear(GearID)
        ON DELETE CASCADE
);

-- ============================================================================
-- INDEXES for Performance Optimization
-- ============================================================================

CREATE INDEX idx_worker_supervisor ON Worker(S_ID);
CREATE INDEX idx_worker_department ON Worker(DepartmentID);
CREATE INDEX idx_equipment_operator ON Equipment(OperatedBy);
CREATE INDEX idx_usage_shift ON Usage_Record(ShiftID);
CREATE INDEX idx_usage_worker ON Usage_Record(WorkerID);
CREATE INDEX idx_usage_equipment ON Usage_Record(EquipmentID);
CREATE INDEX idx_incident_date ON Safety_Incident(IncidentDate);
CREATE INDEX idx_incident_severity ON Safety_Incident(Severity);
CREATE INDEX idx_incident_location ON Safety_Incident(Location);
CREATE INDEX idx_maintenance_equipment ON Maintenance_Record(EquipmentID);
CREATE INDEX idx_maintenance_date ON Maintenance_Record(MaintDate);
CREATE INDEX idx_training_worker ON Training_Record(WorkerID);
CREATE INDEX idx_training_expiry ON Training_Record(ValidUntil);
CREATE INDEX idx_assigned_shift_worker ON Assigned_Shift(WorkerID);
CREATE INDEX idx_assigned_shift_shift ON Assigned_Shift(ShiftID);

-- ============================================================================
-- SEQUENCES FOR AUTO-INCREMENT
-- ============================================================================

CREATE SEQUENCE seq_department   START WITH 1   INCREMENT BY 1;
CREATE SEQUENCE seq_supervisor   START WITH 1   INCREMENT BY 1;
CREATE SEQUENCE seq_worker       START WITH 101 INCREMENT BY 1;
CREATE SEQUENCE seq_equipment    START WITH 201 INCREMENT BY 1;
CREATE SEQUENCE seq_shift        START WITH 301 INCREMENT BY 1;
CREATE SEQUENCE seq_incident     START WITH 401 INCREMENT BY 1;
CREATE SEQUENCE seq_maintenance  START WITH 501 INCREMENT BY 1;
CREATE SEQUENCE seq_transfer     START WITH 601 INCREMENT BY 1;
CREATE SEQUENCE seq_training     START WITH 701 INCREMENT BY 1;
CREATE SEQUENCE seq_gear         START WITH 801 INCREMENT BY 1;

-- ============================================================================
-- SAMPLE DATA INSERTIONS
-- ============================================================================

-- Departments
INSERT INTO Department VALUES (seq_department.NEXTVAL, 'Underground Operations', 'Mine Level 1', NULL, 500000);
INSERT INTO Department VALUES (seq_department.NEXTVAL, 'Maintenance Division', 'Surface', NULL, 300000);
INSERT INTO Department VALUES (seq_department.NEXTVAL, 'Safety & Compliance', 'Administrative', NULL, 200000);

-- Supervisors
INSERT INTO Supervisor VALUES (seq_supervisor.NEXTVAL, 'Arun Mehta', '9876543210', 'Underground Operations', 1, 15, 'Mining Supervisor Certification');
INSERT INTO Supervisor VALUES (seq_supervisor.NEXTVAL, 'Priya Sharma', '9123456780', 'Maintenance Division', 2, 12, 'Equipment Maintenance Specialist');
INSERT INTO Supervisor VALUES (seq_supervisor.NEXTVAL, 'Rajesh Kumar', '9988776655', 'Safety & Compliance', 3, 20, 'Safety Manager Certified');

-- Workers
INSERT INTO Worker VALUES (seq_worker.NEXTVAL, 'Rohan Kumar', 28, 'Operator', '9000010001', 1, 1, DATE '2020-03-15', 45000, 'Active');
INSERT INTO Worker VALUES (seq_worker.NEXTVAL, 'Aisha Verma', 26, 'Technician', '9000010002', 1, 1, DATE '2021-07-20', 40000, 'Active');
INSERT INTO Worker VALUES (seq_worker.NEXTVAL, 'Sameer Khan', 32, 'Operator', '9000010003', 2, 2, DATE '2019-01-10', 50000, 'Active');
INSERT INTO Worker VALUES (seq_worker.NEXTVAL, 'Neha Singh', 24, 'Helper', '9000010004', 2, 2, DATE '2023-05-01', 25000, 'Active');
INSERT INTO Worker VALUES (seq_worker.NEXTVAL, 'Vikram Patel', 35, 'Senior Operator', '9000010005', 1, 1, DATE '2018-09-12', 60000, 'Active');

-- Safety Gear
INSERT INTO Safety_Gear VALUES (seq_gear.NEXTVAL, 'Hard Hat', 'Yellow protective helmet', DATE '2025-08-01', DATE '2027-08-01', 'Available');
INSERT INTO Safety_Gear VALUES (seq_gear.NEXTVAL, 'Safety Vest', 'Reflective safety vest', DATE '2025-09-15', DATE '2027-09-15', 'Available');
INSERT INTO Safety_Gear VALUES (seq_gear.NEXTVAL, 'Safety Gloves', 'Cut-resistant gloves', DATE '2025-10-01', DATE '2026-10-01', 'Available');
INSERT INTO Safety_Gear VALUES (seq_gear.NEXTVAL, 'Respirator', 'HEPA filter respirator', DATE '2025-07-20', DATE '2026-07-20', 'In Use');

-- Equipment
INSERT INTO Equipment VALUES (seq_equipment.NEXTVAL, 'Forklift', 'CAT-100', 'Available', 101, DATE '2019-05-10', 'Monthly', DATE '2025-10-15', 35000);
INSERT INTO Equipment VALUES (seq_equipment.NEXTVAL, 'Welding Machine', 'WM-200', 'Available', 102, DATE '2020-12-01', 'Quarterly', DATE '2025-09-20', 15000);
INSERT INTO Equipment VALUES (seq_equipment.NEXTVAL, 'Crane', 'CR-450', 'Available', 103, DATE '2018-03-15', 'Monthly', DATE '2025-10-01', 55000);
INSERT INTO Equipment VALUES (seq_equipment.NEXTVAL, 'Pneumatic Drill', 'PD-300', 'Available', 104, DATE '2021-08-22', 'Semi-Annual', DATE '2025-08-15', 12000);

-- Shifts
INSERT INTO Shift VALUES (seq_shift.NEXTVAL, DATE '2025-11-01', '08:00-16:00', 8, 'Main Shaft', 10, 'Regular');
INSERT INTO Shift VALUES (seq_shift.NEXTVAL, DATE '2025-11-01', '16:00-00:00', 8, 'East Wing', 8, 'Regular');
INSERT INTO Shift VALUES (seq_shift.NEXTVAL, DATE '2025-11-02', '08:00-16:00', 8, 'Main Shaft', 10, 'Regular');
INSERT INTO Shift VALUES (seq_shift.NEXTVAL, DATE '2025-11-02', '00:00-08:00', 8, 'Maintenance Area', 5, 'Maintenance');

-- Worker-Shift Assignments
INSERT INTO Assigned_Shift VALUES (101, 301, SYSDATE, 1);
INSERT INTO Assigned_Shift VALUES (102, 301, SYSDATE, 1);
INSERT INTO Assigned_Shift VALUES (103, 302, SYSDATE, 2);
INSERT INTO Assigned_Shift VALUES (101, 303, SYSDATE, 1);
INSERT INTO Assigned_Shift VALUES (104, 303, SYSDATE, 1);

-- Usage Records
INSERT INTO Usage_Record VALUES (101, 201, 301, 'Loaded materials', TIMESTAMP '2025-11-01 08:30:00', TIMESTAMP '2025-11-01 15:00:00', 6.5, 'Normal');
INSERT INTO Usage_Record VALUES (102, 202, 301, 'Welding operation', TIMESTAMP '2025-11-01 08:45:00', TIMESTAMP '2025-11-01 14:30:00', 5.75, 'Normal');
INSERT INTO Usage_Record VALUES (103, 203, 302, 'Crane lifting', TIMESTAMP '2025-11-01 16:15:00', TIMESTAMP '2025-11-01 23:30:00', 7.25, 'Minor Issue');
INSERT INTO Usage_Record VALUES (101, 201, 303, 'Transporting goods', TIMESTAMP '2025-11-02 08:00:00', TIMESTAMP '2025-11-02 15:30:00', 7.5, 'Normal');

-- Training Records
INSERT INTO Training_Record VALUES (seq_training.NEXTVAL, 101, DATE '2025-03-10', 'Forklift Operation Level 1', DATE '2026-03-10', 'Completed', 'Basic', 1);
INSERT INTO Training_Record VALUES (seq_training.NEXTVAL, 102, DATE '2025-02-20', 'Welding Basics', DATE '2027-02-20', 'Completed', 'Advanced', 1);
INSERT INTO Training_Record VALUES (seq_training.NEXTVAL, 103, DATE '2025-04-15', 'Crane Operation Advanced', DATE '2026-04-15', 'Completed', 'Expert', 2);

-- Maintenance Records
INSERT INTO Maintenance_Record VALUES (seq_maintenance.NEXTVAL, 203, DATE '2025-10-25', 102, 'Routine', 'Crane inspection and lubrication', 2500, DATE '2025-11-25');
INSERT INTO Maintenance_Record VALUES (seq_maintenance.NEXTVAL, 201, DATE '2025-10-20', 101, 'Preventive', 'Forklift brake inspection', 1500, DATE '2025-11-20');

-- Worker-Gear Assignments
INSERT INTO Worker_Gear VALUES (101, 801, DATE '2025-10-01', NULL, 'Good');
INSERT INTO Worker_Gear VALUES (101, 803, DATE '2025-10-01', NULL, 'Good');
INSERT INTO Worker_Gear VALUES (102, 801, DATE '2025-10-05', NULL, 'Fair');
INSERT INTO Worker_Gear VALUES (103, 802, DATE '2025-09-15', NULL, 'Good');

-- Safety Incidents
INSERT INTO Safety_Incident VALUES (seq_incident.NEXTVAL, DATE '2025-11-01', 'Main Shaft', 3, 'Near Miss', 'Minor slip near the welding area', 102, 'N', 'Open');
INSERT INTO Safety_Incident VALUES (seq_incident.NEXTVAL, DATE '2025-11-02', 'East Wing', 5, 'Equipment Failure', 'Crane malfunction during lifting', 103, 'Y', 'In Progress');
INSERT INTO Safety_Incident VALUES (seq_incident.NEXTVAL, DATE '2025-10-28', 'Main Shaft', 2, 'Near Miss', 'Low-severity near-miss event', 104, 'N', 'Resolved');

-- Incident-Worker Links
INSERT INTO Incident_Worker VALUES (401, 102, 'Primary');
INSERT INTO Incident_Worker VALUES (402, 103, 'Primary');
INSERT INTO Incident_Worker VALUES (402, 101, 'Witness');
INSERT INTO Incident_Worker VALUES (403, 104, 'Affected');

-- Incident-Equipment Links
INSERT INTO Incident_Equipment VALUES (401, 202, 'Contributed');
INSERT INTO Incident_Equipment VALUES (402, 203, 'Direct Cause');
INSERT INTO Incident_Equipment VALUES (403, 201, 'Affected');

-- Equipment Transfers
INSERT INTO Equipment_Transfer VALUES (seq_transfer.NEXTVAL, 201, 101, 105, SYSDATE, 'Transferred to senior operator', 'Promotion');

COMMIT;
