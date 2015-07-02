--consider modifying data types of table variables to suit needs, other columns can be added (such as cost)
-- but this will need to be built in to the XML object following the XES schema guidelines. (somehting for later)
DECLARE @logmapping TABLE(
						[case] char(10)
						, [resource] varchar(255)
						, [transition] varchar(50)
						, [timestamp] varchar(50)
						, [activity] varchar(255)
						)

/* map the columns in the log table --you should edit this section to match your log data */
/* next version I will probably switch to using Table-value functions to store multiple patterns 
of searching any given log data table, with filters passed as params to the funtion
in order to render this script completely generic */
INSERT INTO @logmapping
SELECT LTRIM(RTRIM([Student])) AS [case]
, [Resource] AS [resource]
, 'complete' AS [transition] --may need to include other transitions
, CONVERT(char(19), [ActivityDate], 126) + '.000+08:00' AS [timestamp] --modify for other time zones
, [Stat] + ' \ \ ' + ISNULL([Reason],'') AS [activity]
FROM [dbo].[SampleKSS_LogData_Reasons] AS [trace]
--do any filtering you need here
WHERE ActivityDate >= '2015-01-01'
AND ProgramGroup LIKE 'Diploma%'
AND Org = 'Full Time'
ORDER BY LTRIM(RTRIM([Student])) DESC, ActivityDate
--SELECT * FROM @logmapping


/* do not edit below this line unless you really know what you are doing */

/* This is intended as a generic script that will read in data from a table with the columns
patterned in the table variable @logmapping above. 

The essential and most commonly used optional data is already included here.

Other columns could be added, but to be used they will need to be 
correctly built into the structure of the XES by modifying the SQLXML statements below. */



/* create xml object of unique cases - this will be used for the trace (parent) nodes in the XES */
DECLARE @trace TABLE([case] char(10) NOT NULL PRIMARY KEY, [trace] xml)
INSERT INTO @trace([case], [trace])
SELECT DISTINCT [case], '<trace><string value="' + [case] + '" key="concept:name" /></trace>' -- other data points for case instance may be added
FROM @logmapping
--SELECT * FROM @trace

/* create the xml object for every event - these will be event (child) nodes in the XES */
DECLARE @eventlog XML
SET @eventlog = 
(
SELECT [case]
, [resource]
, [transition]
, [timestamp]
, [activity]
FROM @logmapping AS [trace]
ORDER BY [case], [timestamp]
FOR XML PATH('event'), ROOT('log')
)
--SELECT @eventlog

/* carve the single xml object containing all the events into a new table where each event XML node is in its own row */
DECLARE @event TABLE([case] char(10), [event] xml)
INSERT INTO @event([case], [event]) 
SELECT [log].[event].value('(case)[1]', 'char(10)'), 
[log].[event].query(
'<event>
<string value="{case}" key="concept:instance"/>
<string value="{resource}" key="org:resource"/>
<date value="{timestamp}" key="time:timestamp"/>
<string value="{transition}" key="lifecycle:transition"/>
<string value="{activity}" key="concept:name"/>
</event>' 
) AS [event]
FROM @eventlog.nodes('log/event') [log]([event])
--SELECT * FROM @event

/* create a single XML object from the log data with the required hierarchical structure conforming to OpenXES Schema */
DECLARE @XESlog XML
SET @XESlog =
(
	SELECT [trace].query('trace/*')
	, (
		SELECT [event].query('event/*')
		FROM @event [event]
		WHERE [event].[case] = [trace].[case]
		FOR XML PATH('event'), TYPE
	)
	FROM @trace [trace]
	FOR XML PATH('trace'), ROOT('log')
)
--SELECT @XESlog

/* post processing of the XML object with additional required elements and attributes */
SET @XESlog.modify('
    insert      
        (
            attribute xes.features {"arbitrary depth"}
			, attribute xes.version {"1.0"}
        )
		into (log[1])
')

SET @XESlog.modify('
    insert      
        (
			<!-- this file was created by custom script from Julian Hatwell 2015 -->
			, <extension uri="http://code.fluxicon.com/xes/lifecycle.xesext" prefix="lifecycle" name="Lifecycle"/>
			, <extension uri="http://code.fluxicon.com/xes/time.xesext" prefix="time" name="Time"/>
			, <extension uri="http://code.fluxicon.com/xes/concept.xesext" prefix="concept" name="Concept"/>
			, <extension uri="http://code.fluxicon.com/xes/semantic.xesext" prefix="semantic" name="Semantic"/>
		    , <extension uri="http://code.fluxicon.com/xes/org.xesext" prefix="org" name="Organizational"/>
		    , <global scope="trace"><string value="UNKNOWN" key="concept:name"/></global>
			, <global scope="event">
				<string value="UNKNOWN" key="concept:instance"/>
				<string value="UNKNOWN" key="org:resource"/>
				<date value="1970-01-01T00:00:00.000+08:00" key="time:timestamp"/>
				<string value="UNKNOWN" key="lifecycle:transition"/>
				<string value="UNKNOWN" key="concept:name"/>
			</global>
			, <classifier name="Activity classifier" keys="concept:name lifecycle:transition"/>
			, <string value="Manual Log Export from SQL Server" key="concept:name"/>
			, <string value="standard" key="lifecycle:model"/>
		)
     before (/log/trace)[1]') 

SELECT @XESlog

/*

you can internally name this log file for ProM and other tooling to recognise by modifying the line

<string value="Manual Log Export from SQL Server" key="concept:name"/>

*/


/* in may be necessary to update the time zone as this script was created in Singapore  

you will need to modify the line 

<date value="1970-01-01T00:00:00.000+08:00" key="time:timestamp"/>

and also the set based construction at the top of this script

, CONVERT(char(19), [ActivityDate], 126) + '.000+08:00' AS [timestamp] --modify for other time zones

*/

-- would like to add explicit name space into the object : declare default element namespace "http://code.deckfour.org/xes"; can't seem to get this to work so far
