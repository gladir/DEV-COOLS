{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur PSP (Pascal Server Pages) vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  PSPCW32.PAS - Compilateur Pascal Server Pages vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de PSP86.PAS et les exemples
  SAMPLES\PSP\*

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.psp [-o sortie] [-v] [-d]
              [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .psp du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR PSP (TOKENS PASCAL ET BALISES HTML)
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_CHAR,
              TK_STRING, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT,
              TK_HTML, TK_PSP_OPEN, TK_PSP_CLOSE, TK_PSP_EXPR_OPEN,
              TK_PSP_DIRECTIVE
            TPSPMode : TPL_HTML (texte HTML), TPL_CODE (code Pascal)
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            TplNextToken : aiguillage HTML / code selon TPSPMode
              En mode TPL_HTML : accumuler le texte HTML jusqu a <% ou EOF
              Detecter <% (code), <%= (expression inline), <%@ (directive)
              En mode TPL_CODE : lexer les tokens Pascal jusqu a %>
            LexScanString : chaine entre apostrophes 'abc' avec '' echappement
            LexScanChar : notation #65 ou #$41 (caractere ASCII)
            Commentaires : accolades, parenthese-etoile, double-slash //
            Mots-cles Pascal : AND ARRAY BEGIN BREAK CASE CONST CONTINUE
              DIV DO DOWNTO ELSE END EXCEPT EXIT FINALLY FOR FORWARD
              FUNCTION IF MOD NOT OF OR PROCEDURE PROGRAM RAISE
              RECORD REPEAT RESULT SHL SHR THEN TO TRY TYPE UNTIL
              VAR WHILE WITH XOR
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..2147483647 (32 bits signe)
            Entiers hexadecimaux : $FF, $DEADBEEF (prefixe $)
            Reels : reconnus par le lexeur, tronques en entiers (avertissement)
            Caracteres : #65 ou #$41 -> valeur ordinale dans EAX
            Chaines : 'abc' -> pointeur vers donnees .DATA (ASCIIZ)
              Apostrophe echappee : '' -> un seul caractere '
            Constantes nommees : CONST name = expr;
            Constantes typees : CONST name: Type = expr; (en .DATA)
            NIL : pointeur nul -> EAX=0
            TRUE : booleen -> EAX=1
            FALSE : booleen -> EAX=0

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques  : + - * / DIV MOD (entiers 32 bits)
            Comparaison    : = <> < > <= >=
            Logiques       : AND OR NOT (court-circuit)
            Bits           : AND OR XOR NOT SHL SHR (selon contexte)
            Concatenation  : + (si un operande est String -> _PSPRT_CONCAT)
            Unaire         : + - (signe) NOT (negation logique/bits)
              @ (adresse-de -> LEA EAX,[var])
            Affectation    : := (assignation)
            Precedence (du plus fort au plus faible) :
              1. NOT, unaire +/-, @
              2. * / DIV MOD AND SHL SHR
              3. + - OR XOR
              4. = <> < > <= >= IN

  TODO 05 - TABLE DES SYMBOLES
            TSymCat : SC_VAR, SC_CONST, SC_TYPED_CONST, SC_PARAM,
              SC_VARPARAM, SC_FUNC, SC_PROC, SC_TYPE, SC_FIELD,
              SC_ENUM_VAL, SC_LABEL
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              ScopeLevel, ScopeId, IsForward, IsLocal, ImmVal, DataIdx,
              ParamCnt, VarParamMask
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Prefixes de nommage ASM 32 bits :
              _PSP_ (variable), _PSPF_ (fonction), _PSPK_ (chaine),
              _PSPRT_ (runtime), _PSPL_ (label), _PSPA_ (tableau),
              _PSPR_ (record), _PSPE_ (enum), _PSPX_ (exception)
            Predeclarations des procedures et fonctions standards

  TODO 06 - SYSTEME DE TYPES (32 BITS)
            TTypeKind : TKP_INTEGER (32 bits signe), TKP_WORD (32 bits
              non signe), TKP_BYTE (8 bits), TKP_CHAR (8 bits),
              TKP_BOOLEAN (8 bits etendu 32), TKP_STRING (ptr ASCIIZ 32),
              TKP_REAL (tronque en entier 32 bits), TKP_ARRAY,
              TKP_RECORD, TKP_ENUM, TKP_SUBRANGE, TKP_POINTER (32 bits),
              TKP_NIL, TKP_TEXT (handle fichier 32 bits), TKP_VOID
            TypeTab, TypeInit : enregistrer les types primitifs et utilisateur
            TypeSizeof : INTEGER=4, WORD=4, BYTE=1, CHAR=1, BOOLEAN=1,
              STRING=4 (ptr), POINTER=4, TEXT=4
            TypeCanCoerce : Byte<->Integer, Char<->Integer, Boolean->Integer,
              nil->tout pointeur/String, Real<->Integer, Enum->Integer
            TypeCoerceResult : promotion vers le type le plus large
            TypeInfer, TypeLookupName (insensible a la casse)

  TODO 07 - EMETTEUR DE CODE ASM 80386
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PSPL_NNNNN)
            EmitHeader : .386 / .MODEL FLAT, STDCALL / OPTION CASEMAP:NONE
              INCLUDE windows.inc (ou declarations EXTRN manuelles)
              .STACK 4096
              Declarations EXTRN pour API Win32 :
                ExitProcess, GetStdHandle, WriteFile, ReadFile,
                GetProcessHeap, HeapAlloc, HeapFree
              _TEXT SEGMENT DWORD PUBLIC 'CODE' / ASSUME CS:_TEXT
              Point d entree _PSPF_main
            EmitProlog / EmitEpilog : PUSH EBP / MOV EBP,ESP / SUB ESP,n
              et MOV ESP,EBP / POP EBP / RET
            EmitDataSeg : .DATA SEGMENT ... avec variables et litteraux
            Mode -asm : ecrire le fichier .ASM lisible avec commentaires

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_DWORD/DK_BYTE/DK_STR/DK_ARRAY/
              DK_REC), IntVal, StrVal, ElemCount, ElemSize, RecSize
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray, DataAddRecord
            Variables globales : entrees DK_DWORD (32 bits) dans .DATA
            Constantes typees : entrees DK_DWORD ou DK_STR (immuables)
            Chaines litterales : DB 'abc',0 avec label _PSPK_N
            Fragments HTML : DB '...',0 avec label _PSPK_HTML_N
            Tampons runtime : _PSPRT_STRBUF (512), _PSPRT_NUMBUF (12),
              _PSPRT_CHRBUF (2), _PSPRT_CRLF DB 13,10,0
            Handles stdout : _PSPRT_HSTDOUT DD 0 (initialise au demarrage)

  TODO 09 - VARIABLES ET AFFECTATIONS (32 BITS)
            Variables globales : segment .DATA, acces par label _PSP_nom
              MOV EAX,[_PSP_nom] / MOV [_PSP_nom],EAX
            Variables locales : pile EBP, acces [EBP-offset]
              Taille 4 octets par defaut (DWORD), 1 pour Byte/Char/Boolean
            Parametres VALUE : copie sur pile (comme variable locale)
            Parametres VAR : passage par adresse (pointeur 32 bits sur pile)
            Affectation := : ExprFlushToEAX + MOV [destination], EAX
            Adressage 32 bits : [EBP-n] pour locales, [EBP+n] pour params
            ExprAddrOf, ExprStore, ExprLoad, ExprFlushToEAX
            DeclAllocGlobal / DeclAllocLocal

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, literal char,
              TRUE, FALSE, NIL, identificateur, appel de fonction,
              expression parenthesee (expr)
            Acces variable : SymFind -> ExprLoad (MOV EAX,[addr])
            Acces champ record : expr.champ -> offset dans RECORD
            Acces index tableau : expr[i] -> calcul offset 32 bits
            Appel de fonction : ParseCallArgs (PUSH args) + CALL _PSPF_fn
              Convention STDCALL : arguments droite a gauche, callee cleanup
            Fonctions predefinies en ligne :
              Length, Ord, Chr, Lo, Hi, Swap, SizeOf, Low, High,
              Abs, Sqr, Odd, Succ, Pred, Inc, Dec
            Expression en ligne PSP : <%= expr %> -> evaluer et ecrire

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt parser)
            Arithmetique entiere 32 bits : ADD/SUB/IMUL/IDIV pour +,-,*,DIV
            MOD : IDIV -> resultat dans EDX (reste)
            Division / : IDIV avec resultat dans EAX (quotient)
            Comparaison : CMP + Jcc (JE/JNE/JL/JG/JLE/JGE) -> SETcc + MOVZX
            Comparaison chaines : CALL _PSPRT_STRCMP -> CMP EAX,0 + Jcc
            Concatenation chaines : + -> CALL _PSPRT_CONCAT(ESI,EDI) -> EAX
            Logique AND : court-circuit TEST EAX,EAX / JZ vers false
            Logique OR : court-circuit TEST EAX,EAX / JNZ vers true
            Logique NOT : XOR EAX,1 (booleen) ou NOT EAX (bits)
            Bits : AND/OR/XOR EAX,EBX / SHL EAX,CL / SHR EAX,CL
            Repli de constantes (constant folding) pour operandes immediats

  TODO 12 - ENTREES/SORTIES (Write / WriteLn / Read / ReadLn)
            Ecriture via API Win32 WriteFile :
              GetStdHandle(STD_OUTPUT_HANDLE) -> _PSPRT_HSTDOUT
              WriteFile(hStdOut, ptr, len, &written, NULL)
            Write(expr1, expr2, ...) : evaluer chaque argument,
              convertir en chaine selon le type :
              Integer -> CALL _PSPRT_NUMTOSTR / String -> directement /
              Char -> CALL _PSPRT_CHR / Boolean -> 'TRUE'|'FALSE'
              Puis CALL _PSPRT_PRINTSTR pour chaque argument
            WriteLn([args]) : comme Write + ecriture CR+LF
            Format :width -> stocke mais ignore (avertissement)
            Read(var) : ReadFile depuis STD_INPUT_HANDLE
              Type Char/String -> lire un caractere -> variable
              Type Integer -> lire chaine + CALL _PSPRT_STRTONUM
            ReadLn(var) : Read + consommer jusqu a CR+LF
            Expression inline <%= expr %> : evaluer, convertir, ecrire

  TODO 13 - IF / CASE / BLOCS BEGIN..END
            ParseIfStmt : IF cond THEN stmt [ELSE stmt]
              Emission TEST EAX,EAX / JZ pour condition fausse
              Labels : _PSPL_ELSE_N, _PSPL_ENDIF_N
              Gestion du dangling else (attachement au if le plus proche)
            ParseCaseStmt : CASE expr OF val: stmt; [val: stmt;] [ELSE stmt] END
              Valeurs simples : CMP EAX,val / JE label_branche
              Intervalles : val1..val2 -> CMP EAX,val1 / JL skip /
                CMP EAX,val2 / JG skip -> JMP branche
              Valeurs multiples : val1, val2, val3 : stmt
              Labels : _PSPL_CASE_N, _PSPL_CEND_N
            ParseBlock : BEGIN stmt [; stmt] END

  TODO 14 - BOUCLES : FOR / WHILE / REPEAT / BREAK / CONTINUE
            ParseForStmt : FOR id := lo TO|DOWNTO hi DO stmt
              Variable locale ou globale comme compteur
              TO : increment par INC EAX / CMP EAX,hi / JLE boucle
              DOWNTO : decrement par DEC EAX / CMP EAX,lo / JGE boucle
              Labels : _PSPL_FTEST_N, _PSPL_FINCR_N, _PSPL_FEND_N
            ParseWhileStmt : WHILE cond DO stmt
              Labels : _PSPL_WTEST_N, _PSPL_WEND_N
            ParseRepeatStmt : REPEAT stmts UNTIL cond
              Labels : _PSPL_RBEG_N, _PSPL_RTEST_N
            BREAK : JMP vers label de fin de boucle englobante
            CONTINUE : JMP vers label de test/increment de boucle
            LoopPush / LoopPop : pile de labels pour break/continue
              (max MAX_LOOP_NEST niveaux d imbrication)

  TODO 15 - TABLEAUX (ARRAY)
            ARRAY [lo..hi] OF T : tableau a bornes fixes
              Taille = (hi - lo + 1) * sizeof(T) en 32 bits
              Acces : MOV EAX,[base + (index - lo) * elemsize]
              Adresse : LEA EAX,[_PSPA_nom + offset]
            Variables tableau globales : bloc dans .DATA (DK_ARRAY)
            Variables tableau locales : reserve sur pile [EBP-offset]
            Lecture element : ParseArrayAccess -> calcul index 32 bits
            Ecriture element : arr[i] := expr -> MOV [addr],EAX
            Length(arr) : constante hi - lo + 1
            Low(arr) : constante lo
            High(arr) : constante hi
            SizeOf(arr) : constante (hi - lo + 1) * sizeof(element)
            Verification de bornes (optionnelle) : CMP + JB/JAE -> erreur

  TODO 16 - ENREGISTREMENTS (RECORD) ET WITH
            TYPE TRec = RECORD champ1: T1; champ2: T2; ... END;
              Taille = somme des sizeof(Ti) alignes sur 4 octets
              Acces champ : offset fixe depuis debut du record
              Records globaux : bloc dans .DATA (DK_REC)
              Records locaux : reserve sur pile [EBP-offset]
            Lecture champ : MOV EAX,[base + field_offset]
            Ecriture champ : MOV [base + field_offset],EAX
            Acces imbrique : rec.champ1.champ2 -> offsets cumules
            ParseWithStmt : WITH RecVar DO stmt
              Empiler le record courant sur la pile WITH
              Les champs du record sont accessibles sans prefixe
              Imbrication max : MAX_WITH niveaux
            Passage de records en parametre : par adresse (pointeur)

  TODO 17 - ENUMERATIONS ET SOUS-INTERVALLES
            TYPE TEnum = (Val1, Val2, Val3, ...);
              Valeurs ordinales automatiques 0, 1, 2, ...
              Chaque valeur ajoutee a la table des symboles (SC_ENUM_VAL)
              Ord(EnumVal) -> constante immediate
              Utilisable dans CASE OF et comparaisons
            TYPE TSubRange = lo..hi;
              Sous-intervalle d un type ordinal
              Lo et Hi stockes dans TTypeRec
              Verification optionnelle de bornes a l execution
            Low(T) : borne inferieure du type/tableau
            High(T) : borne superieure du type/tableau
            Succ(x) : ADD EAX,1
            Pred(x) : SUB EAX,1

  TODO 18 - PROCEDURES ET FONCTIONS
            ParseProcDecl / ParseFuncDecl :
              PROCEDURE nom[(params)]; [declarations] BEGIN stmts END;
              FUNCTION nom[(params)]: Type; [declarations] BEGIN stmts END;
            Parametres par valeur : copie DWORD sur pile
            Parametres VAR : LEA + PUSH adresse (pointeur 32 bits)
            Parametres multiples meme type : a, b, c: Integer
            Convention d appel : STDCALL (callee nettoie la pile)
              Arguments empiles droite a gauche
              Retour dans EAX
            Prologue : PUSH EBP / MOV EBP,ESP / SUB ESP,locals_size
              PUSH ESI / PUSH EDI (sauvegarde registres)
            Epilogue : POP EDI / POP ESI / MOV ESP,EBP / POP EBP / RET n
            FORWARD : declaration anticipee (resolue plus tard)
            EXIT : retour premature -> JMP vers label epilogue
            Retour fonction : Name := expr ou Result := expr -> MOV EAX,val
            Variables locales : VAR dans le bloc de la procedure/fonction
            Constantes locales : CONST dans le bloc
            Procedures/fonctions imbriquees (max NEST_MAX niveaux)
              Acces au cadre englobant via lien statique

  TODO 19 - TEMPLATE PSP (HTML / <%  %> / <%= %> / <%@ %>)
            Mode template PSP : alternance HTML / code Pascal
            Texte HTML statique : accumule et emis via _PSPRT_PRINTSTR
              Chaque fragment recoit un label _PSPK_HTML_N dans .DATA
              Emission : PUSH OFFSET _PSPK_HTML_N / CALL _PSPRT_PRINTSTR
            Balise <% ... %> : bloc de code Pascal (instructions)
              Transition TPL_HTML -> TPL_CODE sur <%
              Transition TPL_CODE -> TPL_HTML sur %>
            Balise <%= expr %> : expression inline
              Evaluer l expression, convertir en chaine, ecrire sur stdout
              Types : Integer -> _PSPRT_NUMTOSTR / String -> directement /
                Boolean -> 'TRUE'|'FALSE' / Char -> _PSPRT_CHR
            Balise <%@ attr="val" %> : directive de page
              ContentType="text/html" -> ecrire entete HTTP Content-Type
              Include="file.inc" -> inclure un fichier source
              Language="pascal" -> reconnu et ignore (toujours Pascal)
              CodePage="..." -> reconnu, avertissement (non supporte)
            Gestion du programme principal implicite :
              Si pas de PROGRAM..BEGIN..END, le template est le programme
              Le code entre <% %> forme le corps du programme principal

  TODO 20 - DIRECTIVES DE COMPILATION
            [$I fichier] ou [$INCLUDE fichier] : inclusion de fichier
              Profondeur maximale : MAX_INCLUDE niveaux
              Sauvegarde/restauration de l etat du lexeur
            [$DEFINE nom] : definir un symbole de compilation
            [$UNDEF nom] : supprimer un symbole de compilation
            [$IFDEF nom] : compilation conditionnelle (si defini)
            [$IFNDEF nom] : compilation conditionnelle (si non defini)
            [$ELSE] : branche alternative de la condition
            [$ENDIF] : fin du bloc conditionnel
            [$MODE TP|FPC] : mode de compatibilite (reconnu, ignore)
            Table des defines : MAX_DEFINE entrees
            Commentaires avec directives : accolades peuvent contenir $directives
            Imbrication conditionnelle supportee

  TODO 21 - EXCEPTIONS (TRY / EXCEPT / FINALLY / RAISE)
            ParseTryStmt : TRY stmts EXCEPT [handler] [FINALLY stmts] END
              TRY : sauvegarder ancien handler, installer nouveau
                MOV [_PSPX_HANDLER], OFFSET _PSPL_EXCEPT_N
                MOV [_PSPX_SAVEESP], ESP
                MOV [_PSPX_SAVEEBP], EBP
              EXCEPT : label _PSPL_EXCEPT_N
                Restaurer ESP et EBP depuis sauvegardes
                Restaurer ancien handler
                ON E: ExceptionType DO stmt (optionnel, pattern matching)
              FINALLY : label _PSPL_FINALLY_N
                Execute dans tous les cas (succes ou exception)
                Restaurer ancien handler
            RAISE [expr] : lever une exception
              MOV EAX, code_exception
              JMP [_PSPX_HANDLER] (saut vers handler actif)
              Si pas de handler : CALL _PSPRT_PANIC
            Donnees exception dans .DATA :
              _PSPX_HANDLER DD 0 (adresse handler courant)
              _PSPX_SAVEESP DD 0 (ESP sauvegarde)
              _PSPX_SAVEEBP DD 0 (EBP sauvegarde)
            _PSPRT_PANIC : affiche message d erreur + ExitProcess(1)

  TODO 22 - FONCTIONS DE CHAINES ET RUNTIME STRING
            Fonctions de chaines (appels runtime 32 bits) :
              Length(s)         -> CALL _PSPRT_STRLEN(ESI=s) -> EAX
              Copy(s, pos, len) -> CALL _PSPRT_COPY(ESI,EBX,ECX) -> EAX
              Pos(sub, s)       -> CALL _PSPRT_POS(ESI,EDI) -> EAX (1-base)
              Concat(s1, s2)    -> CALL _PSPRT_CONCAT(ESI,EDI) -> EAX
              Ord(c)            -> MOVZX EAX,BYTE PTR [c]
              Chr(n)            -> CALL _PSPRT_CHR -> EAX=ptr chaine 1 car
              IntToStr(n)       -> CALL _PSPRT_NUMTOSTR -> EAX=ptr
              StrToInt(s)       -> CALL _PSPRT_STRTONUM -> EAX=valeur
              UpCase(c)         -> inline CMP/SUB pour a-z -> A-Z
              LowerCase(s)      -> CALL _PSPRT_LOWERCASE -> EAX=ptr
              Trim(s)           -> CALL _PSPRT_TRIM -> EAX=ptr
              Delete(s, p, n)   -> CALL _PSPRT_DELETE (modifie en place)
              Insert(sub, s, p) -> CALL _PSPRT_INSERT (modifie en place)
            Procedures de conversion :
              Str(n, s)         -> _PSPRT_NUMTOSTR + copie dans s
              Val(s, n, code)   -> _PSPRT_STRTONUM + code d erreur
            Fonctions memoire :
              New(ptr)          -> HeapAlloc(GetProcessHeap, 0, size) -> EAX
              GetMem(ptr, size) -> HeapAlloc -> EAX
              Dispose(ptr)      -> HeapFree(GetProcessHeap, 0, ptr)
              FreeMem(ptr, sz)  -> HeapFree
              FillChar(v, n, c) -> REP STOSB (EDI=v, ECX=n, AL=c)
              Move(src, dst, n) -> REP MOVSB (ESI=src, EDI=dst, ECX=n)
            Fonctions mathematiques :
              Abs(n)            -> CDQ / XOR EAX,EDX / SUB EAX,EDX
              Sqr(n)            -> IMUL EAX,EAX
              Sqrt(n)           -> Newton-Raphson entier 32 bits
              Random / Random(n)-> LCG 32 bits (IMUL+ADD seed)
              Randomize         -> GetTickCount ou RDTSC pour seed
              Odd(n)            -> TEST EAX,1
              Inc(v[,n])        -> ADD [v],n (defaut n=1)
              Dec(v[,n])        -> SUB [v],n (defaut n=1)

  TODO 23 - GENERATION DE FICHIERS PE (.EXE) ET COFF (.OBJ)
            Mode par defaut (-exe implicite) : produire un fichier .EXE
              Generation directe du format PE (Portable Executable) :
              DOS Stub (MZ header + message 'This program requires Win32')
              PE Signature ('PE\0\0')
              COFF File Header (Machine=014Ch i386, NumberOfSections)
              Optional Header (PE32, AddressOfEntryPoint, ImageBase=00400000h,
                SectionAlignment=1000h, FileAlignment=200h,
                SizeOfImage, SizeOfHeaders, Subsystem=IMAGE_SUBSYSTEM_WINDOWS_CUI)
              Section .text : code executable (Characteristics=60000020h)
              Section .data : donnees initialisees (Characteristics=C0000040h)
              Section .rdata : table d importation (Import Directory)
              Import Directory : entree pour KERNEL32.DLL
                Import Lookup Table -> Hint/Name entries pour chaque API
                Import Address Table (IAT) patchee par le loader
                APIs importees : ExitProcess, GetStdHandle, WriteFile,
                  ReadFile, GetProcessHeap, HeapAlloc, HeapFree,
                  GetTickCount
              Relocalisation des adresses : calcul RVA pour chaque reference
              Alignement des sections sur FileAlignment (padding)
            Mode -obj : produire uniquement un fichier COFF .OBJ
              COFF Object File : File Header + Sections + Symbol Table
              Sections : .text (code), .data (donnees)
              Table des symboles COFF : noms publics et externes
              Table des relocalisations : fixups pour le linker
              Symboles EXTERNAL pour les API Win32 (resolution par linker)
            Mode -asm : produire un listing .ASM en plus du binaire
              Fichier texte MASM compatible (.386 / .MODEL FLAT)
              Commentaires descriptifs pour chaque section

  TODO 24 - RUNTIME MINIMAL WIN32
            Initialisation au demarrage (_PSPF_main) :
              CALL GetStdHandle(STD_OUTPUT_HANDLE=-11)
              MOV [_PSPRT_HSTDOUT], EAX
              CALL GetStdHandle(STD_INPUT_HANDLE=-10)
              MOV [_PSPRT_HSTDIN], EAX
            _PSPRT_PRINTSTR(ESI=ptr ASCIIZ) :
              Calculer longueur (REPNE SCASB)
              PUSH 0 / LEA EAX,[EBP-4] / PUSH EAX / PUSH ECX (len)
              PUSH ESI / PUSH [_PSPRT_HSTDOUT] / CALL WriteFile
            _PSPRT_NUMTOSTR(EAX=n, EDI=buf) :
              Entier signe 32 bits -> ASCII decimal dans NUMBUF
              Gestion du signe negatif (NEG + prefixe '-')
              Division successive par 10, stockage inverse
            _PSPRT_STRTONUM(ESI=str) -> EAX :
              ASCII decimal -> entier signe 32 bits
              Gestion du signe et des espaces en tete
            _PSPRT_STRLEN(ESI=str) -> EAX : longueur ASCIIZ
            _PSPRT_CONCAT(ESI=s1, EDI=s2) -> EAX=ptr STRBUF :
              Copier s1 puis s2 dans _PSPRT_STRBUF
            _PSPRT_STRCMP(ESI=s1, EDI=s2) -> EAX (signe) :
              Comparaison lexicographique octet par octet
            _PSPRT_CHR(AL=code) -> EAX=ptr CHRBUF :
              Caractere unique en chaine ASCIIZ de 1 octet
            _PSPRT_COPY(ESI=str, EBX=pos, ECX=len) -> EAX=ptr :
              Extraction de sous-chaine (1-base)
            _PSPRT_POS(ESI=sub, EDI=str) -> EAX :
              Recherche de sous-chaine (1-base, 0 si non trouve)
            _PSPRT_DELETE(ESI=str, EBX=pos, ECX=len) :
              Suppression en place dans la chaine
            _PSPRT_INSERT(ESI=sub, EDI=str, EBX=pos) :
              Insertion en place dans la chaine
            _PSPRT_LOWERCASE(ESI=str) -> EAX=ptr STRBUF :
              Conversion minuscules dans tampon
            _PSPRT_TRIM(ESI=str) -> EAX=ptr STRBUF :
              Suppression espaces debut/fin
            _PSPRT_SQRT(EAX=n) -> EAX : racine carree entiere Newton-Raphson
            _PSPRT_RANDOM -> EAX : LCG 32 bits (seed * 1103515245 + 12345)
            _PSPRT_RANDOMIZE : seed depuis GetTickCount
            _PSPRT_FILLCHAR(EDI=ptr, ECX=count, AL=val) : REP STOSB
            _PSPRT_MOVE(ESI=src, EDI=dst, ECX=count) : REP MOVSB
            _PSPRT_PANIC(ESI=msg) : ecrire message + PUSH 1 / CALL ExitProcess
            _PSPRT_PANIC_DIV0 : 'Runtime error: Division by zero'
            Donnees runtime dans .DATA :
              _PSPRT_HSTDOUT DD 0 / _PSPRT_HSTDIN DD 0
              _PSPRT_CRLF DB 13,10,0
              _PSPRT_TRUE_S DB 'TRUE',0 / _PSPRT_FALSE_S DB 'FALSE',0
              _PSPRT_STRBUF DB 512 DUP(0)
              _PSPRT_CHRBUF DB 0,0 / _PSPRT_NUMBUF DB 12 DUP(0)
              _PSPRT_SEED DD 0 / _PSPRT_DIV0MSG DB '...',0
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : finaliser le fichier de sortie
              Mode ASM : END _PSPF_main dans _TEXT ENDS / .DATA ENDS
              Mode OBJ : ecrire les sections COFF et table des symboles
              Mode EXE : ecrire les sections PE, import table, padding
            Run : pipeline complet
              ParseArgs -> LexInit -> TplNextToken boucle ->
              ParseProgram (ou mode template implicite) ->
              EmitRuntime -> Finaliser sections -> Ecrire fichier
            Statistiques (-v) : lignes lues, symboles, erreurs, avertissements
            Compatibilite avec tous les exemples SAMPLES\PSP\ :
              hello.psp        (HTML + Write, boucle for, WriteLn)
              test_expr.psp    (expressions arithmetiques, comparaisons)
              test_var.psp     (variables, affectations, constantes)
              test_const.psp   (constantes nommees et typees)
              test_if.psp      (if/then/else, case/of, imbrication)
              test_case.psp    (case avec valeurs multiples, intervalles)
              test_loop.psp    (for/while/repeat, break, continue)
              test_func.psp    (fonctions, procedures, forward, exit)
              test_function.psp(fonctions avec Result, parametres var)
              test_types.psp   (types definis par l utilisateur)
              test_string.psp  (operations sur chaines, concatenation)
              test_str.psp     (fonctions de chaines Length/Copy/Pos)
              test_array.psp   (tableaux, acces par index, Length/Low/High)
              test_record.psp  (records, acces champs, with)
              test_enum.psp    (enumerations, Ord, case)
              test_scope.psp   (portees imbriquees, masquage de variables)
              test_write.psp   (Write/WriteLn multi-arguments, types mixtes)
              test_directives.psp (DEFINE/IFDEF/INCLUDE, conditionnels)
              test_include.psp (inclusion de fichiers $I)
              test_errors.psp  (gestion d erreurs, messages)
              test_runtime.psp (fonctions runtime, chaines, math)
              test_stdlib.psp  (fonctions standard Abs/Sqr/Random)
              test_sym.psp     (table des symboles, scopes)
              test_lex.psp     (tokens, commentaires, litteraux)
              test_expr11.psp  (expressions complexes, precedence)
              test_arith.psp   (arithmetique, division, modulo)
              calculcalciumcorrige.psp (fonction Real, calcul medical)
            Smoke tests : PSPCW32.EXE [-v] SAMPLES\PSP\*.psp

  ============================================================ *)

Program PSPCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PSPCW32_VERSION = '1.0';
  PSPCW32_DATE    = '2026-03-07';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_INCLUDE   = {$IFDEF FPC}8{$ELSE}4{$ENDIF};     { profondeur max d inclusion }
  MAX_DEFINE    = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { nombre max de symboles de compilation }
  MAX_FIELD     = {$IFDEF FPC}32{$ELSE}16{$ENDIF};    { champs max par record }
  MAX_ENUM      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { valeurs max par enumeration }
  MAX_WITH      = 8;     { profondeur max de with imbrique }
  STACK_SIZE    = 4096;  { taille pile Win32 }
  FRAME_WARN    = 512;   { seuil avertissement taille cadre (octets) }
  NEST_MAX      = 4;     { profondeur max imbrication proc/func }

  { Prefixes de nommage ASM }
  PSP_VAR_PFX   = '_PSP_';      { variable globale              }
  PSP_FN_PFX    = '_PSPF_';     { fonction / procedure          }
  PSP_STR_PFX   = '_PSPK_';     { constante chaine litterale    }
  PSP_RT_PFX    = '_PSPRT_';    { routine runtime               }
  PSP_LBL_PFX   = '_PSPL_';     { label de saut interne         }
  PSP_ARR_PFX   = '_PSPA_';     { tableau                       }
  PSP_REC_PFX   = '_PSPR_';     { record                        }
  PSP_ENUM_PFX  = '_PSPE_';     { enumeration                   }
  PSP_HTML_PFX  = '_PSPK_HTML_'; { fragment HTML literal         }
  PSP_EX_PFX    = '_PSPX_';     { exception handler             }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Pascal (32 bits) }
  TY_IDX_INTEGER = 0;   { entier 32 bits signe   }
  TY_IDX_WORD    = 1;   { entier 32 bits non signe }
  TY_IDX_BYTE    = 2;   { 8 bits non signe       }
  TY_IDX_CHAR    = 3;   { 8 bits caractere       }
  TY_IDX_BOOLEAN = 4;   { 0 | 1 dans AL/EAX     }
  TY_IDX_STRING  = 5;   { pointeur ASCIIZ 32 bits }
  TY_IDX_REAL    = 6;   { tronque en entier      }
  TY_IDX_POINTER = 7;   { pointeur generique 32 bits }
  TY_IDX_NIL     = 8;   { pointeur nul           }
  TY_IDX_TEXT    = 9;    { fichier texte (handle Win32) }
  TY_PRIM_COUNT  = 10;
  TY_UNKNOWN     = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.psp)                }
    OutFile   : TString;   { fichier de sortie (.exe/.obj/.asm)   }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
    EmitExe   : Boolean;   { produire un .EXE PE (defaut)         }
    EmitObj   : Boolean;   { -obj : produire uniquement un .OBJ   }
    EmitAsm   : Boolean;   { -asm : produire un listing .ASM      }
  End;

  { ---- Tokens Pascal / PSP ---------------------- }
  TTokenKind = (
    TK_EOF,            { fin de fichier                       }
    TK_INTEGER,        { literal entier 42 $FF                }
    TK_REAL,           { literal reel 3.14 1.5E3              }
    TK_STRING,         { literal chaine 'hello'               }
    TK_CHAR,           { literal caractere #65 #$41           }
    TK_IDENT,          { identificateur (non-mot-cle)         }
    TK_KEYWORD,        { mot-cle Pascal reconnu               }
    TK_OP,             { operateur := + - * / = <> < > etc.   }
    TK_PUNCT,          { ponctuation ; , ( ) [ ] . ..         }
    TK_HTML,           { texte HTML literal hors balises       }
    TK_PSP_OPEN,       { balise <% ouvrante                   }
    TK_PSP_CLOSE,      { balise %> fermante                   }
    TK_PSP_EXPR_OPEN,  { balise <%= (expression inline)       }
    TK_PSP_DIRECTIVE   { balise <%@ (directive de page)       }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute           }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)      }
    RealVal  : Real;        { valeur reelle (TK_REAL)          }
    Line     : Integer;     { ligne source (1-base)            }
    Col      : Integer;     { colonne source (1-base)          }
  End;

  { ---- Mode du template PSP --------------------- }
  TPSPMode = (TPL_HTML, TPL_CODE);

  { ---- Segment de donnees ------------ }
  TDataKind = (DK_DWORD, DK_BYTE, DK_STR, DK_ARRAY, DK_REC);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;   { nombre d elements (DK_ARRAY)        }
    ElemSize  : Integer;   { taille d un element (DK_ARRAY)      }
    RecSize   : Integer;   { taille totale en octets (DK_REC)    }
  End;

  { ---- Valeurs d expression --------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                       }
    EK_IMM,    { valeur immediate dans ImmVal                }
    EK_AX,     { valeur dans registre EAX                    }
    EK_MEM     { adresse memoire [EBP+Offset] ou [_PSP_x]   }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 si pas lvalue) }
  End;

  { ---- Genre de type ----------------------------- }
  TTypeKind = (
    TKP_INTEGER,   { entier 32 bits signe                    }
    TKP_WORD,      { entier 32 bits non signe                 }
    TKP_BYTE,      { 8 bits non signe                         }
    TKP_CHAR,      { 8 bits caractere                         }
    TKP_BOOLEAN,   { 0 ou 1 dans AL, etendu EAX               }
    TKP_STRING,    { pointeur ASCIIZ dans EAX                  }
    TKP_REAL,      { tronque en entier 32 bits                 }
    TKP_ARRAY,     { tableau (BaseTypeIdx = type element)      }
    TKP_RECORD,    { enregistrement (FieldCount champs)        }
    TKP_ENUM,      { enumeration (EnumCount valeurs)           }
    TKP_SUBRANGE,  { sous-intervalle (Lo..Hi)                  }
    TKP_POINTER,   { pointeur generique 32 bits                }
    TKP_NIL,       { pointeur nul                              }
    TKP_TEXT,      { fichier texte (handle Win32)              }
    TKP_VOID       { procedure, pas de valeur de retour        }
  );

  { ---- Champ de record --------------------------- }
  TFieldRec = Record
    Name    : TString;
    TypeIdx : Integer;
    Offset  : Integer;  { decalage en octets dans le record }
  End;

  { ---- Valeur d enumeration ---------------------- }
  TEnumValRec = Record
    Name  : TString;
    Value : Integer;
  End;

  { ---- Enregistrement de type -------------------- }
  TTypeRec = Record
    Kind        : TTypeKind;
    Size        : Integer;     { taille en octets                   }
    BaseTypeIdx : Integer;     { type de base (pointer/array/sub)   }
    Lo          : LongInt;     { borne inf (subrange/array)         }
    Hi          : LongInt;     { borne sup (subrange/array)         }
    FieldCount  : Integer;     { nombre de champs (record)          }
    Fields      : Array[0..MAX_FIELD - 1] Of TFieldRec;
    EnumCount   : Integer;     { nombre de valeurs (enum)           }
    Enums       : Array[0..MAX_ENUM - 1] Of TEnumValRec;
  End;

  { ---- Categorie de symbole ---------------------- }
  TSymCat = (
    SC_VAR,          { variable globale ou locale           }
    SC_CONST,        { constante non-typee (substitution)   }
    SC_TYPED_CONST,  { constante typee (en DATA)            }
    SC_PARAM,        { parametre par valeur                 }
    SC_VARPARAM,     { parametre var (par reference)        }
    SC_FUNC,         { fonction                             }
    SC_PROC,         { procedure                            }
    SC_TYPE,         { nom de type                          }
    SC_FIELD,        { champ de record                      }
    SC_ENUM_VAL,     { valeur d enumeration                 }
    SC_LABEL         { label nomme                          }
  );

  { ---- Enregistrement symbole -------------------- }
  TSymRec = Record
    Name        : TString;  { nom original Pascal (minuscule)    }
    MangledName : TString;  { nom ASM mangled (_PSP_xxx etc.)    }
    Cat         : TSymCat;  { categorie (var/const/func etc.)    }
    TypeIdx     : Integer;  { indice dans TypeTab (TY_IDX_*)     }
    Offset      : Integer;  { offset cadre local (EBP+n)         }
    ScopeLevel  : Integer;  { profondeur de portee (0=global)    }
    ScopeId     : Integer;  { identifiant unique de portee       }
    IsForward   : Boolean;  { declaration forward non resolue    }
    IsLocal     : Boolean;  { True si variable locale            }
    ImmVal      : LongInt;  { valeur immediate (SC_CONST)        }
    DataIdx     : Integer;  { index DataTab (SC_TYPED_CONST)     }
    ParamCnt    : Integer;  { nb params (SC_FUNC/SC_PROC)        }
    VarParamMask: LongInt;  { bitmask var params (bit i=1)       }
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

  { Emetteur ASM (pour Cleanup) }
  OutF     : Text;
  OutFOpen : Boolean;

  { Lexeur }
  LexSrcF   : Text;
  LexOpened : Boolean;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  CurToken  : TToken;

  { Analyseur de template }
  TplMode      : TPSPMode;
  TplHtmlBuf   : TString;
  TplPending   : TTokenKind;
  TplHtmlCount : Integer;

  { Segment de donnees }
  DataTab      : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount    : Integer;
  LabelGenSeq  : Integer;

  { Table des symboles }
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Variables et affectations }
  CurFrameOffset   : Integer;  { offset courant dans le cadre local (negatif) }
  PendingAssignName : TString; { nom ident en attente (lookahead ParseVarDecl) }
  HasPendingAssign  : Boolean; { True si une affectation a ete detectee }

  { Pile de boucles pour break/continue }
  LoopBreakLbl    : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl     : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopTop         : Integer;  { sommet de la pile (-1 = vide) }

  { Fonctions et procedures }
  CurFuncName     : TString;  { nom de la fonction en cours ('' si aucune) }
  CurFuncRetOfs   : Integer;  { offset de la valeur de retour [EBP+n] }
  CurRetLabel     : TString;  { label de retour (_PSPL_RET_N) pour Exit }
  CurNestLevel    : Integer;  { profondeur d imbrication proc/func }
  CurParamBytes   : Integer;  { taille des parametres pour RET n }
  MainBodyEmitted : Boolean;  { True si _PSPL_MAINBODY deja emis }
  RuntimeEmitted  : Boolean;  { True si routines runtime deja emises }

  { Pile with pour records }
  WithSymIdx      : Array[0..MAX_WITH - 1] Of Integer;  { symidx du record }
  WithTop         : Integer;  { sommet de la pile (-1 = vide) }

  { Directives et inclusions }
  IncSavedFName   : Array[0..MAX_INCLUDE - 1] Of TString; { nom fichier empile }
  IncSavedFLine   : Array[0..MAX_INCLUDE - 1] Of Integer;{ ligne dans fichier }
  IncSavedLine    : Array[0..MAX_INCLUDE - 1] Of String; { ligne courante  }
  IncSavedLineNo  : Array[0..MAX_INCLUDE - 1] Of Integer;{ numero de ligne }
  IncSavedColNo   : Array[0..MAX_INCLUDE - 1] Of Integer;{ colonne         }
  IncSavedEOF     : Array[0..MAX_INCLUDE - 1] Of Boolean;{ EOF sauvegarde  }
  LexSrcFName     : TString;  { nom du fichier source courant }
  IncTop          : Integer;  { sommet pile inclusion (-1 = vide) }
  DefineTab       : Array[0..MAX_DEFINE - 1] Of TString; { symboles defines }
  DefineCount     : Integer;  { nombre de defines actifs }
  CompilerMode    : TString;  { 'TP' ou 'FPC' }
  ContentTypeLbl  : TString;  { label content-type ou '' }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ Utilitaires chaines - TODO 01 }
Function  StrLowerCase(Const S : TString) : TString; Forward;
Function  StrUpperCase(Const S : TString) : TString; Forward;
Function  IntToStr(N : LongInt) : TString; Forward;
Function  EBPOfs(Ofs : Integer) : TString; Forward;
Function  StrToIntDef(Const S : TString; Def : LongInt) : LongInt; Forward;
{ Messages - TODO 01 }
Procedure FatalError(Const Msg : TString); Forward;
Procedure WarnMsg(Const Msg : TString); Forward;
Procedure ErrorMsg(Const Msg : TString); Forward;
Procedure Expect(Const Expected : TString); Forward;
Procedure SkipTo; Forward;
{ Lexeur - TODO 02 }
Procedure LexInit;       Forward;
Procedure LexClose;      Forward;
Procedure LexNextLine;   Forward;
Procedure LexNextToken;  Forward;
Procedure LexScanIdent;  Forward;
Procedure LexScanNumber; Forward;
Procedure LexScanString; Forward;
Procedure LexScanCharLit;Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexSkipBraceComment; Forward;
Procedure LexSkipParenStarComment; Forward;
Procedure LexSkipLineComment; Forward;
{ Directives et inclusions - TODO 20 }
Procedure LexHandleDollarDirective; Forward;
Procedure IncludePush(Const FileName : TString); Forward;
Procedure IncludePop; Forward;
Function  DefineDefined(Const Name : TString) : Boolean; Forward;
Procedure DefineAdd(Const Name : TString); Forward;
Procedure DefineRemove(Const Name : TString); Forward;
Procedure ParsePSPDirective; Forward;
{ Analyseur de template - TODO 19 }
Procedure TplInit;       Forward;
Procedure TplClose;      Forward;
Procedure TplEmitHtml;   Forward;
Procedure TplEmitPSPOpen(Kind : TTokenKind); Forward;
Procedure TplNextToken;  Forward;
{ Segment de donnees et litteraux - TODO 03 / 08 }
Function  LabelGen : TString; Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddDWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddArray(Const Lbl : TString;
                ECount, ESz : Integer) : Integer; Forward;
Function  DataAddRec(Const Lbl : TString;
                RSz : Integer) : Integer; Forward;
Procedure EmitRaw(Const S : String); Forward;
Procedure EmitDataSeg; Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure ParseConstDecl; Forward;
{ Table des symboles - TODO 05 }
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
               Level : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymInit; Forward;
{ Systeme de types - TODO 06 }
Procedure TypeInit; Forward;
Function  TypeSizeof(TIdx : Integer) : Integer; Forward;
Function  TypeCompatible(T1, T2 : Integer) : Boolean; Forward;
Function  TypeCoerce(SrcType, DstType : Integer) : Integer; Forward;
Function  TypeResolve(Const Name : TString) : Integer; Forward;
Function  TypeIsOrdinal(TIdx : Integer) : Boolean; Forward;
Function  TypeIsNumeric(TIdx : Integer) : Boolean; Forward;
Function  TypeIsPointer(TIdx : Integer) : Boolean; Forward;
{ Emetteur ASM - TODO 07 }
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitBlankLine; Forward;
Function  NewLabel : TString; Forward;
Procedure EmitHeader; Forward;
Procedure EmitFooter; Forward;
Procedure EmitProlog(FrameSize : Integer); Forward;
Procedure EmitEpilog(ParamBytes : Integer); Forward;
Procedure EmitPush(Const Reg : TString); Forward;
Procedure EmitPop(Const Reg : TString); Forward;
Procedure EmitMov(Const Dst, Src : TString); Forward;
Procedure EmitCall(Const Target : TString); Forward;
Procedure EmitJmp(Const Target : TString); Forward;
Procedure EmitJmpCond(Const Cond, Target : TString); Forward;
Procedure EmitCoerce(SrcType, DstType : Integer); Forward;
{ Operateurs et expressions - TODO 04 / 10 / 11 }
Function  OpPrec(Const Op : TString) : Integer; Forward;
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal); Forward;
Procedure ExprFlushToEAX(Var E : TExprVal); Forward;
Procedure ParseCallArgs(FuncIdx : Integer); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ Variables et affectations - TODO 09 }
Procedure ParseVarDecl; Forward;
Procedure ParseAssignment(Const VarName : TString); Forward;
{ Write/WriteLn et emission HTML - TODO 12 / 19 }
Procedure ParseWriteStmt(IsWriteLn : Boolean); Forward;
Procedure EmitHtmlFragment(Const Html : TString); Forward;
Procedure EmitExprInline; Forward;
{ If/Then/Else, Case/Of, Blocs - TODO 13 }
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;
Procedure ParseIfStmt; Forward;
Procedure ParseCaseStmt; Forward;
{ Boucles - TODO 14 }
Procedure ParseForStmt; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseRepeatStmt; Forward;
{ Fonctions et procedures - TODO 18 }
Procedure ParseFuncDecl; Forward;
Procedure ParseProcDecl; Forward;
{ Types definis et enumerations - TODO 06 / 17 }
Procedure ParseTypeDecl; Forward;
Procedure ParseIncDecStmt(IsInc : Boolean); Forward;
{ Enregistrements - TODO 16 }
Procedure ParseWithStmt; Forward;
{ Exceptions - TODO 21 }
Procedure ParseTryExcept; Forward;

{ ============================================================
  STUBS POUR DECLARATIONS FORWARD (a implementer dans les TODOs suivants)
  ============================================================ }

{ --- Stubs Lexeur (TODO 02) --- }
Procedure LexInit; Begin End;
Procedure LexClose; Begin End;
Procedure LexNextLine; Begin End;
Procedure LexNextToken; Begin End;
Procedure LexScanIdent; Begin End;
Procedure LexScanNumber; Begin End;
Procedure LexScanString; Begin End;
Procedure LexScanCharLit; Begin End;
Function IsKeyword(Const S : TString) : Boolean; Begin IsKeyword := False; End;
Function IsIdentStart(Ch : Char) : Boolean; Begin IsIdentStart := False; End;
Function IsIdentCont(Ch : Char) : Boolean; Begin IsIdentCont := False; End;
Function IsHexDigit(Ch : Char) : Boolean; Begin IsHexDigit := False; End;
Function HexVal(Ch : Char) : Integer; Begin HexVal := 0; End;
Procedure PrintToken(Const T : TToken); Begin End;
Procedure LexSkipBraceComment; Begin End;
Procedure LexSkipParenStarComment; Begin End;
Procedure LexSkipLineComment; Begin End;

{ --- Stubs Directives (TODO 20) --- }
Procedure LexHandleDollarDirective; Begin End;
Procedure IncludePush(Const FileName : TString); Begin End;
Procedure IncludePop; Begin End;
Function DefineDefined(Const Name : TString) : Boolean; Begin DefineDefined := False; End;
Procedure DefineAdd(Const Name : TString); Begin End;
Procedure DefineRemove(Const Name : TString); Begin End;
Procedure ParsePSPDirective; Begin End;

{ --- Stubs Template (TODO 19) --- }
Procedure TplInit; Begin End;
Procedure TplClose; Begin End;
Procedure TplEmitHtml; Begin End;
Procedure TplEmitPSPOpen(Kind : TTokenKind); Begin End;
Procedure TplNextToken; Begin End;

{ --- Stubs Donnees (TODO 03 / 08) --- }
Function LabelGen : TString; Begin LabelGen := '_PSPL_00000'; End;
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
               AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin DataAdd := 0; End;
Function DataAddStr(Const S : TString) : TString; Begin DataAddStr := ''; End;
Function DataAddDWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin DataAddDWord := 0; End;
Function DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin DataAddByte := 0; End;
Function DataAddArray(Const Lbl : TString;
              ECount, ESz : Integer) : Integer;
Begin DataAddArray := 0; End;
Function DataAddRec(Const Lbl : TString;
              RSz : Integer) : Integer;
Begin DataAddRec := 0; End;
Procedure EmitRaw(Const S : String); Begin End;
Procedure EmitDataSeg; Begin End;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Begin End;
Procedure ParseConstDecl; Begin End;

{ --- Stubs Symboles (TODO 05) --- }
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Begin SymMangle := Name; End;
Function SymAdd(Const Name : TString; Cat : TSymCat;
             TIdx : Integer) : Integer;
Begin SymAdd := 0; End;
Function SymFind(Const Name : TString) : Integer; Begin SymFind := -1; End;
Function SymFindInScope(Const Name : TString;
             Level : Integer) : Integer;
Begin SymFindInScope := -1; End;
Procedure SymEnterScope; Begin End;
Procedure SymLeaveScope; Begin End;
Procedure SymInit; Begin End;

{ --- Stubs Types (TODO 06) --- }
Procedure TypeInit; Begin End;
Function TypeSizeof(TIdx : Integer) : Integer; Begin TypeSizeof := 4; End;
Function TypeCompatible(T1, T2 : Integer) : Boolean; Begin TypeCompatible := True; End;
Function TypeCoerce(SrcType, DstType : Integer) : Integer;
Begin TypeCoerce := DstType; End;
Function TypeResolve(Const Name : TString) : Integer;
Begin TypeResolve := TY_UNKNOWN; End;
Function TypeIsOrdinal(TIdx : Integer) : Boolean; Begin TypeIsOrdinal := False; End;
Function TypeIsNumeric(TIdx : Integer) : Boolean; Begin TypeIsNumeric := False; End;
Function TypeIsPointer(TIdx : Integer) : Boolean; Begin TypeIsPointer := False; End;

{ --- Stubs Emetteur (TODO 07) --- }
Procedure EmitComment(Const S : TString); Begin End;
Procedure EmitLabel(Const Lbl : TString); Begin End;
Procedure EmitInstr(Const Mnem : TString); Begin End;
Procedure EmitInstrA(Const Mnem, A1 : TString); Begin End;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Begin End;
Procedure EmitBlankLine; Begin End;
Function NewLabel : TString; Begin NewLabel := LabelGen; End;
Procedure EmitHeader; Begin End;
Procedure EmitFooter; Begin End;
Procedure EmitProlog(FrameSize : Integer); Begin End;
Procedure EmitEpilog(ParamBytes : Integer); Begin End;
Procedure EmitPush(Const Reg : TString); Begin End;
Procedure EmitPop(Const Reg : TString); Begin End;
Procedure EmitMov(Const Dst, Src : TString); Begin End;
Procedure EmitCall(Const Target : TString); Begin End;
Procedure EmitJmp(Const Target : TString); Begin End;
Procedure EmitJmpCond(Const Cond, Target : TString); Begin End;
Procedure EmitCoerce(SrcType, DstType : Integer); Begin End;

{ --- Stubs Expressions (TODO 04 / 10 / 11) --- }
Function OpPrec(Const Op : TString) : Integer; Begin OpPrec := 0; End;
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal); Begin End;
Procedure ExprFlushToEAX(Var E : TExprVal); Begin End;
Procedure ParseCallArgs(FuncIdx : Integer); Begin End;
Procedure ParsePrimary(Var Res : TExprVal); Begin End;
Procedure ParseUnary(Var Res : TExprVal); Begin End;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Begin End;
Procedure ParseExpr(Var Res : TExprVal); Begin End;

{ --- Stubs Variables (TODO 09) --- }
Procedure ParseVarDecl; Begin End;
Procedure ParseAssignment(Const VarName : TString); Begin End;

{ --- Stubs Write/HTML (TODO 12 / 19) --- }
Procedure ParseWriteStmt(IsWriteLn : Boolean); Begin End;
Procedure EmitHtmlFragment(Const Html : TString); Begin End;
Procedure EmitExprInline; Begin End;

{ --- Stubs If/Case/Blocs (TODO 13) --- }
Procedure ParseStatement; Begin End;
Procedure ParseBlock; Begin End;
Procedure ParseIfStmt; Begin End;
Procedure ParseCaseStmt; Begin End;

{ --- Stubs Boucles (TODO 14) --- }
Procedure ParseForStmt; Begin End;
Procedure ParseWhileStmt; Begin End;
Procedure ParseRepeatStmt; Begin End;

{ --- Stubs Fonctions/Procedures (TODO 18) --- }
Procedure ParseFuncDecl; Begin End;
Procedure ParseProcDecl; Begin End;

{ --- Stubs Types/Enumerations (TODO 06 / 17) --- }
Procedure ParseTypeDecl; Begin End;
Procedure ParseIncDecStmt(IsInc : Boolean); Begin End;

{ --- Stubs Records (TODO 16) --- }
Procedure ParseWithStmt; Begin End;

{ --- Stubs Exceptions (TODO 21) --- }
Procedure ParseTryExcept; Begin End;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- FatalError ------------------------------------------ }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PSPCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

{ ---- WarnMsg --------------------------------------------- }
Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('PSPCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- ErrorMsg, Expect, SkipTo -------------------- }

Procedure ErrorMsg(Const Msg : TString);
Begin
  WriteLn('PSPCW32: erreur ligne ', LexLineNo, ' : ', Msg);
  Inc(ErrorCount);
End;

Procedure Expect(Const Expected : TString);
Begin
  If CurToken.Val <> Expected Then
  Begin
    ErrorMsg('''' + Expected + ''' attendu, trouve ''' + CurToken.Val + '''');
    SkipTo;
  End
  Else
    TplNextToken;
End;

Procedure SkipTo;
Begin
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin')) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '%>')) Do
    TplNextToken;
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('PSPCW32 v', PSPCW32_VERSION, ' (', PSPCW32_DATE, ')');
  WriteLn('Compilateur Pascal Server Pages -> assembleur 80386 / Win32');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)  Cible: MASM .386 .MODEL FLAT');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('PSPCW32 - Compilateur de PSP (Pascal Server Pages) pour ',
          'l''assembleur du microprocesseur 80386 (Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : PSPCW32 <page.psp> [-o sortie] [-v] [-d] [-w] [-obj] [-asm]');
  WriteLn;
  WriteLn('  page.psp   : fichier Pascal Server Pages source');
  WriteLn('  -o nom     : specifier le nom du fichier de sortie');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -obj       : produire uniquement un .OBJ (format COFF 32 bits)');
  WriteLn('  -asm       : produire egalement un listing assembleur .ASM');
  WriteLn('  -h         : afficher cette aide');
  WriteLn;
  WriteLn('Par defaut, PSPCW32 produit un fichier .EXE (PE Windows 32 bits).');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  ShowBanner;
  ShowUsage;
End;

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

{ Retourne '[EBP+n]' ou '[EBP-n]' selon le signe }
Function EBPOfs(Ofs : Integer) : TString;
Begin
  If Ofs >= 0 Then
    EBPOfs := '[EBP+' + IntToStr(Ofs) + ']'
  Else
    EBPOfs := '[EBP' + IntToStr(Ofs) + ']';
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

{ Retourne l extension d un chemin (avec le point) }
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

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;    { par defaut : produire un .EXE }
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
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

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitObj := True;
      Opts.EmitExe := False;
    End
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-o' Then
    Begin
      If I < ParamCount Then
      Begin
        Inc(I);
        Opts.OutFile := ParamStr(I);
      End
      Else
      Begin
        WriteLn('PSPCW32: -o requiert un nom de fichier');
        ShowUsage;
      End;
    End
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('PSPCW32: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else
    Begin
      WriteLn('PSPCW32: argument inattendu: ', Arg);
      ShowUsage;
    End;

    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PSPCW32: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .psp }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.psp') Then
    WarnMsg('extension attendue .psp, trouvee: ' + Ext);

  { Fichier de sortie par defaut selon le mode }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ---- Nettoyage -------------------------------------------- }

Procedure Cleanup;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale -------------------------------- }

Procedure GlobalInit;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  OutFOpen   := False;
  LexOpened  := False;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  DataCount   := 0;
  LabelGenSeq := 0;
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  TypeCount := 0;
  CurFrameOffset    := 0;
  HasPendingAssign  := False;
  PendingAssignName := '';
  LoopTop := -1;
  CurFuncName   := '';
  CurFuncRetOfs := 0;
  CurRetLabel   := '';
  CurNestLevel  := 0;
  CurParamBytes := 0;
  MainBodyEmitted := False;
  RuntimeEmitted  := False;
  WithTop := -1;
  IncTop        := -1;
  DefineCount   := 0;
  CompilerMode  := 'TP';
  ContentTypeLbl := '';
  LexSrcFName   := '';
  TypeInit;
  SymInit;
End;

{ ---- Pipeline de compilation (stub) ------------------------- }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  { Verifier que le fichier source existe }
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexSrcFName := Opts.SrcFile;

  { Creer le fichier de sortie }
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;

  { TODO 02+ : Initialiser le lexeur et l analyseur template }
  { TODO 07  : Emettre l en-tete ASM }
  { TODO 19  : Boucle principale template PSP }
  { TODO 07  : Emettre le pied de page ASM }
  { TODO 08  : Emettre le segment de donnees }

  Cleanup;
  If Opts.Verbose Then Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
    If Opts.EmitExe Then
      WriteLn('  Mode           : EXE (PE Win32)')
    Else If Opts.EmitObj Then
      WriteLn('  Mode           : OBJ (COFF 32 bits)');
    If Opts.EmitAsm Then
      WriteLn('  Listing ASM    : oui');
  End;
  If ErrorCount > 0 Then Halt(EXIT_ERROR)
                    Else Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowHelp;
  Halt(0);
 End;
 ParseArgs;
 Run;
END.
