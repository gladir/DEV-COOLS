<!--- control.cfm : Exemple structures de controle --->
<!--- Demonstration de cfif/cfelseif/cfelse, cfswitch/cfcase --->

<!--- cfif simple --->
<cfset x = 10>
<cfif x GT 5>
  <cfoutput>x est grand</cfoutput>
</cfif>

<!--- cfif / cfelseif / cfelse --->
<cfset note = 75>
<cfif note GTE 90>
  <cfoutput>Excellent</cfoutput>
<cfelseif note GTE 70>
  <cfoutput>Bien</cfoutput>
<cfelseif note GTE 50>
  <cfoutput>Passable</cfoutput>
<cfelse>
  <cfoutput>Echec</cfoutput>
</cfif>

<!--- cfif avec operateurs logiques --->
<cfset age = 25>
<cfset permis = 1>
<cfif age GTE 18>
  <cfoutput>Majeur</cfoutput>
</cfif>

<!--- cfswitch / cfcase --->
<cfset jour = 3>
<cfswitch expression="#jour#">
  <cfcase value="1">
    <cfoutput>Lundi</cfoutput>
  </cfcase>
  <cfcase value="2">
    <cfoutput>Mardi</cfoutput>
  </cfcase>
  <cfcase value="3">
    <cfoutput>Mercredi</cfoutput>
  </cfcase>
  <cfdefaultcase>
    <cfoutput>Autre jour</cfoutput>
  </cfdefaultcase>
</cfswitch>

<!--- cfif avec comparaison de chaines --->
<cfset lang = "CF">
<cfif lang EQ "CF">
  <cfoutput>ColdFusion</cfoutput>
</cfif>
