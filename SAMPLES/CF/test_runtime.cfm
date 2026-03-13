<cfset a = "Hello">
<cfset b = " World">
<cfset c = a & b>
<cfoutput>#c#</cfoutput>
<cfset n = Len(c)>
<cfoutput>#n#</cfoutput>
<cfset x = Abs(-42)>
<cfoutput>#x#</cfoutput>
<cfset mx = Max(10, 20)>
<cfoutput>#mx#</cfoutput>
<cfset mn = Min(10, 20)>
<cfoutput>#mn#</cfoutput>
<cfset v = Val("123")>
<cfoutput>#v#</cfoutput>
<cfset u = UCase("hello")>
<cfoutput>#u#</cfoutput>
<cfset l = LCase("HELLO")>
<cfoutput>#l#</cfoutput>
<cfset t = Trim("  hi  ")>
<cfoutput>#t#</cfoutput>
