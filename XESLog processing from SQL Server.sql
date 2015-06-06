DECLARE @logshred XML
DECLARE @trace TABLE([case] char(10) NOT NULL PRIMARY KEY, [trace] xml)
DECLARE @event TABLE([case] char(10), [event] xml)
DECLARE @XESlog XML

/* map the unique cases --you should edit this section to match your log table */
INSERT INTO @trace([case], [trace])
SELECT DISTINCT Student, '<trace><string value="' + Student + '" key="concept:name" /></trace>' -- other data points for case instance may be added
FROM [dbo].[SampleKSS_LogData]

/* map the columns in the log table --you should edit this section to match your log table */
SET @logshred = 
(
SELECT[Student] AS [case]
, [Resource] AS [resource]
, 'complete' AS [transition]
, CONVERT(char(19), [ActivityDate], 126) + '.000+08:00' AS [timestamp] --modify for other time zones
, [Stat] + ' \ \ ' + [Reason] AS [activity]
FROM [dbo].[SampleKSS_LogData] AS [trace]
FOR XML PATH('event'), ROOT('log')
)

/* do not edit below this line unless you really know what you are doing */

/* create nodes for each event */
INSERT INTO @event([case], [event]) 
SELECT [log].[event].value('(case)[1]', 'char(10)'), 
[log].[event].query(
'<event>
<string value="{case}" key="concept:instance"/>
<string value="{resource}" key="org:resource"/>
<date value="{timestamp}" key="time:timestamp"/>
<string value="complete" key="lifecycle:transition"/>
<string value="{activity}" key="concept:name"/>
</event>' -- look out for hard-coded complete lifecycle:transition. other implementations may need to create a variable
) AS [event]
FROM @logshred.nodes('log/event') [log]([event])


/* create a single XML object from the log data with the required hierarchical structure conforming to OpenXES Schema */
SET @XESlog =
(
	SELECT trace.query('trace/*')
	, (
		SELECT [event].query('event/*')
		FROM @event [event]
		WHERE trace.[case] = [case]
		FOR XML PATH('event'), TYPE
	)
	FROM @trace trace
	FOR XML PATH('trace'), ROOT('log')
)

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

(/Ratings/Rating[@RatingId="1"]/ToolSkills)[1]')

*/


/* in may be necessary to update the time zone as this script was created in Singapore  

you will need to modify the line 

<date value="1970-01-01T00:00:00.000+08:00" key="time:timestamp"/>

and also the set based construction at the top of this script

, CONVERT(char(19), [ActivityDate], 126) + '.000+08:00' AS [timestamp] --modify for other time zones

*/

-- can't seem to get this to work. would like to add explicit name space into the object : declare default element namespace "http://code.deckfour.org/xes";
