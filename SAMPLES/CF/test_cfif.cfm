<cfset x = 10>
<cfif x GT 5>
  <cfset result = 1>
</cfif>
<cfset y = 3>
<cfif y EQ 1>
  <cfset result = 10>
<cfelseif y EQ 3>
  <cfset result = 30>
<cfelse>
  <cfset result = 0>
</cfif>
<cfoutput>#result#</cfoutput>
