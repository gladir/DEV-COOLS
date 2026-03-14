<!--- hello.cfm : Exemple ColdFusion de base --->
<!--- Demonstration de cfset, cfoutput, variables et chaines --->

<!--- Variables simples --->
<cfset greeting = "Hello World">
<cfset nom = "ColdFusion">
<cfset version = 86>

<!--- Affichage avec cfoutput et expressions hash --->
<cfoutput>#greeting#</cfoutput>
<cfoutput>Bienvenue dans #nom# #version#</cfoutput>

<!--- Concatenation de chaines --->
<cfset msg = "Bonjour" & " " & "le monde">
<cfoutput>#msg#</cfoutput>

<!--- Variables numeriques et calcul --->
<cfset a = 10>
<cfset b = 32>
<cfset somme = a + b>
<cfoutput>Somme: #somme#</cfoutput>

<!--- Chaine vide et reassignation --->
<cfset resultat = "">
<cfset resultat = "OK">
<cfoutput>Resultat: #resultat#</cfoutput>
