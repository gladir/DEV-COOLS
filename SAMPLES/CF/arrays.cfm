<!--- arrays.cfm : Exemple tableaux ColdFusion --->
<!--- Demonstration de ArrayNew, ArrayAppend, ArrayLen, cfloop array --->

<!--- Creation et ajout d elements --->
<cfset fruits = ArrayNew(1)>
<cfset ArrayAppend(fruits, 10)>
<cfset ArrayAppend(fruits, 20)>
<cfset ArrayAppend(fruits, 30)>

<!--- Nombre d elements --->
<cfset n = ArrayLen(fruits)>
<cfoutput>Taille: #n#</cfoutput>

<!--- Acces par index --->
<cfset premier = fruits[1]>
<cfoutput>Premier: #premier#</cfoutput>

<!--- Boucle sur le tableau --->
<cfset somme = 0>
<cfloop array="#fruits#" index="val">
  <cfset somme = somme + val>
</cfloop>
<cfoutput>Somme: #somme#</cfoutput>

<!--- Litteral tableau --->
<cfset nombres = [100, 200, 300]>
<cfset n2 = ArrayLen(nombres)>
<cfoutput>Litteral taille: #n2#</cfoutput>

<!--- Suppression d element --->
<cfset ArrayDeleteAt(fruits, 2)>
<cfset n3 = ArrayLen(fruits)>
<cfoutput>Apres suppression: #n3#</cfoutput>

<!--- Insertion d element --->
<cfset ArrayInsertAt(fruits, 1, 5)>
<cfset n4 = ArrayLen(fruits)>
<cfoutput>Apres insertion: #n4#</cfoutput>

<!--- Conversion tableau vers liste --->
<cfset lst = ArrayToList(nombres)>
<cfoutput>Liste: #lst#</cfoutput>

<!--- Vidage du tableau --->
<cfset ArrayClear(fruits)>
<cfset n5 = ArrayLen(fruits)>
<cfoutput>Apres clear: #n5#</cfoutput>
