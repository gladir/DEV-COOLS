<!--- errors.cfm : Exemple gestion des erreurs ColdFusion --->
<!--- Demonstration de cftry/cfcatch/cffinally, cfthrow, cfrethrow --->

<!--- cftry / cfcatch basique --->
<cftry>
  <cfset x = 42>
  <cfoutput>x = #x#</cfoutput>
  <cfcatch type="any">
    <cfoutput>Erreur attrapee</cfoutput>
  </cfcatch>
</cftry>

<!--- cfthrow avec message --->
<cftry>
  <cfthrow message="Erreur de test" type="application" detail="detail">
  <cfcatch type="application">
    <cfoutput>Catch application: #cfcatch.message#</cfoutput>
  </cfcatch>
</cftry>

<!--- cftry avec cffinally --->
<cftry>
  <cfset y = 10>
  <cfcatch type="any">
    <cfoutput>Erreur</cfoutput>
  </cfcatch>
  <cffinally>
    <cfoutput>Finally execute</cfoutput>
  </cffinally>
</cftry>

<!--- cfrethrow : relancer l exception --->
<cftry>
  <cftry>
    <cfthrow message="erreur interne" type="application">
    <cfcatch type="application">
      <cfrethrow>
    </cfcatch>
  </cftry>
  <cfcatch type="any">
    <cfoutput>Exception relancee</cfoutput>
  </cfcatch>
</cftry>

<!--- cfscript try/catch --->
<cfscript>
  try {
    var z = 99;
  } catch (any e) {
    writeOutput(e.message);
  } finally {
    writeOutput("done");
  }
</cfscript>
