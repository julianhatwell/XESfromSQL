SELECT DISTINCT op.description AS Program
, opg.description AS ProgramGroup
, oi.StartDate AS IntakeStartDate
, oap.description AS ProgramPartner
, oap.country AS PartnerCountry
, oao.description AS Org
, ois.contactID AS Student
, oi.description AS Intake
, os.statusDesc AS Stat
, osr.reasonDesc AS Reason
, ois.lastModifiedBy AS Resource
-- the following takes the given status date DATE type, then takes the primary key and creates a TIME type to add to the status date
-- ensuring that the sequential order of activities with a same date is correctly preserved, although the TIME part is an artefact
-- 11% of cases after 2014 01 01 have this issue
, CASE
	WHEN CONVERT(ois.createDate, DATE) = ois.statusDate
	THEN ois.createDate
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
INNER JOIN ods_statusreason osr
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
WHERE oi.StartDate >= '2014-01-01' 


 
