<cfset color = 2>
<cfswitch expression="color">
  <cfcase value="1">
    <cfset name = 1>
  </cfcase>
  <cfcase value="2,3">
    <cfset name = 23>
  </cfcase>
  <cfdefaultcase>
    <cfset name = 0>
  </cfdefaultcase>
</cfswitch>
<cfoutput>#name#</cfoutput>
