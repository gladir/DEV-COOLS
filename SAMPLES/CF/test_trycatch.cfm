<!--- test_trycatch.cfm : Test de TODO 23 - Gestion des erreurs --->

<!--- Test 1 : cftry / cfcatch basique --->
<cftry>
  <cfset x = 42>
  <cfoutput>#x#</cfoutput>
  <cfcatch type="any">
    <cfoutput>Erreur attrapee</cfoutput>
  </cfcatch>
</cftry>

<!--- Test 2 : cfthrow dans un cftry --->
<cftry>
  <cfthrow message="Erreur de test" type="application" detail="detail test">
  <cfcatch type="application">
    <cfoutput>#cfcatch.message#</cfoutput>
  </cfcatch>
</cftry>

<!--- Test 3 : cftry avec cffinally --->
<cftry>
  <cfset y = 10>
  <cfcatch type="any">
    <cfoutput>Erreur</cfoutput>
  </cfcatch>
  <cffinally>
    <cfoutput>Finally execute</cfoutput>
  </cffinally>
</cftry>

<!--- Test 4 : cfthrow type database --->
<cftry>
  <cfthrow message="DB error" type="database">
  <cfcatch type="database">
    <cfoutput>DB catch</cfoutput>
  </cfcatch>
</cftry>

<!--- Test 5 : cfrethrow --->
<cftry>
  <cftry>
    <cfthrow message="inner error" type="application">
    <cfcatch type="application">
      <cfrethrow>
    </cfcatch>
  </cftry>
  <cfcatch type="any">
    <cfoutput>Rethrown</cfoutput>
  </cfcatch>
</cftry>

<!--- Test 6 : cfscript try/catch --->
<cfscript>
  try {
    var z = 99;
  } catch (any e) {
    writeOutput(e.message);
  } finally {
    writeOutput("done");
  }
</cfscript>

<!--- Test 7 : cfscript throw --->
<cfscript>
  try {
    throw(message="script error", type="application");
  } catch (application e) {
    writeOutput("caught: ");
    writeOutput(cfcatch.message);
  }
</cfscript>
