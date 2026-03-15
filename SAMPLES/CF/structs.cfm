<!--- structs.cfm : Exemple structures ColdFusion --->
<!--- Demonstration de StructNew, StructInsert, StructFind, notation point --->

<!--- Creation d une structure vide --->
<cfset personne = StructNew()>

<!--- Insertion de paires cle/valeur --->
<cfset StructInsert(personne, "nom", "Alice")>
<cfset StructInsert(personne, "age", 30)>
<cfset StructInsert(personne, "ville", "Montreal")>

<!--- Nombre de cles --->
<cfoutput>Cles: #StructCount(personne)#</cfoutput>

<!--- Recherche de valeur par cle --->
<cfoutput>Nom: #StructFind(personne, "nom")#</cfoutput>
<cfoutput>Age: #StructFind(personne, "age")#</cfoutput>

<!--- Test d existence d une cle --->
<cfif StructKeyExists(personne, "ville")>
  <cfoutput>Ville: #StructFind(personne, "ville")#</cfoutput>
</cfif>

<!--- Liste des cles --->
<cfoutput>Cles: #StructKeyList(personne)#</cfoutput>

<!--- Suppression d une cle --->
<cfset StructDelete(personne, "ville")>
<cfoutput>Apres suppression: #StructCount(personne)#</cfoutput>

<!--- Vidage de la structure --->
<cfset StructClear(personne)>
<cfoutput>Apres clear: #StructCount(personne)#</cfoutput>
