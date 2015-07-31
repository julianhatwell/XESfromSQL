--INSERT INTO KSS.IntakeStatus
--SELECT Distinct Stat From [dbo].[SampleKSS_LogData_Reasons]

--INSERT INTO KSS.Reason
--SELECT DISTInCT Reason, 1 From [dbo].[SampleKSS_LogData_Reasons]

--INSERT INTO kss.StatusReason ([IntakeStatusId], [ReasonId])
--SELECT Distinct s.IntakeStatusId, r.ReasonId From [dbo].[KSSLog] lo
--INNER JOIN kss.IntakeStatus s ON lo.stat = s.IntakeStatus
--INNER JOIN kss.Reason r on ISNULL(lo.Reason, '') = r.Reason
--EXCEPT SELECT [IntakeStatusId], [ReasonId] FROM [KSS].[StatusReason]

--CREATE VIEW KSS.StatusReasonMapping
--AS
--SELECT sr. StatusReasonId, s.IntakeStatus, r.Reason, sr.Mapping
--FROM kss.StatusReason sr
--INNER JOIN kss.IntakeStatus s ON sr.IntakeStatusId = s.IntakeStatusId
--INNER JOIN kss.Reason r ON sr.ReasonId = r.ReasonId

--UPDATE KSS.StatusReasonMapping
--SET Mapping = [IntakeStatus] + ' ' + [Reason]
--FROM KSS.StatusReasonMapping WHERE Mapping IS NULL

--UPDATE KSS.StatusReasonMapping
--SET Mapping = RTRIM(LTRIM(Mapping))

SELECT * FROM [KSS].[StatusReasonMapping]