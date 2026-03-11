<!--- Test TODO 21 : Balises de sortie et formatage --->

<!--- Test cfsilent : pas de sortie --->
<cfsilent>
<cfset silentVar = 42>
</cfsilent>

<!--- Test cfsavecontent --->
<cfsavecontent variable="savedContent">
<cfoutput>Hello World</cfoutput>
</cfsavecontent>

<!--- Test DateFormat / TimeFormat / LSCurrencyFormat (stubs) --->
<cfset d = DateFormat(20260101, "mm/dd/yyyy")>
<cfset t = TimeFormat(1200, "HH:mm")>
<cfset c = LSCurrencyFormat(42)>

<!--- Test cfflush (stub) --->
<cfflush>

<!--- Test cfheader / cfcontent (stubs) --->
<cfheader name="X-Test" value="ok">
<cfcontent type="text/plain">

<!--- Test cflog (stub) --->
<cflog text="Test message">

<!--- Afficher les resultats --->
<cfoutput>#silentVar#</cfoutput>
<cfoutput>#savedContent#</cfoutput>
<cfoutput>#d#</cfoutput>
