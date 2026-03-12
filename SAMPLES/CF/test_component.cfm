<!--- test_component.cfm : Test des composants CFC (TODO 20) --->

<!--- Composant simple avec proprietes et methodes --->
<cfcomponent displayName="Animal">
  <cfproperty name="nom" type="string" default="inconnu">
  <cfproperty name="pattes" type="numeric" default="4">

  <cffunction name="crier" returnType="string">
    <cfreturn "Grr!">
  </cffunction>

  <cffunction name="description" returnType="string">
    <cfreturn "Animal">
  </cffunction>
</cfcomponent>

<!--- Instanciation avec CreateObject --->
<cfset chat = CreateObject("component", "Animal")>
<cfoutput>Chat cree</cfoutput>

<!--- Composant enfant avec heritage --->
<cfcomponent displayName="Chien" extends="Animal">
  <cfproperty name="race" type="string" default="berger">

  <cffunction name="crier" returnType="string">
    <cfreturn "Wouf!">
  </cffunction>
</cfcomponent>

<!--- Instanciation avec new --->
<cfset rex = new Chien()>
<cfoutput>Rex cree</cfoutput>

<!--- Appel de methode --->
<cfset son = crier()>
<cfoutput>Son: #son#</cfoutput>

<!--- Fin du test --->
<cfoutput>Test composant OK</cfoutput>
