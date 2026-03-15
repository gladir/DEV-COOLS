<cfset greeting = "Hello World">
<cfset n = Len(greeting)>
<cfoutput>#n#</cfoutput>
<cfset l = Left(greeting, 5)>
<cfoutput>#l#</cfoutput>
<cfset r = Right(greeting, 5)>
<cfoutput>#r#</cfoutput>
<cfset m = Mid(greeting, 7, 5)>
<cfoutput>#m#</cfoutput>
<cfset t = Trim("  hello  ")>
<cfoutput>#t#</cfoutput>
<cfset u = UCase(greeting)>
<cfoutput>#u#</cfoutput>
<cfset lc = LCase(greeting)>
<cfoutput>#lc#</cfoutput>
<cfset pos = Find("World", greeting)>
<cfoutput>#pos#</cfoutput>
<cfset c = Chr(65)>
<cfoutput>#c#</cfoutput>
<cfset a = Asc("A")>
<cfoutput>#a#</cfoutput>
<cfset v = Val("42")>
<cfoutput>#v#</cfoutput>
<cfset rep = RepeatString("ab", 3)>
<cfoutput>#rep#</cfoutput>
<cfset rev = Reverse("Hello")>
<cfoutput>#rev#</cfoutput>
