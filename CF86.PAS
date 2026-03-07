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

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
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

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
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

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
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

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_STRUCT),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddStruct : variantes d ajout
            Variables de page (scope variables) : entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _CFK_N
            Tables de structures : paires cle/valeur dans DATA
            Contenu texte brut (hors balises) : DB dans DATA pour affichage

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
            <cfset nomVariable = expression>
              Variables non declarees : creation implicite dans scope variables
              Scope explicite : <cfset local.x = 5> ou <cfset variables.x = 5>
            Variables globales : segment DATA, acces par label _CFV_nom
            Variables locales (dans cffunction) : pile BP, acces [BP-offset]
            Mot-cle var : var nomVar = expr (declaration locale en cfscript)
            Affectation := ExprLoad + MOV destination, AX
            Affectation de struct : copie par reference (pointeur)
            Affectation de array : copie par reference (pointeur)

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
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
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;
{ TODO 07 }
Function  LabelGen : TString; Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
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
Function  DataAddStruct(Const Lbl : TString; ASize : Integer) : Integer; Forward;
Procedure DataInit; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
{ TODO 04 }
Function  NewLabel(Const Prefix : TString) : TString; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Function  IsCFBinOp(Const T : TToken) : Boolean; Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure ExprEmitBinOp(Const Op : TString;
                        Var L : TExprVal; Var R : TExprVal); Forward;
Procedure ExprEmitUnary(Const Op : TString;
                        Var E : TExprVal); Forward;
{ TODO 05 }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                         Level : Integer) : Integer; Forward;
Function  SymAdd(Const AName : TString; ACat : TSymCat;
                 ATypeIdx : Integer; AOffset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
{ TODO 06 }
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  TypeInfer(Const E : TExprVal) : Integer; Forward;
Function  TypeLookupName(Const Name : TString) : Integer; Forward;
{ TODO 09 }
Function  VarAlloc(Const AName : TString; ATypeIdx : Integer) : Integer; Forward;
Function  VarAddrOf(SIdx : Integer) : TString; Forward;
Procedure VarLoad(SIdx : Integer); Forward;
Procedure VarStore(SIdx : Integer); Forward;
Procedure ParseCfSet; Forward;
Procedure ParseVarDecl; Forward;
{ TODO 10 }
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Function  ParseCallArgs : Integer; Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;

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

{ ---- DataAddStruct : ajouter un bloc structure dans DataTab - }
(* Cree une entree DK_STRUCT_BLK de taille ASize octets.       *)
(* Utilisee pour les structures ColdFusion (paires cle/valeur). *)
Function DataAddStruct(Const Lbl : TString; ASize : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_STRUCT_BLK, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := ASize;
  DataAddStruct := Idx;
End;

{ ============================================================ }
{  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]      }
{ ============================================================ }

{ ---- DataInit : pre-populer le segment DATA avec les -------- }
(* constantes et buffers internes de CF86.                      *)
(* Contenu :                                                     *)
(*   _CF_CRLF      DB 13,10,0       (retour chariot)            *)
(*   _CF_NULL_STR   DB 0              (chaine vide)              *)
(*   _CF_STRBUF    DB 256 DUP(0)    (buffer chaines temporaire) *)
(*   _CF_TXTBUF    DB 512 DUP(0)    (buffer texte brut/output)  *)
(* Ces entrees sont ajoutees en premier dans DataTab pour etre  *)
(* disponibles durant toute la compilation.                     *)
Procedure DataInit;
Var
  Idx : Integer;
Begin
  DataCount := 0;

  { Retour chariot CRLF - caracteres de controle geres par EmitDataSeg }
  DataAdd('_CF_CRLF', DK_STR, 0, #13#10);

  { Chaine vide (null string) }
  DataAdd('_CF_NULL_STR', DK_STR, 0, '');

  { Buffer pour concatenation de chaines temporaires }
  Idx := DataAdd('_CF_STRBUF', DK_ARRAY_BLK, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := 256;

  { Buffer pour contenu texte brut (sortie cfoutput) }
  Idx := DataAdd('_CF_TXTBUF', DK_ARRAY_BLK, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := 512;
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
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- NewLabel : generer un label unique _CFL_prefix_N ------- }
Function NewLabel(Const Prefix : TString) : TString;
Var
  NS : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, NS);
  NewLabel := CF_LBL_PFX + Prefix + '_' + NS;
End;

{ ---- IsAssignOp : teste si Op est un operateur d affectation }
(* ColdFusion n a que = pour l affectation                     *)
Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp := (Op = '=');
End;

{ ---- IsCFBinOp : teste si le token courant est un operateur  }
(* binaire ColdFusion (operateur symbolique ou mot-cle)        *)
Function IsCFBinOp(Const T : TToken) : Boolean;
Var
  U : TString;
Begin
  IsCFBinOp := False;
  If T.Kind = TK_OP Then
  Begin
    IsCFBinOp := (BinOpPrec(T.Val) > 0);
    Exit;
  End;
  If T.Kind = TK_KEYWORD Then
  Begin
    U := StrUpperCase(T.Val);
    IsCFBinOp :=
      (U = 'EQ')  Or (U = 'NEQ')      Or (U = 'LT')  Or (U = 'LTE') Or
      (U = 'GT')  Or (U = 'GTE')      Or (U = 'AND') Or (U = 'OR')  Or
      (U = 'XOR') Or (U = 'MOD')      Or (U = 'CONTAINS');
  End;
End;

{ ---- BinOpPrec : table de precedences ColdFusion (Pratt) --- }
(* Retourne 0 si l operateur n est pas binaire.                *)
(* Niveaux (croissant = plus serre) :                          *)
(*   ? :           -> 1  (ternaire)                            *)
(*   OR XOR ||     -> 2  (OU logique / XOR)                    *)
(*   AND &&        -> 3  (ET logique)                          *)
(*   EQ NEQ LT LTE GT GTE CONTAINS == != < <= > >=  -> 4      *)
(*   + - &         -> 5  (addition, soustraction, concat)      *)
(*   * / MOD \     -> 6  (multiplication, division, modulo)    *)
(*   NOT ! unaire  -> traites par ExprEmitUnary / ParsePrimary *)
Function BinOpPrec(Const Op : TString) : Integer;
Var
  U : TString;
Begin
  U := StrUpperCase(Op);
  { Ternaire }
  If (U = '?') Or (U = ':') Then
    BinOpPrec := 1
  { OU logique / XOR }
  Else If (U = 'OR') Or (U = 'XOR') Or (U = '||') Then
    BinOpPrec := 2
  { ET logique }
  Else If (U = 'AND') Or (U = '&&') Then
    BinOpPrec := 3
  { Comparaison }
  Else If (U = 'EQ')  Or (U = 'NEQ')      Or (U = 'LT')  Or (U = 'LTE') Or
          (U = 'GT')  Or (U = 'GTE')      Or (U = 'CONTAINS') Or
          (U = '==')  Or (U = '!=')        Or (U = '<')   Or (U = '<=')  Or
          (U = '>')   Or (U = '>=') Then
    BinOpPrec := 4
  { Addition, soustraction, concatenation }
  Else If (U = '+') Or (U = '-') Or (U = '&') Then
    BinOpPrec := 5
  { Multiplication, division, modulo, division entiere }
  Else If (U = '*') Or (U = '/') Or (U = 'MOD') Or (U = '\') Then
    BinOpPrec := 6
  Else
    BinOpPrec := 0;
End;

{ ---- BinOpIsRight : vrai si operateur droit-associatif ----- }
(* En ColdFusion : le ternaire ? est droit-associatif         *)
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '?');
End;

{ ---- ExprFlushToAX : charger la valeur d une TExprVal ------ }
(* dans le registre AX, quel que soit son mode (IMM/MEM/AX)   *)
Procedure ExprFlushToAX(Var E : TExprVal);
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      EmitInstr('MOV', 'AX, ' + S);
      E.Kind := EK_AX;
    End;
    EK_MEM :
    Begin
      { Chaine litterale : Offset = index DataTab -> OFFSET label }
      If E.TypeIdx = TY_IDX_STRING Then
      Begin
        If (E.Offset >= 0) And (E.Offset < DataCount) Then
          EmitInstr('MOV', 'AX, OFFSET ' + DataTab[E.Offset].LblName)
        Else
          EmitInstr('XOR', 'AX, AX');
      End
      { Variable locale : [BP-n] }
      Else If E.Offset < 0 Then
      Begin
        Str(-E.Offset, S);
        EmitInstr('MOV', 'AX, [BP-' + S + ']');
      End
      { Variable globale ou parametre : [BP+n] ou [_CFV_label] }
      Else
      Begin
        If (E.SymIdx >= 0) And (E.SymIdx < SymCount) Then
          EmitInstr('MOV', 'AX, [' + SymTab[E.SymIdx].MangledName + ']')
        Else
        Begin
          Str(E.Offset, S);
          EmitInstr('MOV', 'AX, [BP+' + S + ']');
        End;
      End;
      E.Kind := EK_AX;
    End;
    EK_AX  : ;  { deja dans AX }
    EK_NONE : ;  { rien a faire }
  End;
End;

{ ---- NormOp : normaliser un operateur ColdFusion ---------- }
(* Convertit les mots-cles ColdFusion en forme symbolique     *)
(* pour simplifier le traitement dans ExprEmitBinOp            *)
Function NormOp(Const Op : TString) : TString;
Var
  U : TString;
Begin
  U := StrUpperCase(Op);
  If      U = 'EQ'  Then NormOp := '=='
  Else If U = 'NEQ' Then NormOp := '!='
  Else If U = 'LT'  Then NormOp := '<'
  Else If U = 'LTE' Then NormOp := '<='
  Else If U = 'GT'  Then NormOp := '>'
  Else If U = 'GTE' Then NormOp := '>='
  Else If U = 'AND' Then NormOp := '&&'
  Else If U = 'OR'  Then NormOp := '||'
  Else NormOp := Op;
End;

{ ---- ExprEmitBinOp : generer le code 8086 pour op binaire -- }
(* Pliage de constantes si L et R sont EK_IMM.                 *)
(* Operateurs CF couverts :                                    *)
(*   + - * / MOD \ (arith)  & (concat)                        *)
(*   EQ NEQ LT LTE GT GTE CONTAINS == != < <= > >= (comp)     *)
(*   AND OR XOR && || (logique, avec court-circuit)            *)
Procedure ExprEmitBinOp(Const Op : TString;
                        Var L : TExprVal; Var R : TExprVal);
Var
  NP    : TString;
  LblE  : TString;
  LblT  : TString;
Begin
  NP := NormOp(Op);

  { ---- Pliage de constantes -------------------------------- }
  If (L.Kind = EK_IMM) And (R.Kind = EK_IMM) Then
  Begin
    If      NP = '+'  Then L.ImmVal := L.ImmVal + R.ImmVal
    Else If NP = '-'  Then L.ImmVal := L.ImmVal - R.ImmVal
    Else If NP = '*'  Then L.ImmVal := L.ImmVal * R.ImmVal
    Else If NP = '/'  Then
    Begin
      If R.ImmVal = 0 Then
      Begin CompileError('division par zero'); L.ImmVal := 0; End
      Else L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If (StrUpperCase(Op) = 'MOD') Or (NP = '%') Then
    Begin
      If R.ImmVal = 0 Then
      Begin CompileError('modulo par zero'); L.ImmVal := 0; End
      Else L.ImmVal := L.ImmVal Mod R.ImmVal;
    End
    Else If NP = '\' Then
    Begin
      If R.ImmVal = 0 Then
      Begin CompileError('division entiere par zero'); L.ImmVal := 0; End
      Else L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If NP = '==' Then
    Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If NP = '!=' Then
    Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If NP = '<'  Then
    Begin If L.ImmVal <  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If NP = '<=' Then
    Begin If L.ImmVal <= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If NP = '>'  Then
    Begin If L.ImmVal >  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If NP = '>=' Then
    Begin If L.ImmVal >= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If NP = '&&' Then
    Begin
      If (L.ImmVal <> 0) And (R.ImmVal <> 0) Then L.ImmVal := 1
      Else L.ImmVal := 0;
    End
    Else If NP = '||' Then
    Begin
      If (L.ImmVal <> 0) Or (R.ImmVal <> 0) Then L.ImmVal := 1
      Else L.ImmVal := 0;
    End
    Else If StrUpperCase(Op) = 'XOR' Then
    Begin
      If ((L.ImmVal <> 0) And (R.ImmVal = 0)) Or
         ((L.ImmVal = 0) And (R.ImmVal <> 0)) Then L.ImmVal := 1
      Else L.ImmVal := 0;
    End
    Else If NP = '&' Then
      L.ImmVal := 0;  { concat de constantes : pas supporte en IMM }
    L.TypeIdx := TY_IDX_NUMERIC;
    Exit;
  End;

  { ---- Court-circuit && / AND ------------------------------ }
  If NP = '&&' Then
  Begin
    LblE := NewLabel('SCAND');
    ExprFlushToAX(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ', LblE);
    ExprFlushToAX(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblE);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblE);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- Court-circuit || / OR ------------------------------- }
  If NP = '||' Then
  Begin
    LblE := NewLabel('SCOR');
    ExprFlushToAX(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JNZ', LblE);
    ExprFlushToAX(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblE);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblE);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- XOR logique ----------------------------------------- }
  If StrUpperCase(Op) = 'XOR' Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    LblT := NewLabel('XNLA');
    EmitInstr('JZ', LblT);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblT);
    EmitInstr('PUSH', 'AX');
    ExprFlushToAX(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    LblE := NewLabel('XNLB');
    EmitInstr('JZ', LblE);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblE);
    EmitInstr('POP', 'BX');
    EmitInstr('XOR', 'AX, BX');
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- Concatenation & ------------------------------------- }
  If NP = '&' Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('PUSH', 'SI');
    ExprFlushToAX(R);
    EmitInstr('MOV', 'DI, AX');
    EmitInstr('POP', 'SI');
    EmitInstr('CALL', CF_RT_PFX + 'CONCAT');
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_STRING;
    Exit;
  End;

  { ---- CONTAINS -------------------------------------------- }
  If StrUpperCase(Op) = 'CONTAINS' Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('PUSH', 'SI');
    ExprFlushToAX(R);
    EmitInstr('MOV', 'DI, AX');
    EmitInstr('POP', 'SI');
    EmitInstr('CALL', CF_RT_PFX + 'CONTAINS');
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- Cas general : L dans AX, R dans BX ----------------- }
  ExprFlushToAX(L);
  EmitInstr('PUSH', 'AX');
  ExprFlushToAX(R);
  EmitInstr('MOV', 'BX, AX');
  EmitInstr('POP', 'AX');
  { AX = gauche, BX = droite }

  { Arithmetique }
  If      NP = '+'  Then EmitInstr('ADD', 'AX, BX')
  Else If NP = '-'  Then EmitInstr('SUB', 'AX, BX')
  Else If NP = '*'  Then EmitInstr('IMUL', 'BX')
  Else If NP = '/'  Then
  Begin
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
  End
  Else If (StrUpperCase(Op) = 'MOD') Or (NP = '%') Then
  Begin
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    EmitInstr('MOV', 'AX, DX');
  End
  Else If NP = '\' Then
  Begin
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    { quotient deja dans AX }
  End
  { Comparaison }
  Else If NP = '==' Then
  Begin
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETE', 'AL');
  End
  Else If NP = '!=' Then
  Begin
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETNE', 'AL');
  End
  Else If NP = '<' Then
  Begin
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETL', 'AL');
  End
  Else If NP = '<=' Then
  Begin
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETLE', 'AL');
  End
  Else If NP = '>' Then
  Begin
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETG', 'AL');
  End
  Else If NP = '>=' Then
  Begin
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETGE', 'AL');
  End;

  L.Kind := EK_AX;
End;

{ ---- ExprEmitUnary : generer le code 8086 pour op unaire --- }
(* NOT / ! -> TEST AX,AX ; MOV AX,0 ; SETZ AL                 *)
(* unaire - -> NEG AX                                          *)
(* unaire + -> rien (identite)                                 *)
Procedure ExprEmitUnary(Const Op : TString; Var E : TExprVal);
Var
  U : TString;
Begin
  U := StrUpperCase(Op);

  { Pliage de constante unaire }
  If E.Kind = EK_IMM Then
  Begin
    If (U = 'NOT') Or (U = '!') Then
    Begin
      If E.ImmVal <> 0 Then E.ImmVal := 0 Else E.ImmVal := 1;
      E.TypeIdx := TY_IDX_BOOLEAN;
    End
    Else If U = '-' Then
      E.ImmVal := -E.ImmVal
    Else If U = '+' Then
      ;  { identite }
    Exit;
  End;

  ExprFlushToAX(E);
  If (U = 'NOT') Or (U = '!') Then
  Begin
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETZ', 'AL');
    E.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If U = '-' Then
    EmitInstr('NEG', 'AX')
  Else If U = '+' Then
    ;  { identite : rien a generer }
  E.Kind := EK_AX;
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymNameClean : nettoyer un nom pour nommage ASM ------- }
(* Remplace tout caractere non alpha-numerique par _ .          *)
Function SymNameClean(Const Name : TString) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := '';
  For I := 1 To Length(Name) Do
  Begin
    If Length(S) >= MAX_STR Then Break;
    If ((Name[I] >= 'A') And (Name[I] <= 'Z')) Or
       ((Name[I] >= 'a') And (Name[I] <= 'z')) Or
       ((Name[I] >= '0') And (Name[I] <= '9')) Or
       (Name[I] = '_') Then
      S := S + Name[I]
    Else
      S := S + '_';
  End;
  If S = '' Then S := '_anon';
  SymNameClean := S;
End;

{ ---- SymMangle : generer un label ASM depuis un symbole ---- }
(* Le prefixe depend de la categorie du symbole :               *)
(*   SC_VAR, SC_LOCAL, SC_PARAM   -> _CFV_                     *)
(*   SC_FUNCTION                  -> _CFF_                     *)
(*   SC_COMPONENT                 -> _CFC_                     *)
(*   SC_CFPROPERTY                -> _CFP_                     *)
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx : TString;
Begin
  Case Cat Of
    SC_VAR        : Pfx := CF_VAR_PFX;
    SC_LOCAL      : Pfx := CF_VAR_PFX;
    SC_PARAM      : Pfx := CF_VAR_PFX;
    SC_FUNCTION   : Pfx := CF_FN_PFX;
    SC_COMPONENT  : Pfx := CF_CMP_PFX;
    SC_CFPROPERTY : Pfx := CF_PROP_PFX;
  Else
    Pfx := CF_VAR_PFX;
  End;
  SymMangle := Pfx + SymNameClean(StrLowerCase(Name));
End;

{ ---- SymFind : rechercher un symbole par nom --------------- }
(* Parcourt la table du plus recent au plus ancien pour         *)
(* respecter la portee la plus interne (shadowing).             *)
(* ColdFusion est insensible a la casse -> comparaison lower.   *)
(* Retourne l index (0-base) ou -1 si non trouve.               *)
Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Lw : TString;
  Sw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    Sw := StrLowerCase(SymTab[I].Name);
    If Sw = Lw Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ---- SymFindInScope : rechercher dans un scope specifique -- }
(* Ne retourne que les symboles dont ScopeLevel = Level.        *)
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Lw : TString;
  Sw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    Sw := StrLowerCase(SymTab[I].Name);
    If (Sw = Lw) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ---- SymAdd : ajouter un symbole dans la table ------------- }
(* Retourne l index du symbole (0-base) ou -1 en cas d erreur.  *)
Function SymAdd(Const AName : TString; ACat : TSymCat;
                ATypeIdx : Integer; AOffset : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := AName;
  SymTab[Idx].MangledName := SymMangle(AName, ACat);
  SymTab[Idx].Cat         := ACat;
  SymTab[Idx].TypeIdx     := ATypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := AOffset;
  SymTab[Idx].IsLocal     := (ACat = SC_LOCAL) Or (ACat = SC_PARAM);
  SymTab[Idx].IsArgument  := (ACat = SC_PARAM);
  SymTab[Idx].IsOutput    := False;
  SymTab[Idx].DeclLine    := CurToken.Line;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', AName,
            ' cat=', Ord(ACat),
            ' scope=', CurScope,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ ---- SymEnterScope : entrer dans un nouveau scope ---------- }
(* Empile le nombre de symboles pour pouvoir les retirer au     *)
(* retour de scope avec SymLeaveScope.                          *)
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
End;

{ ---- SymLeaveScope : quitter la portee courante ------------ }
(* Retire tous les symboles ajoutes dans cette portee.          *)
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
End;

{ ---- SymNextOffset : calculer le prochain offset [BP-n] ---- }
(* Chaque variable locale occupe 2 octets (mot 16 bits).        *)
Function SymNextOffset : Integer;
Begin
  Inc(CurFrameSize, 2);
  SymNextOffset := -CurFrameSize;
End;

{ ---- SymInit : initialiser la table des symboles ----------- }
(* Remet a zero la table et enregistre les portees predefinies   *)
(* de ColdFusion : variables, local, arguments, form, url, cgi, *)
(* application, session, request (stubs).                       *)
Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Cat         := SC_VAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsLocal     := False;
    SymTab[I].IsArgument  := False;
    SymTab[I].IsOutput    := False;
    SymTab[I].DeclLine    := 0;
  End;
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeKindOf : retourner le TTypeKind pour un indice ----- }
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TKC_ANY;
End;

{ ---- TypeSizeof : taille en octets d un type par index ------ }
(* numeric=2, string=2 (ptr), boolean=2, array=2 (ptr),         *)
(* struct=2 (ptr), query=2 (ptr), null=2, any=2.                *)
(* En 16 bits tout tient dans un mot (AX).                      *)
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

{ ---- TypeMangle : prefixe ASM selon le type ----------------- }
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TKC_NUMERIC : TypeMangle := '_CFN_';
    TKC_STRING  : TypeMangle := '_CFS_';
    TKC_BOOLEAN : TypeMangle := '_CFB_';
    TKC_ARRAY   : TypeMangle := '_CFA_';
    TKC_STRUCT  : TypeMangle := '_CFT_';
    TKC_QUERY   : TypeMangle := '_CFQ_';
    TKC_NULL    : TypeMangle := '_CFZ_';
    TKC_ANY     : TypeMangle := '_CFX_';
  Else
    TypeMangle := '_CFX_';
  End;
End;

{ ---- TypeIsNumeric : vrai si le type est comparable a un nombre }
(* En ColdFusion, numeric, boolean et null sont numeriques.      *)
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TKC_NUMERIC) Or (K = TKC_BOOLEAN) Or (K = TKC_NULL);
End;

{ ---- TypeIsPtr : vrai si le type est un pointeur ------------ }
(* string, array, struct et query sont des pointeurs 16 bits.   *)
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TKC_STRING) Or (K = TKC_ARRAY) Or
    (K = TKC_STRUCT) Or (K = TKC_QUERY);
End;

{ ---- TypeCanCoerce : coercition ColdFusion ------------------- }
(* ColdFusion est faiblement type : presque toute coercition     *)
(* est acceptee (string <-> numeric, bool <-> numeric, etc.).    *)
(* Seuls les types complexes (struct/query/array) ne se          *)
(* convertissent pas implicitement vers les scalaires.           *)
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Var
  SK, DK : TTypeKind;
Begin
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  If (DstIdx = TY_UNKNOWN) Or (DstIdx = TY_IDX_ANY) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  If (SrcIdx = TY_UNKNOWN) Or (SrcIdx = TY_IDX_ANY) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  SK := TypeKindOf(SrcIdx);
  DK := TypeKindOf(DstIdx);
  (* scalaire -> scalaire : toujours OK en CF *)
  If ((SK = TKC_NUMERIC) Or (SK = TKC_STRING) Or
      (SK = TKC_BOOLEAN) Or (SK = TKC_NULL)) And
     ((DK = TKC_NUMERIC) Or (DK = TKC_STRING) Or
      (DK = TKC_BOOLEAN) Or (DK = TKC_NULL)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  TypeCanCoerce := False;
End;

{ ---- TypeCoerceResult : type resultat d une operation binaire }
(* Comparaisons -> boolean, concat & -> string, arith -> numeric *)
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
  U : TString;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);
  U := StrUpperCase(Op);
  (* Operateurs de comparaison -> booleen *)
  If (U = 'EQ')  Or (U = 'NEQ') Or
     (U = 'LT')  Or (U = 'LTE') Or
     (U = 'GT')  Or (U = 'GTE') Or
     (U = '==')  Or (U = '!=')  Or
     (U = '<')   Or (U = '<=')  Or
     (U = '>')   Or (U = '>=')  Or
     (U = 'CONTAINS') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;
  (* Operateurs logiques -> booleen *)
  If (U = 'AND') Or (U = 'OR') Or (U = 'XOR') Or
     (U = '&&')  Or (U = '||') Or (U = 'NOT') Or (U = '!') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;
  (* Concatenation -> string *)
  If U = '&' Then
  Begin
    TypeCoerceResult := TY_IDX_STRING;
    Exit;
  End;
  (* Arithmetique : si les deux cotes sont numeriques -> numeric *)
  If (U = '+') Or (U = '-') Or (U = '*') Or
     (U = '/') Or (U = 'MOD') Or (U = '\') Then
  Begin
    If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
      TypeCoerceResult := TY_IDX_NUMERIC
    Else If (LK = TKC_STRING) Or (RK = TKC_STRING) Then
      TypeCoerceResult := TY_IDX_NUMERIC  (* CF coerce string -> number en arith *)
    Else
      TypeCoerceResult := TY_IDX_NUMERIC;
    Exit;
  End;
  (* Par defaut : type du cote gauche *)
  If LeftIdx <> TY_UNKNOWN Then
    TypeCoerceResult := LeftIdx
  Else
    TypeCoerceResult := RightIdx;
End;

{ ---- TypeInfer : deduire le type d une expression ----------- }
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx <> TY_UNKNOWN Then
    TypeInfer := E.TypeIdx
  Else If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_NUMERIC
  Else
    TypeInfer := TY_UNKNOWN;
End;

{ ---- TypeLookupName : chercher un type par nom -------------- }
(* ColdFusion est insensible a la casse -> comparaison lower.   *)
Function TypeLookupName(Const Name : TString) : Integer;
Var
  I  : Integer;
  Lw : TString;
  Tw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := 0 To TypeCount - 1 Do
  Begin
    Tw := StrLowerCase(TypeTab[I].Name);
    If Tw = Lw Then
    Begin
      TypeLookupName := I;
      Exit;
    End;
  End;
  TypeLookupName := TY_UNKNOWN;
End;

{ ---- TypeInit : enregistrer les types primitifs ColdFusion -- }
(* Indices fixes : TY_IDX_NUMERIC=0 .. TY_IDX_ANY=7            *)
(* Mapping 8086 :                                               *)
(*   numeric = 2 octets (word, AX)                              *)
(*   string  = 2 octets (pointeur near vers chaine DATA)        *)
(*   boolean = 2 octets (0=false, 1=true dans AX)               *)
(*   array   = 2 octets (pointeur vers bloc DATA)               *)
(*   struct  = 2 octets (pointeur vers table cle/valeur)        *)
(*   query   = 2 octets (pointeur stub)                         *)
(*   null    = 2 octets (AX=0)                                  *)
(*   any     = 2 octets (type dynamique par defaut)             *)
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TKC_ANY;
    TypeTab[I].Size := 0;
  End;
  (* TY_IDX_NUMERIC = 0 *)
  TypeTab[0].Name := 'numeric';
  TypeTab[0].Kind := TKC_NUMERIC;
  TypeTab[0].Size := 2;
  (* TY_IDX_STRING = 1 *)
  TypeTab[1].Name := 'string';
  TypeTab[1].Kind := TKC_STRING;
  TypeTab[1].Size := 2;
  (* TY_IDX_BOOLEAN = 2 *)
  TypeTab[2].Name := 'boolean';
  TypeTab[2].Kind := TKC_BOOLEAN;
  TypeTab[2].Size := 2;
  (* TY_IDX_ARRAY = 3 *)
  TypeTab[3].Name := 'array';
  TypeTab[3].Kind := TKC_ARRAY;
  TypeTab[3].Size := 2;
  (* TY_IDX_STRUCT = 4 *)
  TypeTab[4].Name := 'struct';
  TypeTab[4].Kind := TKC_STRUCT;
  TypeTab[4].Size := 2;
  (* TY_IDX_QUERY = 5 *)
  TypeTab[5].Name := 'query';
  TypeTab[5].Kind := TKC_QUERY;
  TypeTab[5].Size := 2;
  (* TY_IDX_NULL = 6 *)
  TypeTab[6].Name := 'null';
  TypeTab[6].Kind := TKC_NULL;
  TypeTab[6].Size := 2;
  (* TY_IDX_ANY = 7 *)
  TypeTab[7].Name := 'any';
  TypeTab[7].Kind := TKC_ANY;
  TypeTab[7].Size := 2;
  TypeCount := TY_PRIM_COUNT;
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

(* ---- LabelGen : generer un label unique _CFL_NNNNN ---------- *)
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := CF_LBL_PFX + S;
End;

(* ---- EmitRaw : ecrire une ligne brute dans le fichier ------- *)
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, S);
End;

(* ---- EmitBlankLine : ligne vide ----------------------------- *)
Procedure EmitBlankLine;
Begin
  If OutFOpen Then WriteLn(OutF);
End;

(* ---- EmitComment : commentaire ASM '; texte' ---------------- *)
Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '; ', S);
End;

(* ---- EmitLabel : label ASM suivi de ':' en colonne 0 -------- *)
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then WriteLn(OutF, Lbl, ':');
End;

(* ---- EmitInstr : instruction avec operandes optionnels ------ *)
(* Si Ops est vide, emet juste le mnemonique.                    *)
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Not OutFOpen Then Exit;
  If Ops <> '' Then WriteLn(OutF, '        ', Mnem, '   ', Ops)
  Else WriteLn(OutF, '        ', Mnem);
End;

(* ---- EmitInstrA : instruction + un operande ----------------- *)
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  EmitInstr(Mnem, A1);
End;

(* ---- EmitInstrAB : instruction + deux operandes ------------- *)
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  EmitInstr(Mnem, A1 + ', ' + A2);
End;

(* ---- EmitOpen : ouvrir le fichier de sortie ASM ------------- *)
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

(* ---- EmitProlog : prologue de procedure --------------------- *)
(* PUSH BP / MOV BP,SP                                           *)
Procedure EmitProlog;
Begin
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
End;

(* ---- EmitEpilog : epilogue de procedure --------------------- *)
(* MOV SP,BP / POP BP                                            *)
Procedure EmitEpilog;
Begin
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
End;

(* ---- EmitHeader : en-tete du fichier ASM -------------------- *)
(* .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT PUBLIC             *)
(* Point d entree : _CFF_Main + init DS                          *)
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
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
End;

(* ---- EmitDataSeg : emettre le segment DATA complet ---------- *)
(* Emettre _CF_CRLF + toutes les entrees DataTab                 *)
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
  Ch   : Char;
  InStr : Boolean;
Begin
  EmitRaw('_DATA SEGMENT PUBLIC ''DATA''');
  EmitBlankLine;
  EmitComment('Donnees statiques CF86');
  EmitBlankLine;
  (* Emettre les entrees DataTab *)
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
      Begin
        (* Gerer les caracteres de controle : emettre en octets *)
        (* numeriques separes des portions texte.                *)
        S := '';
        InStr := False;
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          Ch := DataTab[I].StrVal[J];
          If (Ord(Ch) < 32) Or (Ord(Ch) > 126) Then
          Begin
            (* Caractere de controle -> emettre en numerique *)
            If InStr Then
            Begin
              S := S + ''',';
              InStr := False;
            End;
            S := S + IntToStr(Ord(Ch)) + ',';
          End
          Else
          Begin
            (* Caractere imprimable *)
            If Not InStr Then
            Begin
              S := S + '''';
              InStr := True;
            End;
            If Ch = '''' Then
              S := S + ''''''
            Else
              S := S + Ch;
          End;
        End;
        If InStr Then
          S := S + ''',';
        (* Ajouter le zero terminal *)
        S := S + '0';
        EmitRaw(DataTab[I].LblName + '  DB  ' + S);
      End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].ElemCount) + ' DUP(0)');
      DK_STRUCT_BLK :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].ElemCount) + ' DUP(0)');
    End;
  End;
  EmitBlankLine;
  EmitRaw('_DATA ENDS');
End;

(* ---- EmitRuntime : emettre les routines runtime ------------- *)
(* Stub pour TODO 22 : les routines runtime seront ajoutees ici  *)
Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('--- Runtime minimal CF86 ---');
  (* TODO 22 : emettre les routines runtime ici *)
  EmitBlankLine;
End;

(* ---- EmitClose : fermer le fichier assembleur --------------- *)
(* Emettre runtime + _TEXT ENDS + DATA + END _CFF_Main           *)
Procedure EmitClose;
Begin
  If Not OutFOpen Then Exit;
  EmitBlankLine;
  EmitComment('--- Fin du code ---');
  EmitEpilog;
  (* Terminaison DOS *)
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT', '21h');
  EmitBlankLine;
  EmitRuntime;
  EmitRaw('_TEXT ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('END ' + CF_FN_PFX + 'Main');
  Close(OutF);
  OutFOpen := False;
End;

{ ============================================================ }
{  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]            }
{ ============================================================ }

{ ---- VarAlloc : allouer une variable dans la table ---------- }
(* Si CurFnDepth > 0, la variable est locale (pile BP).        *)
(* Sinon, la variable est globale (segment DATA, DK_WORD).     *)
(* Retourne l index du symbole ou -1 si erreur.                *)
Function VarAlloc(Const AName : TString; ATypeIdx : Integer) : Integer;
Var
  Idx  : Integer;
  Off  : Integer;
  DIdx : Integer;
  Cat  : TSymCat;
Begin
  If CurFnDepth > 0 Then
  Begin
    { Variable locale : allouee sur la pile [BP-n] }
    Cat := SC_LOCAL;
    Off := SymNextOffset;
    Idx := SymAdd(AName, Cat, ATypeIdx, Off);
    If (Idx >= 0) And (ATypeIdx = TY_IDX_STRING) Then
    Begin
      { Reservons aussi un buffer statique DATA pour les chaines locales }
      DIdx := DataAddWord(SymTab[Idx].MangledName, 0);
      If DIdx >= 0 Then
        DataTab[DIdx].Kind := DK_WORD;
    End;
  End
  Else
  Begin
    { Variable globale : allouee dans le segment DATA }
    Cat := SC_VAR;
    Off := 0;
    Idx := SymAdd(AName, Cat, ATypeIdx, Off);
    If Idx >= 0 Then
    Begin
      { Creer une entree DK_WORD dans DATA pour stocker la valeur }
      DIdx := DataAddWord(SymTab[Idx].MangledName, 0);
      If (DIdx < 0) Then
        CompileError('impossible d''allouer variable DATA : ' + AName);
    End;
  End;
  VarAlloc := Idx;
End;

{ ---- VarAddrOf : retourner la reference ASM d une variable - }
(* Variables locales : [BP-n]                                   *)
(* Variables globales/parametres : [_CFV_nom]                   *)
Function VarAddrOf(SIdx : Integer) : TString;
Var
  S : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    VarAddrOf := '[0]';
    Exit;
  End;
  If SymTab[SIdx].IsLocal And (SymTab[SIdx].Offset < 0) Then
  Begin
    Str(-SymTab[SIdx].Offset, S);
    VarAddrOf := '[BP-' + S + ']';
  End
  Else If SymTab[SIdx].IsArgument And (SymTab[SIdx].Offset > 0) Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    VarAddrOf := '[BP+' + S + ']';
  End
  Else
    VarAddrOf := '[' + SymTab[SIdx].MangledName + ']';
End;

{ ---- VarLoad : charger la valeur d une variable dans AX ---- }
(* Numeriques et booleens : MOV AX, [addr]                     *)
(* Strings et pointeurs   : MOV AX, OFFSET label (global)      *)
(*                          ou LEA AX, [addr] (si pointeur)    *)
Procedure VarLoad(SIdx : Integer);
Var
  Addr : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  Addr := VarAddrOf(SIdx);
  If TypeIsPtr(SymTab[SIdx].TypeIdx) And
     (Not SymTab[SIdx].IsLocal) Then
    EmitInstr('MOV', 'AX, OFFSET ' + SymTab[SIdx].MangledName)
  Else
    EmitInstr('MOV', 'AX, ' + Addr);
End;

{ ---- VarStore : stocker AX dans une variable ---------------- }
(* AX contient la valeur a affecter.                            *)
(* Numeriques : MOV [addr], AX                                 *)
(* Strings    : CALL _CFRT_STRCPY (copie de reference)         *)
Procedure VarStore(SIdx : Integer);
Var
  Addr : TString;
  TK   : TTypeKind;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  Addr := VarAddrOf(SIdx);
  TK := TypeKindOf(SymTab[SIdx].TypeIdx);
  If TK = TKC_STRING Then
  Begin
    { Copie par reference pour les chaines : stocker le pointeur }
    EmitInstr('MOV', Addr + ', AX');
  End
  Else
    EmitInstr('MOV', Addr + ', AX');
End;

{ ---- ParseScopePrefix : extraire le prefixe de portee ------- }
(* Detecte variables.nom, local.nom, arguments.nom              *)
(* Retourne le nom sans prefixe et positionne la categorie.     *)
(* Si pas de prefixe reconnu, retourne le nom tel quel.         *)
Function ParseScopePrefix(Const FullName : TString;
                          Var OutCat : TSymCat) : TString;
Var
  DotPos : Integer;
  Pfx    : TString;
  Rest   : TString;
  I      : Integer;
Begin
  DotPos := 0;
  For I := 1 To Length(FullName) Do
    If FullName[I] = '.' Then
    Begin
      DotPos := I;
      Break;
    End;

  If DotPos > 1 Then
  Begin
    Pfx  := StrLowerCase(Copy(FullName, 1, DotPos - 1));
    Rest := Copy(FullName, DotPos + 1, Length(FullName) - DotPos);
    If Pfx = 'variables' Then
    Begin
      OutCat := SC_VAR;
      ParseScopePrefix := Rest;
      Exit;
    End
    Else If Pfx = 'local' Then
    Begin
      OutCat := SC_LOCAL;
      ParseScopePrefix := Rest;
      Exit;
    End
    Else If Pfx = 'arguments' Then
    Begin
      OutCat := SC_PARAM;
      ParseScopePrefix := Rest;
      Exit;
    End
    Else If (Pfx = 'form') Or (Pfx = 'url') Or (Pfx = 'cgi') Or
            (Pfx = 'application') Or (Pfx = 'session') Or
            (Pfx = 'request') Then
    Begin
      WarnMsg('portee ' + Pfx + ' non supportee en mode DOS, traite comme variables');
      OutCat := SC_VAR;
      ParseScopePrefix := Rest;
      Exit;
    End;
  End;

  { Pas de prefixe de portee reconnu }
  OutCat := SC_VAR;
  ParseScopePrefix := FullName;
End;

{ ---- ParseCfSet : traiter <cfset variable = expression> ----- }
(* Format : <cfset nomVariable = expression>                    *)
(* ou      <cfset variables.nom = expression>                   *)
(* ou      <cfset local.nom = expression>                       *)
(* La variable est creee implicitement si elle n existe pas.     *)
Procedure ParseCfSet;
Var
  VarName   : TString;
  CleanName : TString;
  SIdx      : Integer;
  Res       : TExprVal;
  Cat       : TSymCat;
  FullIdent : TString;
Begin
  EmitComment('---- CFSET ----');

  { Le token courant doit etre un identifiant (nom de variable) }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identifiant attendu apres <cfset>');
    { Consommer jusqu a la fin de la balise }
    While (CurToken.Kind <> TK_TAG_CLOSE) And
          (CurToken.Kind <> TK_TAG_SELFCLOSE) And
          (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_TAG_CLOSE) Or
       (CurToken.Kind = TK_TAG_SELFCLOSE) Then
      ParserAdvance;
    Exit;
  End;

  FullIdent := CurToken.Val;
  ParserAdvance;

  { Gerer la notation par point : scope.variable }
  While (CurToken.Kind = TK_OP) And (CurToken.Val = '.') Do
  Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      FullIdent := FullIdent + '.' + CurToken.Val;
      ParserAdvance;
    End
    Else
    Begin
      CompileError('identifiant attendu apres le point');
      Break;
    End;
  End;

  { Extraire le scope et le nom reel }
  Cat := SC_VAR;
  CleanName := ParseScopePrefix(FullIdent, Cat);
  VarName := CleanName;

  { Verifier l operateur d affectation = }
  If (CurToken.Kind <> TK_OP) Or (CurToken.Val <> '=') Then
  Begin
    CompileError('"=" attendu dans <cfset>');
    While (CurToken.Kind <> TK_TAG_CLOSE) And
          (CurToken.Kind <> TK_TAG_SELFCLOSE) And
          (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_TAG_CLOSE) Or
       (CurToken.Kind = TK_TAG_SELFCLOSE) Then
      ParserAdvance;
    Exit;
  End;
  ParserAdvance;  { consommer = }

  { Evaluer l expression a droite du = (TODO 10 : ParseExpr) }
  ExprMakeNone(Res);
  ParseExpr(Res);

  { Chercher ou creer la variable cible }
  SIdx := SymFind(VarName);
  If SIdx < 0 Then
    SIdx := VarAlloc(VarName, TypeInfer(Res));

  { Generer l affectation }
  If SIdx >= 0 Then
  Begin
    ExprFlushToAX(Res);
    VarStore(SIdx);
  End;

  { Consommer la balise fermante si presente }
  If (CurToken.Kind = TK_TAG_CLOSE) Or
     (CurToken.Kind = TK_TAG_SELFCLOSE) Then
    ParserAdvance;
End;

{ ---- ParseVarDecl : traiter var nom = expr (cfscript) ------- }
(* Syntaxe cfscript : var nomVariable = expression;             *)
(* Cree une variable locale dans la portee courante.            *)
Procedure ParseVarDecl;
Var
  VarName : TString;
  SIdx    : Integer;
  Res     : TExprVal;
Begin
  EmitComment('---- VAR (local) ----');
  { Le token courant est un identifiant (nom de variable) }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identifiant attendu apres var');
    Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;

  { Allocation de variable locale }
  ExprMakeNone(Res);

  { Verifier si affectation avec = }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance;  { consommer = }
    { Evaluer l expression a droite (TODO 10 : ParseExpr) }
    ParseExpr(Res);
  End
  Else
    ExprMakeImm(0, TY_IDX_NUMERIC, Res);

  { Creer la variable locale }
  SIdx := VarAlloc(VarName, TypeInfer(Res));

  { Generer l affectation initiale }
  If SIdx >= 0 Then
  Begin
    ExprFlushToAX(Res);
    VarStore(SIdx);
  End;

  { Consommer le point-virgule si present }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================ }
{  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]                }
{ ============================================================ }

{ ---- ParseCallArgs : parser les arguments d un appel -------- }
(* Consomme la parenthese ouvrante, evalue chaque argument,     *)
(* les empile (PUSH AX) et retourne le nombre d arguments.      *)
(* Gere aussi les arguments nommes : param="val"                *)
Function ParseCallArgs : Integer;
Var
  ArgCount : Integer;
  ArgVal   : TExprVal;
Begin
  ArgCount := 0;
  { La parenthese ouvrante ( est deja verifiee par l appelant }
  ParserAdvance;  { consommer ( }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Note : les arguments nommes (param="val") sont traites comme }
    { des expressions par ParseExpr (ident = val sera evalue).     }
    ParseExpr(ArgVal);
    ExprFlushToAX(ArgVal);
    EmitInstr('PUSH', 'AX');
    Inc(ArgCount);
    { Virgule entre arguments }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  End;
  { Consommer la parenthese fermante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  ParseCallArgs := ArgCount;
End;

{ ---- ParsePrimary : expression primaire ColdFusion ---------- }
(* Gere les atomes du langage d expression :                    *)
(*   - Litteral entier, flottant, chaine                        *)
(*   - Mots-cles booleens (true/false/yes/no) et null           *)
(*   - Identificateur -> variable, acces struct, appel fonction *)
(*   - Parentheses : ( expr )                                   *)
(*   - NOT / ! expr (operateur unaire logique)                  *)
(*   - - expr (negation unaire)                                 *)
(*   - IsDefined("var") -> AX=1 si existe, 0 sinon             *)
(*   - Len(str) -> CALL _CFRT_STRLEN -> AX                     *)
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Name     : TString;
  SIdx     : Integer;
  ArgCount : Integer;
  U        : TString;
  SubExpr  : TExprVal;
  InnerStr : TString;
Begin
  ExprMakeNone(Res);

  { ---- Litteral entier ------------------------------------ }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
  End

  { ---- Litteral flottant (tronque a entier) --------------- }
  Else If CurToken.Kind = TK_FLOAT Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
  End

  { ---- Litteral chaine ------------------------------------ }
  Else If CurToken.Kind = TK_STRING Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
  End

  { ---- Mots-cles booleens / null -------------------------- }
  Else If CurToken.Kind = TK_KEYWORD Then
  Begin
    U := StrUpperCase(CurToken.Val);
    If IsBoolKeyword(CurToken.Val) Or (U = 'NULL') Then
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End
    Else
    Begin
      { Mot-cle non litteral (NOT est gere par ParseUnary) }
      ExprMakeNone(Res);
      ParserAdvance;
    End;
  End

  { ---- Identificateur ------------------------------------- }
  Else If CurToken.Kind = TK_IDENT Then
  Begin
    Name := CurToken.Val;
    U := StrUpperCase(Name);
    ParserAdvance;

    { -- Fonction integree : IsDefined("var") ---------------- }
    If (U = 'ISDEFINED') And
       (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      EmitComment('IsDefined()');
      ParserAdvance;  { consommer ( }
      If CurToken.Kind = TK_STRING Then
      Begin
        InnerStr := CurToken.Val;
        ParserAdvance;  { consommer la chaine }
        SIdx := SymFind(InnerStr);
        If SIdx >= 0 Then
          ExprMakeImm(1, TY_IDX_BOOLEAN, Res)
        Else
          ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else
      Begin
        WarnMsg('IsDefined attend une chaine litterale');
        ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
        { Consommer l argument }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End

    { -- Fonction integree : Len(expr) ---------------------- }
    Else If (U = 'LEN') And
            (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      EmitComment('Len()');
      ArgCount := ParseCallArgs;
      EmitInstr('POP', 'SI');  { recuperer l argument (pointeur chaine) }
      EmitInstr('CALL', CF_RT_PFX + 'STRLEN');
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_NUMERIC;
      Res.SymIdx  := -1;
    End

    { -- Appel de fonction utilisateur : nom( args ) --------- }
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      EmitComment('appel ' + Name);
      ArgCount := ParseCallArgs;
      { Appeler la fonction }
      EmitInstr('CALL', CF_FN_PFX + SymNameClean(Name));
      { Nettoyer la pile : ArgCount * 2 octets }
      If ArgCount > 0 Then
      Begin
        Str(ArgCount * 2, InnerStr);
        EmitInstr('ADD', 'SP, ' + InnerStr);
      End;
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_ANY;
      Res.SymIdx  := -1;
    End

    { -- Acces membre par point : struct.cle ---------------- }
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '.') Then
    Begin
      { Construire le nom complet scope.member }
      While (CurToken.Kind = TK_OP) And (CurToken.Val = '.') Do
      Begin
        ParserAdvance;  { consommer . }
        If CurToken.Kind = TK_IDENT Then
        Begin
          Name := Name + '.' + CurToken.Val;
          ParserAdvance;
        End
        Else
        Begin
          CompileError('identifiant attendu apres "."');
          Break;
        End;
      End;
      { Rechercher comme nom complet (scope.variable) }
      SIdx := SymFind(Name);
      If SIdx >= 0 Then
      Begin
        VarLoad(SIdx);
        Res.Kind    := EK_AX;
        Res.TypeIdx := SymTab[SIdx].TypeIdx;
        Res.SymIdx  := SIdx;
      End
      Else
      Begin
        WarnMsg('membre non resolu : ' + Name);
        ExprMakeImm(0, TY_IDX_ANY, Res);
      End;
    End

    { -- Acces par crochet : struct["cle"] ou array[i] ------ }
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      EmitComment('acces [] : ' + Name);
      SIdx := SymFind(Name);
      ParserAdvance;  { consommer [ }
      ParseExpr(SubExpr);
      { Fermer le crochet }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        ParserAdvance;
      { Si c est un tableau : calculer l offset }
      If (SIdx >= 0) And (TypeKindOf(SymTab[SIdx].TypeIdx) = TKC_ARRAY) Then
      Begin
        { AX = index, multiplier par 2 (16-bit words) }
        ExprFlushToAX(SubExpr);
        EmitInstr('SHL', 'AX, 1');
        EmitInstr('MOV', 'BX, AX');
        EmitInstr('MOV', 'AX, OFFSET ' + SymTab[SIdx].MangledName);
        EmitInstr('ADD', 'BX, AX');
        EmitInstr('MOV', 'AX, [BX]');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_ANY;
        Res.SymIdx  := -1;
      End
      { Si c est un struct : appeler le runtime }
      Else If (SIdx >= 0) And (TypeKindOf(SymTab[SIdx].TypeIdx) = TKC_STRUCT) Then
      Begin
        VarLoad(SIdx);
        EmitInstr('MOV', 'SI, AX');
        ExprFlushToAX(SubExpr);
        EmitInstr('MOV', 'DI, AX');
        EmitInstr('CALL', CF_RT_PFX + 'STRUCTGET');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_ANY;
        Res.SymIdx  := -1;
      End
      Else
      Begin
        { Variable non trouvee ou type inconnu }
        ExprFlushToAX(SubExpr);
        WarnMsg('acces [] sur variable non resolue : ' + Name);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_ANY;
        Res.SymIdx  := -1;
      End;
    End

    { -- Variable simple ------------------------------------ }
    Else
    Begin
      SIdx := SymFind(Name);
      If SIdx >= 0 Then
      Begin
        VarLoad(SIdx);
        Res.Kind    := EK_AX;
        Res.TypeIdx := SymTab[SIdx].TypeIdx;
        Res.SymIdx  := SIdx;
      End
      Else
      Begin
        WarnMsg('variable non definie : ' + Name);
        ExprMakeImm(0, TY_IDX_NUMERIC, Res);
      End;
    End;
  End

  { ---- Parentheses ( expr ) ------------------------------- }
  Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer ( }
    ParseExpr(SubExpr);
    Res := SubExpr;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End

  { ---- Token non reconnu (unaires geres par ParseUnary) --- }
  Else
  Begin
    ExprMakeNone(Res);
  End;
End;

{ ---- ParseUnary : operateur unaire avant ParsePrimary ------- }
(* Traite les prefixes unaires NOT, !, -, + puis ParsePrimary  *)
Procedure ParseUnary(Var Res : TExprVal);
Var
  U : TString;
Begin
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    U := StrUpperCase(CurToken.Val);
    If U = 'NOT' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      ExprEmitUnary('NOT', Res);
      Exit;
    End;
  End;
  If CurToken.Kind = TK_OP Then
  Begin
    If CurToken.Val = '!' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      ExprEmitUnary('!', Res);
      Exit;
    End
    Else If CurToken.Val = '-' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      ExprEmitUnary('-', Res);
      Exit;
    End
    Else If CurToken.Val = '+' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      Exit;
    End;
  End;
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : parseur Pratt a precedence ------------ }
(* Boucle sur les operateurs binaires tant que leur precedence  *)
(* est >= MinPrec.  Utilise ExprEmitBinOp pour la generation.   *)
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op    : TString;
  Prec  : Integer;
  Right : TExprVal;
  NextP : Integer;
Begin
  ParseUnary(Res);
  While (CurToken.Kind <> TK_EOF) And IsCFBinOp(CurToken) Do
  Begin
    Op := CurToken.Val;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
    ParserAdvance;  { consommer l operateur }
    If BinOpIsRight(Op) Then
      NextP := Prec
    Else
      NextP := Prec + 1;
    ExprMakeNone(Right);
    ParseExprPrec(NextP, Right);
    ExprEmitBinOp(Op, Res, Right);
  End;
End;

{ ---- ParseExpr : point d entree d evaluation d expression --- }
(* Appelle ParseExprPrec avec la precedence minimale = 1.       *)
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

Procedure ParsePage;
Var
  TagLower : TString;
Begin
  While CurToken.Kind <> TK_EOF Do
  Begin
    { Balise CF ouvrante }
    If CurToken.Kind = TK_TAG_OPEN Then
    Begin
      TagLower := StrLowerCase(CurToken.Val);
      If TagLower = 'cfset' Then
      Begin
        ParserAdvance;  { consommer <cfset }
        ParseCfSet;
      End
      Else
        ParserAdvance;  { balise non reconnue - passer }
    End
    { Mot-cle var en mode cfscript }
    Else If (CurToken.Kind = TK_KEYWORD) And
            (StrLowerCase(CurToken.Val) = 'var') Then
    Begin
      ParserAdvance;  { consommer var }
      ParseVarDecl;
    End
    Else
      ParserAdvance;  { token non traite - avancer }
  End;
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
  DataInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  { Point d entree programme }
  EmitComment('Point d''entree programme CF86');
  EmitLabel(CF_FN_PFX + 'Main');
  EmitProlog;
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;

  ParserAdvance;
  ParsePage;

  LexClose;
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
