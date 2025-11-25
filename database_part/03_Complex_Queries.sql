-- ============================================================================
-- UNDERGROUND MINING DATABASE - COMPLEX ANALYTICAL QUERIES
-- Advanced reporting, analytics, and business intelligence
-- ============================================================================

-- =============================================================================
-- SECTION 1: SAFETY ANALYTICS & INCIDENT MANAGEMENT
-- =============================================================================

-- Query 1A: Monthly incident trends by location with YoY comparison
SELECT 
    IncidentMonth,
    Location,
    IncidentsThisMonth,
    LAG(IncidentsThisMonth) OVER (PARTITION BY Location ORDER BY IncidentMonth) AS IncidentsPrevMonth,
    ROUND(((IncidentsThisMonth - LAG(IncidentsThisMonth) OVER (PARTITION BY Location ORDER BY IncidentMonth)) / 
           LAG(IncidentsThisMonth) OVER (PARTITION BY Location ORDER BY IncidentMonth)) * 100, 2) AS PercentChange
FROM (
    SELECT 
        TO_CHAR(IncidentDate, 'YYYY-MM') AS IncidentMonth,
        Location,
        COUNT(*) AS IncidentsThisMonth
    FROM Safety_Incident
    WHERE IncidentDate >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -11)
    GROUP BY TO_CHAR(IncidentDate, 'YYYY-MM'), Location
)
ORDER BY IncidentMonth DESC, Location;

-- Query 1B: High-risk incidents requiring investigation with detailed context
SELECT 
    si.IncidentID,
    si.IncidentDate,
    si.Location,
    si.IncidentType,
    si.Severity,
    si.Description,
    si.ResolutionStatus,
    w_reporter.Name AS ReportedBy,
    LISTAGG(iw.Role_In_Incident || ': ' || w.Name, ' | ') WITHIN GROUP (ORDER BY w.Name) AS InvolvedWorkers,
    LISTAGG(e.Type || ' (' || ie.EquipmentRole || ')', ' | ') WITHIN GROUP (ORDER BY e.Type) AS InvolvedEquipment,
    CASE 
        WHEN si.Severity >= 4 THEN 'ESCALATE'
        WHEN si.Severity = 3 THEN 'MONITOR'
        ELSE 'STANDARD'
    END AS ActionRequired
FROM Safety_Incident si
LEFT JOIN Worker w_reporter ON si.ReportedBy = w_reporter.WorkerID
LEFT JOIN Incident_Worker iw ON si.IncidentID = iw.IncidentID
LEFT JOIN Worker w ON iw.WorkerID = w.WorkerID
LEFT JOIN Incident_Equipment ie ON si.IncidentID = ie.IncidentID
LEFT JOIN Equipment e ON ie.EquipmentID = e.EquipmentID
WHERE si.InvestigationRequired = 'Y'
GROUP BY si.IncidentID, si.IncidentDate, si.Location, si.IncidentType, si.Severity, 
         si.Description, si.ResolutionStatus, w_reporter.Name
ORDER BY si.Severity DESC, si.IncidentDate DESC;

-- Query 1C: Worker safety profile with incident clustering
SELECT 
    w.WorkerID,
    w.Name,
    w.Role,
    d.DeptName,
    COUNT(DISTINCT iw.IncidentID) AS TotalIncidents,
    ROUND(AVG(si.Severity), 2) AS AvgSeverity,
    MAX(si.Severity) AS MaxSeverity,
    MIN(si.Severity) AS MinSeverity,
    STDDEV(si.Severity) AS SeverityStdDev,
    RANK() OVER (ORDER BY COUNT(DISTINCT iw.IncidentID) DESC) AS IncidentRank,
    CASE 
        WHEN COUNT(DISTINCT iw.IncidentID) >= 3 THEN 'HIGH INCIDENT WORKER'
        WHEN COUNT(DISTINCT iw.IncidentID) >= 1 THEN 'MODERATE INCIDENT WORKER'
        ELSE 'SAFE WORKER'
    END AS WorkerClassification
FROM Worker w
LEFT JOIN Incident_Worker iw ON w.WorkerID = iw.WorkerID
LEFT JOIN Safety_Incident si ON iw.IncidentID = si.IncidentID
LEFT JOIN Department d ON w.DepartmentID = d.DepartmentID
GROUP BY w.WorkerID, w.Name, w.Role, d.DeptName
HAVING COUNT(DISTINCT iw.IncidentID) > 0
ORDER BY TotalIncidents DESC, AvgSeverity DESC;

-- Query 1D: Incident hotspots - locations with highest severity concentration
SELECT 
    Location,
    COUNT(*) AS TotalIncidents,
    ROUND(AVG(Severity), 2) AS AvgSeverity,
    COUNT(CASE WHEN Severity >= 4 THEN 1 END) AS CriticalIncidents,
    COUNT(CASE WHEN Severity >= 4 THEN 1 END) * 100 / COUNT(*) AS CriticalPercentage,
    MIN(IncidentDate) AS FirstIncident,
    MAX(IncidentDate) AS LastIncident,
    ROUND((MAX(IncidentDate) - MIN(IncidentDate)), 1) AS DaysSinceFirstIncident,
    PERCENT_RANK() OVER (ORDER BY AVG(Severity)) AS SeverityRank
FROM Safety_Incident
GROUP BY Location
ORDER BY AvgSeverity DESC, TotalIncidents DESC;

-- =============================================================================
-- SECTION 2: EQUIPMENT & MAINTENANCE ANALYTICS
-- =============================================================================

-- Query 2A: Equipment performance and reliability analysis
SELECT 
    e.EquipmentID,
    e.Type,
    e.Model,
    e.Status,
    w_operator.Name AS CurrentOperator,
    COUNT(DISTINCT ur.WorkerID) AS NumberOfOperators,
    SUM(ur.HoursUsed) AS TotalHoursUsed,
    COUNT(DISTINCT ur.ShiftID) AS TotalShiftsUsed,
    COUNT(CASE WHEN ur.Outcome = 'Normal' THEN 1 END) AS NormalUsages,
    COUNT(CASE WHEN ur.Outcome != 'Normal' THEN 1 END) AS ProblematicUsages,
    ROUND(COUNT(CASE WHEN ur.Outcome = 'Normal' THEN 1 END) * 100 / COUNT(*), 2) AS ReliabilityPercent,
    COUNT(DISTINCT mr.MaintenanceID) AS MaintenanceRecords,
    ROUND(SUM(mr.Cost), 2) AS TotalMaintenanceCost,
    MAX(mr.MaintDate) AS LastMaintenanceDate,
    DATEDIFF(DAY, MAX(mr.MaintDate), SYSDATE) AS DaysSinceMaintenance
FROM Equipment e
LEFT JOIN Worker w_operator ON e.OperatedBy = w_operator.WorkerID
LEFT JOIN Usage_Record ur ON e.EquipmentID = ur.EquipmentID
LEFT JOIN Maintenance_Record mr ON e.EquipmentID = mr.EquipmentID
GROUP BY e.EquipmentID, e.Type, e.Model, e.Status, w_operator.Name
ORDER BY ReliabilityPercent ASC, ProblematicUsages DESC;

-- Query 2B: Maintenance schedule compliance and downtime analysis
SELECT 
    e.EquipmentID,
    e.Type,
    e.MaintenanceSchedule,
    MAX(mr.MaintDate) AS LastMaintenance,
    MAX(mr.NextDueDate) AS NextDue,
    CASE 
        WHEN MAX(mr.NextDueDate) < SYSDATE THEN 'OVERDUE'
        WHEN MAX(mr.NextDueDate) <= SYSDATE + 7 THEN 'DUE SOON'
        ELSE 'ON SCHEDULE'
    END AS MaintenanceStatus,
    COUNT(DISTINCT mr.MaintenanceID) AS TotalMaintenances,
    ROUND(AVG(mr.Cost), 2) AS AvgMaintenanceCost,
    SUM(CASE WHEN mr.MaintenanceType = 'Emergency' THEN 1 ELSE 0 END) AS EmergencyMaintenances,
    ROUND(((SYSDATE - MIN(e.PurchaseDate)) / 365.25), 1) AS AgeInYears,
    ROUND(e.DepreciationValue, 2) AS CurrentValue
FROM Equipment e
LEFT JOIN Maintenance_Record mr ON e.EquipmentID = mr.EquipmentID
GROUP BY e.EquipmentID, e.Type, e.MaintenanceSchedule, e.PurchaseDate, e.DepreciationValue
ORDER BY CASE WHEN MAX(mr.NextDueDate) < SYSDATE THEN 0 WHEN MAX(mr.NextDueDate) <= SYSDATE + 7 THEN 1 ELSE 2 END,
         MAX(mr.NextDueDate) ASC;

-- Query 2C: Equipment transfer audit trail and usage patterns
SELECT 
    e.EquipmentID,
    e.Type,
    COUNT(DISTINCT et.TransferID) AS TotalTransfers,
    LISTAGG(w_from.Name || ' → ' || w_to.Name || ' (' || et.TransferReason || ')', ' → ') 
        WITHIN GROUP (ORDER BY et.TransferDate DESC) AS TransferHistory,
    MAX(et.TransferDate) AS LastTransfer,
    STRING_AGG(DISTINCT et.TransferReason, ', ') AS TransferReasons
FROM Equipment e
LEFT JOIN Equipment_Transfer et ON e.EquipmentID = et.EquipmentID
LEFT JOIN Worker w_from ON et.FromWorkerID = w_from.WorkerID
LEFT JOIN Worker w_to ON et.ToWorkerID = w_to.WorkerID
GROUP BY e.EquipmentID, e.Type
HAVING COUNT(DISTINCT et.TransferID) > 0
ORDER BY TotalTransfers DESC;

-- =============================================================================
-- SECTION 3: WORKER PRODUCTIVITY & UTILIZATION
-- =============================================================================

-- Query 3A: Worker utilization matrix with multi-dimensional analysis
SELECT 
    w.WorkerID,
    w.Name,
    w.Role,
    d.DeptName,
    COUNT(DISTINCT asn.ShiftID) AS AssignedShifts,
    SUM(s.Duration) AS TotalAssignedHours,
    COUNT(DISTINCT ur.EquipmentID) AS EquipmentTypes,
    ROUND(SUM(ur.HoursUsed), 2) AS ActualHoursWorked,
    ROUND(SUM(ur.HoursUsed) / SUM(s.Duration) * 100, 2) AS UtilizationPercent,
    COUNT(DISTINCT CASE WHEN ur.Outcome = 'Minor Issue' THEN ur.ShiftID END) AS ShiftsWithMinorIssues,
    COUNT(DISTINCT CASE WHEN ur.Outcome = 'Major Issue' THEN ur.ShiftID END) AS ShiftsWithMajorIssues,
    ROUND(COUNT(DISTINCT iw.IncidentID) * 100 / NULLIF(COUNT(DISTINCT asn.ShiftID), 0), 2) AS IncidentRatePerShift,
    RANK() OVER (ORDER BY SUM(ur.HoursUsed) DESC) AS ProductivityRank,
    PERCENT_RANK() OVER (ORDER BY ROUND(SUM(ur.HoursUsed) / SUM(s.Duration) * 100, 2)) AS UtilizationTile
FROM Worker w
LEFT JOIN Assigned_Shift asn ON w.WorkerID = asn.WorkerID
LEFT JOIN Shift s ON asn.ShiftID = s.ShiftID
LEFT JOIN Usage_Record ur ON w.WorkerID = ur.WorkerID
LEFT JOIN Incident_Worker iw ON w.WorkerID = iw.WorkerID
LEFT JOIN Department d ON w.DepartmentID = d.DepartmentID
WHERE w.EmploymentStatus = 'Active'
GROUP BY w.WorkerID, w.Name, w.Role, d.DeptName
ORDER BY ActualHoursWorked DESC NULLS LAST;

-- Query 3B: Training and certification compliance tracking
SELECT 
    w.WorkerID,
    w.Name,
    w.Role,
    COUNT(DISTINCT tr.TrainingID) AS TotalTrainings,
    COUNT(DISTINCT CASE WHEN tr.TrainingStatus = 'Completed' THEN tr.TrainingID END) AS CompletedTrainings,
    COUNT(DISTINCT CASE WHEN tr.TrainingStatus = 'Expired' THEN tr.TrainingID END) AS ExpiredTrainings,
    COUNT(DISTINCT CASE WHEN tr.ValidUntil < SYSDATE AND tr.TrainingStatus = 'Completed' THEN tr.TrainingID END) AS CertificationsExpiring,
    LISTAGG(tr.Course || ' (Valid until ' || TO_CHAR(tr.ValidUntil, 'YYYY-MM-DD') || ')', ', ') 
        WITHIN GROUP (ORDER BY tr.ValidUntil DESC) AS ActiveCertifications,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN tr.TrainingStatus = 'Completed' AND tr.ValidUntil >= SYSDATE THEN tr.TrainingID END) = 0 THEN 'NO VALID CERTS'
        WHEN COUNT(DISTINCT CASE WHEN tr.TrainingStatus = 'Completed' AND tr.ValidUntil >= SYSDATE THEN tr.TrainingID END) >= 3 THEN 'HIGHLY CERTIFIED'
        WHEN COUNT(DISTINCT CASE WHEN tr.TrainingStatus = 'Completed' AND tr.ValidUntil >= SYSDATE THEN tr.TrainingID END) >= 1 THEN 'CERTIFIED'
        ELSE 'IN PROGRESS'
    END AS CertificationStatus
FROM Worker w
LEFT JOIN Training_Record tr ON w.WorkerID = tr.WorkerID
GROUP BY w.WorkerID, w.Name, w.Role
ORDER BY CompletedTrainings DESC, ExpiredTrainings ASC;

-- Query 3C: Worker safety gear compliance and assignment tracking
SELECT 
    w.WorkerID,
    w.Name,
    w.Role,
    COUNT(DISTINCT wg.GearID) AS AssignedGearTypes,
    LISTAGG(DISTINCT sg.GearType, ', ') WITHIN GROUP (ORDER BY sg.GearType) AS GearAssigned,
    COUNT(DISTINCT CASE WHEN wg.Condition = 'Good' THEN wg.GearID END) AS GearInGoodCondition,
    COUNT(DISTINCT CASE WHEN wg.Condition IN ('Fair', 'Poor', 'Damaged') THEN wg.GearID END) AS DamagedGear,
    COUNT(DISTINCT CASE WHEN wg.ReturnedDate IS NULL THEN wg.GearID END) AS CurrentlyHoldingGear,
    ROUND(COUNT(DISTINCT CASE WHEN wg.Condition = 'Good' THEN wg.GearID END) * 100 / 
          NULLIF(COUNT(DISTINCT wg.GearID), 0), 2) AS GearQualityPercent,
    CASE 
        WHEN COUNT(DISTINCT wg.GearID) = 0 THEN 'NO GEAR ASSIGNED'
        WHEN ROUND(COUNT(DISTINCT CASE WHEN wg.Condition = 'Good' THEN wg.GearID END) * 100 / 
                   NULLIF(COUNT(DISTINCT wg.GearID), 0), 2) < 70 THEN 'REPLACE GEAR'
        ELSE 'COMPLIANT'
    END AS GearComplianceStatus
FROM Worker w
LEFT JOIN Worker_Gear wg ON w.WorkerID = wg.WorkerID AND wg.ReturnedDate IS NULL
LEFT JOIN Safety_Gear sg ON wg.GearID = sg.GearID
GROUP BY w.WorkerID, w.Name, w.Role
ORDER BY AssignedGearTypes DESC, GearQualityPercent ASC;

-- =============================================================================
-- SECTION 4: DEPARTMENT & SHIFT MANAGEMENT
-- =============================================================================

-- Query 4A: Department-level safety metrics and performance
SELECT 
    d.DepartmentID,
    d.DeptName,
    d.Location,
    COUNT(DISTINCT w.WorkerID) AS TotalWorkers,
    COUNT(DISTINCT CASE WHEN w.EmploymentStatus = 'Active' THEN w.WorkerID END) AS ActiveWorkers,
    COUNT(DISTINCT si.IncidentID) AS DepartmentIncidents,
    ROUND(AVG(si.Severity), 2) AS AvgIncidentSeverity,
    COUNT(CASE WHEN si.Severity >= 4 THEN 1 END) AS CriticalIncidents,
    ROUND(COUNT(DISTINCT si.IncidentID) * 100 / NULLIF(COUNT(DISTINCT w.WorkerID), 0), 2) AS IncidentsPerWorker,
    COUNT(DISTINCT tr.TrainingID) AS TotalTrainings,
    ROUND(d.SafetyBudget, 2) AS SafetyBudget,
    ROUND(SUM(mr.Cost), 2) AS MaintenanceSpend,
    RANK() OVER (ORDER BY ROUND(AVG(si.Severity), 2) DESC) AS SafetyRank
FROM Department d
LEFT JOIN Worker w ON d.DepartmentID = w.DepartmentID
LEFT JOIN Incident_Worker iw ON w.WorkerID = iw.WorkerID
LEFT JOIN Safety_Incident si ON iw.IncidentID = si.IncidentID
LEFT JOIN Training_Record tr ON w.WorkerID = tr.WorkerID
LEFT JOIN Equipment e ON w.DepartmentID = d.DepartmentID
LEFT JOIN Maintenance_Record mr ON e.EquipmentID = mr.EquipmentID
GROUP BY d.DepartmentID, d.DeptName, d.Location, d.SafetyBudget
ORDER BY CriticalIncidents DESC, AvgIncidentSeverity DESC;

-- Query 4B: Shift utilization and worker distribution analysis
SELECT 
    s.ShiftID,
    s.ShiftDate,
    s.ShiftTime,
    s.Location,
    s.ShiftType,
    s.MaxWorkers,
    COUNT(DISTINCT asn.WorkerID) AS AssignedWorkers,
    ROUND(COUNT(DISTINCT asn.WorkerID) * 100 / s.MaxWorkers, 2) AS ShiftUtilizationPercent,
    COUNT(DISTINCT ur.EquipmentID) AS EquipmentInUse,
    ROUND(SUM(ur.HoursUsed), 2) AS TotalEquipmentHours,
    COUNT(DISTINCT CASE WHEN ur.Outcome != 'Normal' THEN ur.EquipmentID END) AS EquipmentWithIssues,
    COUNT(DISTINCT si.IncidentID) AS IncidentsThisShift,
    CASE 
        WHEN COUNT(DISTINCT asn.WorkerID) >= s.MaxWorkers THEN 'AT CAPACITY'
        WHEN COUNT(DISTINCT asn.WorkerID) >= s.MaxWorkers * 0.8 THEN 'HIGH UTILIZATION'
        WHEN COUNT(DISTINCT asn.WorkerID) >= s.MaxWorkers * 0.5 THEN 'MODERATE UTILIZATION'
        ELSE 'LOW UTILIZATION'
    END AS CapacityStatus
FROM Shift s
LEFT JOIN Assigned_Shift asn ON s.ShiftID = asn.ShiftID
LEFT JOIN Usage_Record ur ON asn.ShiftID = ur.ShiftID
LEFT JOIN Safety_Incident si ON s.Location = si.Location AND 
                                 si.IncidentDate = s.ShiftDate
GROUP BY s.ShiftID, s.ShiftDate, s.ShiftTime, s.Location, s.ShiftType, s.MaxWorkers
ORDER BY s.ShiftDate DESC, s.ShiftTime;

-- =============================================================================
-- SECTION 5: RISK ASSESSMENT & PREDICTIVE ANALYTICS
-- =============================================================================

-- Query 5A: Worker risk scoring and classification matrix
SELECT 
    w.WorkerID,
    w.Name,
    w.Role,
    d.DeptName,
    COUNT(DISTINCT iw.IncidentID) * 2 + 
    ROUND(AVG(si.Severity), 2) * 3 + 
    (SELECT COUNT(*) FROM Assigned_Shift WHERE WorkerID = w.WorkerID) * 0.1 +
    (SELECT COUNT(*) FROM Usage_Record WHERE WorkerID = w.WorkerID AND Outcome != 'Normal') * 1.5
    AS RiskScore,
    NTILE(5) OVER (ORDER BY 
        COUNT(DISTINCT iw.IncidentID) * 2 + 
        ROUND(AVG(si.Severity), 2) * 3 + 
        (SELECT COUNT(*) FROM Assigned_Shift WHERE WorkerID = w.WorkerID) * 0.1 +
        (SELECT COUNT(*) FROM Usage_Record WHERE WorkerID = w.WorkerID AND Outcome != 'Normal') * 1.5
    ) AS RiskQuintile,
    CASE 
        WHEN (COUNT(DISTINCT iw.IncidentID) * 2 + ROUND(AVG(si.Severity), 2) * 3) > 15 THEN 'CRITICAL RISK'
        WHEN (COUNT(DISTINCT iw.IncidentID) * 2 + ROUND(AVG(si.Severity), 2) * 3) > 10 THEN 'HIGH RISK'
        WHEN (COUNT(DISTINCT iw.IncidentID) * 2 + ROUND(AVG(si.Severity), 2) * 3) > 5 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS RiskCategory,
    CASE 
        WHEN (COUNT(DISTINCT iw.IncidentID) * 2 + ROUND(AVG(si.Severity), 2) * 3) > 15 THEN 'Immediate retraining and role reassessment'
        WHEN (COUNT(DISTINCT iw.IncidentID) * 2 + ROUND(AVG(si.Severity), 2) * 3) > 10 THEN 'Enhanced monitoring and safety training'
        WHEN (COUNT(DISTINCT iw.IncidentID) * 2 + ROUND(AVG(si.Severity), 2) * 3) > 5 THEN 'Regular safety refresher courses'
        ELSE 'Continue standard safety protocols'
    END AS RecommendedAction
FROM Worker w
LEFT JOIN Incident_Worker iw ON w.WorkerID = iw.WorkerID
LEFT JOIN Safety_Incident si ON iw.IncidentID = si.IncidentID
LEFT JOIN Department d ON w.DepartmentID = d.DepartmentID
WHERE w.EmploymentStatus = 'Active'
GROUP BY w.WorkerID, w.Name, w.Role, d.DeptName
ORDER BY RiskScore DESC;

-- Query 5B: Equipment reliability and failure prediction
SELECT 
    e.EquipmentID,
    e.Type,
    COUNT(DISTINCT ur.ShiftID) AS UsageFrequency,
    COUNT(DISTINCT CASE WHEN ur.Outcome != 'Normal' THEN ur.ShiftID END) AS IssueCount,
    ROUND(COUNT(DISTINCT CASE WHEN ur.Outcome != 'Normal' THEN ur.ShiftID END) * 100 / 
          NULLIF(COUNT(DISTINCT ur.ShiftID), 0), 2) AS IssueFrequencyPercent,
    COUNT(DISTINCT mr.MaintenanceID) AS MaintenanceEvents,
    CASE 
        WHEN DATEDIFF(DAY, MAX(mr.MaintDate), SYSDATE) > 90 THEN 'OVERDUE FOR MAINTENANCE'
        WHEN ROUND(COUNT(DISTINCT CASE WHEN ur.Outcome != 'Normal' THEN ur.ShiftID END) * 100 / 
                   NULLIF(COUNT(DISTINCT ur.ShiftID), 0), 2) > 20 THEN 'HIGH FAILURE RATE'
        WHEN ROUND(COUNT(DISTINCT CASE WHEN ur.Outcome != 'Normal' THEN ur.ShiftID END) * 100 / 
                   NULLIF(COUNT(DISTINCT ur.ShiftID), 0), 2) > 10 THEN 'MODERATE FAILURE RATE'
        ELSE 'RELIABLE'
    END AS EquipmentStatus,
    RANK() OVER (ORDER BY ROUND(COUNT(DISTINCT CASE WHEN ur.Outcome != 'Normal' THEN ur.ShiftID END) * 100 / 
                                 NULLIF(COUNT(DISTINCT ur.ShiftID), 0), 2) DESC) AS ReliabilityRank
FROM Equipment e
LEFT JOIN Usage_Record ur ON e.EquipmentID = ur.EquipmentID
LEFT JOIN Maintenance_Record mr ON e.EquipmentID = mr.EquipmentID
GROUP BY e.EquipmentID, e.Type
ORDER BY IssueFrequencyPercent DESC;

-- Query 5C: Predictive shift risk assessment (incidents by location/time pattern)
SELECT 
    s.Location,
    s.ShiftTime,
    COUNT(DISTINCT s.ShiftID) AS TotalShifts,
    COUNT(DISTINCT si.IncidentID) AS HistoricalIncidents,
    ROUND(AVG(si.Severity), 2) AS AvgHistoricalSeverity,
    COUNT(DISTINCT CASE WHEN si.Severity >= 4 THEN si.IncidentID END) AS CriticalIncidents,
    ROUND(COUNT(DISTINCT si.IncidentID) * 100 / NULLIF(COUNT(DISTINCT s.ShiftID), 0), 2) AS IncidentRatePercent,
    CASE 
        WHEN COUNT(DISTINCT si.IncidentID) >= 3 AND ROUND(AVG(si.Severity), 2) >= 3.5 THEN 'VERY HIGH RISK'
        WHEN COUNT(DISTINCT si.IncidentID) >= 2 OR ROUND(AVG(si.Severity), 2) >= 3.5 THEN 'HIGH RISK'
        WHEN COUNT(DISTINCT si.IncidentID) >= 1 OR ROUND(AVG(si.Severity), 2) >= 2.5 THEN 'MODERATE RISK'
        ELSE 'LOW RISK'
    END AS ShiftRiskProfile
FROM Shift s
LEFT JOIN Safety_Incident si ON s.Location = si.Location
GROUP BY s.Location, s.ShiftTime
ORDER BY IncidentRatePercent DESC, AvgHistoricalSeverity DESC;

-- =============================================================================
-- SECTION 6: EXECUTIVE SUMMARY DASHBOARDS
-- =============================================================================

-- Query 6A: Overall Mining Operation Safety Dashboard
SELECT 
    'Total Active Workers' AS Metric, 
    CAST(COUNT(DISTINCT CASE WHEN EmploymentStatus = 'Active' THEN WorkerID END) AS VARCHAR2(50)) AS Value
FROM Worker
UNION ALL
SELECT 'Total Safety Incidents', CAST(COUNT(*) AS VARCHAR2(50))
FROM Safety_Incident
WHERE IncidentDate >= ADD_MONTHS(SYSDATE, -12)
UNION ALL
SELECT 'Critical Incidents (Severity >= 4)', CAST(COUNT(*) AS VARCHAR2(50))
FROM Safety_Incident
WHERE Severity >= 4 AND IncidentDate >= ADD_MONTHS(SYSDATE, -12)
UNION ALL
SELECT 'Average Incident Severity', CAST(ROUND(AVG(Severity), 2) AS VARCHAR2(50))
FROM Safety_Incident
WHERE IncidentDate >= ADD_MONTHS(SYSDATE, -12)
UNION ALL
SELECT 'Equipment Operational', CAST(COUNT(*) AS VARCHAR2(50))
FROM Equipment
WHERE Status = 'Available'
UNION ALL
SELECT 'Active Certifications', CAST(COUNT(*) AS VARCHAR2(50))
FROM Training_Record
WHERE TrainingStatus = 'Completed' AND ValidUntil >= SYSDATE
UNION ALL
SELECT 'Expired Certifications', CAST(COUNT(*) AS VARCHAR2(50))
FROM Training_Record
WHERE TrainingStatus = 'Completed' AND ValidUntil < SYSDATE;

-- Query 6B: Department Performance Scorecard
SELECT 
    d.DeptName,
    COUNT(DISTINCT w.WorkerID) AS Workers,
    ROUND(AVG(si.Severity), 2) AS AvgIncidentSeverity,
    COUNT(DISTINCT si.IncidentID) AS YearlyIncidents,
    COUNT(DISTINCT mr.MaintenanceID) AS MaintenanceEvents,
    ROUND(SUM(mr.Cost), 0) AS MaintenanceCost,
    RANK() OVER (ORDER BY AVG(si.Severity) DESC) AS SafetyRank
FROM Department d
LEFT JOIN Worker w ON d.DepartmentID = w.DepartmentID
LEFT JOIN Incident_Worker iw ON w.WorkerID = iw.WorkerID
LEFT JOIN Safety_Incident si ON iw.IncidentID = si.IncidentID AND si.IncidentDate >= ADD_MONTHS(SYSDATE, -12)
LEFT JOIN Equipment e ON d.DepartmentID = w.DepartmentID
LEFT JOIN Maintenance_Record mr ON e.EquipmentID = mr.EquipmentID
GROUP BY d.DeptName
ORDER BY SafetyRank;

-- ============================================================================
-- END OF COMPLEX QUERIES
-- ============================================================================
