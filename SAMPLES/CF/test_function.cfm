<!--- test_function.cfm : Test des fonctions utilisateur (TODO 19) --->

<!--- Fonction simple avec cffunction --->
<cffunction name="double" returnType="numeric">
  <cfargument name="n" type="numeric" required="yes">
  <cfreturn n * 2>
</cffunction>

<!--- Appel de la fonction --->
<cfset result = double(21)>
<cfoutput>Double de 21: #result#</cfoutput>

<!--- Fonction avec deux parametres --->
<cffunction name="addNums" returnType="numeric">
  <cfargument name="a" type="numeric" required="yes">
  <cfargument name="b" type="numeric" required="yes">
  <cfreturn a + b>
</cffunction>

<cfset sum = addNums(10, 32)>
<cfoutput>Somme: #sum#</cfoutput>

<!--- Fonction sans retour explicite --->
<cffunction name="greet" returnType="void">
  <cfargument name="name" type="string" required="yes">
  <cfoutput>Bonjour #name#!</cfoutput>
</cffunction>

<cfset greet("Monde")>

<!--- Fonction avec variable locale --->
<cffunction name="square" returnType="numeric">
  <cfargument name="x" type="numeric" required="yes">
  <cfset temp = x * x>
  <cfreturn temp>
</cffunction>

<cfset sq = square(7)>
<cfoutput>Carre de 7: #sq#</cfoutput>

<!--- Fonction appelant une autre fonction --->
<cffunction name="doubleAdd" returnType="numeric">
  <cfargument name="a" type="numeric" required="yes">
  <cfargument name="b" type="numeric" required="yes">
  <cfreturn double(a) + double(b)>
</cffunction>

<cfset da = doubleAdd(3, 4)>
<cfoutput>doubleAdd: #da#</cfoutput>
