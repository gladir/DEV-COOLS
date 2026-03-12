<!--- include.cfm : Exemple inclusion et modules ColdFusion --->
<!--- Demonstration de cfinclude, cfmodule, cfinvoke --->

<!--- Variable avant inclusion --->
<cfset greeting = "Bonjour">
<cfoutput>#greeting#</cfoutput>

<!--- Inclusion d un fichier externe --->
<cfinclude template="include_helper.cfm">
<cfoutput>#helper_msg#</cfoutput>

<!--- cfinvoke pour appeler une methode de composant --->
<cfinvoke component="Compteur" method="incrementer" returnVariable="result">
<cfoutput>Resultat invoke: #result#</cfoutput>

<!--- cfimport pour importer une bibliotheque de tags --->
<cfimport taglib="/tags" prefix="ui">

<cfoutput>Include OK</cfoutput>
