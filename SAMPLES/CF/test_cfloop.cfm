<cfset total = 0>
<cfloop index="i" from="1" to="5" step="1">
  <cfset total = total + i>
</cfloop>
<cfoutput>#total#</cfoutput>
<cfset countdown = 0>
<cfloop index="j" from="10" to="1" step="-1">
  <cfset countdown = countdown + 1>
</cfloop>
<cfset sum = 0>
<cfloop index="k" from="1" to="10" step="2">
  <cfset sum = sum + k>
</cfloop>
<cfoutput>#sum#</cfoutput>
