-- ============================================================================
-- UNDERGROUND MINING DATABASE - PL/SQL OBJECTS
-- Triggers, Procedures, Functions, and PL/SQL Blocks
-- ============================================================================

-- ============================================================================
-- TRIGGERS: Automated business logic and data integrity
-- ============================================================================

-- Trigger: Update equipment status to 'In Use' when a usage record is created
CREATE OR REPLACE TRIGGER trg_update_equipment_status
AFTER INSERT ON Usage_Record
FOR EACH ROW
BEGIN
    UPDATE Equipment
    SET Status = 'In Use'
    WHERE EquipmentID = :NEW.EquipmentID;
END;
/

-- Trigger: Revert equipment status to 'Available' when all usage records are deleted
CREATE OR REPLACE TRIGGER trg_usage_after_delete
AFTER DELETE ON Usage_Record
FOR EACH ROW
DECLARE
    cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO cnt FROM Usage_Record WHERE EquipmentID = :OLD.EquipmentID;
    IF cnt = 0 THEN
        UPDATE Equipment SET Status = 'Available' WHERE EquipmentID = :OLD.EquipmentID;
    END IF;
END;
/

-- Trigger: Update equipment LastMaintenance and status after maintenance record insert
CREATE OR REPLACE TRIGGER trg_maintenance_after_insert
AFTER INSERT ON Maintenance_Record
FOR EACH ROW
BEGIN
    UPDATE Equipment
    SET LastMaintenance = :NEW.MaintDate,
        Status = 'Maintenance'
    WHERE EquipmentID = :NEW.EquipmentID;
    
    -- Log the maintenance event for audit
    DBMS_OUTPUT.PUT_LINE('Maintenance logged for Equipment ' || :NEW.EquipmentID || ' on ' || :NEW.MaintDate);
END;
/

-- Trigger: Update equipment operator when transfer occurs
CREATE OR REPLACE TRIGGER trg_transfer_after_insert
AFTER INSERT ON Equipment_Transfer
FOR EACH ROW
BEGIN
    UPDATE Equipment SET OperatedBy = :NEW.ToWorkerID WHERE EquipmentID = :NEW.EquipmentID;
END;
/

-- Trigger: Validate severity level before inserting/updating incident
CREATE OR REPLACE TRIGGER trg_check_severity
BEFORE INSERT OR UPDATE ON Safety_Incident
FOR EACH ROW
BEGIN
    IF :NEW.Severity < 1 OR :NEW.Severity > 5 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Severity must be between 1 and 5.');
    END IF;
END;
/

-- Trigger: Validate worker age on insert
CREATE OR REPLACE TRIGGER trg_check_worker_age
BEFORE INSERT ON Worker
FOR EACH ROW
BEGIN
    IF :NEW.Age < 18 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Worker must be at least 18 years old.');
    END IF;
END;
/

-- Trigger: Validate training expiry date is after training date
CREATE OR REPLACE TRIGGER trg_check_training_validity
BEFORE INSERT OR UPDATE ON Training_Record
FOR EACH ROW
BEGIN
    IF :NEW.ValidUntil <= :NEW.TrainingDate THEN
        RAISE_APPLICATION_ERROR(-20003, 'Training expiry must be after training date.');
    END IF;
END;
/

-- Trigger: Validate shift maximum workers before assignment
CREATE OR REPLACE TRIGGER trg_check_shift_capacity
BEFORE INSERT ON Assigned_Shift
FOR EACH ROW
DECLARE
    v_current_count NUMBER;
    v_max_workers NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_current_count FROM Assigned_Shift WHERE ShiftID = :NEW.ShiftID;
    SELECT MaxWorkers INTO v_max_workers FROM Shift WHERE ShiftID = :NEW.ShiftID;
    
    IF v_current_count >= v_max_workers THEN
        RAISE_APPLICATION_ERROR(-20004, 'Shift capacity exceeded.');
    END IF;
END;
/

-- Trigger: Enforce that high-severity incidents require investigation
CREATE OR REPLACE TRIGGER trg_enforce_investigation
BEFORE INSERT ON Safety_Incident
FOR EACH ROW
BEGIN
    IF :NEW.Severity >= 4 THEN
        :NEW.InvestigationRequired := 'Y';
        :NEW.ResolutionStatus := 'In Progress';
    END IF;
END;
/

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function: Get incident count for a worker
CREATE OR REPLACE FUNCTION get_incident_count(p_workerID NUMBER)
RETURN NUMBER
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Incident_Worker
    WHERE WorkerID = p_workerID;
    RETURN v_count;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
END;
/

-- Function: Calculate risk score for a worker (incidents, severity, shifts, equipment issues)
CREATE OR REPLACE FUNCTION get_worker_risk_score(p_workerID NUMBER)
RETURN NUMBER
IS
    v_incidents NUMBER;
    v_avg_severity NUMBER;
    v_shifts NUMBER;
    v_equipment_issues NUMBER;
    v_score NUMBER;
BEGIN
    -- Count incidents and average severity
    SELECT COUNT(DISTINCT iw.IncidentID), NVL(AVG(si.Severity), 0)
    INTO v_incidents, v_avg_severity
    FROM Incident_Worker iw
    LEFT JOIN Safety_Incident si ON iw.IncidentID = si.IncidentID
    WHERE iw.WorkerID = p_workerID;

    -- Count assigned shifts
    SELECT COUNT(*) INTO v_shifts FROM Assigned_Shift WHERE WorkerID = p_workerID;

    -- Count equipment usage with issues
    SELECT COUNT(*) INTO v_equipment_issues
    FROM Usage_Record
    WHERE WorkerID = p_workerID AND Outcome != 'Normal';

    -- Risk formula: incidents * avg_severity * 2 + shifts * 0.1 + equipment_issues * 1.5
    v_score := NVL(v_incidents * v_avg_severity * 2, 0) + NVL(v_shifts * 0.1, 0) + NVL(v_equipment_issues * 1.5, 0);
    
    RETURN ROUND(v_score, 2);
EXCEPTION
    WHEN OTHERS THEN RETURN 0;
END;
/

-- Function: Get equipment downtime percentage
CREATE OR REPLACE FUNCTION get_equipment_downtime_percent(p_equipmentID NUMBER, p_days NUMBER DEFAULT 30)
RETURN NUMBER
IS
    v_maint_days NUMBER;
    v_downtime_percent NUMBER;
BEGIN
    SELECT NVL(COUNT(*), 0)
    INTO v_maint_days
    FROM Maintenance_Record
    WHERE EquipmentID = p_equipmentID
      AND MaintDate >= TRUNC(SYSDATE) - p_days;

    v_downtime_percent := ROUND((v_maint_days / p_days) * 100, 2);
    RETURN v_downtime_percent;
EXCEPTION
    WHEN OTHERS THEN RETURN 0;
END;
/

-- Function: Check if worker has required certification for role
CREATE OR REPLACE FUNCTION has_required_certification(p_workerID NUMBER, p_course VARCHAR2)
RETURN CHAR
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Training_Record
    WHERE WorkerID = p_workerID
      AND Course = p_course
      AND TrainingStatus = 'Completed'
      AND ValidUntil >= SYSDATE;
    
    RETURN CASE WHEN v_count > 0 THEN 'Y' ELSE 'N' END;
EXCEPTION
    WHEN OTHERS THEN RETURN 'N';
END;
/

-- Function: Return cursor of top incident workers
CREATE OR REPLACE FUNCTION get_top_incident_workers(p_limit NUMBER DEFAULT 10)
RETURN SYS_REFCURSOR
IS
    rc SYS_REFCURSOR;
BEGIN
    OPEN rc FOR
        SELECT WorkerID, Name, cnt_incidents, IncidentSeverity
        FROM (
            SELECT w.WorkerID, w.Name, COUNT(iw.IncidentID) OVER (PARTITION BY w.WorkerID) AS cnt_incidents,
                   ROUND(AVG(si.Severity) OVER (PARTITION BY w.WorkerID), 2) AS IncidentSeverity,
                   ROW_NUMBER() OVER (ORDER BY COUNT(iw.IncidentID) OVER (PARTITION BY w.WorkerID) DESC) rn
            FROM Worker w
            LEFT JOIN Incident_Worker iw ON w.WorkerID = iw.WorkerID
            LEFT JOIN Safety_Incident si ON iw.IncidentID = si.IncidentID
        )
        WHERE rn <= NVL(p_limit, 10)
        ORDER BY cnt_incidents DESC;
    RETURN rc;
END;
/

-- Function: Calculate worker utilization score (hours worked vs assigned)
CREATE OR REPLACE FUNCTION get_worker_utilization_score(p_workerID NUMBER)
RETURN NUMBER
IS
    v_assigned_hours NUMBER;
    v_actual_hours NUMBER;
    v_utilization NUMBER;
BEGIN
    SELECT NVL(SUM(Duration), 0)
    INTO v_assigned_hours
    FROM Assigned_Shift a
    JOIN Shift s ON a.ShiftID = s.ShiftID
    WHERE a.WorkerID = p_workerID;

    SELECT NVL(SUM(HoursUsed), 0)
    INTO v_actual_hours
    FROM Usage_Record
    WHERE WorkerID = p_workerID;

    IF v_assigned_hours = 0 THEN
        RETURN 0;
    ELSE
        v_utilization := ROUND((v_actual_hours / v_assigned_hours) * 100, 2);
        RETURN LEAST(v_utilization, 100);
    END IF;
EXCEPTION
    WHEN OTHERS THEN RETURN 0;
END;
/

-- ============================================================================
-- PROCEDURES
-- ============================================================================

-- Procedure: Record maintenance and optionally mark equipment available
CREATE OR REPLACE PROCEDURE record_maintenance(
    p_equipmentID   NUMBER,
    p_performedBy   NUMBER,
    p_maintenanceType VARCHAR2,
    p_notes         VARCHAR2,
    p_cost          NUMBER DEFAULT 0,
    p_maintenance_date DATE DEFAULT SYSDATE,
    p_set_available BOOLEAN DEFAULT FALSE
)
IS
    v_next_due_date DATE;
BEGIN
    -- Calculate next due date based on maintenance type
    v_next_due_date := CASE 
        WHEN p_maintenanceType = 'Routine' THEN ADD_MONTHS(p_maintenance_date, 1)
        WHEN p_maintenanceType = 'Preventive' THEN ADD_MONTHS(p_maintenance_date, 3)
        WHEN p_maintenanceType = 'Corrective' THEN ADD_MONTHS(p_maintenance_date, 1)
        WHEN p_maintenanceType = 'Emergency' THEN p_maintenance_date + 7
        ELSE ADD_MONTHS(p_maintenance_date, 1)
    END;

    INSERT INTO Maintenance_Record (
        MaintenanceID, EquipmentID, MaintDate, PerformedBy, MaintenanceType, Notes, Cost, NextDueDate
    ) VALUES (
        seq_maintenance.NEXTVAL, p_equipmentID, p_maintenance_date, p_performedBy, 
        p_maintenanceType, p_notes, p_cost, v_next_due_date
    );

    UPDATE Equipment
    SET LastMaintenance = p_maintenance_date,
        Status = CASE WHEN p_set_available THEN 'Available' ELSE 'Maintenance' END
    WHERE EquipmentID = p_equipmentID;

    DBMS_OUTPUT.PUT_LINE('Maintenance recorded for Equipment ' || p_equipmentID || '. Next due: ' || v_next_due_date);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20005, 'Error recording maintenance: ' || SQLERRM);
END;
/

-- Procedure: Transfer equipment with full audit trail
CREATE OR REPLACE PROCEDURE transfer_equipment(
    p_equipmentID   NUMBER,
    p_toWorkerID    NUMBER,
    p_transferReason VARCHAR2,
    p_notes         VARCHAR2 DEFAULT NULL
)
IS
    v_fromWorker NUMBER;
    v_equipment_type VARCHAR2(30);
BEGIN
    -- Get current operator and equipment info
    SELECT OperatedBy, Type
    INTO v_fromWorker, v_equipment_type
    FROM Equipment
    WHERE EquipmentID = p_equipmentID;

    -- Insert transfer record
    INSERT INTO Equipment_Transfer (
        TransferID, EquipmentID, FromWorkerID, ToWorkerID, TransferReason, Notes
    ) VALUES (
        seq_transfer.NEXTVAL, p_equipmentID, v_fromWorker, p_toWorkerID, p_transferReason, p_notes
    );

    -- Trigger will update Equipment.OperatedBy

    DBMS_OUTPUT.PUT_LINE('Transfer logged: ' || v_equipment_type || ' from Worker ' || 
                         v_fromWorker || ' to Worker ' || p_toWorkerID);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20006, 'Equipment not found: ' || p_equipmentID);
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20007, 'Error transferring equipment: ' || SQLERRM);
END;
/

-- Procedure: Report safety incident with multiple workers and equipment
CREATE OR REPLACE PROCEDURE report_incident(
    p_incident_date  DATE,
    p_location       VARCHAR2,
    p_severity       NUMBER,
    p_incidentType   VARCHAR2,
    p_description    VARCHAR2,
    p_reported_by    NUMBER,
    p_workers        SYS.ODCINUMBERLIST DEFAULT NULL,
    p_equipment      SYS.ODCINUMBERLIST DEFAULT NULL
)
IS
    v_incidentID NUMBER;
    v_investigation CHAR(1);
BEGIN
    -- Validate severity
    IF p_severity < 1 OR p_severity > 5 THEN
        RAISE_APPLICATION_ERROR(-20008, 'Severity must be 1-5.');
    END IF;

    -- Determine if investigation needed (severity >= 4)
    v_investigation := CASE WHEN p_severity >= 4 THEN 'Y' ELSE 'N' END;

    -- Insert main incident
    v_incidentID := seq_incident.NEXTVAL;
    INSERT INTO Safety_Incident (
        IncidentID, IncidentDate, Location, Severity, IncidentType, Description, 
        ReportedBy, InvestigationRequired
    ) VALUES (
        v_incidentID, p_incident_date, p_location, p_severity, p_incidentType, 
        p_description, p_reported_by, v_investigation
    );

    -- Link workers if provided
    IF p_workers IS NOT NULL THEN
        FOR i IN 1..p_workers.COUNT LOOP
            INSERT INTO Incident_Worker (IncidentID, WorkerID, Role_In_Incident)
            VALUES (v_incidentID, p_workers(i), 'Primary');
        END LOOP;
    END IF;

    -- Link equipment if provided
    IF p_equipment IS NOT NULL THEN
        FOR i IN 1..p_equipment.COUNT LOOP
            INSERT INTO Incident_Equipment (IncidentID, EquipmentID, EquipmentRole)
            VALUES (v_incidentID, p_equipment(i), 'Direct Cause');
        END LOOP;
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Incident #' || v_incidentID || ' recorded at ' || p_location || 
                         ' with severity ' || p_severity);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20009, 'Error reporting incident: ' || SQLERRM);
END;
/

-- Procedure: Assign worker to shift with capacity check
CREATE OR REPLACE PROCEDURE assign_worker_to_shift(
    p_workerID      NUMBER,
    p_shiftID       NUMBER,
    p_assignedBy    NUMBER,
    p_validate      BOOLEAN DEFAULT TRUE
)
IS
    v_shift_count NUMBER;
    v_max_workers NUMBER;
    v_worker_count NUMBER;
    v_worker_exists NUMBER;
BEGIN
    -- Verify worker exists
    SELECT COUNT(*) INTO v_worker_exists FROM Worker WHERE WorkerID = p_workerID;
    IF v_worker_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Worker does not exist.');
    END IF;

    -- Check shift capacity if requested
    IF p_validate THEN
        SELECT COUNT(*) INTO v_shift_count FROM Assigned_Shift WHERE ShiftID = p_shiftID;
        SELECT MaxWorkers INTO v_max_workers FROM Shift WHERE ShiftID = p_shiftID;
        
        IF v_shift_count >= v_max_workers THEN
            RAISE_APPLICATION_ERROR(-20011, 'Shift capacity would be exceeded.');
        END IF;
    END IF;

    -- Check for duplicate assignment
    SELECT COUNT(*) INTO v_worker_count
    FROM Assigned_Shift
    WHERE WorkerID = p_workerID AND ShiftID = p_shiftID;

    IF v_worker_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Worker already assigned to this shift.');
    END IF;

    -- Assign worker
    INSERT INTO Assigned_Shift (WorkerID, ShiftID, AssignedBy)
    VALUES (p_workerID, p_shiftID, p_assignedBy);

    DBMS_OUTPUT.PUT_LINE('Worker ' || p_workerID || ' assigned to Shift ' || p_shiftID);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20013, 'Error assigning worker: ' || SQLERRM);
END;
/

-- Procedure: Record equipment usage with detailed tracking
CREATE OR REPLACE PROCEDURE record_equipment_usage(
    p_workerID      NUMBER,
    p_equipmentID   NUMBER,
    p_shiftID       NUMBER,
    p_startTime     TIMESTAMP,
    p_endTime       TIMESTAMP,
    p_usageTrack    VARCHAR2,
    p_outcome       VARCHAR2 DEFAULT 'Normal'
)
IS
    v_hours_used NUMBER;
    v_equipment_exists NUMBER;
    v_worker_exists NUMBER;
    v_shift_exists NUMBER;
BEGIN
    -- Validate references
    SELECT COUNT(*) INTO v_equipment_exists FROM Equipment WHERE EquipmentID = p_equipmentID;
    SELECT COUNT(*) INTO v_worker_exists FROM Worker WHERE WorkerID = p_workerID;
    SELECT COUNT(*) INTO v_shift_exists FROM Shift WHERE ShiftID = p_shiftID;

    IF v_equipment_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20014, 'Equipment does not exist.');
    END IF;
    IF v_worker_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20015, 'Worker does not exist.');
    END IF;
    IF v_shift_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20016, 'Shift does not exist.');
    END IF;

    -- Calculate hours used
    v_hours_used := ROUND((p_endTime - p_startTime) * 24, 2);

    -- Insert usage record
    INSERT INTO Usage_Record (
        WorkerID, EquipmentID, ShiftID, StartTime, EndTime, HoursUsed, UsageTrack, Outcome
    ) VALUES (
        p_workerID, p_equipmentID, p_shiftID, p_startTime, p_endTime, v_hours_used, p_usageTrack, p_outcome
    );

    DBMS_OUTPUT.PUT_LINE('Equipment usage recorded: ' || v_hours_used || ' hours.');
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20017, 'Error recording usage: ' || SQLERRM);
END;
/

-- Procedure: Conduct safety audit for a worker and generate recommendation
CREATE OR REPLACE PROCEDURE conduct_safety_audit(
    p_workerID      NUMBER,
    p_audit_date    DATE DEFAULT SYSDATE
)
IS
    v_incident_count NUMBER;
    v_risk_score NUMBER;
    v_utilization NUMBER;
    v_avg_severity NUMBER;
    v_recommendation VARCHAR2(400);
BEGIN
    -- Get audit metrics
    SELECT get_incident_count(p_workerID) INTO v_incident_count FROM DUAL;
    SELECT get_worker_risk_score(p_workerID) INTO v_risk_score FROM DUAL;
    SELECT get_worker_utilization_score(p_workerID) INTO v_utilization FROM DUAL;

    SELECT NVL(AVG(si.Severity), 0)
    INTO v_avg_severity
    FROM Incident_Worker iw
    JOIN Safety_Incident si ON iw.IncidentID = si.IncidentID
    WHERE iw.WorkerID = p_workerID;

    -- Generate recommendation
    v_recommendation := CASE
        WHEN v_risk_score > 20 THEN 'HIGH RISK: Immediate safety retraining and equipment reassignment required.'
        WHEN v_risk_score > 10 THEN 'MEDIUM RISK: Safety refresher course recommended. Monitor equipment usage.'
        WHEN v_risk_score > 5 THEN 'LOW RISK: Continue regular safety awareness training.'
        ELSE 'SAFE: No immediate concerns. Maintain current safety practices.'
    END;

    -- Output audit report
    DBMS_OUTPUT.PUT_LINE('=== SAFETY AUDIT REPORT FOR WORKER ' || p_workerID || ' ===');
    DBMS_OUTPUT.PUT_LINE('Audit Date: ' || p_audit_date);
    DBMS_OUTPUT.PUT_LINE('Total Incidents: ' || v_incident_count);
    DBMS_OUTPUT.PUT_LINE('Risk Score: ' || v_risk_score);
    DBMS_OUTPUT.PUT_LINE('Equipment Utilization: ' || v_utilization || '%');
    DBMS_OUTPUT.PUT_LINE('Average Incident Severity: ' || v_avg_severity);
    DBMS_OUTPUT.PUT_LINE('Recommendation: ' || v_recommendation);
    DBMS_OUTPUT.PUT_LINE('===============================');
END;
/

-- ============================================================================
-- PL/SQL BLOCKS: Demonstrating Loop Types and Sample Data Insertion
-- ============================================================================

-- FOR LOOP: Insert sample workers for demonstration
BEGIN
    FOR i IN 1..5 LOOP
        INSERT INTO Worker (WorkerID, Name, Age, Role, Contact, S_ID, DepartmentID, HireDate, Salary, EmploymentStatus)
        VALUES (
            seq_worker.NEXTVAL,
            'Demo_Worker_' || i,
            22 + i,
            'Helper',
            '900001000' || i,
            1,
            1,
            SYSDATE,
            30000 + (i * 1000),
            'Active'
        );
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('5 demo workers inserted via FOR LOOP.');
END;
/

-- WHILE LOOP: Insert additional equipment for demonstration
DECLARE
    counter NUMBER := 1;
BEGIN
    WHILE counter <= 5 LOOP
        INSERT INTO Equipment (EquipmentID, Type, Model, Status, OperatedBy, PurchaseDate)
        VALUES (
            seq_equipment.NEXTVAL,
            'Demo_Equipment_Type_' || counter,
            'Model_' || counter,
            'Available',
            101,
            SYSDATE - (counter * 30)
        );
        counter := counter + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('5 equipment records inserted via WHILE LOOP.');
END;
/

-- LOOP...EXIT WHEN: Insert additional shifts for demonstration
DECLARE
    x NUMBER := 1;
BEGIN
    LOOP
        INSERT INTO Shift (ShiftID, ShiftDate, ShiftTime, Duration, Location, MaxWorkers, ShiftType)
        VALUES (
            seq_shift.NEXTVAL,
            SYSDATE + x,
            '08:00-16:00',
            8,
            'Demo_Location_' || x,
            10,
            'Regular'
        );
        EXIT WHEN x = 5;
        x := x + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('5 shifts inserted via LOOP...EXIT WHEN.');
END;
/

COMMIT;
