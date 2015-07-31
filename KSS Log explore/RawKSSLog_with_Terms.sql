SELECT DISTINCT op.description AS Program
, opg.description AS ProgramGroup
, oi.StartDate AS IntakeStartDate
, oap.description AS ProgramPartner
, oap.country AS PartnerCountry
, oao.description AS Org
, ois.contactID AS Student
, oi.description AS Intake
, oi.description AS Intake
, os.statusDesc AS Stat
, CASE
	WHEN ot.termCode IS NOT NULL THEN ot.termCode
	ELSE osr.reasonDesc END
AS Reason
, ois.lastModifiedBy AS Resource
, ot.termCode AS Term
, ot.startDate AS TermStartDate
, ot.endDate AS TermEndDate
-- the following takes the given status date DATE type, then takes the primary key and creates a TIME type to add to the status date
-- ensuring that the sequential order of activities with a same date is correctly preserved, although the TIME part is an artefact
-- 11% of cases after 2014 01 01 have this issue
, CASE
	WHEN ot.startDate IS NOT NULL THEN CONVERT(ot.startDate, DATETIME)
	WHEN CONVERT(ois.createDate, DATE) = ois.statusDate THEN ois.createDate
	ELSE 
	ADDTIME(CONVERT(ois.statusDate, DATETIME),
	MAKETIME(ROUND((FLOOR(ois.intakeStatusId/3600)/24-FLOOR(FLOOR(ois.intakeStatusId/3600)/24))*24,0),
	FLOOR((ois.intakeStatusId/3600 - FLOOR(ois.intakeStatusId/3600))*60),
	((ois.intakeStatusId/3600 - FLOOR(ois.intakeStatusId/3600))*60-FLOOR((ois.intakeStatusId/3600 - FLOOR(ois.intakeStatusId/3600))*60))*60)) 
	END
AS ActivityDate
FROM ods_intakeStatus ois
INNER JOIN ods_status os
	ON ois.statusId = os.statusId
LEFT OUTER JOIN ods_statusreason osr
	ON ois.reasonID = osr.reasonId
INNER JOIN ods_intake oi 
	ON ois.intakeID = oi.intakeId
INNER JOIN ods_program op
	ON oi.programId = op.programId
LEFT OUTER JOIN ods_acadorg oao
	ON oi.orgId = oao.orgId
LEFT OUTER JOIN ods_programGroup opg
	ON op.programGroupId = opg.programGroupId
LEFT OUTER JOIN ods_acadpartner oap
	ON op.partnerId = oap.partnerId	
LEFT OUTER JOIN ods_intakeTerm oit
	ON oi.intakeId = oit.intakeId
LEFT OUTER JOIN ods_term ot
	ON oit.termId = ot.termId
	-- AND oao.orgId = ot.orgId
	-- AND oap.partnerId = ot.partnerId
	-- AND op.programId = ot.programId
	AND os.statusDesc LIKE 'Active%'
	AND CASE
	WHEN CONVERT(ois.createDate, DATE) = ois.statusDate
	THEN ois.createDate
	ELSE 
	ADDTIME(CONVERT(ois.statusDate, DATETIME),
	MAKETIME(ROUND((FLOOR(ois.intakeStatusId/3600)/24-FLOOR(FLOOR(ois.intakeStatusId/3600)/24))*24,0),
	FLOOR((ois.intakeStatusId/3600 - FLOOR(ois.intakeStatusId/3600))*60),
	((ois.intakeStatusId/3600 - FLOOR(ois.intakeStatusId/3600))*60-FLOOR((ois.intakeStatusId/3600 - FLOOR(ois.intakeStatusId/3600))*60))*60)) 
	END <= ot.startDate
	-- AND ot.endDate <= (SELECT statusDate FROM lastNonActiveStatusDate lnasd WHERE ois.contactID = lnasd.contactId)
				-- INNER JOIN ods_status os2
-- 				ON cor_ois.statusId = os2.statusId
-- 				WHERE ois.contactID = cor_ois.contactID
-- 				-- AND os2.statusDesc Not LIKE 'Active%'
-- 				GROUP BY cor_ois.contactID)
WHERE oi.StartDate >= '2014-01-01' 
ORDER BY IntakeStartDate, Student, ActivityDate
LIMIT 100000
 
