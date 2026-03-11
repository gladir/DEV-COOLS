<cfset greeting = "Hello">
<cfinclude template="test_include_helper.cfm">
<cfoutput>#greeting#</cfoutput>
<cfinvoke component="MyComp" method="doSomething" returnVariable="result">
<cfimport taglib="/tags" prefix="ui">
