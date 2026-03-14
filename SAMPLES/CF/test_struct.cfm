<!--- test_struct.cfm : Test des structures ColdFusion (TODO 18) --->

<!--- Creation d une structure vide --->
<cfset myStruct = StructNew()>

<!--- Insertion de paires cle/valeur --->
<cfset StructInsert(myStruct, "nom", "Alice")>
<cfset StructInsert(myStruct, "age", 30)>
<cfset StructInsert(myStruct, "ville", "Quebec")>

<!--- Afficher le nombre de cles --->
<cfoutput>Nombre de cles: #StructCount(myStruct)#</cfoutput>

<!--- Rechercher une cle --->
<cfoutput>Nom: #StructFind(myStruct, "nom")#</cfoutput>

<!--- Tester l existence d une cle --->
<cfif StructKeyExists(myStruct, "age")>
  <cfoutput>Age existe: #StructFind(myStruct, "age")#</cfoutput>
</cfif>

<!--- Liste des cles --->
<cfoutput>Cles: #StructKeyList(myStruct)#</cfoutput>

<!--- Supprimer une cle --->
<cfset StructDelete(myStruct, "ville")>
<cfoutput>Apres suppression: #StructCount(myStruct)#</cfoutput>

<!--- Vider la structure --->
<cfset StructClear(myStruct)>
<cfoutput>Apres clear: #StructCount(myStruct)#</cfoutput>
