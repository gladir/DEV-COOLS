(* ============================================================
  PSP86.PAS - Compilateur Pascal Server Pages vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  Pascal Server Pages (.PSP) est un langage de template melant
  du code HTML statique et des blocs de code Pascal inseres
  entre les balises <% ... %> (similaire a ASP 3.0 mais en Pascal).
  Les expressions en ligne s ecrivent <%= expr %>.
  Le compilateur produit un fichier .ASM autonome (mode CGI DOS).

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (page.psp [sortie.asm] [-v] [-d] [-w])
            FatalError(msg), WarnMsg(msg), EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detection de l extension .psp sur le fichier source
            Ouverture du fichier source en lecture ; creation du fichier ASM
            Programme principal : validation des arguments et appel Run

  TODO 02 - LEXEUR (TOKENS PASCAL) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_STRING,
              TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT,
              TK_HTML (texte literal hors balises), TK_PSP_OPEN, TK_PSP_CLOSE,
              TK_PSP_EXPR_OPEN (<%=), TK_PSP_DIRECTIVE (<%@)
            LexInit, LexClose, LexNextToken
            LexScanIdent : identifier ou mot-cle Pascal
            LexScanNumber : entier decimal, hexadecimal ($FF), reel (3.14)
            LexScanString : chaine simple-quote ('It''s') ; #65 #$41 (char literal)
            Commentaires Pascal : { ... }  (star...star)  // commentaire ligne
            IsKeyword : program begin end var const type
              if then else while do for to downto
              repeat until case of function procedure
              forward array record string integer boolean
              char byte word real nil true false
              not and or xor div mod shl shr in
              with uses write writeln read readln
              break continue exit halt
              try except finally raise (stubs Delphi)
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - ANALYSEUR DE TEMPLATE PSP [IMPLEMENTE]
            Boucle principale : lire le fichier .psp caractere par caractere
            Mode IN_HTML (hors balises) :
              Accumuler le texte HTML brut dans un buffer
              A la rencontre de <% ou fin de fichier :
                Emettre le texte HTML comme chaine DATA + CALL _PSPRT_PRINT
            Mode IN_CODE (entre <% et %>) :
              Basculer vers le lexeur Pascal pour analyser les tokens
              A la rencontre de %> : revenir en mode IN_HTML
            Balise d expression <%= expr %> :
              Evaluer l expression Pascal -> AX
              Convertir selon le type -> _PSPRT_NUMTOSTR si entier
              Emettre CALL _PSPRT_PRINT pour afficher le resultat
            Balise de directive <%@ Directive=Valeur %> :
              ContentType : emettre en-tete HTTP Content-Type: ... CR LF CR LF
              Include : inclure un fichier .psp dans le flux source
              CodePage : stub + avertissement (non implemente)
            Gestion des blocs multiples :
              Chaque bloc <% ... %> est compile dans le meme scope global
              Les declarations (var, function, procedure) persistent
              Les blocs begin...end sont concatenes dans _PSPF_main
            Terminateur de bloc : end. ou end; acceptes (le . est optionnel)
            Imbrication interdite : <% ... <% ... %> ... %> -> erreur

  TODO 04 - LITTERAUX ET CONSTANTES PASCAL [IMPLEMENTE]
            Entiers decimaux : 0, 42, -1, 32767
            Entiers hexadecimaux : $FF, $0A, $FFFF
            Reels : 3.14, 1.5E3 -> tronques en entier + avertissement
            Caracteres : 'A' (chaine de longueur 1), #65, #$41
              Caracteres speciaux : #13#10 (CR+LF), #9 (tab), #0 (nul)
            Chaines : 'Hello World', '' (vide), 'l''echo' (quote doublee)
              Chaines multi-segments : 'abc'#13#10'def' -> concatenation compile
            Booleens : True -> MOV AX,1 ; False -> XOR AX,AX
            nil : XOR AX,AX (pointeur nul)
            Constantes nommees : const MAX = 100; -> substitution a la compilation
            Constantes typees : const X: Integer = 42; -> entree DATA DK_WORD

  TODO 05 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques   : + - * (IMUL) / (IDIV quotient) div (IDIV) mod (IDIV reste)
            Comparaison     : = <> < > <= >= (CMP + Jcc -> AX=0|1)
            Logiques        : and or xor not (booleens -> AX=0|1)
            Bits            : and or xor not shl shr (sur entiers -> AX)
              Distinction logique/bits par le type des operandes :
                Boolean and Boolean -> logique ; Integer and Integer -> bits
            Concatenation   : + si l un des operandes est String -> _PSPRT_CONCAT
            Affectation     : := (non un operateur d expression en Pascal)
            Unaires         : - (NEG AX) not (NOT AX ou XOR AX,1 selon type)
                              @ (adresse de -> LEA AX,[var])
                              ^ (dereferencement pointeur -> MOV BX,AX / MOV AX,[BX])
            Ensemble        : in (test appartenance sous-plage -> CMP + JB/JA)
            Precedences Pascal (du plus fort au plus faible) :
              Niveau 1 : not - @ ^ (unaires)
              Niveau 2 : * / div mod and shl shr (multiplicatifs)
              Niveau 3 : + - or xor (additifs)
              Niveau 4 : = <> < > <= >= in (comparaison)

  TODO 06 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymCat : SC_VAR, SC_CONST, SC_TYPED_CONST, SC_PARAM,
              SC_VARPARAM (parametre var par reference), SC_FUNC, SC_PROC,
              SC_TYPE, SC_FIELD (champ de record), SC_ENUM_VAL, SC_LABEL
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              ScopeLevel, ScopeId, IsForward, IsLocal
            SymTab[0..MAX_SYM-1], SymCount
            SymAdd, SymFind, SymFindInScope, SymMangle
            Portees imbriquees : ScopeLevel = 0 (global) .. SCOPE_MAX
              SymEnterScope : incrementer ScopeLevel, enregistrer ScopeId
              SymLeaveScope : invalider les symboles du scope courant
            Prefixes de mangling :
              _PSP_  (variable globale)    _PSPL_ (label genere)
              _PSPF_ (function/procedure)  _PSPK_ (chaine constante)
              _PSPRT_(routine runtime)     _PSPR_ (record)
              _PSPA_ (tableau)             _PSPE_ (enum)
            Resolution des noms : recherche du scope le plus interne vers global
            Symboles predeclares : Integer, Word, Byte, Char, Boolean,
              String, Real, True, False, nil, Write, WriteLn, Read, ReadLn

  TODO 07 - SYSTEME DE TYPES
            TTypeKind : TKP_INTEGER (entier 16 bits signe),
              TKP_WORD (entier 16 bits non signe), TKP_BYTE (8 bits non signe),
              TKP_CHAR (8 bits), TKP_BOOLEAN (0|1 dans AL, etendu AX),
              TKP_STRING (pointeur ASCIIZ dans AX),
              TKP_REAL (avertissement : tronque en entier 16 bits),
              TKP_ARRAY, TKP_RECORD, TKP_ENUM, TKP_SUBRANGE,
              TKP_POINTER (pointeur generique, 16 bits), TKP_NIL,
              TKP_TEXT (fichier texte), TKP_VOID (procedure, pas de retour)
            TypeTab[0..MAX_TYPE-1], TypeCount
            TTypeRec : Kind, Size, BaseTypeIdx (pour pointer/array/subrange),
              Lo, Hi (pour subrange/array), FieldList (pour record),
              EnumList (pour enum)
            TypeInit : enregistrer les types primitifs aux index reserves
              TY_IDX_INTEGER=0, TY_IDX_WORD=1, TY_IDX_BYTE=2,
              TY_IDX_CHAR=3, TY_IDX_BOOLEAN=4, TY_IDX_STRING=5,
              TY_IDX_REAL=6, TY_IDX_POINTER=7, TY_IDX_NIL=8, TY_IDX_TEXT=9
            TypeSizeof : Integer=2, Word=2, Byte=1, Char=1, Boolean=1,
              String=2 (ptr), Pointer=2, Text=2 (handle)
            Compatibilite de types :
              Integer <-> Word (implicite avec avertissement si signe/non-signe)
              Byte -> Integer (promotion implicite), Char -> Integer (Ord)
              Char <-> String (1 caractere, conversion implicite)
              Boolean -> Integer (0|1), Enum -> Integer (Ord)
            TypeCoerce : emission de code de conversion selon types source/dest

  TODO 08 - EMETTEUR DE CODE ASM
            TEmitter : OutF (fichier Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw(s), EmitLabel(lbl), EmitInstr(instr) (indentation 8 espaces)
            EmitComment(s), EmitBlankLine
            LabelGen : compteur global -> _PSPL_NNNNN
            NewLabel : retourne le prochain label unique
            EmitHeader : .MODEL SMALL / .STACK 1024 / .386 (optionnel pour MOVZX)
              _TEXT SEGMENT PUBLIC 'CODE' / ASSUME CS:_TEXT, DS:_DATA
              _PSPF_main: / MOV AX, _DATA / MOV DS, AX
            EmitProlog : PUSH BP / MOV BP,SP / [SUB SP, framesize]
            EmitEpilog : MOV SP,BP / POP BP / RET [n] (n = taille params)
            EmitPush(reg), EmitPop(reg), EmitMov, EmitCall, EmitJmp
            EmitCoerce(srcType, dstType) : code de conversion inline

  TODO 09 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_REC),
              IntVal, StrVal, ElemCount, RecSize
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddWord, DataAddByte
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS
            Chaines HTML litterales -> entrees DK_STR (ASCIIZ)
              Chaque fragment HTML accumule -> _PSPK_HTML_N DB '...',0
            Chaines Pascal litterales -> entrees DK_STR
            Variables globales : var X: Integer -> _PSP_X DW 0
            Constantes typees : const S: String = 'abc' -> _PSPK_S DB 'abc',0
            Tableaux globaux : _PSPA_arr DW elem_count DUP(0)
            Records globaux : _PSPR_rec DB rec_size DUP(0)
            Buffers internes :
              _PSP_STRBUF DB 512 DUP(0)  (buffer concatenation/conversion)
              _PSP_NUMBUF DB 12 DUP(0)   (buffer itoa)
              _PSP_HEAP DB 4096 DUP(0)   (tas statique)
              _PSP_HEAPTOP DW 0          (sommet du tas)
              _PSP_CRLF DB 13,10,0       (saut de ligne)

  TODO 10 - VARIABLES ET AFFECTATIONS
            ParseVarDecl : var a, b, c: Integer; s: String;
              Declarations multiples sur une meme ligne (meme type)
              Variables locales : SUB SP,2 par variable (Integer/Word/Pointer)
                SUB SP,1 pour Byte/Char/Boolean (aligne sur 2 si necessaire)
              Variables globales : entree dans DataTab (DK_WORD ou DK_BYTE)
            Affectation : ParseAssignment -> ident := expr ;
              Variable locale : MOV [BP-n], AX
              Variable globale : MOV [_PSP_ident], AX
              Parametre var (reference) : MOV BX,[BP+n] / MOV [BX], AX
            Verification de type : type de l expression doit etre compatible
              avec le type de la variable cible
            Affectation de chaine : copie de pointeur (shallow copy)
              s := 'hello' -> MOV AX, OFFSET _PSPK_N / MOV [BP-n], AX
            Indexation array et champs record comme cibles :
              arr[i] := expr et rec.champ := expr (traites dans TODO 19 et 20)

  TODO 11 - EXPRESSIONS
            ParseExpr : expression complete (comparaison en sommet)
            ParseSimpleExpr : +, -, or, xor (binaires additifs)
            ParseTerm : *, /, div, mod, and, shl, shr (multiplicatifs)
            ParseFactor :
              Litteral entier -> MOV AX, valeur
              Litteral chaine -> MOV AX, OFFSET _PSPK_N
              Litteral caractere -> MOV AX, ord(c) ou OFFSET _PSPK_N si String
              Identificateur -> MOV AX, [BP-n] ou [_PSP_ident]
              Appel de fonction -> ParseCallArgs + CALL _PSPF_nom ;  AX = retour
              (expr) -> ParseExpr recursivement
              not expr -> ParseFactor + NOT AX ou XOR AX,1
              -expr -> ParseFactor + NEG AX
              @ident -> LEA AX, [BP-n] ou MOV AX, OFFSET _PSP_ident
              Transtypage : Integer(expr), Char(expr), Byte(expr), Word(expr)
            ParseCallArgs : evaluation et PUSH des arguments de gauche a droite
            Detection du type de l expression pour coercition automatique :
              Integer + String -> _PSPRT_NUMTOSTR + _PSPRT_CONCAT
              Char + String -> promotion Char en chaine 1 caractere

  TODO 12 - WRITE / WRITELN ET EMISSION HTML
            ParseWriteStmt : Write(arg1, arg2, ...) et WriteLn(...)
              Pour chaque argument :
                Si Integer/Word/Byte -> CALL _PSPRT_NUMTOSTR + CALL _PSPRT_PRINT
                Si Boolean -> afficher 'TRUE' ou 'FALSE'
                Si Char -> afficher 1 octet via INT 21h AH=02h
                Si String -> CALL _PSPRT_PRINT directement
              WriteLn : apres les arguments, emettre CR+LF
            Formatage Write(n:w) : largeur de champ w (padding espaces a gauche)
              Write(r:w:d) : stub + avertissement (pas de virgule flottante)
            Texte HTML literal (hors <% %>) :
              Chaque fragment HTML -> _PSPK_HTML_N en DATA
              Emission : MOV SI, OFFSET _PSPK_HTML_N / CALL _PSPRT_PRINTSTR
            Expression inline <%= expr %> :
              Evaluer expr -> AX
              Si type String : CALL _PSPRT_PRINT
              Si type Integer : CALL _PSPRT_NUMTOSTR + CALL _PSPRT_PRINT
              Si type Boolean : emit 'TRUE'/'FALSE'
            En-tete HTTP (si directive ContentType) :
              _PSPK_HDR DB 'Content-Type: text/html',13,10,13,10,0
              Emission au debut du code avant tout autre sortie
            Separateur : WriteLn sans argument -> emet seulement CR+LF

  TODO 13 - IF / THEN / ELSE + CASE / OF
            ParseIfStmt : if expr then stmt [else stmt]
              Evaluation de la condition : ParseExpr -> AX
              TEST AX,AX / JZ _PSPL_ELSE_N ou _PSPL_ENDIF_N
              Compilation du bloc then
              Si else present : JMP _PSPL_ENDIF_N + label _PSPL_ELSE_N
              Label _PSPL_ENDIF_N en fin
            Dangling else : rattachement au if le plus proche (standard Pascal)
            Blocs : begin ... end en tant que statement compose
            ParseCaseStmt : case expr of val: stmt; ... [else stmt;] end;
              Evaluation de l expression switch -> PUSH AX sur pile
              Chaque branche case : POP AX / CMP AX,valeur / JE _PSPL_CASE_N
                Apres le stmt de la branche -> JMP _PSPL_CSEND_N
              Plages : 1..5 -> CMP AX,1 / JB next / CMP AX,5 / JA next
              Valeurs multiples : 1, 3, 5 : -> CMP AX,1 / JE hit / CMP AX,3 ...
              Branche else (default) : label apres toutes les branches
              Label _PSPL_CSEND_N en fin du case

  TODO 14 - BOUCLES : FOR / WHILE / REPEAT
            ParseForStmt : for v := expr1 to|downto expr2 do stmt
              to   : _PSPL_FTEST_N: CMP [BP-n],limite / JG  _PSPL_FEND_N
              downto: _PSPL_FTEST_N: CMP [BP-n],limite / JL  _PSPL_FEND_N
              Increment : INC WORD PTR [BP-n] ou DEC selon to/downto
              Label _PSPL_FTEST_N (test), _PSPL_FEND_N (sortie)
            ParseWhileStmt : while expr do stmt
              _PSPL_WTEST_N: evaluation condition / TEST AX,AX / JZ _PSPL_WEND_N
              Compilation du bloc / JMP _PSPL_WTEST_N
              Label _PSPL_WEND_N (sortie)
            ParseRepeatStmt : repeat stmts until expr ;
              _PSPL_RBEG_N: compilation des instructions
              Evaluation condition / TEST AX,AX / JZ _PSPL_RBEG_N
            Break : JMP vers le label _PSPL_*END_N de la boucle courante
            Continue : JMP vers le label de test/increment de la boucle courante
            LoopPush / LoopPop : pile des labels break/continue pour imbrication

  TODO 15 - CHAINES DE CARACTERES (String)
            Representation : pointeur 16 bits vers ASCIIZ (termine par 0)
            Affectation : copie de pointeur (pas de copie profonde)
              s := 'abc' -> MOV AX, OFFSET _PSPK_N / MOV [BP-n], AX
            Concatenation : s := s1 + s2 ;
              PUSH AX (s2) / ... load s1 into AX
              POP BX / CALL _PSPRT_CONCAT -> AX = ptr _PSP_STRBUF
            Comparaison : s1 = s2      -> CALL _PSPRT_STRCMP / TEST AX,AX / SETZ
                          s1 <> s2     -> CALL _PSPRT_STRCMP / TEST AX,AX / SETNZ
                          s1 < s2 etc. -> CALL _PSPRT_STRCMP / CMP AX,0 / Jcc
            Fonctions de chaine (appels inline) :
              Length(s)         -> CALL _PSPRT_STRLEN(SI=AX) -> AX = longueur
              Copy(s, pos, len) -> CALL _PSPRT_COPY(SI,BX,CX) -> AX = ptr buf
              Pos(sub, s)       -> CALL _PSPRT_POS(SI=sub,DI=s) -> AX = position (1-base) ou 0
              Delete(s, pos, len) -> CALL _PSPRT_DELETE(SI,BX,CX) -> modifie buf
              Insert(sub, s, pos) -> CALL _PSPRT_INSERT(SI=sub,DI=s,BX=pos)
              Concat(s1,s2,...) -> chaine de CALL _PSPRT_CONCAT
              UpCase(c)         -> AND AL,0DFh (si 'a'..'z') -> AX
              LowerCase(s)      -> CALL _PSPRT_LOWERCASE(SI=AX) -> AX = ptr buf
              Trim(s)           -> CALL _PSPRT_TRIM(SI=AX) -> AX = ptr buf
            Conversion nombre <-> chaine :
              IntToStr(n)  / Str(n, s)  -> CALL _PSPRT_NUMTOSTR
              StrToInt(s)  / Val(s,n,c) -> CALL _PSPRT_STRTONUM
              Chr(n)       -> CALL _PSPRT_CHR -> AX = ptr chaine 1 car
              Ord(c)       -> valeur directe (AX = code ASCII)

  TODO 16 - FONCTIONS ET PROCEDURES
            ParseFuncDecl : function Nom(params): TypeRetour;
              [forward;] -> enregistrement sans corps, IsForward = true
              Bloc : [const] [type] [var] begin stmts end;
              Valeur de retour : Nom := expr; -> MOV [BP+retoffset], AX
                Ou Result := expr; (extension Free Pascal) -> meme chose
              Label de retour : _PSPL_RET_N pour Exit premature
              Emission : _PSPF_Nom PROC NEAR ... _PSPF_Nom ENDP
            ParseProcDecl : procedure Nom(params);
              Identique sauf pas de valeur de retour (TypeIdx = TY_VOID)
            Parametres :
              Par valeur : function F(x: Integer) -> copie sur pile
              Par reference : function F(var x: Integer) -> pointeur sur pile
                Lecture : MOV BX,[BP+n] / MOV AX,[BX]
                Ecriture : MOV BX,[BP+n] / MOV [BX],AX
              Plusieurs params meme type : (a, b, c: Integer)
              Valeurs par defaut : stub + avertissement (non standard TP)
            Forward declaration : procedure P; forward;
              Premier passage : enregistre le symbole SC_PROC + IsForward
              Deuxieme passage : associe le corps a la declaration
            Fonctions imbriquees (1 niveau) : procedure interne dans une procedure
              Acces au cadre parent via chainage statique [BP]
              Avertissement si plus de 2 niveaux d imbrication
            Appel : ParseCallArgs empile les arguments dans l ordre Pascal
              (gauche a droite), CALL _PSPF_Nom, resultat dans AX

  TODO 17 - PORTEE, PILE ET CADRES D'APPEL
            Convention d appel Pascal :
              Arguments empiles gauche a droite (premier arg en premier)
              Le sous-programme nettoie la pile (RET n)
            Prologue de sous-programme :
              PUSH BP / MOV BP,SP / SUB SP, framesize
              framesize = nombre de variables locales * 2 (ou taille alignee)
            Epilogue :
              MOV SP,BP / POP BP / RET paramsize
              paramsize = nombre de parametres * 2
            Acces aux parametres : [BP+4] premier param, [BP+6] deuxieme, etc.
              (apres le BP sauvegarde et l adresse de retour)
            Acces aux variables locales : [BP-2] premiere var, [BP-4] deuxieme, etc.
            Parametres var (reference) :
              L appelant empile LEA AX,[BP-n] / PUSH AX (adresse)
              Le sous-programme lit l adresse : MOV BX,[BP+n] / MOV AX,[BX]
            Chainage statique pour procedures imbriquees :
              L appelant empile le BP parent comme argument supplementaire
              La procedure interne accede au cadre parent via [BP+framelink]
            CurFrameSize : taille courante du cadre local (compteur de mots)
            MaxNesting : avertissement si imbrication > NEST_MAX (4 niveaux)
            Sauvegarde registres : SI, DI preserves par convention dans le code

  TODO 18 - CONSTANTES, TYPES DEFINIS ET ENUMERATIONS
            ParseConstDecl : const PI = 3; MAX = 100; NAME = 'test';
              Constantes non typees : valeur substituee a la compilation
              Constantes typees : const X: Integer = 42; -> DATA DK_WORD
              Constantes chaine : const S = 'abc'; -> DATA DK_STR
            ParseTypeDecl : type TMonType = ... ;
              Alias de type : type TEntier = Integer; -> meme TypeIdx
              Enumeration : type TCouleur = (Rouge, Vert, Bleu);
                Chaque valeur -> SC_ENUM_VAL, Ord = 0, 1, 2, ...
                Fonctions : Ord(v), Succ(v), Pred(v), Low(T), High(T)
              Sous-plage : type TJour = 1..31;
                Stockage : meme taille que le type de base
                Verification de bornes a la compilation si possible
              Pointeur : type PEntier = ^Integer;
                TypeRec.BaseTypeIdx = TY_IDX_INTEGER
              Tableau : type TTab = array[1..10] of Integer;
                (traite en detail dans TODO 19)
              Record : type TPoint = record X,Y: Integer; end;
                (traite en detail dans TODO 20)
            Fonctions ordinales integrees :
              Ord(x) -> AX tel quel (valeur ordinale)
              Chr(n) -> CALL _PSPRT_CHR
              Succ(x) -> INC AX
              Pred(x) -> DEC AX
              Inc(x)  -> INC WORD PTR [BP-n]
              Inc(x,n)-> ADD WORD PTR [BP-n], n
              Dec(x)  -> DEC WORD PTR [BP-n]
              Dec(x,n)-> SUB WORD PTR [BP-n], n
              Low(T)  -> MOV AX, borne_inf
              High(T) -> MOV AX, borne_sup

  TODO 19 - TABLEAUX (Array)
            Declaration : var arr: array[lo..hi] of TypeElem;
              Calcul de la taille : (hi - lo + 1) * SizeOf(TypeElem)
              Variable locale : SUB SP, taille_totale
              Variable globale : _PSPA_arr DB taille_totale DUP(0)
            Tableau litteral : non standard en TP -> stub + avertissement
            Declaration avec taille constante : const N = 10; var a: array[1..N] of Integer;
            Acces en lecture : a[i]
              Index constant : LEA BX,[BP - base_offset + (i-lo)*elemsize]
                MOV AX,[BX]
              Index variable : MOV CX,AX / SUB CX,lo / SHL CX,1 (si word)
                LEA BX,[BP - base_offset] / ADD BX,CX / MOV AX,[BX]
            Acces en ecriture : a[i] := expr;
              Meme calcul d adresse + MOV [BX], AX
            Verification de bornes : si -w (warnings) et index constant :
              Verifier lo <= i <= hi a la compilation ; avertissement sinon
            Tableaux de chaines : array[1..N] of String;
              Chaque element = pointeur 16 bits (2 octets)
            Tableaux multi-dimensionnels : array[1..R, 1..C] of Integer;
              Linearisation : offset = ((i-lo_r)*cols + (j-lo_c)) * elemsize
              Avertissement si plus de 2 dimensions
            Fonctions sur tableaux :
              Length(arr)   -> MOV AX, hi-lo+1 (constante compilee)
              High(arr)     -> MOV AX, hi
              Low(arr)      -> MOV AX, lo
              SizeOf(arr)   -> MOV AX, taille_totale
            FillChar(arr, size, val) : CALL _PSPRT_FILLCHAR
            Move(src, dst, count) : CALL _PSPRT_MOVE

  TODO 20 - ENREGISTREMENTS (Record)
            ParseRecordType : record champ1: Type1; champ2: Type2; ... end;
              Calcul des offsets : chaque champ aligne selon sa taille
              Taille totale du record : somme des tailles des champs
              Enregistrement dans TypeTab : TKP_RECORD + FieldList
            Declaration : var p: TPoint; -> allocation locale ou globale
              Local : SUB SP, SizeOf(TPoint)
              Global : _PSPR_p DB SizeOf(TPoint) DUP(0)
            Acces en lecture : p.X -> LEA BX,[BP-base] / ADD BX,offset_X / MOV AX,[BX]
            Acces en ecriture : p.X := 10; -> meme adresse + MOV [BX],AX
            Acces imbrique : r.inner.field -> calcul offset cumule
            ParseWithStmt : with p do begin X := 10; Y := 20; end;
              Empiler le pointeur de base du record sur une pile with
              Lors de la resolution d un identifiant : chercher d abord dans
                les champs du record courant (stack with)
              Imbrication : with r1 do with r2 do ... (plusieurs niveaux)
            Records imbriques : record contenant un record comme champ
              Calcul d offset recursif
            Variant record (simplifie) :
              record case Tag: Integer of
                0: (x: Integer);
                1: (s: String);
              end;
              Tous les variants partagent le meme espace (union)
              Taille = max(taille de chaque variant) + taille du tag
              Avertissement : pas de verification de coherence a l execution

  TODO 21 - DIRECTIVES PSP ET INCLUSIONS
            Directives de page <%@ ... %> :
              ContentType=text/html : emission d un en-tete HTTP en debut de sortie
                _PSPK_CT DB 'Content-Type: text/html',13,10,13,10,0
                Avant tout autre code : MOV SI, OFFSET _PSPK_CT / CALL _PSPRT_PRINTSTR
              ContentType=text/plain : idem avec text/plain
              ContentType=application/json : idem
              Include file="chemin.psp" : inclure le contenu d un autre fichier
                Ouverture du fichier inclus, insertion dans le flux du lexeur
                Retour au fichier principal apres la fin de l include
                Profondeur maximale d inclusion : INCLUDE_MAX (8)
              CodePage=65001 : stub + avertissement (pas de support Unicode)
            Directives Pascal {$ ... } :
              {$I filename} ou {$INCLUDE filename} : inclusion de fichier source
                Meme mecanisme que l include PSP mais dans le code Pascal
              {$DEFINE nom} : definir un symbole de compilation
              {$UNDEF nom} : indefinir un symbole
              {$IFDEF nom} / {$IFNDEF nom} / {$ELSE} / {$ENDIF} :
                Compilation conditionnelle : si symbole defini/indefini
                Pile de conditions pour imbrication
              {$MODE TP} : mode Turbo Pascal (compatible TP7)
              {$MODE FPC} : mode Free Pascal (active Result, etc.)
                Detecte au debut de la compilation, affecte certaines extensions
            DefineTab[0..MAX_DEFINE-1] : table des symboles de compilation
            IncludeStack[0..INCLUDE_MAX-1] : pile des fichiers inclus

  TODO 22 - FONCTIONS ET PROCEDURES STANDARD
            Entrees/Sorties :
              Write(...) et WriteLn(...) : traites dans TODO 12
              Read(v) : INT 21h AH=01h -> caractere dans AL ; boucle pour nombre
              ReadLn(v) : Read(v) + consommer jusqu a CR
              Assign(f, nom) : stub, fichier texte non supporte en mode CGI
              Reset(f), Rewrite(f), Close(f) : stubs + avertissement
              EOF(f), EOLN(f) : stubs -> MOV AX,1 (toujours vrai)
            Mathematiques :
              Abs(n)    -> CWD / XOR AX,DX / SUB AX,DX (valeur absolue)
              Sqr(n)    -> IMUL AX,AX (carre)
              Sqrt(n)   -> CALL _PSPRT_SQRT (Newton-Raphson entier)
              Odd(n)    -> AND AX,1 (impair -> AX=1)
              Random    -> CALL _PSPRT_RANDOM (LCG 16 bits) -> AX
              Random(n) -> CALL _PSPRT_RANDOM / XOR DX,DX / IDIV n -> DX (reste)
              Randomize -> CALL _PSPRT_RANDOMIZE (graine depuis horloge)
            Systeme :
              Halt       -> MOV AX,4C00h / INT 21h
              Halt(code) -> MOV AX,4C00h + code / INT 21h
              Exit       -> JMP _PSPL_RET_N (sortie de la procedure courante)
              Break      -> JMP label_end de la boucle courante
              Continue   -> JMP label_test de la boucle courante
              SizeOf(T)  -> MOV AX, taille (constante compilee)
              Lo(w)      -> AND AX,00FFh
              Hi(w)      -> MOV AL,AH / XOR AH,AH
              Swap(w)    -> XCHG AL,AH
            Memoire :
              New(p)      -> CALL _PSPRT_ALLOC(CX=sizeof(type)) -> AX=ptr
              Dispose(p)  -> stub (pas de liberation dans le heap statique)
              GetMem(p,n) -> CALL _PSPRT_ALLOC(CX=n) -> AX=ptr
              FreeMem(p,n)-> stub + avertissement
              FillChar(v, n, c) -> CALL _PSPRT_FILLCHAR(DI=ptr, CX=n, AL=c)
              Move(src, dst, n) -> CALL _PSPRT_MOVE(SI=src, DI=dst, CX=n)
            Conversion (voir aussi TODO 15) :
              Str(n, s)   -> _PSPRT_NUMTOSTR + copie ptr dans s
              Val(s, n, code) -> _PSPRT_STRTONUM + code=0 si OK
              IntToStr(n) -> _PSPRT_NUMTOSTR -> AX=ptr (extension FPC)
              StrToInt(s) -> _PSPRT_STRTONUM -> AX=entier (extension FPC)
            Environnement (extensions CGI) :
              ParamStr(i) -> stub MOV AX,0 + avertissement
              ParamCount  -> stub MOV AX,0  + avertissement
              GetEnv(s)   -> INT 21h AH=62h (stub) + avertissement

  TODO 23 - GESTION DES ERREURS
            Erreurs de compilation :
              FatalError(msg) : affiche 'Erreur ligne N : msg' + arret (exit code 1)
              WarnMsg(msg) : affiche 'Avertissement ligne N : msg' (si -w actif)
              Compteur d erreurs et d avertissements : affiche le total en fin
            Erreurs de syntaxe :
              Expect(token) : si le token courant ne correspond pas -> FatalError
              SkipTo(tokens) : avancer jusqu a un token de synchronisation
                Tokens de synchro : ; end %> begin (pour recovery minimaliste)
            Erreurs de type :
              Type incompatible dans affectation -> erreur
              Type incompatible dans expression -> avertissement + coercition
              Parametre de type incorrect -> erreur
            Erreurs d execution (code genere) :
              Division par zero : TEST BX,BX / JNZ ok / CALL _PSPRT_PANIC_DIV0
              Depassement de pile : avertissement compile si framesize > FRAME_WARN
              Index hors bornes (si verifiable a la compilation) : avertissement
            Gestion try/except (style Delphi, basique) :
              try bloc except [on E: Exception do bloc] end;
              Similaire a TODO 23 de JS86 : vecteur _PSPX_HANDLER + save/restore SP/BP
              raise expr -> evaluer expr + JMP vers le handler ou _PSPRT_PANIC
              Stub simplifie : try/except attrape toutes les erreurs sans filtre
              finally : toujours execute apres try ou except
              _PSPX_HANDLER DW 0, _PSPX_SAVESP DW 0, _PSPX_SAVEBP DW 0

  TODO 24 - RUNTIME MINIMAL
            _PSPRT_PRINT(BX=handle, DX=buf, CX=len) : INT 21h AH=40h
            _PSPRT_PRINTSTR(SI=ptr ASCIIZ) : calcule longueur + _PSPRT_PRINT BX=1
            _PSPRT_PRINTLN : _PSPRT_PRINTSTR + emet CR+LF
            _PSPRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX=longueur
            _PSPRT_NUMTOSTR(AX=n) : entier signe -> ASCII dans _PSP_NUMBUF -> AX=ptr
            _PSPRT_STRTONUM(SI=str) : ASCII -> entier signe -> AX
            _PSPRT_CONCAT(AX=s1, BX=s2) : copie s1+s2 dans _PSP_STRBUF -> AX=ptr
            _PSPRT_STRCMP(SI=s1, DI=s2) : compare -> AX = -1/0/+1
            _PSPRT_COPY(SI=src, BX=pos, CX=len) : sous-chaine -> AX=ptr buf
            _PSPRT_POS(SI=sub, DI=str) : recherche -> AX = position 1-base ou 0
            _PSPRT_DELETE(SI=str, BX=pos, CX=len) : supprime en place -> buf
            _PSPRT_INSERT(SI=sub, DI=str, BX=pos) : insere -> buf
            _PSPRT_LOWERCASE(SI=str) : minuscules -> AX=ptr buf
            _PSPRT_TRIM(SI=str) : supprime espaces debut/fin -> AX=ptr buf
            _PSPRT_CHR(AL=code) : 1 caractere -> AX=ptr chaine 1 car dans buf
            _PSPRT_SQRT(AX=n) : racine carree entiere (Newton-Raphson) -> AX
            _PSPRT_RANDOM : LCG 16 bits -> AX (graine _PSPRT_SEED DW 1)
            _PSPRT_RANDOMIZE : INT 1Ah AH=00h -> CX:DX -> _PSPRT_SEED
            _PSPRT_ALLOC(CX=nb_bytes) : allocation bump dans _PSP_HEAP -> AX=ptr
            _PSPRT_FILLCHAR(DI=ptr, CX=n, AL=val) : REP STOSB
            _PSPRT_MOVE(SI=src, DI=dst, CX=n) : REP MOVSB
            _PSPRT_PANIC(SI=msg) : affiche msg + MOV AX,4C01h + INT 21h
            _PSPRT_PANIC_DIV0 : msg = 'Runtime error: Division by zero'
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _PSP_HEAP DB 4096 DUP(0) + _PSP_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _PSPF_main dans _TEXT ENDS / _DATA ENDS
            Run : pipeline complet :
              1. ParseArgs et ouverture des fichiers
              2. EmitHeader (_TEXT SEGMENT, _PSPF_main:, MOV AX,_DATA / MOV DS,AX)
              3. Boucle de template : alterner HTML literal / blocs <% %>
              4. Emission MOV AX,4C00h / INT 21h (fin du programme)
              5. EmitRuntime (routines _PSPRT_ )
              6. _TEXT ENDS
              7. EmitDataSeg (_DATA SEGMENT ... _DATA ENDS)
              8. END _PSPF_main
            Fichiers SAMPLES\PSP\ existants et a creer :
              hello.psp           (HTML + Write/WriteLn, boucle for, variables)
              test_string.psp     (chaines, concatenation, litteraux)
              test_function.psp   (fonctions, parametres, appels)
              test_case.psp       (case/of, entiers)
              calculcalciumcorrige.psp (fonctions Real, calcul scientifique)
              -- fichiers supplementaires a creer --
              test_if.psp         (if/then/else, booleens, comparaisons)
              test_array.psp      (tableaux, acces, boucle sur elements)
              test_record.psp     (records, champs, with)
              test_include.psp    (directive <%@ Include %>, {$I})
              test_expr.psp       (expressions, operateurs, priorites)
            Smoke tests : PSP86.EXE -v SAMPLES\PSP\*.psp

  ============================================================ *)

{ ============================================================
  PSP86 - Compilateur Pascal Server Pages -> assembleur 8086
  Version : 1.0  Date : 2026-03-06
  Compilation : ppc386 -O2 -Mtp PSP86.PAS
  ============================================================ }

Program PSP86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PSP86_VERSION = '1.0';
  PSP86_DATE    = '2026-03-06';

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
  MAX_INCLUDE   = 8;     { profondeur max d inclusion }
  MAX_DEFINE    = 64;    { nombre max de symboles de compilation }
  MAX_FIELD     = 32;    { champs max par record }
  MAX_ENUM      = 64;    { valeurs max par enumeration }
  MAX_WITH      = 8;     { profondeur max de with imbrique }
  STACK_SIZE    = 1024;
  FRAME_WARN    = 256;   { seuil avertissement taille cadre (octets) }
  NEST_MAX      = 4;     { profondeur max imbrication proc/func }

  { Prefixes de nommage ASM }
  PSP_VAR_PFX   = '_PSP_';     { variable globale              }
  PSP_FN_PFX    = '_PSPF_';    { fonction / procedure          }
  PSP_STR_PFX   = '_PSPK_';    { constante chaine litterale    }
  PSP_RT_PFX    = '_PSPRT_';   { routine runtime               }
  PSP_LBL_PFX   = '_PSPL_';    { label de saut interne         }
  PSP_ARR_PFX   = '_PSPA_';    { tableau                       }
  PSP_REC_PFX   = '_PSPR_';    { record                        }
  PSP_ENUM_PFX  = '_PSPE_';    { enumeration                   }
  PSP_HTML_PFX  = '_PSPK_HTML_'; { fragment HTML literal        }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Pascal }
  TY_IDX_INTEGER = 0;   { entier 16 bits signe   }
  TY_IDX_WORD    = 1;   { entier 16 bits non signe }
  TY_IDX_BYTE    = 2;   { 8 bits non signe       }
  TY_IDX_CHAR    = 3;   { 8 bits caractere       }
  TY_IDX_BOOLEAN = 4;   { 0 | 1 dans AL/AX      }
  TY_IDX_STRING  = 5;   { pointeur ASCIIZ        }
  TY_IDX_REAL    = 6;   { tronque en entier      }
  TY_IDX_POINTER = 7;   { pointeur generique     }
  TY_IDX_NIL     = 8;   { pointeur nul           }
  TY_IDX_TEXT    = 9;    { fichier texte (handle) }
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
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Pascal / PSP (TODO 02) ---------------------- }
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

  { ---- Mode du template PSP (TODO 03) --------------------- }
  TPSPMode = (TPL_HTML, TPL_CODE);

  { ---- Segment de donnees (TODO 04) ----------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR);

  TDataRec = Record
    LblName : TString;
    Kind    : TDataKind;
    IntVal  : LongInt;
    StrVal  : TString;
  End;

  { ---- Valeurs d expression (TODO 04) --------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                       }
    EK_IMM,    { valeur immediate dans ImmVal                }
    EK_AX,     { valeur dans registre AX                     }
    EK_MEM     { adresse memoire [BP+Offset] ou [_PSP_x]    }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 si pas lvalue) }
  End;

  { ---- Categorie de symbole (TODO 06) ---------------------- }
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

  { ---- Enregistrement symbole (TODO 06) -------------------- }
  TSymRec = Record
    Name        : TString;  { nom original Pascal (minuscule)    }
    MangledName : TString;  { nom ASM mangled (_PSP_xxx etc.)    }
    Cat         : TSymCat;  { categorie (var/const/func etc.)    }
    TypeIdx     : Integer;  { indice dans TypeTab (TY_IDX_*)     }
    Offset      : Integer;  { offset cadre local (BP+n)          }
    ScopeLevel  : Integer;  { profondeur de portee (0=global)    }
    ScopeId     : Integer;  { identifiant unique de portee       }
    IsForward   : Boolean;  { declaration forward non resolue    }
    IsLocal     : Boolean;  { True si variable locale            }
    ImmVal      : LongInt;  { valeur immediate (SC_CONST)        }
    DataIdx     : Integer;  { index DataTab (SC_TYPED_CONST)     }
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

  { Lexeur (TODO 02) }
  LexSrcF   : Text;
  LexOpened : Boolean;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  CurToken  : TToken;

  { Analyseur de template (TODO 03) }
  TplMode      : TPSPMode;
  TplHtmlBuf   : TString;
  TplPending   : TTokenKind;
  TplHtmlCount : Integer;

  { Segment de donnees (TODO 04) }
  DataTab      : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount    : Integer;
  LabelGenSeq  : Integer;

  { Table des symboles (TODO 06) }
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ Utilitaires chaines (TODO 01) }
Function  StrLowerCase(Const S : TString) : TString; Forward;
Function  StrUpperCase(Const S : TString) : TString; Forward;
Function  IntToStr(N : LongInt) : TString; Forward;
Function  StrToIntDef(Const S : TString; Def : LongInt) : LongInt; Forward;
{ Messages (TODO 01) }
Procedure FatalError(Const Msg : TString); Forward;
Procedure WarnMsg(Const Msg : TString); Forward;
{ Lexeur (TODO 02) }
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
{ Analyseur de template (TODO 03) }
Procedure TplInit;       Forward;
Procedure TplClose;      Forward;
Procedure TplEmitHtml;   Forward;
Procedure TplEmitPSPOpen(Kind : TTokenKind); Forward;
Procedure TplNextToken;  Forward;
{ Segment de donnees et litteraux (TODO 04) }
Function  LabelGen : TString; Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure EmitRaw(Const S : String); Forward;
Procedure EmitDataSeg; Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure ParseConstDecl; Forward;
{ Table des symboles (TODO 06) }
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
               Level : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymInit; Forward;
{ Emetteur ASM (TODO 05) }
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
{ Operateurs et expressions (TODO 05) }
Function  OpPrec(Const Op : TString) : Integer; Forward;
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal); Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS PASCAL) [IMPLEMENTE]
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle Pascal ---------- }
{ Comparaison insensible a la casse                            }
Function IsKeyword(Const S : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(S);
  IsKeyword :=
    (L = 'program')   Or (L = 'begin')     Or (L = 'end')       Or
    (L = 'var')        Or (L = 'const')     Or (L = 'type')      Or
    (L = 'if')         Or (L = 'then')      Or (L = 'else')      Or
    (L = 'while')      Or (L = 'do')        Or (L = 'for')       Or
    (L = 'to')         Or (L = 'downto')    Or (L = 'repeat')    Or
    (L = 'until')      Or (L = 'case')      Or (L = 'of')        Or
    (L = 'function')   Or (L = 'procedure') Or (L = 'forward')   Or
    (L = 'array')      Or (L = 'record')    Or (L = 'string')    Or
    (L = 'integer')    Or (L = 'boolean')   Or (L = 'char')      Or
    (L = 'byte')       Or (L = 'word')      Or (L = 'real')      Or
    (L = 'nil')        Or (L = 'true')      Or (L = 'false')     Or
    (L = 'not')        Or (L = 'and')       Or (L = 'or')        Or
    (L = 'xor')        Or (L = 'div')       Or (L = 'mod')       Or
    (L = 'shl')        Or (L = 'shr')       Or (L = 'in')        Or
    (L = 'with')       Or (L = 'uses')      Or (L = 'write')     Or
    (L = 'writeln')    Or (L = 'read')      Or (L = 'readln')    Or
    (L = 'break')      Or (L = 'continue')  Or (L = 'exit')      Or
    (L = 'halt')       Or (L = 'try')       Or (L = 'except')    Or
    (L = 'finally')    Or (L = 'raise')     Or (L = 'result');
End;

{ ---- PrintToken : affichage debug d'un token --------------- }
Procedure PrintToken(Const T : TToken);
Var
  S : TString;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF           : Write('EOF');
    TK_INTEGER       : Write('INT(', T.IntVal, ')');
    TK_REAL          : Write('REAL(', T.Val, ')');
    TK_STRING        : Write('STR(''', T.Val, ''')');
    TK_CHAR          : Write('CHAR(#', T.IntVal, ')');
    TK_IDENT         : Write('IDENT(', T.Val, ')');
    TK_KEYWORD       : Write('KW(', T.Val, ')');
    TK_OP            : Write('OP(', T.Val, ')');
    TK_PUNCT         : Write('PUNCT(', T.Val, ')');
    TK_HTML          : Begin
                         S := T.Val;
                         If Length(S) > 40 Then
                           S := Copy(S, 1, 37) + '...';
                         Write('HTML("', S, '")');
                       End;
    TK_PSP_OPEN      : Write('PSP_OPEN');
    TK_PSP_CLOSE     : Write('PSP_CLOSE');
    TK_PSP_EXPR_OPEN : Write('PSP_EXPR');
    TK_PSP_DIRECTIVE : Write('PSP_DIR');
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

{ ---- Fonctions de test sur les caracteres ------------------- }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ---- LexSkipBraceComment : sauter accolade-commentaire ------ }
Procedure LexSkipBraceComment;
Begin
  Inc(LexColNo); { sauter '{' }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If LexLine[LexColNo] = '}' Then
    Begin
      Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipParenStarComment : sauter paren-star comment ---- }
Procedure LexSkipParenStarComment;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '(' et '*' }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ')') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipLineComment : sauter // ... fin de ligne -------- }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ---- LexScanIdent : scanner un identificateur ou mot-cle --- }
Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  CurToken.RealVal := 0.0;
  { Mots-cles Pascal : stocker en minuscules normalisees }
  If IsKeyword(S) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := StrLowerCase(S);
  End
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
{ Entiers decimaux, hexadecimaux ($FF), reels (3.14, 1.5E3)    }
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsReal  : Boolean;
  NegExp  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  ExpVal  : Integer;
  FltVal  : Real;
Begin
  N       := 0;
  IsReal  := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;

  { Scanner la partie entiere decimale }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;

  { Partie decimale .ddd (mais pas '..' qui est le token de plage) }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] <> '.') And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsReal := True;
    Inc(LexColNo); { sauter '.' }
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;

  { Exposant E [+-] ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
  Begin
    IsReal := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;

  If IsReal Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    CurToken.Kind    := TK_REAL;
    CurToken.RealVal := FltVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.IntVal := N;
    Str(FltVal:0:6, CurToken.Val);
  End
  Else
  Begin
    CurToken.Kind    := TK_INTEGER;
    CurToken.IntVal  := N;
    CurToken.RealVal := 0.0;
    Str(N, CurToken.Val);
  End;
End;

{ ---- LexScanHexNumber : scanner un entier hexadecimal $FF -- }
Procedure LexScanHexNumber;
Var
  N : LongInt;
Begin
  Inc(LexColNo); { sauter '$' }
  N := 0;
  While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 16 + HexVal(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
  CurToken.Kind    := TK_INTEGER;
  CurToken.IntVal  := N;
  CurToken.RealVal := 0.0;
  Str(N, CurToken.Val);
End;

{ ---- LexScanString : chaine Pascal entre quotes simples ---- }
{ Gere le doublement de quote : 'l''echo' -> l'echo            }
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter quote ouvrante }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
    Begin
      Inc(LexColNo);
      { Quote doublee '' -> un seul caractere ' }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
        Inc(LexColNo);
      End
      Else
        Break; { fin de chaine }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind    := TK_STRING;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  { Si chaine de longueur 1, stocker aussi le code ASCII }
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1]);
End;

{ ---- LexScanCharLit : caractere #nn ou #$nn ----------------- }
Procedure LexScanCharLit;
Var
  V : LongInt;
  S : TString;
Begin
  S := '';
  { Scanner une sequence de #nn segments et concatener }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
  Begin
    Inc(LexColNo); { sauter '#' }
    V := 0;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
    Begin
      Inc(LexColNo); { sauter '$' }
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      While (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Begin
        V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
        Inc(LexColNo);
      End;
    End;
    If Length(S) < MAX_STR Then
      S := S + Chr(V And $FF);
  End;

  { Si suivi d'une chaine 'xxx', concatener }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
  Begin
    Inc(LexColNo); { sauter quote ouvrante }
    While LexColNo <= Length(LexLine) Do
    Begin
      If LexLine[LexColNo] = '''' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
        Begin
          If Length(S) < MAX_STR Then S := S + '''';
          Inc(LexColNo);
        End
        Else
          Break;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End;
    { Peut etre suivi d'un autre #nn }
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
    Begin
      { Recurse : appeler a nouveau LexScanCharLit et concatener }
      { Simplifie : on reitere dans la boucle While ci-dessus }
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
      Begin
        Inc(LexColNo);
        V := 0;
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
        Begin
          Inc(LexColNo);
          While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
          Begin
            V := V * 16 + HexVal(LexLine[LexColNo]);
            Inc(LexColNo);
          End;
        End
        Else
        Begin
          While (LexColNo <= Length(LexLine)) And
                (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
          Begin
            V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
            Inc(LexColNo);
          End;
        End;
        If Length(S) < MAX_STR Then
          S := S + Chr(V And $FF);
      End;
    End;
  End;

  { Si un seul caractere -> TK_CHAR, sinon TK_STRING }
  If Length(S) = 1 Then
  Begin
    CurToken.Kind   := TK_CHAR;
    CurToken.IntVal := Ord(S[1]);
  End
  Else
  Begin
    CurToken.Kind   := TK_STRING;
    CurToken.IntVal := 0;
  End;
  CurToken.Val     := S;
  CurToken.RealVal := 0.0;
End;

{ ---- LexInit / LexClose ------------------------------------ }
Procedure LexInit;
Begin
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  { Lire la premiere ligne }
  LexNextLine;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire // ligne }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexSkipLineComment;
    End

    { Commentaire accolade - ne pas confondre avec dollar-directives }
    Else If Ch = '{' Then
    Begin
      LexSkipBraceComment;
    End

    { Commentaire ( star ... star ) ou operateur '(' }
    Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipParenStarComment;
    End

    { Entier hexadecimal $FF }
    Else If (Ch = '$') And (LexColNo < Length(LexLine)) And
            IsHexDigit(LexLine[LexColNo + 1]) Then
    Begin
      LexScanHexNumber;
      Scanning := False;
    End

    { Caractere literal #nn }
    Else If Ch = '#' Then
    Begin
      LexScanCharLit;
      Scanning := False;
    End

    { Chaine Pascal 'xxx' }
    Else If Ch = '''' Then
    Begin
      LexScanString;
      { Si suivi immediatement par #nn -> concatener (multi-segment) }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
      Begin
        { Sauvegarder la chaine deja scannee et concatener }
        { On reutilise directement CurToken.Val comme base }
        { LexScanCharLit va produire un nouveau token, on doit fusionner }
        { Approche simplifiee : deja geree dans LexScanCharLit }
      End;
      Scanning := False;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Operateur d affectation := }
    Else If (Ch = ':') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := ':=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <> }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Token de plage .. }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '..';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateurs simples }
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = '@') Or
            (Ch = '^') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation }
    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '[') Or (Ch = ']') Or (Ch = '.') Or (Ch = ':') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Balise fermante %> (geree ici en contexte code Pascal) }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_PSP_CLOSE;
      CurToken.Val  := '%>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Caractere inconnu : avancer et signaler }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ord=' + IntToStr(Ord(Ch)) + ')');
      Inc(LexColNo);
    End;
  End;

  PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - ANALYSEUR DE TEMPLATE PSP [IMPLEMENTE]
  ============================================================ }

{ ---- TplInit : initialiser l analyseur de template --------- }
Procedure TplInit;
Begin
  TplMode      := TPL_HTML;
  TplHtmlBuf   := '';
  TplPending   := TK_EOF;
  TplHtmlCount := 0;
End;

{ ---- TplClose : finaliser l analyseur de template ---------- }
Procedure TplClose;
Begin
  If TplMode = TPL_CODE Then
    WarnMsg('fin de fichier atteinte en mode code (balise %> manquante ?)');
End;

{ ---- TplEmitHtml : emettre le buffer HTML comme token ------- }
{ Procedure interne utilisee par TplNextToken                   }
Procedure TplEmitHtml;
Begin
  CurToken.Kind    := TK_HTML;
  CurToken.Val     := TplHtmlBuf;
  CurToken.Line    := LexLineNo;
  CurToken.Col     := LexColNo;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  Inc(TplHtmlCount);
  PrintToken(CurToken);
  TplHtmlBuf := '';
End;

{ ---- TplEmitPSPOpen : emettre un token PSP open ------------- }
Procedure TplEmitPSPOpen(Kind : TTokenKind);
Begin
  CurToken.Kind := Kind;
  CurToken.Line := LexLineNo;
  CurToken.Col  := LexColNo;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  Case Kind Of
    TK_PSP_OPEN:      CurToken.Val := '<%';
    TK_PSP_EXPR_OPEN: CurToken.Val := '<%=';
    TK_PSP_DIRECTIVE:  CurToken.Val := '<%@';
  Else
    CurToken.Val := '';
  End;
  TplMode := TPL_CODE;
  PrintToken(CurToken);
End;

{ ---- TplNextToken : token suivant en mode template --------- }
{ Alterne entre mode HTML (accumulation texte brut) et mode    }
{ CODE (lexeur Pascal via LexNextToken).                       }
{ En HTML : accumule les caracteres jusqu a < pourcent ou EOF. }
{ En CODE : delegue a LexNextToken, revient en HTML sur        }
{   TK_PSP_CLOSE (pourcent >).                                 }
Procedure TplNextToken;
Var
  Ch    : Char;
  Kind  : TTokenKind;
Begin
  { 1) Si un tag PSP est en attente (apres emission de TK_HTML) }
  If TplPending <> TK_EOF Then
  Begin
    Kind := TplPending;
    TplPending := TK_EOF;
    TplEmitPSPOpen(Kind);
    Exit;
  End;

  { 2) Mode HTML : scanner caractere par caractere }
  If TplMode = TPL_HTML Then
  Begin
    TplHtmlBuf := '';

    While Not LexEOF Do
    Begin
      { Fin de ligne : ajouter saut de ligne au buffer }
      If LexColNo > Length(LexLine) Then
      Begin
        { Vider le buffer si presque plein (reserve pour CR+LF) }
        If Length(TplHtmlBuf) >= MAX_STR - 1 Then
        Begin
          TplEmitHtml;
          Exit;
        End;
        TplHtmlBuf := TplHtmlBuf + #13#10;
        LexNextLine;
        Continue;
      End;

      Ch := LexLine[LexColNo];

      { Detection de la balise ouvrante <pourcent }
      If (Ch = '<') And (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = '%') Then
      Begin
        Inc(LexColNo, 2);

        { Determiner le type : <%=  <%@  ou  <% simple }
        If (LexColNo <= Length(LexLine)) And
           (LexLine[LexColNo] = '=') Then
        Begin
          Kind := TK_PSP_EXPR_OPEN;
          Inc(LexColNo);
        End
        Else If (LexColNo <= Length(LexLine)) And
                (LexLine[LexColNo] = '@') Then
        Begin
          Kind := TK_PSP_DIRECTIVE;
          Inc(LexColNo);
        End
        Else
          Kind := TK_PSP_OPEN;

        { Si du HTML a emettre d abord, mettre le tag en attente }
        If Length(TplHtmlBuf) > 0 Then
        Begin
          TplPending := Kind;
          TplEmitHtml;
          Exit;
        End
        Else
        Begin
          { Pas de HTML, emettre directement le tag PSP }
          TplEmitPSPOpen(Kind);
          Exit;
        End;
      End
      Else
      Begin
        { Caractere HTML normal }
        If Length(TplHtmlBuf) >= MAX_STR Then
        Begin
          { Buffer plein : emettre le fragment }
          TplEmitHtml;
          Exit;
        End;
        TplHtmlBuf := TplHtmlBuf + Ch;
        Inc(LexColNo);
      End;
    End;

    { EOF atteint en mode HTML }
    If Length(TplHtmlBuf) > 0 Then
    Begin
      TplEmitHtml;
      Exit;
    End;

    { Plus de HTML, emettre TK_EOF }
    CurToken.Kind    := TK_EOF;
    CurToken.Val     := '';
    CurToken.Line    := LexLineNo;
    CurToken.Col     := LexColNo;
    CurToken.IntVal  := 0;
    CurToken.RealVal := 0.0;
    PrintToken(CurToken);
  End

  { 3) Mode CODE : deleguer au lexeur Pascal }
  Else
  Begin
    LexNextToken;

    { Si le lexeur retourne pourcent>, repasser en mode HTML }
    If CurToken.Kind = TK_PSP_CLOSE Then
      TplMode := TPL_HTML;
  End;
End;

{ ============================================================
  TODO 04 - LITTERAUX ET CONSTANTES PASCAL [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques ---------------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := PSP_LBL_PFX + IntToStr(LabelGenSeq);
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier ASM --- }
Procedure EmitRaw(Const S : String);
Begin
  WriteLn(OutF, S);
End;

{ ---- DataAdd : ajouter une entree dans DataTab -------------- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  DataTab[DataCount].LblName := Lbl;
  DataTab[DataCount].Kind    := Kind;
  DataTab[DataCount].IntVal  := AIntVal;
  DataTab[DataCount].StrVal  := AStrVal;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ---- DataAddStr : creer un label et stocker une chaine ------ }
{ Retourne le label genere (_PSPK_N).                           }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := PSP_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DataTab ------ }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- EmitDataSeg : emettre le segment _DATA complet --------- }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  { Constantes Pascal runtime }
  EmitRaw(PSP_RT_PFX + 'CRLF    DB  13,10,0');
  EmitRaw(PSP_RT_PFX + 'STRBUF  DB  256 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'NUMBUF  DB  12 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'TRUE_S  DB  ''TRUE'',0');
  EmitRaw(PSP_RT_PFX + 'FALSE_S DB  ''FALSE'',0');
  { Entrees dynamiques de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        If DataTab[I].StrVal <> '' Then
          EmitRaw(DataTab[I].LblName + '  DW  OFFSET ' + DataTab[I].StrVal)
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
        Begin
          { Doubler les apostrophes pour syntaxe MASM }
          S := '';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
        End;
    End;
  End;
  EmitRaw('_DATA   ENDS');
End;

{ ---- LitEval : evaluer un token litteral en TExprVal -------- }
{ Gere : TK_INTEGER, TK_REAL (tronque+warn), TK_STRING,         }
{        TK_CHAR, TK_KEYWORD (true/false/nil).                  }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  Lw : TString;
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case T.Kind Of
    { --- Entiers (decimaux et hexadecimaux) --- }
    TK_INTEGER :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Reels : tronquer en entier + avertissement --- }
    TK_REAL :
    Begin
      WarnMsg('reel ' + T.Val + ' tronque en entier');
      Res.Kind    := EK_IMM;
      Res.ImmVal  := Trunc(T.RealVal);
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Chaines : stocker en DATA, retourner index DataTab --- }
    TK_STRING :
    Begin
      DataAddStr(T.Val);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.SymIdx  := DataCount - 1;  { index de l entree dans DataTab }
    End;

    { --- Caracteres : valeur ordinale dans ImmVal --- }
    TK_CHAR :
    Begin
      If Length(T.Val) = 1 Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := Ord(T.Val[1]);
        Res.TypeIdx := TY_IDX_CHAR;
      End
      Else
      Begin
        { Multi-caractere (#13#10 etc.) : traiter comme chaine }
        DataAddStr(T.Val);
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_STRING;
      End;
    End;

    { --- Mots-cles speciaux : true, false, nil --- }
    TK_KEYWORD :
    Begin
      Lw := T.Val;
      If Lw = 'true' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 1;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'false' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'nil' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_NIL;
      End;
    End;
  Else
    { Token non reconnu comme litteral }
    Res.Kind := EK_NONE;
  End;
End;

{ ---- ParseConstDecl : analyser un bloc const ---------------- }
{ Syntaxe : const Ident = Expr;                                 }
{           const Ident : Type = Expr;                          }
{ Apres le mot-cle 'const', peut contenir plusieurs constantes. }
Procedure ParseConstDecl;
Var
  CName   : TString;
  CType   : TString;
  IsTyped : Boolean;
  Ev      : TExprVal;
  Idx     : Integer;
  DIdx    : Integer;
Begin
  { Le mot-cle 'const' a deja ete consomme par l appelant }
  { Boucle : tant qu on voit un identificateur, on parse une constante }
  While (CurToken.Kind = TK_IDENT) Or
        ((CurToken.Kind = TK_KEYWORD) And
         ((CurToken.Val = 'integer') Or (CurToken.Val = 'word') Or
          (CurToken.Val = 'byte') Or (CurToken.Val = 'char') Or
          (CurToken.Val = 'boolean') Or (CurToken.Val = 'string') Or
          (CurToken.Val = 'real'))) Do
  Begin
    { Nom de la constante }
    If CurToken.Kind <> TK_IDENT Then
      Break;
    CName := CurToken.Val;
    TplNextToken;

    { Constante typee ? const X : Integer = 42; }
    IsTyped := False;
    CType   := '';
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      IsTyped := True;
      TplNextToken;
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        CType := CurToken.Val;
        TplNextToken;
      End
      Else
        WarnMsg('type attendu apres '':'' dans la constante ' + CName);
    End;

    { Signe = }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      TplNextToken
    Else
    Begin
      WarnMsg('''='' attendu dans la declaration de constante ' + CName);
      Break;
    End;

    { Valeur : expression constante (pliage de constantes) }
    ParseExpr(Ev);

    { Enregistrer la constante dans la table des symboles (TODO 06) }
    If IsTyped Then
    Begin
      { Constante typee -> entree DATA + symbole SC_TYPED_CONST }
      If Ev.TypeIdx = TY_IDX_STRING Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST_TYPED: ', CName, ' : ', CType,
                  ' = ''', DataTab[Ev.SymIdx].StrVal, '''');
        DIdx := DataAdd(PSP_VAR_PFX + CName, DK_WORD, 0,
                        DataTab[Ev.SymIdx].LblName);
      End
      Else
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST_TYPED: ', CName, ' : ', CType,
                  ' = ', Ev.ImmVal);
        DIdx := DataAddWord(PSP_VAR_PFX + CName, Ev.ImmVal);
      End;
      Idx := SymAdd(CName, SC_TYPED_CONST, Ev.TypeIdx);
      If Idx >= 0 Then
      Begin
        SymTab[Idx].ImmVal  := Ev.ImmVal;
        SymTab[Idx].DataIdx := DIdx;
      End;
    End
    Else
    Begin
      { Constante non-typee -> substitution : symbole SC_CONST }
      { Valeur immediate stockee dans ImmVal de TSymRec         }
      If Ev.TypeIdx = TY_IDX_STRING Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST: ', CName,
                  ' = ''', DataTab[Ev.SymIdx].StrVal, '''');
        DIdx := DataAdd(PSP_VAR_PFX + CName, DK_WORD, 0,
                        DataTab[Ev.SymIdx].LblName);
        Idx := SymAdd(CName, SC_CONST, Ev.TypeIdx);
        If Idx >= 0 Then
        Begin
          SymTab[Idx].ImmVal  := 0;
          SymTab[Idx].DataIdx := DIdx;
        End;
      End
      Else
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST: ', CName, ' = ', Ev.ImmVal);
        Idx := SymAdd(CName, SC_CONST, Ev.TypeIdx);
        If Idx >= 0 Then
        Begin
          SymTab[Idx].ImmVal  := Ev.ImmVal;
          SymTab[Idx].DataIdx := -1;
        End;
      End;
    End;

    { Point-virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;
End;

{ ============================================================
  TODO 06 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymMangle : generer le nom ASM mangled ------------------- }
{ Le prefixe depend de la categorie du symbole.                   }
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx : TString;
Begin
  Case Cat Of
    SC_VAR        : Pfx := PSP_VAR_PFX;
    SC_CONST      : Pfx := PSP_VAR_PFX;
    SC_TYPED_CONST: Pfx := PSP_VAR_PFX;
    SC_PARAM      : Pfx := PSP_VAR_PFX;
    SC_VARPARAM   : Pfx := PSP_VAR_PFX;
    SC_FUNC       : Pfx := PSP_FN_PFX;
    SC_PROC       : Pfx := PSP_FN_PFX;
    SC_TYPE       : Pfx := '';
    SC_FIELD      : Pfx := PSP_REC_PFX;
    SC_ENUM_VAL   : Pfx := PSP_ENUM_PFX;
    SC_LABEL      : Pfx := PSP_LBL_PFX;
  Else
    Pfx := PSP_VAR_PFX;
  End;
  SymMangle := Pfx + StrUpperCase(Name);
End;

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
{ Retourne l indice du symbole ajoute, ou -1 si table pleine.    }
{ Verifie les doublons dans le scope courant.                     }
Function SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer;
Var
  Lw  : TString;
  Idx : Integer;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  Lw := StrLowerCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Lw, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    { Si c est un forward, on autorise la redefinition }
    If SymTab[Dup].IsForward Then
    Begin
      SymTab[Dup].IsForward := False;
      SymTab[Dup].TypeIdx   := TIdx;
      SymAdd := Dup;
      Exit;
    End
    Else
    Begin
      WarnMsg('symbole deja declare dans ce scope: ' + Name);
      SymAdd := Dup;
      Exit;
    End;
  End;

  Idx := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);

  SymTab[Idx].Name        := Lw;
  SymTab[Idx].MangledName := SymMangle(Lw, Cat);
  SymTab[Idx].Cat         := Cat;
  SymTab[Idx].TypeIdx     := TIdx;
  SymTab[Idx].Offset      := 0;
  SymTab[Idx].ScopeLevel  := CurScopeLevel;
  SymTab[Idx].ScopeId     := CurScopeId;
  SymTab[Idx].IsForward   := False;
  SymTab[Idx].IsLocal     := (CurScopeLevel > 0);
  SymTab[Idx].ImmVal      := 0;
  SymTab[Idx].DataIdx     := -1;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Lw,
            ' cat=', Ord(Cat),
            ' scope=', CurScopeLevel,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

{ ---- SymFind : rechercher un symbole (interne -> global) ----- }
{ Parcourt la table du plus recent au plus ancien, retourne le    }
{ premier symbole dont le ScopeLevel est inferieur ou egal au     }
{ scope courant. Retourne -1 si non trouve.                       }
Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel <= CurScopeLevel) Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ---- SymFindInScope : rechercher dans un scope precis -------- }
{ Retourne l indice du symbole ou -1 si non trouve.               }
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ---- SymEnterScope : entrer dans un nouveau scope ------------ }
Procedure SymEnterScope;
Begin
  If CurScopeLevel >= MAX_SCOPE Then
  Begin
    WarnMsg('profondeur de scope maximale atteinte');
    Exit;
  End;
  Inc(CurScopeLevel);
  Inc(ScopeIdSeq);
  CurScopeId := ScopeIdSeq;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScopeLevel,
            ' id=', CurScopeId);
End;

{ ---- SymLeaveScope : quitter le scope courant ---------------- }
{ Les symboles du scope courant restent dans la table mais ne     }
{ seront plus trouves par SymFind car ScopeLevel > CurScopeLevel. }
Procedure SymLeaveScope;
Begin
  If CurScopeLevel <= 0 Then
  Begin
    WarnMsg('tentative de quitter le scope global');
    Exit;
  End;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScopeLevel);
  Dec(CurScopeLevel);
  { Restaurer le ScopeId du scope parent }
  If CurScopeLevel = 0 Then
    CurScopeId := 0
  Else
    CurScopeId := CurScopeLevel;  { simplifie, suffisant pour l instant }
End;

{ ---- SymInit : predeclarer les types et symboles builtin ----- }
{ Enregistre les types primitifs et les constantes/procedures     }
{ predefinies dans la table des symboles au scope global (0).     }
Procedure SymInit;
Var
  Idx : Integer;
Begin
  { Types primitifs }
  Idx := SymAdd('integer', SC_TYPE, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'INTEGER';
  Idx := SymAdd('word', SC_TYPE, TY_IDX_WORD);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'WORD';
  Idx := SymAdd('byte', SC_TYPE, TY_IDX_BYTE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BYTE';
  Idx := SymAdd('char', SC_TYPE, TY_IDX_CHAR);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'CHAR';
  Idx := SymAdd('boolean', SC_TYPE, TY_IDX_BOOLEAN);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BOOLEAN';
  Idx := SymAdd('string', SC_TYPE, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'STRING';
  Idx := SymAdd('real', SC_TYPE, TY_IDX_REAL);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'REAL';

  { Constantes predefinies : true, false, nil }
  Idx := SymAdd('true', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 1;
    SymTab[Idx].MangledName := 'TRUE';
  End;
  Idx := SymAdd('false', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'FALSE';
  End;
  Idx := SymAdd('nil', SC_CONST, TY_IDX_NIL);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'NIL';
  End;

  { Procedures/fonctions runtime predeclarees }
  Idx := SymAdd('write', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'WRITE';
  Idx := SymAdd('writeln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'WRITELN';
  Idx := SymAdd('read', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'READ';
  Idx := SymAdd('readln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'READLN';
End;

{ ============================================================
  TODO 05 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- Emetteur ASM : instructions formatees ------------------- }

{ EmitComment : commentaire ASM (prefixe ;) }
Procedure EmitComment(Const S : TString);
Begin
  WriteLn(OutF, '; ', S);
End;

{ EmitLabel : label ASM suivi de ':' en colonne 0 }
Procedure EmitLabel(Const Lbl : TString);
Begin
  WriteLn(OutF, Lbl, ':');
End;

{ EmitInstr : instruction sans operande (8 espaces) }
Procedure EmitInstr(Const Mnem : TString);
Begin
  WriteLn(OutF, '        ', Mnem);
End;

{ EmitInstrA : instruction + un operande }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

{ EmitInstrAB : instruction + deux operandes }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

{ ---- OpPrec : precedence des operateurs binaires Pascal ------ }
{ Retourne 0 si ce n est pas un operateur binaire connu.         }
{ Niveaux Pascal :                                               }
{   4 = multiplicatifs : * / div mod and shl shr                 }
{   3 = additifs       : + - or xor                              }
{   2 = comparaison    : = <> < > <= >= in                       }
{   1 = pas d operateur (seuil pour ParseExpr)                   }
Function OpPrec(Const Op : TString) : Integer;
Begin
  If (Op = '*') Or (Op = '/') Or (Op = 'div') Or (Op = 'mod') Or
     (Op = 'and') Or (Op = 'shl') Or (Op = 'shr') Then
    OpPrec := 4
  Else If (Op = '+') Or (Op = '-') Or (Op = 'or') Or (Op = 'xor') Then
    OpPrec := 3
  Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
          (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
    OpPrec := 2
  Else
    OpPrec := 0;
End;

{ ---- ExprMakeImm : creer une valeur immediate --------------- }
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal);
Begin
  R.Kind    := EK_IMM;
  R.ImmVal  := V;
  R.TypeIdx := TIdx;
  R.Offset  := 0;
  R.SymIdx  := -1;
End;

{ ---- ExprFlushToAX : materialiser une expression dans AX ---- }
{ Si deja AX, ne rien faire. Si immediate, MOV AX, imm.         }
{ Si memoire, sera gere au TODO 06/09.                          }
Procedure ExprFlushToAX(Var E : TExprVal);
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstrAB('XOR', 'AX', 'AX')
      Else
        EmitInstrAB('MOV', 'AX', IntToStr(E.ImmVal));
      E.Kind := EK_AX;
    End;
    EK_AX :
      ; { deja dans AX }
    EK_MEM :
    Begin
      { Sera gere proprement au TODO 06 avec SymTab }
      { Pour l instant, stub : laisser en AX }
      E.Kind := EK_AX;
    End;
    EK_NONE :
    Begin
      EmitInstrAB('XOR', 'AX', 'AX');
      E.Kind := EK_AX;
    End;
  End;
End;

{ ---- ParsePrimary : token primaire -> TExprVal --------------- }
{ Gere : litteraux (entier, reel, chaine, char, true/false/nil), }
{        identificateurs (stub -> EK_MEM, TODO 06),              }
{        sous-expression parenthesee (expr).                     }
Procedure ParsePrimary(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case CurToken.Kind Of
    { Litteraux numeriques }
    TK_INTEGER, TK_REAL, TK_CHAR :
    Begin
      LitEval(CurToken, Res);
      TplNextToken;
    End;

    { Chaine litterale }
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      { Emettre LEA AX, label de la chaine }
      If (Res.SymIdx >= 0) And (Res.SymIdx < DataCount) Then
        EmitInstrAB('LEA', 'AX', DataTab[Res.SymIdx].LblName)
      Else If DataCount > 0 Then
        EmitInstrAB('LEA', 'AX', DataTab[DataCount - 1].LblName);
      Res.Kind := EK_AX;
      TplNextToken;
    End;

    { Mots-cles speciaux : true, false, nil }
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true') Or (CurToken.Val = 'false') Or
         (CurToken.Val = 'nil') Then
      Begin
        LitEval(CurToken, Res);
        TplNextToken;
      End
      Else
      Begin
        { Mot-cle non gere comme expression : erreur douce }
        WarnMsg('mot-cle inattendu dans expression: ' + CurToken.Val);
        TplNextToken;
      End;
    End;

    { Identificateur (variable, constante nommee, appel fonction) }
    TK_IDENT :
    Begin
      { Rechercher dans la table des symboles (TODO 06) }
      Res.SymIdx := SymFind(CurToken.Val);
      If Res.SymIdx >= 0 Then
      Begin
        { Symbole trouve }
        If Opts.DebugMode Then
          WriteLn('  EXPR_IDENT: ', CurToken.Val,
                  ' -> sym[', Res.SymIdx, '] cat=',
                  Ord(SymTab[Res.SymIdx].Cat));
        Case SymTab[Res.SymIdx].Cat Of
          SC_CONST :
          Begin
            { Constante non-typee : substitution immediate }
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_TYPED_CONST :
          Begin
            { Constante typee : reference memoire DATA }
            Res.Kind    := EK_MEM;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_VAR, SC_PARAM, SC_VARPARAM :
          Begin
            { Variable : reference memoire }
            Res.Kind    := EK_MEM;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
            Res.Offset  := SymTab[Res.SymIdx].Offset;
          End;
          SC_FUNC :
          Begin
            { Fonction : sera un appel }
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_ENUM_VAL :
          Begin
            { Valeur d enumeration : immediate }
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
        Else
          { Autre categorie (type, proc, field, label) }
          Res.Kind    := EK_MEM;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_INTEGER;
        End;
      End
      Else
      Begin
        { Symbole non trouve : avertissement, traiter comme 0 }
        WarnMsg('symbole non declare: ' + CurToken.Val);
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End;
      TplNextToken;
      { Detecter un appel de fonction : ident( }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        { Stub : sauter les arguments jusqu a ) }
        TplNextToken;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind := EK_AX;
      End;
    End;

    { Sous-expression parenthesee }
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        TplNextToken;  { consommer ( }
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken  { consommer ) }
        Else
          WarnMsg(''')'' attendu apres expression parenthesee');
      End
      Else
      Begin
        WarnMsg('token inattendu dans expression: ' + CurToken.Val);
        TplNextToken;
      End;
    End;

  Else
    WarnMsg('expression attendue, token: ' + CurToken.Val);
    TplNextToken;
  End;
End;

{ ---- ParseUnary : operateurs unaires prefixes --------------- }
{ Niveau 1 : not, -, @, ^                                       }
Procedure ParseUnary(Var Res : TExprVal);
Begin
  { not (logique ou bits selon type) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      { Pliage de constantes }
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
      End
      Else
        Res.ImmVal := Not Res.ImmVal;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
      Begin
        { not booleen : XOR AX,1 }
        EmitInstrAB('XOR', 'AX', '1');
      End
      Else
      Begin
        { not entier (bits) : NOT AX }
        EmitInstr('NOT    AX');
      End;
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  { Moins unaire }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NEG    AX');
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  { Plus unaire (no-op) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    Exit;
  End;

  { @ (adresse de) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '@') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    { Stub : sera gere au TODO 06 avec LEA AX,[var] }
    If Opts.Warnings Then
      WarnMsg('@ : adresse de -> stub, sera gere au TODO 06');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_POINTER;
    Res.SymIdx  := -1;
    Exit;
  End;

  { ^ (dereferencement pointeur : prefixe en Pascal = ptr^) }
  { En Pascal, ^ est normalement postfixe, mais on le gere ici en prefixe }
  { Le vrai postfixe sera gere au TODO 09 }

  { Pas d operateur unaire : appeler ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : Pratt parser pour operateurs binaires --- }
{ Boucle de montee de precedence.                                }
{ AX = gauche, BX = droite pour emission.                        }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op        : TString;
  Prec      : Integer;
  Right     : TExprVal;
  LeftIsImm : Boolean;
  LeftImm   : LongInt;
  ResType   : Integer;
  LblSkip   : TString;
  LblDone   : TString;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    { Detecter operateur binaire }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'div') Or (CurToken.Val = 'mod') Or
             (CurToken.Val = 'and') Or (CurToken.Val = 'or') Or
             (CurToken.Val = 'xor') Or (CurToken.Val = 'shl') Or
             (CurToken.Val = 'shr') Or (CurToken.Val = 'in')) Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End;

    { Arreter si pas operateur ou precedence insuffisante }
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    TplNextToken;  { consommer l operateur }

    { Sauvegarder operande gauche }
    LeftIsImm := (Res.Kind = EK_IMM);
    LeftImm   := Res.ImmVal;
    If Not LeftIsImm Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
    End;

    { Recurser cote droit (gauche-assoc : Prec + 1) }
    ParseExprPrec(Prec + 1, Right);

    { Pliage de constantes si les deux sont immediats }
    If LeftIsImm And (Right.Kind = EK_IMM) Then
    Begin
      If Op = '+' Then
        ExprMakeImm(LeftImm + Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '-' Then
        ExprMakeImm(LeftImm - Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '*' Then
        ExprMakeImm(LeftImm * Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Div Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('division par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'mod' Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Mod Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('modulo par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'and' Then
        ExprMakeImm(LeftImm And Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'or' Then
        ExprMakeImm(LeftImm Or Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'xor' Then
        ExprMakeImm(LeftImm Xor Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'shl' Then
        ExprMakeImm(LeftImm Shl Integer(Right.ImmVal And 15),
                    TY_IDX_INTEGER, Res)
      Else If Op = 'shr' Then
        ExprMakeImm(LeftImm Shr Integer(Right.ImmVal And 15),
                    TY_IDX_INTEGER, Res)
      { Comparaisons -> booleen }
      Else If Op = '=' Then
        ExprMakeImm(Ord(LeftImm = Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<>' Then
        ExprMakeImm(Ord(LeftImm <> Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<' Then
        ExprMakeImm(Ord(LeftImm < Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>' Then
        ExprMakeImm(Ord(LeftImm > Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<=' Then
        ExprMakeImm(Ord(LeftImm <= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>=' Then
        ExprMakeImm(Ord(LeftImm >= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = 'in' Then
      Begin
        WarnMsg('in : ensembles non supportes, retourne 0');
        ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else
        ExprMakeImm(0, TY_IDX_INTEGER, Res);
    End
    Else
    Begin
      { ---- Emission de code binaire ---- }
      { Determiner le type resultat }
      ResType := Res.TypeIdx;
      If (Res.TypeIdx = TY_IDX_STRING) Or (Right.TypeIdx = TY_IDX_STRING) Then
        ResType := TY_IDX_STRING
      Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
              (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
        ResType := TY_IDX_BOOLEAN;

      { Charger droite dans BX }
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');

      { Restaurer gauche dans AX }
      If LeftIsImm Then
        EmitInstrAB('MOV', 'AX', IntToStr(LeftImm))
      Else
        EmitInstrA('POP', 'AX');

      { AX = gauche, BX = droite }

      { --- Arithmetique --- }
      If Op = '+' Then
      Begin
        If ResType = TY_IDX_STRING Then
          { Concatenation chaine : CALL _PSPRT_CONCAT }
          EmitInstr('CALL   ' + PSP_RT_PFX + 'CONCAT')
        Else
          EmitInstrAB('ADD', 'AX', 'BX');
      End
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'AX', 'BX')

      Else If Op = '*' Then
        EmitInstrA('IMUL', 'BX')

      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        { IDIV BX : AX = quotient, DX = reste }
        LblSkip := LabelGen;
        LblDone := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrA('JMP', LblDone);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        WarnMsg('division par zero possible a l''execution');
        EmitLabel(LblDone);
      End

      Else If Op = 'mod' Then
      Begin
        LblSkip := LabelGen;
        LblDone := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrAB('MOV', 'AX', 'DX');  { reste dans DX }
        EmitInstrA('JMP', LblDone);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblDone);
      End

      { --- Bits / Logiques (meme instruction, type determine le sens) --- }
      Else If Op = 'and' Then
        EmitInstrAB('AND', 'AX', 'BX')

      Else If Op = 'or' Then
        EmitInstrAB('OR', 'AX', 'BX')

      Else If Op = 'xor' Then
        EmitInstrAB('XOR', 'AX', 'BX')

      Else If Op = 'shl' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHL', 'AX', 'CL');
      End

      Else If Op = 'shr' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHR', 'AX', 'CL');
      End

      { --- Comparaisons : CMP + Jcc -> AX = 0|1 --- }
      Else If Op = '=' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<>' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JGE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<=' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JG', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JLE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>=' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JL', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = 'in' Then
      Begin
        { in : test appartenance sous-plage (stub) }
        EmitInstrAB('XOR', 'AX', 'AX');
        WarnMsg('in : ensembles non supportes, retourne 0');
      End;

      Res.Kind    := EK_AX;
      Res.TypeIdx := ResType;
      Res.SymIdx  := -1;
    End;
  Until False;
End;

{ ---- ParseExpr : point d entree pour les expressions --------- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d'erreur et d'avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PSP86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    { Supprimer le fichier de sortie partiel }
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('PSP86: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('PSP86 v', PSP86_VERSION, ' (', PSP86_DATE, ')');
  WriteLn('Compilateur Pascal Server Pages -> assembleur 8086');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)  Cible: MASM .MODEL SMALL');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: PSP86 <page.psp> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  page.psp   : fichier Pascal Server Pages source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: page.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
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

Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V : LongInt;
  C : Integer;
Begin
  Val(S, V, C);
  If C = 0 Then StrToIntDef := V
  Else          StrToIntDef := Def;
End;

{ Extrait le nom de base d'un chemin (sans extension) }
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

    If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('PSP86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PSP86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PSP86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .psp }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.psp') Then
    WarnMsg('extension attendue .psp, trouvee: ' + Ext);

  { Fichier de sortie par defaut : meme nom avec .asm }
  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
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
  { TODO 04 }
  DataCount   := 0;
  LabelGenSeq := 0;
  { TODO 06 }
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
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

  { Creer le fichier de sortie }
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;

  { Initialiser le lexeur et l analyseur template }
  LexInit;
  TplInit;

  { Boucle principale : analyseur de template PSP }
  Repeat
    TplNextToken;
    { TODO 04 : intercepter const pour test }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const') Then
    Begin
      TplNextToken;
      ParseConstDecl;
    End;
  Until CurToken.Kind = TK_EOF;

  { Fermer l analyseur template et le lexeur }
  TplClose;
  LexClose;

  { Emettre le segment de donnees (TODO 04) }
  EmitDataSeg;

  Cleanup;

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
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
  ParseArgs;
  Run;
End.
