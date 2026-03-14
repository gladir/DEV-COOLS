<!--- component.cfc : Exemple composant ColdFusion --->
<!--- Demonstration de cfcomponent, cfproperty, cffunction, this --->

<!--- Composant simple --->
<cfcomponent displayName="Compteur">
  <cfproperty name="valeur" type="numeric" default="0">

  <cffunction name="incrementer" returnType="numeric">
    <cfset valeur = valeur + 1>
    <cfreturn valeur>
  </cffunction>

  <cffunction name="getValeur" returnType="numeric">
    <cfreturn valeur>
  </cffunction>
</cfcomponent>

<!--- Composant avec heritage --->
<cfcomponent displayName="CompteurDouble" extends="Compteur">
  <cffunction name="incrementer" returnType="numeric">
    <cfset valeur = valeur + 2>
    <cfreturn valeur>
  </cffunction>
</cfcomponent>

<!--- Instanciation --->
<cfset cpt = CreateObject("component", "Compteur")>
<cfset r1 = incrementer()>
<cfoutput>Apres increment: #r1#</cfoutput>

<cfset r2 = incrementer()>
<cfoutput>Apres 2e increment: #r2#</cfoutput>

<cfset v = getValeur()>
<cfoutput>Valeur courante: #v#</cfoutput>

<cfoutput>Composant OK</cfoutput>
