{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur ColdFusion vers assembleur 8086
}

(* ============================================================
  CF86.PAS - Compilateur ColdFusion vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (page.cfm [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .cfm (page) ou .cfc (composant)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS CFML)
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT,
              TK_TAG_OPEN, TK_TAG_CLOSE, TK_TAG_SELFCLOSE,
              TK_TEXT (contenu texte brut entre balises)
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaines entre guillemets doubles "abc"
              ou apostrophes simples 'abc'
              Sequences d echappement : "" (double guillemet dans chaine)
            LexScanTag : scanner <cf...> et </cf...> -> TK_TAG_OPEN / TK_TAG_CLOSE
              Attributs de balise : nom="valeur" ou nom='valeur'
            LexScanText : contenu texte brut entre balises (hors <cf...>)
            LexScanExpression : detecter #expression# (interpolation dans texte)
            Commentaires : <!--- ... ---> (commentaires CFML, peuvent etre imbriques)
              // et /* ... */ dans les blocs <cfscript>
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..65535 ou -32768..32767
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Chaines : "abc" ou 'abc' -> pointeur vers donnees DATA
              Concatenation de chaines : operateur &
              Interpolation : #variable# dans les chaines -> _CFRT_CONCAT
            Booleens : true, false, yes, no -> AX=1 ou AX=0
            Dates : "01/15/2026" (avertissement, traite comme chaine)
            NULL : valeur nulle (javaCast("null","")) -> AX=0

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques   : + - * / MOD (modulo) \ (division entiere)
            Concatenation   : & (chaine & chaine -> appel _CFRT_CONCAT)
            Comparaison     : EQ NEQ LT LTE GT GTE
              Formes alternatives : == != < <= > >=
            Logiques        : AND OR NOT XOR (court-circuit)
              Formes alternatives : && || !
            Affectation     : = (dans <cfset> ou cfscript)
            Unaire          : + - (signe) NOT ! (negation logique)
            Ternaire        : (cond) ? valExpr : valExpr (cfscript uniquement)
            Operateur de portee : structName.cleName ou scope.variable
              (point comme separateur de portee)
            Precedence (du plus fort au plus faible) :
              1. NOT, unaire +/-
              2. * / MOD \
              3. + - &
              4. EQ NEQ LT LTE GT GTE CONTAINS
              5. AND
              6. OR XOR
              7. ? : (ternaire)

  TODO 05 - TABLE DES SYMBOLES
            TSymKind : SK_VAR, SK_PARAM, SK_FUNCTION, SK_COMPONENT,
              SK_ARGUMENT, SK_LOCAL, SK_CFPROPERTY
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsLocal, IsArgument, IsOutput
            SymAdd, SymFind, SymFindInScope, SymMangle
            Portees ColdFusion (scopes) :
              variables  : portee par defaut (page)
              local      : portee locale a la fonction (var ou local.x)
              arguments  : parametres de fonction
              form       : donnees de formulaire (stub, pas de HTTP)
              url        : parametres URL (stub, pas de HTTP)
              cgi        : variables CGI (stub, pas de HTTP)
              application / session / request : stubs + avertissement
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees

  TODO 06 - SYSTEME DE TYPES
            TTypeKind : TKC_NUMERIC (entier 16 bits signe), TKC_STRING (ptr),
              TKC_BOOLEAN (0/1 dans AX), TKC_ARRAY (ptr bloc DATA),
              TKC_STRUCT (ptr table cle/valeur), TKC_QUERY (stub ptr),
              TKC_NULL, TKC_ANY (type dynamique par defaut)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : numeric=2o, ptr=2o (string/array/struct/query)
            Typage dynamique : ColdFusion est faiblement type
              Coercition automatique string <-> numeric selon contexte
              IsNumeric(val) pour determiner le type a l execution
            JavaCast : javaCast("int", val) -> conversion explicite (stub)

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _CFL_NNNNN)
            Prefixes : _CFV_ (variable), _CFF_ (fonction), _CFK_ (chaine const),
              _CFRT_ (runtime), _CFL_ (label), _CFT_ (type),
              _CFC_ (composant), _CFP_ (propriete)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_STRUCT),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddStruct : variantes d ajout
            Variables de page (scope variables) : entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _CFK_N
            Tables de structures : paires cle/valeur dans DATA
            Contenu texte brut (hors balises) : DB dans DATA pour affichage

  TODO 09 - VARIABLES ET AFFECTATIONS
            <cfset nomVariable = expression>
              Variables non declarees : creation implicite dans scope variables
              Scope explicite : <cfset local.x = 5> ou <cfset variables.x = 5>
            Variables globales : segment DATA, acces par label _CFV_nom
            Variables locales (dans cffunction) : pile BP, acces [BP-offset]
            Mot-cle var : var nomVar = expr (declaration locale en cfscript)
            Affectation := ExprLoad + MOV destination, AX
            Affectation de struct : copie par reference (pointeur)
            Affectation de array : copie par reference (pointeur)

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, ident, appel de fonction
            Acces variable avec scope : scope.nom -> recherche dans la portee
            Acces cle de structure : struct.cle ou struct["cle"]
              Notation par point : monStruct.maCle -> offset dans struct
              Notation par crochet : monStruct["maCle"] -> recherche dynamique
            Acces index de tableau : monArray[i] -> offset calcule
            Interpolation : #expression# dans chaines et texte
              Evaluer l expression, convertir en chaine, concatener
            Appel de fonction : nomFonction(arg1, arg2, ...)
              Arguments nommes : nomFonction(param1="val", param2="val")
            IsDefined("variable") : verifie si variable existe -> AX=0|1
            Len(chaine) : longueur -> CALL _CFRT_STRLEN -> AX

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
            MOD : IDIV -> resultat dans DX (reste)
            Division entiere \ : IDIV -> resultat dans AX (quotient)
            Concatenation chaine : & -> CALL _CFRT_CONCAT(SI=gauche, DI=droite) -> AX
            Comparaison EQ/NEQ : CMP + JE/JNE -> AX=1|0
            Comparaison LT/LTE/GT/GTE : CMP + Jcc -> AX=1|0
            Comparaison chaine : CALL _CFRT_STRCMP -> drapeaux
            CONTAINS : CALL _CFRT_STRCONTAINS(SI=str, DI=sub) -> AX=0|1
            Logique AND : court-circuit JZ vers false-branch
            Logique OR : court-circuit JNZ vers true-branch
            Logique NOT : XOR AX,1
            Logique XOR : XOR AX, BX apres evaluation des deux operandes

  TODO 12 - ENTREES/SORTIES (CFOUTPUT / WRITEOUTPUT)
            <cfoutput>texte #expr#</cfoutput> :
              Emettre le texte brut via INT 21h AH=40h BX=1 (STDOUT)
              Evaluer chaque #expr# et afficher le resultat
            WriteOutput(expr) : affichage direct en cfscript
              -> CALL _CFRT_PRINT si chaine, _CFRT_NUMTOSTR + _CFRT_PRINT si numerique
            <cfdump var="#variable#"> : affichage de debogage (stub simplifie)
              -> Afficher type et valeur de la variable
            <cfabort> : arret immediat -> MOV AX,4C00h / INT 21h
            Fonctions de sortie internes :
              _CFRT_PRINT(SI=msg, CX=len) : INT 21h AH=40h BX=1
              _CFRT_PRINTLN : _CFRT_PRINT + CR+LF via _CF_CRLF DB 13,10,0

  TODO 13 - STRUCTURES CONDITIONNELLES (CFIF / CFSWITCH)
            <cfif condition>...</cfif>
            <cfif condition>...<cfelseif condition>...<cfelse>...</cfif>
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _CFL_ELSEIF_N, _CFL_ELSE_N, _CFL_ENDIF_N
            <cfswitch expression="expr">
              <cfcase value="val1">...</cfcase>
              <cfcase value="val2,val3">...</cfcase>
              <cfdefaultcase>...</cfdefaultcase>
            </cfswitch>
              Emission : CMP + JE pour chaque valeur, virgule -> valeurs multiples
              Labels : _CFL_CASE_N, _CFL_CDEF_N, _CFL_CSEND_N
            En cfscript : if (cond) { } else if (cond) { } else { }
            En cfscript : switch (expr) { case "val": ... break; default: ... }

  TODO 14 - BOUCLES (CFLOOP)
            <cfloop index="i" from="1" to="10" step="1">...</cfloop>
              Boucle FOR : variable i, increment automatique
              Labels : _CFL_FTEST_N, _CFL_FINCR_N, _CFL_FEND_N
            <cfloop condition="expression">...</cfloop>
              Boucle WHILE : tant que condition vraie
              Labels : _CFL_WTEST_N, _CFL_WEND_N
            <cfloop array="#monArray#" index="element">...</cfloop>
              Boucle sur tableau : parcours de chaque element
              Labels : _CFL_ATEST_N, _CFL_AEND_N
            <cfloop collection="#monStruct#" item="cle">...</cfloop>
              Boucle sur structure : parcours des cles
              Labels : _CFL_STEST_N, _CFL_SEND_N
            <cfbreak> : sortie de boucle -> JMP vers _CFL_*END_N
            <cfcontinue> : iteration suivante -> JMP vers _CFL_*INCR_N ou *TEST_N
            En cfscript : for (i=1; i<=10; i++) { }
            En cfscript : while (cond) { }
            En cfscript : do { } while (cond);
            En cfscript : for (element in collection) { }
            LoopPush / LoopPop : pile de labels pour break/continue

  TODO 15 - FONCTIONS INTEGREES DE CHAINE
            Len(str)               -> CALL _CFRT_STRLEN -> AX
            Left(str, count)       -> CALL _CFRT_LEFT -> AX=ptr
            Right(str, count)      -> CALL _CFRT_RIGHT -> AX=ptr
            Mid(str, start, count) -> CALL _CFRT_MID -> AX=ptr
            Trim(str)              -> CALL _CFRT_TRIM -> AX=ptr
            LTrim(str) / RTrim(str) -> CALL _CFRT_LTRIM / _CFRT_RTRIM
            UCase(str)             -> CALL _CFRT_UCASE -> AX=ptr
            LCase(str)             -> CALL _CFRT_LCASE -> AX=ptr
            Find(substr, str)      -> CALL _CFRT_FIND -> AX (position, 0 si absent)
            FindNoCase(sub, str)   -> CALL _CFRT_FINDNOCASE -> AX
            Replace(str, sub, rep) -> CALL _CFRT_REPLACE -> AX=ptr
            ReplaceNoCase(str, sub, rep) -> avertissement + CALL _CFRT_REPLACE
            Chr(code)              -> caractere ASCII -> AL
            Asc(str)               -> code ASCII du premier caractere -> AX
            Val(str)               -> CALL _CFRT_STRTONUM -> AX (conversion chaine->nombre)
            RepeatString(str, n)   -> CALL _CFRT_REPEAT -> AX=ptr
            Reverse(str)           -> CALL _CFRT_REVERSE -> AX=ptr
            ListLen / ListGetAt / ListAppend : fonctions de listes (delimiteur virgule)

  TODO 16 - FONCTIONS INTEGREES NUMERIQUES ET MATHEMATIQUES
            Int(n)          -> troncature -> AX
            Round(n)        -> arrondi -> AX (simplifie : meme que Int pour entiers)
            Abs(n)          -> CALL _CFRT_ABS -> AX (valeur absolue)
            Max(a, b)       -> CALL _CFRT_MAX -> AX
            Min(a, b)       -> CALL _CFRT_MIN -> AX
            Sgn(n)          -> signe -> AX (-1, 0 ou 1)
            IncrementValue(n)  -> AX = n + 1
            DecrementValue(n)  -> AX = n - 1
            NumberFormat(n, mask) -> CALL _CFRT_NUMTOSTR + formatage (simplifie)
            IsNumeric(val)  -> test si la valeur est numerique -> AX=0|1
            IsBoolean(val)  -> test si la valeur est booleenne -> AX=0|1
            IsDefined(name) -> test si la variable existe -> AX=0|1
            IsNull(val)     -> test si la valeur est null -> AX=0|1
            IsSimpleValue(val) -> test si chaine ou nombre -> AX=0|1
            RandRange(lo, hi) -> avertissement + AX=lo (pas de vrai random sur DOS)

  TODO 17 - TABLEAUX (ARRAYS)
            ArrayNew(dimension) : creation de tableau -> AX=ptr
              dimension=1 pour tableau simple (seule dimension supportee)
            ArrayAppend(arr, val) : ajout en fin -> CALL _CFRT_ARRAPPEND
            ArrayLen(arr)          -> CALL _CFRT_ARRLEN -> AX
            ArrayDeleteAt(arr, pos) : suppression -> CALL _CFRT_ARRDEL
            ArrayInsertAt(arr, pos, val) : insertion -> CALL _CFRT_ARRINS
            ArrayClear(arr)        -> reinitialiser le tableau
            ArraySort(arr, type)   -> avertissement (tri non implemente)
            ArrayToList(arr, delim) -> CALL _CFRT_ARRTOLIST -> AX=ptr chaine
            Litteraux de tableau : [1, 2, 3] -> allocation dans DATA
            Acces par index : arr[i] -> offset calcule (base 1 en ColdFusion)
              Attention : ColdFusion utilise des indices commencant a 1
            Affectation element : arr[i] = val -> MOV dans DATA a l offset
            Boucle cfloop array : voir TODO 14

  TODO 18 - STRUCTURES (STRUCTS)
            StructNew() : creation de structure vide -> AX=ptr
            StructInsert(struct, cle, val) : ajout cle/valeur
              -> CALL _CFRT_STINSERT
            StructFind(struct, cle) : recherche par cle -> AX=valeur
              -> CALL _CFRT_STFIND
            StructKeyExists(struct, cle) : test existence -> AX=0|1
            StructDelete(struct, cle) : suppression cle
            StructCount(struct)   -> nombre de cles -> AX
            StructKeyList(struct) -> liste des cles -> AX=ptr chaine
            StructClear(struct)   -> vider la structure
            Litteraux de structure : {cle1: val1, cle2: val2}
              ou {cle1 = val1, cle2 = val2}
            Acces par point : struct.cle -> offset dans table
            Acces par crochet : struct["cle"] -> recherche dynamique
            Structures imbriquees : struct.sousCle.champ
            Implementation interne : table de paires (cle, valeur)
              MAX_STRUCT_KEYS entrees, recherche lineaire par cle

  TODO 19 - FONCTIONS UTILISATEUR (CFFUNCTION)
            <cffunction name="nom" returnType="type" access="public">
              <cfargument name="param" type="type" required="yes" default="val">
              ... corps ...
              <cfreturn expression>
            </cffunction>
            En cfscript : function nom(param1, param2) { return expr; }
            Convention d appel : cdecl 16 bits, arguments empiles droite a gauche
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            Parametres : acces [BP+offset] selon position
            Variables locales : var nomVar ou local.nomVar -> [BP-offset]
            <cfreturn expr> : MOV AX, valeur + JMP vers epilogue
            Attributs access : public, private, remote, package (stub)
            Attribut returnType : string, numeric, boolean, void, any (verification)
            Arguments par defaut : default="valeur" si argument non fourni
            Arguments nommes : fonction(param1="val") -> resolution par nom

  TODO 20 - COMPOSANTS CFC (CFCOMPONENT)
            <cfcomponent displayName="NomComposant" extends="ParentComp">
              <cfproperty name="prop" type="type" default="val">
              <cffunction ...>...</cffunction>
            </cfcomponent>
            En cfscript : component extends="Parent" { property name="prop"; }
            Heritage : extends="NomParent" -> copie des methodes du parent
            Proprietes : <cfproperty> -> getter/setter automatiques
              getPropName() / setPropName(val) generes implicitement
            Portee this : acces aux proprietes et methodes du composant
              this.propriete -> acces au champ de l instance
            CreateObject("component", "NomComp") : instanciation -> AX=ptr
              ou new NomComp() en cfscript
            Methode init() : constructeur appele apres instanciation
            Appel de methode : instance.methode(args)
              -> PUSH instance (this) + CALL _CFC_NomComp_methode
            Vtable simplifiee : table DW des offsets methode dans DATA

  TODO 21 - BALISES DE SORTIE ET FORMATAGE
            <cfoutput query="nomQuery"> : boucle sur resultats (stub)
              -> parcourir les lignes du query et afficher
            <cfoutput group="colonne"> : regroupement (stub + avertissement)
            <cfsavecontent variable="nomVar">...</cfsavecontent>
              Rediriger la sortie dans une variable chaine
              -> ecrire dans un buffer temporaire au lieu de STDOUT
            <cfsilent>...</cfsilent> : supprimer toute sortie
              -> ne pas emettre de code d affichage pour le contenu
            <cfflush> : vider le tampon de sortie (stub, pas de buffer HTTP)
            <cfheader> / <cfcontent> : stubs + avertissement (contexte HTTP)
            <cflog text="message"> : ecriture dans un fichier log (stub)
            Formatage : DateFormat, TimeFormat, NumberFormat, LSCurrencyFormat
              -> stubs simplifie renvoyant la valeur brute en chaine

  TODO 22 - INCLUSION ET MODULES (CFINCLUDE / CFMODULE)
            <cfinclude template="chemin/fichier.cfm">
              Inclusion textuelle du fichier source
              LexInit sur le fichier inclus, puis retour au fichier principal
              Pile d inclusion : MAX_INCLUDE niveaux (detection de boucle)
            <cfmodule template="chemin/module.cfm" attributeCollection="#attrs#">
              Execution du module comme sous-programme
              Passage d attributs via scope attributes dans le module
            <cfinvoke component="NomComp" method="methode" returnVariable="ret">
              Appel de methode sur un composant externe
              -> CreateObject + appel de methode
            <cfimport taglib="chemin" prefix="prefixe"> : importation (stub)
            CustomTags : <cf_montag> -> recherche dans le chemin des tags (stub)
            Portee caller : acces aux variables de la page appelante (stub)

  TODO 23 - GESTION DES ERREURS (CFTRY / CFCATCH / CFTHROW)
            <cftry>
              ... corps ...
              <cfcatch type="typeErreur">
                cfcatch.message, cfcatch.detail, cfcatch.type
                ... traitement ...
              </cfcatch>
              <cffinally>
                ... toujours execute ...
              </cffinally>
            </cftry>
            <cfthrow message="msg" type="type" detail="detail">
              Lever une exception : AX = code erreur, BX = ptr message
            En cfscript : try { } catch (type e) { } finally { }
            En cfscript : throw(message="msg", type="type");
            Mecanisme sans support OS :
              _CF_HANDLER DW 0 dans DATA (ptr vers handler courant)
              TRY : sauvegarder ancien handler, installer nouveau
                MOV [_CF_HANDLER], OFFSET _CFL_CATCH_N
              CATCH : label _CFL_CATCH_N, CMP AX pour le type
              FINALLY : label _CFL_FINALLY_N, execute dans tous les cas
              Restauration : MOV [_CF_HANDLER], ancien_handler
            <cfrethrow> : relancer l exception courante vers le handler parent
            Types d exception : any, application, database, template, security

  TODO 24 - RUNTIME MINIMAL
            _CFRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _CFRT_PRINTLN : _CFRT_PRINT + CR+LF via _CF_CRLF DB 13,10,0
            _CFRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _CFRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _CFRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _CFRT_CONCAT(SI=src1, DI=src2) : concatenation chaines -> AX=ptr buf
            _CFRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _CFRT_STRCONTAINS(SI=str, DI=sub) : recherche sous-chaine -> AX=0|1
            _CFRT_LEFT(SI=str, CX=n) : n premiers caracteres -> AX=ptr
            _CFRT_RIGHT(SI=str, CX=n) : n derniers caracteres -> AX=ptr
            _CFRT_MID(SI=str, BX=start, CX=len) : sous-chaine -> AX=ptr
            _CFRT_TRIM(SI=str) : suppression espaces debut/fin -> AX=ptr
            _CFRT_UCASE(SI=str) : majuscules -> AX=ptr
            _CFRT_LCASE(SI=str) : minuscules -> AX=ptr
            _CFRT_FIND(SI=str, DI=sub) : position de sous-chaine -> AX
            _CFRT_ABS(AX=n) : valeur absolue -> AX
            _CFRT_MAX(AX=a, BX=b) : maximum -> AX
            _CFRT_MIN(AX=a, BX=b) : minimum -> AX
            _CFRT_ARRAPPEND(BX=arr, AX=val) : ajout element au tableau
            _CFRT_ARRLEN(BX=arr) : nombre d elements -> AX
            _CFRT_STINSERT(BX=struct, SI=cle, AX=val) : insertion cle/valeur
            _CFRT_STFIND(BX=struct, SI=cle) : recherche cle -> AX=valeur
            _CFRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _CF_HEAP DB 4096 DUP(0) + _CF_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _CFF_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParsePage ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _CFF_Main
            Fichiers SAMPLES\COLDFUSION\ a creer :
              hello.cfm     (cfoutput, variables, cfset, chaines)
              math.cfm      (cffunction, operations, cfreturn)
              control.cfm   (cfif/cfelseif/cfelse, cfswitch/cfcase)
              loops.cfm     (cfloop index/condition/array/collection, cfbreak)
              strings.cfm   (Len, Left, Right, Mid, Trim, UCase, Find, Replace)
              arrays.cfm    (ArrayNew, ArrayAppend, ArrayLen, cfloop array)
              structs.cfm   (StructNew, StructInsert, StructFind, notation point)
              component.cfc (cfcomponent, cfproperty, cffunction, this)
              errors.cfm    (cftry/cfcatch/cffinally, cfthrow, cfrethrow)
              include.cfm   (cfinclude, cfmodule, cfinvoke)
            Smoke tests : CF86.EXE -v SAMPLES\COLDFUSION\*.cfm

  ============================================================ *)

Program CF86;

Begin
End.
