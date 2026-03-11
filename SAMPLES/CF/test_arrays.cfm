<cfset arr = ArrayNew(1)>
<cfset ArrayAppend(arr, 10)>
<cfset ArrayAppend(arr, 20)>
<cfset ArrayAppend(arr, 30)>
<cfset n = ArrayLen(arr)>
<cfoutput>#n#</cfoutput>
<cfset v = arr[2]>
<cfoutput>#v#</cfoutput>
<cfset arr2 = [100, 200, 300]>
<cfset n2 = ArrayLen(arr2)>
<cfoutput>#n2#</cfoutput>
<cfset ArrayDeleteAt(arr, 2)>
<cfset n3 = ArrayLen(arr)>
<cfoutput>#n3#</cfoutput>
<cfset ArrayInsertAt(arr, 1, 5)>
<cfset n4 = ArrayLen(arr)>
<cfoutput>#n4#</cfoutput>
<cfset lst = ArrayToList(arr2)>
<cfoutput>#lst#</cfoutput>
<cfset ArrayClear(arr)>
<cfset n5 = ArrayLen(arr)>
<cfoutput>#n5#</cfoutput>
