USE [TestingDB]
GO

/****** Object:  UserDefinedFunction [KSS].[SampleLog_PreProcessing]    Script Date: 06/07/2015 3:54:28 PM ******/
DROP FUNCTION [KSS].[SampleLog_PreProcessing_with_mapped_status]
GO

/****** Object:  UserDefinedFunction [KSS].[SampleLog_PreProcessing]    Script Date: 06/07/2015 3:54:28 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE FUNCTION [KSS].[SampleLog_PreProcessing]
(	
@EarliestIntakeStartDate datetime
, @LatestIntakeStartDate datetime
, @ProgramGroup nvarchar(255)
, @FullTime bit
, @UseStatusMappings bit
)
RETURNS TABLE 
AS
RETURN 
(
SELECT LTRIM(RTRIM([Student])) AS [case]
, [Resource] AS [resource]
, 'complete' AS [transition] --may need to include other transitions
, CONVERT(char(19), [ActivityDate], 126) + '.000+08:00' AS [timestamp] --modify for other time zones
, CASE 
	WHEN @UseStatusMappings = 1 
	THEN srm.Mapping 
	ELSE [trace].[Stat] + ' \ \ ' + ISNULL([trace].[Reason],'') END
	AS [activity]
FROM [dbo].[SampleKSS_LogData_Reasons] AS [trace]
INNER JOIN [KSS].[StatusReasonMapping] srm
ON trace.Stat = srm.IntakeStatus AND trace.Reason = srm.Reason
--do any filtering you need here
WHERE IntakeStartDate BETWEEN @EarliestIntakeStartDate AND @LatestIntakeStartDate
AND ProgramGroup LIKE @ProgramGroup
AND CASE @FullTime WHEN 1 THEN 'Full Time' ELSE 'Part Time' END = Org
)

