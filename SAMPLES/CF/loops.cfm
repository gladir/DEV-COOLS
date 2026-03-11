<!--- loops.cfm : Exemple boucles ColdFusion --->
<!--- Demonstration de cfloop index/condition/array/collection, cfbreak --->

<!--- cfloop index : compteur simple --->
<cfset total = 0>
<cfloop index="i" from="1" to="10" step="1">
  <cfset total = total + i>
</cfloop>
<cfoutput>Somme 1..10 = #total#</cfoutput>

<!--- cfloop index : pas negatif --->
<cfset compte = 0>
<cfloop index="j" from="5" to="1" step="-1">
  <cfset compte = compte + 1>
</cfloop>
<cfoutput>Decompte: #compte#</cfoutput>

<!--- cfloop index : pas de 2 --->
<cfset impairs = 0>
<cfloop index="k" from="1" to="9" step="2">
  <cfset impairs = impairs + k>
</cfloop>
<cfoutput>Somme impairs: #impairs#</cfoutput>

<!--- cfloop avec cfbreak --->
<cfset trouve = 0>
<cfloop index="m" from="1" to="100" step="1">
  <cfif m EQ 7>
    <cfset trouve = m>
    <cfbreak>
  </cfif>
</cfloop>
<cfoutput>Trouve: #trouve#</cfoutput>
