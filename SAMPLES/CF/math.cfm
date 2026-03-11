<!--- math.cfm : Exemple fonctions et operations mathematiques --->
<!--- Demonstration de cffunction, operations, cfreturn --->

<!--- Fonction utilisateur : addition --->
<cffunction name="additionner" returnType="numeric">
  <cfargument name="a" type="numeric" required="yes">
  <cfargument name="b" type="numeric" required="yes">
  <cfreturn a + b>
</cffunction>

<!--- Fonction utilisateur : factorielle iterative --->
<cffunction name="factorielle" returnType="numeric">
  <cfargument name="n" type="numeric" required="yes">
  <cfset resultat = 1>
  <cfloop index="i" from="1" to="#n#" step="1">
    <cfset resultat = resultat * i>
  </cfloop>
  <cfreturn resultat>
</cffunction>

<!--- Appels et affichage --->
<cfset s = additionner(10, 32)>
<cfoutput>10 + 32 = #s#</cfoutput>

<cfset f = factorielle(5)>
<cfoutput>5! = #f#</cfoutput>

<!--- Fonctions mathematiques internes --->
<cfset va = Abs(-42)>
<cfoutput>Abs(-42) = #va#</cfoutput>

<cfset vmx = Max(15, 27)>
<cfoutput>Max(15,27) = #vmx#</cfoutput>

<cfset vmn = Min(15, 27)>
<cfoutput>Min(15,27) = #vmn#</cfoutput>

<cfset vi = IncrementValue(9)>
<cfoutput>IncrementValue(9) = #vi#</cfoutput>

<cfset vd = DecrementValue(11)>
<cfoutput>DecrementValue(11) = #vd#</cfoutput>

<cfset vs = Sgn(-3)>
<cfoutput>Sgn(-3) = #vs#</cfoutput>
