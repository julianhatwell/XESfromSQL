--consider modifying data types of table variables to suit needs, other columns can be added (such as cost)
-- but this will need to be built in to the XML object following the XES schema guidelines. (something for later)
DECLARE @logmapping TABLE(
						[case] char(10)
						, [resource] varchar(255)
						, [transition] varchar(50)
						, [timestamp] varchar(50)
						, [activity] varchar(255)
						)

/* project specific section */
/* logic for preprocessing log has been moved to separate table value functions, specific to each project */
/* of course the whole thing may have to be modified if additional attributes are required in the XES file */
DECLARE @EarliestIntakeStartDate datetime = '2015-03-01'
DECLARE @LatestIntakeStartDate datetime = '2015-06-01'
DECLARE @ProgramGroup nvarchar(255) = 'Diploma%'
DECLARE @FullTime bit = 1
DECLARE @UseStatusMappigs bit = 1

--there are two versions of the function, one is the raw status + reason, the other is mapped/interpreted for simplification
INSERT INTO @logmapping
SELECT [case], [resource], [transition], [timestamp], [activity]
FROM KSS.SampleLog_PreProcessing
	(
		@EarliestIntakeStartDate
		, @LatestIntakeStartDate
		, @ProgramGroup
		, @FullTime
		, @UseStatusMappigs
	) AS [trace]
ORDER BY [case], [timestamp]
--take a look at the results to far
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
