<!--- strings.cfm : Exemple fonctions de chaines --->
<!--- Demonstration de Len, Left, Right, Mid, Trim, UCase, Find, Replace --->

<cfset texte = "Hello World">

<!--- Len : longueur --->
<cfset n = Len(texte)>
<cfoutput>Len: #n#</cfoutput>

<!--- Left : caracteres a gauche --->
<cfset g = Left(texte, 5)>
<cfoutput>Left: #g#</cfoutput>

<!--- Right : caracteres a droite --->
<cfset d = Right(texte, 5)>
<cfoutput>Right: #d#</cfoutput>

<!--- Mid : sous-chaine --->
<cfset m = Mid(texte, 7, 5)>
<cfoutput>Mid: #m#</cfoutput>

<!--- Trim : suppression espaces --->
<cfset t = Trim("  salut  ")>
<cfoutput>Trim: #t#</cfoutput>

<!--- UCase : majuscules --->
<cfset u = UCase(texte)>
<cfoutput>UCase: #u#</cfoutput>

<!--- LCase : minuscules --->
<cfset l = LCase(texte)>
<cfoutput>LCase: #l#</cfoutput>

<!--- Find : position de sous-chaine --->
<cfset pos = Find("World", texte)>
<cfoutput>Find: #pos#</cfoutput>

<!--- Replace : remplacement --->
<cfset r = Replace(texte, "World", "CF86")>
<cfoutput>Replace: #r#</cfoutput>

<!--- Chr et Asc --->
<cfset c = Chr(65)>
<cfoutput>Chr(65): #c#</cfoutput>

<cfset a = Asc("A")>
<cfoutput>Asc(A): #a#</cfoutput>

<!--- Val : conversion chaine->nombre --->
<cfset v = Val("42")>
<cfoutput>Val: #v#</cfoutput>
