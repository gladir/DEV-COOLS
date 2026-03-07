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

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (page.cfm [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .cfm (page) ou .cfc (composant)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS CFML) [IMPLEMENTE]
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

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
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

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  CF86_VERSION = '1.0';
  CF86_DATE    = '2026-03-06';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_INCLUDE   = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  STACK_SIZE    = 1024;

  { Prefixes de nommage ASM }
  CF_VAR_PFX  = '_CFV_';    { variable scalaire                   }
  CF_FN_PFX   = '_CFF_';    { fonction / methode                  }
  CF_STR_PFX  = '_CFK_';    { constante chaine litterale          }
  CF_RT_PFX   = '_CFRT_';   { routine runtime                     }
  CF_LBL_PFX  = '_CFL_';    { label de saut interne               }
  CF_CMP_PFX  = '_CFC_';    { composant CFC                       }
  CF_PROP_PFX = '_CFP_';    { propriete de composant              }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs ColdFusion }
  TY_IDX_NUMERIC  = 0;  { entier 16 bits signe  }
  TY_IDX_STRING   = 1;  { pointeur chaine DATA  }
  TY_IDX_BOOLEAN  = 2;  { 0 ou 1 dans AX        }
  TY_IDX_ARRAY    = 3;  { pointeur bloc DATA     }
  TY_IDX_STRUCT   = 4;  { pointeur struct DATA   }
  TY_IDX_QUERY    = 5;  { pointeur stub query    }
  TY_IDX_NULL     = 6;  { AX=0                   }
  TY_IDX_ANY      = 7;  { type dynamique         }
  TY_PRIM_COUNT   = 8;
  TY_UNKNOWN      = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { page source (.cfm / .cfc)            }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
    IsComponent : Boolean; { True si .cfc, False si .cfm          }
  End;

  { ---- Tokens CFML (TODO 02) ----------------------------- }
  TTokenKind = (
    TK_EOF,        { fin de fichier                          }
    TK_INTEGER,    { literal entier 42                       }
    TK_FLOAT,      { literal flottant 3.14                   }
    TK_STRING,     { literal chaine "abc" ou 'abc'           }
    TK_IDENT,      { identificateur (non-mot-cle)            }
    TK_KEYWORD,    { mot-cle CF reconnu (EQ, AND, OR...)     }
    TK_OP,         { operateur + - * / etc.                  }
    TK_PUNCT,      { ponctuation ; , ( ) [ ]                 }
    TK_TAG_OPEN,   { <cfset, <cfif, <cfoutput...             }
    TK_TAG_CLOSE,  { </cfset>, </cfif>, </cfoutput>...       }
    TK_TAG_SELFCLOSE, { <cfset .../> auto-fermant             }
    TK_TEXT        { contenu texte brut entre balises         }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Categories de symboles (TODO 05) ------------------ }
  TSymCat = (
    SC_VAR,        { variable scope variables (defaut)  }
    SC_LOCAL,      { variable locale (var / local.x)    }
    SC_PARAM,      { parametre de fonction (cfargument) }
    SC_FUNCTION,   { declaration cffunction             }
    SC_COMPONENT,  { declaration cfcomponent            }
    SC_CFPROPERTY  { propriete cfproperty               }
  );

  TSymRec = Record
    Name        : TString;   { identifiant CF                  }
    MangledName : TString;   { _CFV_nom / _CFF_nom             }
    Cat         : TSymCat;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux              }
    IsLocal     : Boolean;   { variable locale dans cffunction }
    IsArgument  : Boolean;   { parametre cfargument            }
    IsOutput    : Boolean;   { argument output=yes             }
    DeclLine    : Integer;
  End;

  { ---- Types internes (TODO 06) -------------------------- }
  TTypeKind = (
    TKC_NUMERIC,
    TKC_STRING,
    TKC_BOOLEAN,
    TKC_ARRAY,
    TKC_STRUCT,
    TKC_QUERY,
    TKC_NULL,
    TKC_ANY
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { octets : numeric=2, ptr=2 }
  End;

  { ---- Valeurs d expression (TODO 11) -------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur            }
    EK_IMM,    { immediate dans ImmVal           }
    EK_AX,     { valeur dans AX                  }
    EK_MEM     { adresse [BP+Offset] ou [_CFV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 = pas de lvalue) }
  End;

  { ---- Segment de donnees (TODO 08) ---------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_STRUCT_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Lexeur (TODO 02) }
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;
  InCfScript : Boolean;   { True dans un bloc <cfscript> }
  InTag      : Boolean;   { True dans les attributs d une balise CF }
  InHashExpr : Boolean;   { True dans une interpolation #expr# }

  { Table des symboles (TODO 05) }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  { Table des types (TODO 06) }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur ASM (TODO 07) }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;
  CurFnDepth   : Integer;    { 0 = global, >0 = dans une cffunction }
  CurFnRetLbl  : TString;
  CurFnName    : TString;
  CurCompName  : TString;    { nom du composant courant (TODO 20) }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;

  { Segment de donnees (TODO 08) }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;
  InSilentMode   : Boolean;  { True dans <cfsilent> }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ TODO 01 }
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitRuntime;   Forward;
Procedure EmitHeader;    Forward;
Procedure EmitOpen;      Forward;
Procedure ParsePage;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;
{ TODO 02 }
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsCFKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString(Quote : Char); Forward;
Procedure LexScanTag;          Forward;
Procedure LexScanText;         Forward;
Procedure LexSkipCFComment;    Forward;
Procedure LexSkipLineComment;  Forward;
Procedure LexSkipBlockComment; Forward;
Procedure LexNextToken;        Forward;
Procedure ParserAdvance;       Forward;
{ TODO 03 }
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : Integer; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Utilitaires chaines ------------------------------------ }

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V : LongInt;
  C : Integer;
Begin
  Val(S, V, C);
  If C = 0 Then StrToIntDef := V
  Else          StrToIntDef := Def;
End;

{ Extrait le nom de base d un chemin (sans extension) }
Function BaseName(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
  S : TString;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If LastDot > LastSep Then
    S := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    S := Copy(Path, LastSep + 1, Length(Path));
  BaseName := S;
End;

{ Remplace l extension d un chemin }
Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

{ Extrait l extension d un chemin en minuscules }
Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := StrLowerCase(Copy(Path, LastDot, Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('CF86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('CF86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('CF86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('CF86 v', CF86_VERSION, ' (', CF86_DATE, ')');
  WriteLn('Compilateur ColdFusion -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: CF86 <source.cfm|.cfc> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.cfm : page ColdFusion source');
  WriteLn('  source.cfc : composant ColdFusion source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h         : afficher cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
End;

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SrcFile     := '';
  Opts.OutFile     := '';
  Opts.Verbose     := False;
  Opts.DebugMode   := False;
  Opts.Warnings    := False;
  Opts.IsComponent := False;
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowUsage
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('CF86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('CF86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('CF86: fichier source manquant');
    ShowUsage;
  End;

  { Detecter l extension .cfm (page) ou .cfc (composant) }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext = '.cfc' Then
    Opts.IsComponent := True
  Else If (Ext <> '.cfm') And (Ext <> '.cfc') Then
  Begin
    WriteLn('CF86: avertissement: extension non reconnue: ', Ext);
    WriteLn('  extensions attendues: .cfm (page) ou .cfc (composant)');
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage -------------------------------------------- }

Procedure Cleanup;
Begin
  If LexOpened Then
    LexClose;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale des variables globales -------- }

Procedure GlobalInit;
Begin
  ErrorCount     := 0;
  WarnCount      := 0;
  TotalLines     := 0;
  TotalSyms      := 0;
  SymCount       := 0;
  ScopeTop       := 0;
  CurScope       := 0;
  LabelSeq       := 0;
  TypeCount      := 0;
  DataCount      := 0;
  OutFOpen       := False;
  LexOpened      := False;
  LexEOF         := False;
  InCfScript     := False;
  InTag          := False;
  InHashExpr     := False;
  CurFnDepth     := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  CurCompName    := '';
  LoopTop        := 0;
  RuntimeEmitted := False;
  InSilentMode   := False;
  CurFrameSize   := 0;
  LabelGenSeq    := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS CFML) [IMPLEMENTE]
  ============================================================ }

{ ---- Test de caracteres ------------------------------------- }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

{ ---- IsCFKeyword : teste si S est un mot-cle CFML ---------- }
(* S doit etre en minuscules ou en casse quelconque             *)
Function IsCFKeyword(Const S : TString) : Boolean;
Var
  U : TString;
Begin
  U := StrUpperCase(S);
  IsCFKeyword :=
    (U = 'EQ')       Or (U = 'NEQ')      Or (U = 'LT')       Or
    (U = 'LTE')      Or (U = 'GT')       Or (U = 'GTE')      Or
    (U = 'AND')      Or (U = 'OR')       Or (U = 'NOT')      Or
    (U = 'XOR')      Or (U = 'MOD')      Or (U = 'CONTAINS') Or
    (U = 'IS')       Or (U = 'TRUE')     Or (U = 'FALSE')    Or
    (U = 'YES')      Or (U = 'NO')       Or (U = 'NULL')     Or
    (U = 'VAR')      Or (U = 'IF')       Or (U = 'ELSE')     Or
    (U = 'WHILE')    Or (U = 'DO')       Or (U = 'FOR')      Or
    (U = 'IN')       Or (U = 'BREAK')    Or (U = 'CONTINUE') Or
    (U = 'SWITCH')   Or (U = 'CASE')     Or (U = 'DEFAULT')  Or
    (U = 'FUNCTION') Or (U = 'RETURN')   Or (U = 'NEW')      Or
    (U = 'TRY')      Or (U = 'CATCH')    Or (U = 'FINALLY')  Or
    (U = 'THROW')    Or (U = 'COMPONENT') Or (U = 'PROPERTY') Or
    (U = 'THIS')     Or (U = 'IMPORT');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Var
  NS : TString;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF          : Write('EOF');
    TK_INTEGER      : Begin Str(T.IntVal, NS); Write('INT(', NS, ')'); End;
    TK_FLOAT        : Write('FLOAT(', T.Val, ')');
    TK_STRING       : Write('STR("', T.Val, '")');
    TK_IDENT        : Write('IDENT(', T.Val, ')');
    TK_KEYWORD      : Write('KW(', T.Val, ')');
    TK_OP           : Write('OP(', T.Val, ')');
    TK_PUNCT        : Write('PUNCT(', T.Val, ')');
    TK_TAG_OPEN     : Write('TAG_OPEN(<', T.Val, '>)');
    TK_TAG_CLOSE    : Write('TAG_CLOSE(</', T.Val, '>)');
    TK_TAG_SELFCLOSE: Write('TAG_SELFCLOSE');
    TK_TEXT         : Write('TEXT("', T.Val, '")');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ----------- }
Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- LexInit : ouvrir le fichier source et initialiser ----- }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  InTag      := False;
  InCfScript := False;
  InHashExpr := False;
  LexNextLine;
End;

{ ---- LexClose : fermer le fichier source ------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- LexScanIdent : scanner un identifiant ou mot-cle ------ }
(* ColdFusion est insensible a la casse : on met en minuscules *)
Procedure LexScanIdent;
Var
  S, Lo : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  Lo := StrLowerCase(S);
  CurToken.IntVal := 0;
  CurToken.Val    := Lo;
  If IsCFKeyword(Lo) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsFloat : Boolean;
  FracDiv : Real;
  FracVal : Real;
  FltVal  : Real;
Begin
  N       := 0;
  IsFloat := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  { Partie entiere }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;
  { Partie decimale .ddd }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    CurToken.Kind     := TK_FLOAT;
    CurToken.FloatVal := FltVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
  End
  Else
    CurToken.Kind := TK_INTEGER;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
End;

{ ---- LexScanString : scanner une chaine ColdFusion --------- }
(*  Quote = '"' ou Quote = chr(39) (apostrophe)                 *)
(*  Echappement : doubler le delimiteur ("" dans "..." )        *)
Procedure LexScanString(Quote : Char);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo);  { sauter le delimiteur ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = Quote Then
    Begin
      { Delimiteur double = echappement }
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = Quote) Then
      Begin
        If Length(S) < MAX_STR Then S := S + Quote;
        Inc(LexColNo); Inc(LexColNo);
      End
      Else
      Begin
        Inc(LexColNo);  { fermer la chaine }
        Break;
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexSkipCFComment : sauter <!--- ... ---> -------------- }
(*  Les commentaires CFML peuvent etre imbriques                *)
Procedure LexSkipCFComment;
Var
  Depth : Integer;
Begin
  Inc(LexColNo, 5);  { sauter <!--- }
  Depth := 1;
  While (Not LexEOF) And (Depth > 0) Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexColNo + 4 <= Length(LexLine)) And
            (LexLine[LexColNo] = '<') And (LexLine[LexColNo+1] = '!') And
            (LexLine[LexColNo+2] = '-') And (LexLine[LexColNo+3] = '-') And
            (LexLine[LexColNo+4] = '-') Then
    Begin
      Inc(Depth);
      Inc(LexColNo, 5);
    End
    Else If (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo] = '-') And (LexLine[LexColNo+1] = '-') And
            (LexLine[LexColNo+2] = '>') Then
    Begin
      Dec(Depth);
      Inc(LexColNo, 3);
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipLineComment : sauter // jusqu a fin de ligne ---- }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ---- LexSkipBlockComment : sauter /* ... */ (cfscript) ------ }
Procedure LexSkipBlockComment;
Var
  Done : Boolean;
Begin
  Inc(LexColNo); Inc(LexColNo);  { sauter /* }
  Done := False;
  While (Not LexEOF) And (Not Done) Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Done := True;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexScanTag : scanner <cf...> ou </cf...> -------------- }
(*  Produit TK_TAG_OPEN ou TK_TAG_CLOSE                        *)
Procedure LexScanTag;
Var
  S       : TString;
  IsClose : Boolean;
Begin
  S := '';
  IsClose := False;
  Inc(LexColNo);  { sauter '<' }
  { Detecter la forme fermante </cf... }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '/') Then
  Begin
    IsClose := True;
    Inc(LexColNo);
  End;
  { Lire le nom de la balise : cf... }
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := StrLowerCase(S);
  CurToken.IntVal := 0;
  If IsClose Then
  Begin
    CurToken.Kind := TK_TAG_CLOSE;
    { Pour les balises fermantes, consommer jusqu au > }
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] <> '>') Do
      Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Inc(LexColNo);
    { Detecter </cfscript> pour sortir du mode cfscript }
    If CurToken.Val = 'cfscript' Then
      InCfScript := False;
  End
  Else
  Begin
    CurToken.Kind := TK_TAG_OPEN;
    InTag := True;
    { Detecter <cfscript> pour entrer en mode cfscript }
    If CurToken.Val = 'cfscript' Then
    Begin
      { Consommer le reste de la balise jusqu au > }
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] <> '>') Do
        Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
        Inc(LexColNo);
      InTag := False;
      InCfScript := True;
    End;
  End;
End;

{ ---- LexScanText : scanner du texte brut entre balises ------ }
(*  S arrete devant <cf, </cf, <!--- ou #expr#                  *)
Procedure LexScanText;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  While Not LexEOF Do
  Begin
    { Fin de ligne -> ajouter CR+LF et continuer }
    If LexColNo > Length(LexLine) Then
    Begin
      If Length(S) < MAX_STR Then S := S + #13;
      If Length(S) < MAX_STR Then S := S + #10;
      LexNextLine;
      If LexEOF Then Break;
      Continue;
    End;
    Ch := LexLine[LexColNo];
    { Detecter <cf ou </cf ou <!--- }
    If Ch = '<' Then
    Begin
      If (LexColNo + 2 <= Length(LexLine)) And
         ((LexLine[LexColNo+1] = 'c') Or (LexLine[LexColNo+1] = 'C')) And
         ((LexLine[LexColNo+2] = 'f') Or (LexLine[LexColNo+2] = 'F')) Then
        Break;
      If (LexColNo + 3 <= Length(LexLine)) And
         (LexLine[LexColNo+1] = '/') And
         ((LexLine[LexColNo+2] = 'c') Or (LexLine[LexColNo+2] = 'C')) And
         ((LexLine[LexColNo+3] = 'f') Or (LexLine[LexColNo+3] = 'F')) Then
        Break;
      If (LexColNo + 4 <= Length(LexLine)) And
         (LexLine[LexColNo+1] = '!') And (LexLine[LexColNo+2] = '-') And
         (LexLine[LexColNo+3] = '-') And (LexLine[LexColNo+4] = '-') Then
        Break;
    End;
    { Detecter # (debut d interpolation) }
    If Ch = '#' Then
    Begin
      { ## est un echappement -> un seul # dans le texte }
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo+1] = '#') Then
      Begin
        If Length(S) < MAX_STR Then S := S + '#';
        Inc(LexColNo); Inc(LexColNo);
      End
      Else
        Break;  { debut d une expression #expr# }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_TEXT;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexNextToken : produire le prochain token -------------- }
Procedure LexNextToken;
Var
  Ch, Ch2 : Char;
Begin
  CurToken.Kind     := TK_EOF;
  CurToken.Val      := '';
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  While Not LexEOF Do
  Begin
    { Avancer a la ligne suivante si fin de ligne }
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      If LexEOF Then Break;
      Continue;
    End;

    Ch := LexLine[LexColNo];

    { === Mode expression : dans un tag, cfscript ou #expr# === }
    If InTag Or InCfScript Or InHashExpr Then
    Begin
      { Sauter les espaces }
      If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Then
      Begin
        Inc(LexColNo);
        Continue;
      End;

      { Commentaire CFML <!--- ... ---> }
      If (Ch = '<') And (LexColNo + 4 <= Length(LexLine)) And
         (LexLine[LexColNo+1] = '!') And (LexLine[LexColNo+2] = '-') And
         (LexLine[LexColNo+3] = '-') And (LexLine[LexColNo+4] = '-') Then
      Begin
        LexSkipCFComment;
        Continue;
      End;

      { Commentaires cfscript : // et /* ... */ }
      If InCfScript Then
      Begin
        If (Ch = '/') And (LexColNo < Length(LexLine)) And
           (LexLine[LexColNo+1] = '/') Then
        Begin
          LexSkipLineComment;
          Continue;
        End;
        If (Ch = '/') And (LexColNo < Length(LexLine)) And
           (LexLine[LexColNo+1] = '*') Then
        Begin
          LexSkipBlockComment;
          Continue;
        End;
      End;

      { Noter la position du token }
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;

      { Fermeture # pour sortir de l interpolation #expr# }
      If InHashExpr And (Ch = '#') Then
      Begin
        CurToken.Kind := TK_PUNCT;
        CurToken.Val  := '#';
        Inc(LexColNo);
        InHashExpr := False;
        Exit;
      End;

      { Fermeture de balise : /> (self-close) }
      If InTag And (Not InHashExpr) And (Ch = '/') And
         (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo+1] = '>') Then
      Begin
        CurToken.Kind := TK_TAG_SELFCLOSE;
        CurToken.Val  := '/>';
        Inc(LexColNo); Inc(LexColNo);
        InTag := False;
        Exit;
      End;

      { Fermeture de balise : > }
      If InTag And (Not InHashExpr) And (Ch = '>') Then
      Begin
        CurToken.Kind := TK_PUNCT;
        CurToken.Val  := '>';
        Inc(LexColNo);
        InTag := False;
        Exit;
      End;

      { Detecter </cfscript> dans le mode cfscript }
      If InCfScript And (Ch = '<') And
         (LexColNo + 10 <= Length(LexLine)) Then
      Begin
        If StrLowerCase(Copy(LexLine, LexColNo, 11)) = '</cfscript>' Then
        Begin
          CurToken.Kind := TK_TAG_CLOSE;
          CurToken.Val  := 'cfscript';
          Inc(LexColNo, 11);
          InCfScript := False;
          Exit;
        End;
      End;

      { Identifiant ou mot-cle }
      If IsIdentStart(Ch) Then
      Begin
        LexScanIdent;
        Exit;
      End;

      { Nombre }
      If (Ch >= '0') And (Ch <= '9') Then
      Begin
        LexScanNumber;
        Exit;
      End;

      { Chaine double-quote }
      If Ch = '"' Then
      Begin
        LexScanString('"');
        Exit;
      End;

      { Chaine simple-quote }
      If Ch = '''' Then
      Begin
        LexScanString('''');
        Exit;
      End;

      { Hash # pour interpolation dans les attributs }
      If (Ch = '#') And InTag And (Not InHashExpr) Then
      Begin
        CurToken.Kind := TK_PUNCT;
        CurToken.Val  := '#';
        Inc(LexColNo);
        InHashExpr := True;
        Exit;
      End;

      { Operateurs multi-caracteres }
      Ch2 := #0;
      If LexColNo < Length(LexLine) Then
        Ch2 := LexLine[LexColNo + 1];

      Case Ch Of
        '=': Begin
               If Ch2 = '=' Then
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '==';
                 Inc(LexColNo, 2);
               End
               Else
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '=';
                 Inc(LexColNo);
               End;
               Exit;
             End;
        '!': Begin
               If Ch2 = '=' Then
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '!=';
                 Inc(LexColNo, 2);
               End
               Else
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '!';
                 Inc(LexColNo);
               End;
               Exit;
             End;
        '<': Begin
               If Ch2 = '=' Then
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '<=';
                 Inc(LexColNo, 2);
               End
               Else
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '<';
                 Inc(LexColNo);
               End;
               Exit;
             End;
        '>': Begin
               If Ch2 = '=' Then
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '>=';
                 Inc(LexColNo, 2);
               End
               Else
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '>';
                 Inc(LexColNo);
               End;
               Exit;
             End;
        '&': Begin
               If Ch2 = '&' Then
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '&&';
                 Inc(LexColNo, 2);
               End
               Else
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '&';
                 Inc(LexColNo);
               End;
               Exit;
             End;
        '|': Begin
               If Ch2 = '|' Then
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '||';
                 Inc(LexColNo, 2);
               End
               Else
               Begin
                 CurToken.Kind := TK_OP; CurToken.Val := '|';
                 Inc(LexColNo);
               End;
               Exit;
             End;
        '+','-','*','%','\': Begin
               CurToken.Kind := TK_OP; CurToken.Val := Ch;
               Inc(LexColNo);
               Exit;
             End;
        '/': Begin
               CurToken.Kind := TK_OP; CurToken.Val := '/';
               Inc(LexColNo);
               Exit;
             End;
        '?',':': Begin
               CurToken.Kind := TK_OP; CurToken.Val := Ch;
               Inc(LexColNo);
               Exit;
             End;
        '.': Begin
               CurToken.Kind := TK_OP; CurToken.Val := '.';
               Inc(LexColNo);
               Exit;
             End;
      End; { Case }

      { Ponctuation }
      If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
         (Ch = ',') Or (Ch = ';') Or (Ch = '{') Or (Ch = '}') Or
         (Ch = '#') Then
      Begin
        CurToken.Kind := TK_PUNCT;
        CurToken.Val  := Ch;
        Inc(LexColNo);
        Exit;
      End;

      { Caractere inconnu : avancer }
      CompileError('caractere inattendu: ' + Ch);
      Inc(LexColNo);
    End

    { === Mode texte : hors balise et hors cfscript === }
    Else
    Begin
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;

      { Commentaire CFML <!--- ... ---> }
      If (Ch = '<') And (LexColNo + 4 <= Length(LexLine)) And
         (LexLine[LexColNo+1] = '!') And (LexLine[LexColNo+2] = '-') And
         (LexLine[LexColNo+3] = '-') And (LexLine[LexColNo+4] = '-') Then
      Begin
        LexSkipCFComment;
        Continue;
      End;

      { Balise ColdFusion ouvrante : <cf... }
      If (Ch = '<') And (LexColNo + 2 <= Length(LexLine)) And
         ((LexLine[LexColNo+1] = 'c') Or (LexLine[LexColNo+1] = 'C')) And
         ((LexLine[LexColNo+2] = 'f') Or (LexLine[LexColNo+2] = 'F')) Then
      Begin
        LexScanTag;
        Exit;
      End;

      { Balise fermante : </cf... }
      If (Ch = '<') And (LexColNo + 3 <= Length(LexLine)) And
         (LexLine[LexColNo+1] = '/') And
         ((LexLine[LexColNo+2] = 'c') Or (LexLine[LexColNo+2] = 'C')) And
         ((LexLine[LexColNo+3] = 'f') Or (LexLine[LexColNo+3] = 'F')) Then
      Begin
        LexScanTag;
        Exit;
      End;

      { Hash # : debut d interpolation #expression# }
      If Ch = '#' Then
      Begin
        { ## est un echappement -> traiter comme texte }
        If (LexColNo < Length(LexLine)) And
           (LexLine[LexColNo+1] = '#') Then
        Begin
          LexScanText;
          If CurToken.Val <> '' Then Exit;
          Continue;
        End
        Else
        Begin
          CurToken.Kind := TK_PUNCT;
          CurToken.Val  := '#';
          Inc(LexColNo);
          InHashExpr := True;
          Exit;
        End;
      End;

      { Texte brut entre balises }
      LexScanText;
      If CurToken.Val <> '' Then Exit;
    End;
  End;

  { Fin de fichier }
  CurToken.Kind := TK_EOF;
  CurToken.Val  := '';
  CurToken.Line := LexLineNo;
  CurToken.Col  := LexColNo;
End;

{ ---- ParserAdvance : lire le prochain token et debug ------- }
Procedure ParserAdvance;
Begin
  LexNextToken;
  PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAdd : ajouter une entree generique dans DataTab --- }
(* Retourne l index dans DataTab ou -1 si plein.               *)
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ---- DataAddStr : creer un label _CFK_N et stocker chaine -- }
(* Reutilise les doublons (meme contenu -> meme label).        *)
(* Retourne l index dans DataTab.                              *)
Function DataAddStr(Const S : TString) : Integer;
Var
  I   : Integer;
  Lbl : TString;
Begin
  { Chercher un doublon existant }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := I;
      Exit;
    End;
  Inc(LabelGenSeq);
  Lbl := CF_STR_PFX + IntToStr(LabelGenSeq);
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DataTab ----- }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- ExprMakeImm : construire une valeur immediate --------- }
(* ATTENTION TP7 : ne pas retourner de Record - utiliser Var   *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNone : valeur vide (void / erreur) ------------ }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeBool : construire une valeur booleenne --------- }
(* AVal <> 0 -> AX=1 (true), AVal = 0 -> AX=0 (false)        *)
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : convertir un token TK_INTEGER en valeur -- }
(* IntVal est deja calcule par LexScanNumber                   *)
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUMERIC, Res);
End;

{ ---- LitEvalFloat : convertir un token TK_FLOAT en valeur -- }
(* ColdFusion traite les flottants comme des entiers (trunc)   *)
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUMERIC, Res);
  WarnMsg('flottant tronque a entier : ' + T.Val);
End;

{ ---- IsBoolKeyword : test rapide true/false/yes/no ---------- }
Function IsBoolKeyword(Const S : TString) : Boolean;
Var
  U : TString;
Begin
  U := StrUpperCase(S);
  IsBoolKeyword := (U = 'TRUE') Or (U = 'FALSE') Or
                   (U = 'YES')  Or (U = 'NO');
End;

{ ---- LitEvalKW : evaluer un mot-cle litteral ---------------- }
(* true / yes -> AX=1, false / no -> AX=0, null -> AX=0       *)
Procedure LitEvalKW(Const T : TToken; Var Res : TExprVal);
Var
  U : TString;
Begin
  U := StrUpperCase(T.Val);
  If (U = 'TRUE') Or (U = 'YES') Then
    ExprMakeBool(1, Res)
  Else If (U = 'FALSE') Or (U = 'NO') Then
    ExprMakeBool(0, Res)
  Else If U = 'NULL' Then
    ExprMakeImm(0, TY_IDX_NULL, Res)
  Else
    ExprMakeNone(Res);
End;

{ ---- LitEval : dispatcher principal pour les litteraux ----- }
(* Types de tokens acceptes :                                   *)
(*   TK_INTEGER  -> entier decimal (LitEvalInt)                 *)
(*   TK_FLOAT    -> flottant tronque (LitEvalFloat)             *)
(*   TK_STRING   -> chaine -> DataAddStr + EK_MEM               *)
(*   TK_KEYWORD  -> true/false/yes/no/null (LitEvalKW)          *)
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_FLOAT   : LitEvalFloat(T, Res);
    TK_STRING  :
    Begin
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := DataAddStr(T.Val);
      Res.SymIdx  := -1;
    End;
    TK_KEYWORD :
      LitEvalKW(T, Res);
  Else
    ExprMakeNone(Res);
  End;
End;

{ ============================================================
  STUBS POUR COMPILATION (implementes dans les TODOs suivants)
  ============================================================ }

Procedure TypeInit;
Begin
  TypeCount := 0;
End;

Procedure SymInit;
Begin
  SymCount := 0;
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('CF86: impossible de creer ', Opts.OutFile);
    Inc(ErrorCount);
    OutFOpen := False;
    Exit;
  End;
  OutFOpen := True;
End;

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, S);
End;

Procedure EmitBlankLine;
Begin
  If OutFOpen Then WriteLn(OutF);
End;

Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '; ', S);
End;

Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then WriteLn(OutF, Lbl, ':');
End;

Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Not OutFOpen Then Exit;
  If Ops <> '' Then WriteLn(OutF, #9, Mnem, #9, Ops)
  Else WriteLn(OutF, #9, Mnem);
End;

Procedure EmitHeader;
Begin
  EmitComment('CF86 v' + CF86_VERSION + ' - ' + CF86_DATE);
  EmitComment('Compilateur ColdFusion -> assembleur 8086');
  EmitComment('Source: ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT SEGMENT PUBLIC ''CODE''');
  EmitRaw('  ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
End;

Procedure EmitRuntime;
Begin
  { stub }
  RuntimeEmitted := True;
End;

Procedure EmitDataSeg;
Begin
  { stub }
  EmitBlankLine;
  EmitRaw('_DATA SEGMENT PUBLIC ''DATA''');
  EmitRaw('_CF_CRLF  DB 13, 10, 0');
  EmitRaw('_DATA ENDS');
  EmitBlankLine;
End;

Procedure EmitClose;
Begin
  If Not OutFOpen Then Exit;
  EmitBlankLine;
  EmitRaw('_TEXT ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitRaw('END ' + CF_FN_PFX + 'Main');
  Close(OutF);
  OutFOpen := False;
End;

Procedure ParsePage;
Begin
  { stub : consommer tous les tokens }
  While CurToken.Kind <> TK_EOF Do
    ParserAdvance;
End;

{ ============================================================
  PROCEDURE RUN - PIPELINE DE COMPILATION
  ============================================================ }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  { Point d entree programme }
  EmitComment('Point d''entree programme CF86');
  EmitLabel(CF_FN_PFX + 'Main');
  EmitInstr('MOV', 'AX, @DATA');
  EmitInstr('MOV', 'DS, AX');
  EmitBlankLine;

  ParserAdvance;
  ParsePage;

  LexClose;

  { Epilogue : sortie DOS propre }
  EmitBlankLine;
  EmitComment('Fin de programme');
  EmitInstr('MOV', 'AX, 4C00h');
  EmitInstr('INT', '21h');
  EmitBlankLine;

  EmitRuntime;
  EmitClose;

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
    If Opts.IsComponent Then
      WriteLn('  Mode           : composant CFC')
    Else
      WriteLn('  Mode           : page CFM');
  End;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowUsage;
 End;
  ParseArgs;
  Run;
End.
