{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur C++ vers assembleur 8086
}

(* ============================================================
  CPP86.PAS - Compilateur C++ vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.cpp [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .cpp ou .cxx ou .cc ou .h
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS C++) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_CHAR,
              TK_STRING, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT, TK_PREPROC
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets doubles "abc"
              Sequences d echappement : \n \t \r \\ \" \0 \xNN
            LexScanChar : litteral caractere entre apostrophes 'A'
              ou notation hexadecimale '\x41'
            Commentaires : // ligne unique, /* ... */ bloc multi-lignes
            Mots-cles : auto bool break case catch char class const
              continue default delete do double else enum extern
              false float for friend goto if inline int long
              namespace new operator private protected public register
              return short signed sizeof static struct switch
              template this throw true try typedef union unsigned
              using virtual void volatile while
            Directives preprocesseur : detecter # en debut de ligne
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 ou -32768..32767 (16 bits)
            Entiers hexadecimaux : 0xFF, 0x1A
            Entiers octaux : 077
            Suffixes : U (unsigned), L (long) reconnus et ignores (16 bits)
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Notation scientifique : 1.5e3 -> 1500 (trunc)
            Caracteres : 'A', '\n', '\t', '\0', '\xNN'
            Chaines : "abc" -> pointeur vers donnees DATA, nul terminal
            true : constante booleenne -> AX=1
            false : constante booleenne -> AX=0
            NULL / nullptr : constante pointeur nul -> AX=0
            Constantes enum : valeurs entieres auto-incrementees ou explicites
            sizeof(type) : constante a la compilation

  TODO 04 - PREPROCESSEUR SIMPLIFIE
            #include "fichier" : inclusion textuelle (une passe)
            #include <iostream> : header standard (stubs integres)
            #define NOM valeur : substitution textuelle simple
            #define NOM(args) : macros avec parametres (stub simplifie)
            #ifdef / #ifndef / #else / #endif : compilation conditionnelle
            #undef NOM : suppression de macro
            __LINE__, __FILE__ : macros predefinies
            #pragma once : empecher inclusion multiple
            Commentaires dans les directives : ignorer // et /* ... */

  TODO 05 - OPERATEURS ET PRECEDENCE
            Arithmetiques  : + - * / % (entiers 16 bits)
            Comparaison    : == != < <= > >=
            Logiques       : && || ! (court-circuit)
            Bits           : & | ^ ~ << >>
            Affectation    : = += -= *= /= %= &= |= ^= <<= >>=
            Increment      : ++ -- (prefixe et postfixe)
            Ternaire       : cond ? expr1 : expr2
            Membre         : . -> :: (direct, via pointeur, resolution portee)
            Adresse/Deref  : & (adresse de) * (dereferencement)
            sizeof         : taille en octets d un type ou expression
            new / delete   : allocation / liberation dynamique
            Cast           : (type)expr, static_cast<type>(expr)
            Virgule        : expr1, expr2 (evaluee gauche a droite)
            Precedence C++ standard (15 niveaux du plus fort au plus faible)

  TODO 06 - TABLE DES SYMBOLES
            TSymKind : SK_VAR, SK_CONST, SK_TYPE, SK_FUNC, SK_PARAM,
              SK_FIELD, SK_CLASS, SK_ENUM, SK_NAMESPACE
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsStatic, AccessLevel (public/private/protected)
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Name mangling : _Z prefixe pour fonctions (Itanium ABI simplifie)
            Resolution de surcharge : recherche par nom + signature
            Acces qualifie : Namespace::Classe::Membre

  TODO 07 - SYSTEME DE TYPES
            TTypeKind : TYK_VOID, TYK_BOOL, TYK_CHAR, TYK_SHORT,
              TYK_INT, TYK_LONG, TYK_UNSIGNED, TYK_FLOAT, TYK_DOUBLE,
              TYK_PTR, TYK_REF, TYK_ARRAY, TYK_STRUCT, TYK_UNION,
              TYK_CLASS, TYK_ENUM, TYK_FUNC
            TypeTab, TypeInit : enregistrer les types primitifs et utilisateur
            TypeSizeof : bool=1, char=1, short=2, int=2, long=4(stub 2), ptr=2
            Conversions implicites : char->int, bool->int, enum->int
            Conversions explicites : static_cast, C-style cast (type)expr
            const qualifier : marquer les variables en lecture seule
            Pointeur et reference : T*, T& -> 2 octets (near pointer)
            typedef / using : alias de type

  TODO 08 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _CC_NNNNN)
            Prefixes : _CC_V_ (variable), _CC_F_ (fonction),
              _CC_K_ (chaine const), _CC_RT_ (runtime), _CC_L_ (label),
              _CC_C_ (classe/vtable), _CC_NS_ (namespace)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 09 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr : variantes d ajout
            Variables globales : DW dans DATA avec label _CC_V_nom
            Constantes const : valeurs immuables dans DATA
            Chaines litterales : DB 'abc',0 avec label _CC_K_N
            Tables virtuelles (vtable) : DW offset par methode virtuelle
            Variables static de classe : dans DATA avec label _CC_V_Classe_Membre

  TODO 10 - VARIABLES ET AFFECTATIONS
            Variables globales : segment DATA, acces par label _CC_V_nom
            Variables locales : pile BP, acces [BP-offset]
            Parametres par valeur : copie sur pile (acces [BP+offset])
            Parametres par reference (T&) : adresse sur pile
            Affectation = : ExprLoad + MOV destination, AX
            Affectation composee += -= *= /= etc : Load + Op + Store
            Increment/Decrement ++ -- : INC/DEC direct ou via registre
            Initialisation a la declaration : int x = 42;

  TODO 11 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, ident, appel de fonction
            Acces membre : expr.membre -> offset dans struct/class
            Acces via pointeur : expr->membre -> dereferencement + offset
            Acces index : expr[i] -> offset dans tableau
            Dereferencement * : MOV BX,AX / MOV AX,[BX]
            Adresse & : LEA AX, variable
            new T : allocation dynamique -> CALL _CC_RT_NEW -> AX=ptr
            delete ptr : liberation -> CALL _CC_RT_DELETE
            sizeof(T) : constante a la compilation -> MOV AX, taille
            this : pointeur vers l objet courant (premier parametre cache)
            static_cast<T>(expr) : conversion de type
            Appel de fonction : ParseCallExpr -> PUSH args + CALL label

  TODO 12 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour + - * /
            Modulo % : IDIV -> resultat dans DX (reste)
            Bits : AND/OR/XOR/NOT/SHL/SHR pour & | ^ ~ << >>
            Comparaison : CMP + Jcc pour == != < <= > >=
            Logique && : court-circuit JZ vers false-branch
            Logique || : court-circuit JNZ vers true-branch
            Logique ! : XOR AX,1
            Ternaire ? : evaluer condition, JZ vers false-branch
            Virgule : evaluer gauche, ignorer, evaluer droite -> AX

  TODO 13 - ENTREES/SORTIES (iostream)
            cout << expr : ecriture sur stdout
              cout << "texte" -> INT 21h AH=40h BX=1 (STDOUT)
              cout << nombre -> CALL _CC_RT_NUMTOSTR + ecriture
              cout << endl   -> ecriture CR+LF
              cout << '\n'   -> ecriture LF
            cin >> var : lecture depuis stdin
              cin >> nombre -> INT 21h AH=0Ah + CALL _CC_RT_STRTONUM
              cin >> chaine -> INT 21h AH=0Ah (lecture ligne)
            cerr << expr : ecriture sur stderr (handle 2)
            printf / scanf (stubs C) : avertissement + delegation au runtime
            #include <iostream> : activer les stubs cout / cin / cerr

  TODO 14 - IF / ELSE / SWITCH
            ParseIfStmt : if (cond) stmt [else stmt]
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _CC_L_ELSE_N, _CC_L_ENDIF_N
            else if : chaine de conditions (pas de mot-cle elif en C++)
            ParseSwitchStmt : switch (expr) {
              case val: stmts break; ... default: stmts }
              Emission : CMP + JE pour chaque case
              break : JMP vers fin du switch
              default : label par defaut si aucun case ne correspond
              Labels : _CC_L_CASE_N, _CC_L_SWEND_N
              fall-through : si pas de break, execution sequentielle

  TODO 15 - BOUCLES : while / do-while / for / break / continue
            ParseWhileStmt : while (cond) stmt
              Labels : _CC_L_WTEST_N, _CC_L_WEND_N
            ParseDoWhileStmt : do stmt while (cond);
              Labels : _CC_L_DBEG_N, _CC_L_DTEST_N
            ParseForStmt : for (init; cond; incr) stmt
              init : declaration ou expression
              Labels : _CC_L_FTEST_N, _CC_L_FINCR_N, _CC_L_FEND_N
            break : JMP vers fin de boucle englobante
            continue : JMP vers test/increment de boucle englobante
            LoopPush / LoopPop : pile de labels pour break/continue

  TODO 16 - TABLEAUX ET POINTEURS
            Tableaux statiques : int arr[10] -> 20 octets dans DATA ou pile
              Acces : arr[i] -> base + i*sizeof(T)
              Multidimensionnel : int mat[3][4] -> 24 octets
            Tableaux avec initialisation : int arr[] = {1, 2, 3}
            Arithmetique de pointeurs : ptr+n -> ptr + n*sizeof(*ptr)
              ptr-ptr -> difference / sizeof(T)
            Equivalence tableau/pointeur : arr[i] equiv *(arr+i)
            Chaines C : char* ou char[] -> pointeur vers donnees
            Pointeurs de fonction : int (*fp)(int) -> variable 2 octets
              Appel indirect : CALL [fp]

  TODO 17 - STRUCTURES ET UNIONS
            struct Nom { type1 champ1; type2 champ2; ... };
              Taille = somme des sizeof(Ti) alignes
              Acces champ : offset fixe depuis debut
            union Nom { type1 champ1; type2 champ2; ... };
              Taille = max des sizeof(Ti), champs partagent l offset 0
            typedef struct { ... } Nom;
            Initialisation : Nom var = {val1, val2};
            Affectation de struct : copie champ par champ ou REP MOVSW
            Pointeur vers struct : Nom* ptr -> acces via ptr->champ
            struct imbriquees : struct contenant d autres struct

  TODO 18 - FONCTIONS ET PROTOTYPES
            ParseFuncDecl : type nom(params) { corps }
            Prototypes : type nom(params); (declaration forward)
            Parametres par valeur : copie sur pile
            Parametres par reference : T& -> adresse sur pile
            Parametres par defaut : int f(int x = 0)
            Convention d appel : cdecl 16 bits (caller cleanup)
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            return expr : MOV AX, valeur + JMP vers epilogue
            Surcharge de fonctions : meme nom, parametres differents
              Name mangling : _CC_F_nom_types pour distinguer les surcharges
            Fonctions inline : expansion directe (stub simplifie)
            main() : point d entree, genere label PUBLIC _main

  TODO 19 - CLASSES ET OBJETS
            class Nom { public: ... private: ... protected: ... };
              Sections d acces : public, private, protected
            Champs de donnees : offset dans l instance (comme struct)
            Methodes : fonctions avec this implicite (premier parametre cache)
              Appel : PUSH ptr_objet + CALL _CC_F_Classe_Methode
            Constructeur : Nom::Nom() appele automatiquement apres allocation
              Constructeur par defaut si aucun defini
            Destructeur : Nom::~Nom() appele avant liberation
            Operateur new : CALL _CC_RT_NEW(CX=sizeof(Classe)) -> AX=ptr
              Appel constructeur apres allocation
            Operateur delete : appel destructeur puis CALL _CC_RT_DELETE
            Membres static : variables de classe dans DATA (pas dans l instance)
            this : pointeur vers l objet courant -> [BP+4] (premier param)

  TODO 20 - HERITAGE ET METHODES VIRTUELLES
            class Derivee : public Base { ... };
              Heritage simple : champs de Base precedent ceux de Derivee
              sizeof(Derivee) = sizeof(Base) + champs_propres
            Appel constructeur de Base : Base::Base() en debut de Derivee
            Methodes virtuelles : virtual type methode(params);
              Vtable : table de pointeurs de methodes dans DATA
              Chaque classe : _CC_C_Nom_VTBL DW proc1, proc2, ...
              Appel : MOV BX,[AX] (ptr vtable) / CALL [BX+offset]
            Surcharge (override) : redefinition dans la classe derivee
            Pure virtual : virtual type methode() = 0 (classe abstraite)
              Erreur si instanciation directe de classe abstraite
            dynamic_cast (stub) : verification de type a l execution
            Polymorphisme : appel via pointeur de Base -> dispatch virtuel

  TODO 21 - SURCHARGE D OPERATEURS
            Syntaxe : type operator+(const T& rhs);
            Operateurs surchargeables : + - * / % == != < > <= >=
              ++ -- << >> [] () -> = += -= *= /= etc.
            operator<< pour cout : ostream& operator<<(ostream&, const T&)
              Permet : cout << monObjet
            operator[] : acces par index personnalise
            operator() : objet appelable (foncteur)
            operator= : affectation personnalisee
            Operateurs amis : friend type operator+(const T&, const T&)
            Implementation : appel de fonction avec name mangling specifique

  TODO 22 - TEMPLATES (BASIQUE)
            template<typename T> / template<class T>
            Fonctions template : template<typename T> T max(T a, T b)
              Instanciation implicite : max(1, 2) -> max<int>
              Instanciation explicite : max<int>(1, 2)
            Classes template : template<typename T> class Vector { ... }
              Instanciation : Vector<int> v;
            Specialisation : template<> class Vector<bool> { ... }
            Mecanisme : generation de code separe pour chaque instanciation
              Substitution de T par le type concret
              Labels : _CC_F_nom_T pour chaque instanciation
            Limitation : un seul parametre template, pas de template de template

  TODO 23 - EXCEPTIONS (try / catch / throw)
            ParseTryStmt : try { stmts } catch (Type& e) { stmts }
            catch multiples : try { } catch (T1&) { } catch (T2&) { }
            catch(...) : attraper toute exception
            throw expr : lever une exception
              AX = code exception, BX = argument optionnel
            Mecanisme sans support OS :
              _CC_HANDLER DW 0 dans DATA (ptr vers handler courant)
              try : sauvegarder ancien handler, installer nouveau
              catch : label _CC_L_CATCH_N, CMP AX pour chaque type
              Restauration : handler precedent apres sortie du try
            throw sans handler : affiche message + Halt
            Destructeurs : appel automatique lors du deroulement de pile
              (stub simplifie)

  TODO 24 - ESPACES DE NOMS (namespace)
            namespace Nom { declarations }
            using namespace Nom : rendre tous les symboles de Nom visibles
            using Nom::symbole : importation selective
            Espaces imbriques : namespace A { namespace B { ... } }
              C++17 : namespace A::B { ... } (stub)
            Espace anonyme : namespace { ... } -> portee fichier (comme static)
            std : espace de noms standard (cout, cin, cerr, endl, string)
            Resolution : Nom::symbole -> recherche dans la table du namespace
            Name mangling : prefixe _CC_NS_Nom_ pour les symboles du namespace

  TODO 25 - RUNTIME MINIMAL ET GENERATION FINALE
            _CC_RT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _CC_RT_PRINTLN : _CC_RT_PRINT + CR+LF via _CC_CRLF DB 13,10,0
            _CC_RT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _CC_RT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _CC_RT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _CC_RT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _CC_RT_NEW(CX=nb_octets) : allocation heap -> AX=ptr
            _CC_RT_DELETE(BX=ptr) : liberation (stub)
            _CC_RT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _CC_HEAP DB 4096 DUP(0) + _CC_HEAPTOP DW 0
            EmitClose : END _main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseTranslationUnit ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _main
            Fichiers SAMPLES\CPP\ a creer :
              hello.cpp    (cout, variables, constantes, chaines)
              math.cpp     (fonctions, surcharge, recursion, return)
              control.cpp  (if/else, switch, while, for, do-while)
              arrays.cpp   (tableaux, pointeurs, arithmetique pointeurs)
              structs.cpp  (struct, union, typedef, pointeurs struct)
              classes.cpp  (class, heritage, methodes virtuelles)
              templates.cpp (fonctions et classes template)
              except.cpp   (try/catch/throw, catch(...))
            Smoke tests : CPP86.EXE -v SAMPLES\CPP\*.cpp

  ============================================================ *)

Program CPP86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

(* ============================================================
  CONSTANTES
  ============================================================ *)
Const
  CPP86_VERSION = '1.0';
  CPP86_DATE    = '2026-03-07';

  (* Limites internes *)
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_CLASS     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_VTBL      = 16;
  MAX_MACRO     = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  STACK_SIZE    = 1024;

  (* Prefixes de nommage ASM *)
  CC_VAR_PFX  = '_CC_V_';     (* variable globale / locale statique   *)
  CC_FN_PFX   = '_CC_F_';     (* fonction / methode                   *)
  CC_STR_PFX  = '_CC_K_';     (* constante chaine litterale           *)
  CC_RT_PFX   = '_CC_RT_';    (* routine runtime                      *)
  CC_LBL_PFX  = '_CC_L_';     (* label de saut interne                *)
  CC_CLS_PFX  = '_CC_C_';     (* classe / vtable                      *)
  CC_NS_PFX   = '_CC_NS_';    (* namespace                            *)

  (* Codes de sortie *)
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  (* Indices de types primitifs C++ *)
  TY_IDX_VOID     = 0;
  TY_IDX_BOOL     = 1;
  TY_IDX_CHAR     = 2;
  TY_IDX_SHORT    = 3;
  TY_IDX_INT      = 4;
  TY_IDX_LONG     = 5;
  TY_IDX_UNSIGNED = 6;
  TY_IDX_FLOAT    = 7;
  TY_IDX_DOUBLE   = 8;
  TY_IDX_PTR      = 9;
  TY_IDX_REF      = 10;
  TY_PRIM_COUNT   = 11;
  TY_UNKNOWN      = -1;

(* ============================================================
  TYPES
  ============================================================ *)
Type
  TString = String[MAX_STR];

  (* ---- Options de compilation ----------------------------- *)
  TOptions = Record
    SrcFile   : TString;   (* fichier source (.cpp/.cxx/.cc)        *)
    OutFile   : TString;   (* fichier assembleur de sortie (.asm)   *)
    Verbose   : Boolean;   (* -v : banniere et statistiques         *)
    DebugMode : Boolean;   (* -d : affichage de chaque token        *)
    Warnings  : Boolean;   (* -w : activer les avertissements       *)
  End;

  (* ---- Tokens C++ (TODO 02) ------------------------------- *)
  TTokenKind = (
    TK_EOF,       (* fin de fichier                          *)
    TK_INTEGER,   (* literal entier 42 0xFF 077              *)
    TK_FLOAT,     (* literal flottant 3.14 1.5e3             *)
    TK_CHAR,      (* literal caractere 'A' '\n'              *)
    TK_STRING,    (* literal chaine "abc"                    *)
    TK_IDENT,     (* identificateur (non-mot-cle)            *)
    TK_KEYWORD,   (* mot-cle C++ reconnu                     *)
    TK_OP,        (* operateur + - * / == != etc.            *)
    TK_PUNCT,     (* ponctuation ; , ( ) etc.                *)
    TK_PREPROC    (* directive preprocesseur #include etc.   *)
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     (* valeur textuelle brute          *)
    IntVal   : LongInt;     (* valeur entiere (TK_INTEGER)     *)
    FloatVal : Real;        (* valeur flottante (TK_FLOAT)     *)
    Line     : Integer;     (* ligne source (1-base)           *)
    Col      : Integer;     (* colonne source (1-base)         *)
  End;

  (* ---- Categories de symboles (TODO 06) ------------------- *)
  TSymKind = (
    SK_VAR,        (* variable locale ou globale         *)
    SK_CONST,      (* constante const                    *)
    SK_TYPE,       (* typedef / using / struct / class   *)
    SK_FUNC,       (* declaration de fonction            *)
    SK_PARAM,      (* parametre formel de fonction       *)
    SK_FIELD,      (* champ de struct/class/union        *)
    SK_CLASS,      (* declaration de classe              *)
    SK_ENUM,       (* valeur d enumeration               *)
    SK_NAMESPACE   (* espace de noms                     *)
  );

  (* ---- Niveaux d acces (TODO 19) -------------------------- *)
  TAccessLevel = (AL_PUBLIC, AL_PRIVATE, AL_PROTECTED);

  TSymRec = Record
    Name        : TString;   (* identifiant C++                *)
    MangledName : TString;   (* _CC_V_nom / _CC_F_nom          *)
    Kind        : TSymKind;
    TypeIdx     : Integer;   (* indice dans TypeTab             *)
    ScopeLevel  : Integer;
    Offset      : Integer;   (* [BP-n] pour locaux             *)
    IsStatic    : Boolean;   (* static qualifier                *)
    IsConst     : Boolean;   (* const qualifier                 *)
    Access      : TAccessLevel;
    DeclLine    : Integer;
  End;

  (* ---- Types internes (TODO 07) --------------------------- *)
  TTypeKind = (
    TYK_VOID,
    TYK_BOOL,
    TYK_CHAR,
    TYK_SHORT,
    TYK_INT,
    TYK_LONG,
    TYK_UNSIGNED,
    TYK_FLOAT,
    TYK_DOUBLE,
    TYK_PTR,
    TYK_REF,
    TYK_ARRAY,
    TYK_STRUCT,
    TYK_UNION,
    TYK_CLASS,
    TYK_ENUM,
    TYK_FUNC
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   (* octets : int=2, char=1, ptr=2 *)
    BaseIdx : Integer;   (* type de base pour ptr/ref/array *)
  End;

  (* ---- Valeurs d expression (TODO 11) --------------------- *)
  TExprKind = (
    EK_NONE,   (* void / pas de valeur             *)
    EK_IMM,    (* immediate dans ImmVal             *)
    EK_AX,     (* valeur dans AX                    *)
    EK_MEM     (* adresse [BP+Offset] ou [_CC_V_x]  *)
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   (* indice dans SymTab (-1 = pas de lvalue) *)
  End;

  (* ---- Segment de donnees (TODO 09) ----------------------- *)
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

(* ============================================================
  VARIABLES GLOBALES
  ============================================================ *)
Var
  (* Options *)
  Opts : TOptions;

  (* Compteurs generaux *)
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  (* Valeur fictive pour ignorer un retour TExprVal *)
  GExprDummy : TExprVal;

  (* Lexeur (TODO 02) *)
  LexSrcF    : Text;
  LexLine    : String;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  LexOpened  : Boolean;
  CurToken   : TToken;

  (* Table des symboles (TODO 06) *)
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  (* Table des types (TODO 07) *)
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  (* Emetteur ASM (TODO 08) *)
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;
  CurFnDepth   : Integer;
  CurFnRetLbl  : TString;
  CurFnName    : TString;
  CurClassName : TString;
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;

  (* Segment de donnees (TODO 09) *)
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  (* Etat general *)
  RuntimeEmitted : Boolean;

(* ============================================================
  FORWARD DECLARATIONS
  ============================================================ *)
(* TODO 02 - Lexeur *)
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Procedure LexSkipBlockComment; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexScanString;       Forward;
Procedure LexScanCharLit;      Forward;
Procedure LexNextToken;        Forward;
(* TODO 03 - Litteraux *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
(* TODO 05 - Operateurs *)
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
(* TODO 06 - Table des symboles *)
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString; Scope : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
(* TODO 07 - Systeme de types *)
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
(* TODO 08 - Emetteur ASM *)
Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
Procedure EmitOpen;  Forward;
Procedure EmitClose; Forward;
Procedure EmitDataSeg; Forward;
Procedure EmitHeader; Forward;
(* TODO 09 - Donnees *)
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure EmitRuntime; Forward;
(* TODO 10 - Variables *)
Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Procedure ParseDeclStmt; Forward;
Procedure ParseExprStmt; Forward;
(* TODO 13 - I/O *)
Procedure ParseCoutStmt; Forward;
Procedure ParseCinStmt; Forward;
(* TODO 14 - Controle *)
Procedure ParseIfStmt; Forward;
Procedure ParseSwitchStmt; Forward;
(* TODO 15 - Boucles *)
Procedure ParseWhileStmt; Forward;
Procedure ParseDoWhileStmt; Forward;
Procedure ParseForStmt; Forward;
(* TODO 18 - Fonctions *)
Procedure ParseFuncDecl; Forward;
(* Parseur principal *)
Procedure ParserAdvance; Forward;
Procedure ParseStmt; Forward;
Procedure TypeInit; Forward;
Procedure SymInit; Forward;

(* ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ *)

(* ---- Messages d erreur et d avertissement ----------------- *)

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('CPP86: FATAL: ', Msg);
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
  Write('CPP86:');
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
  Write('CPP86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

(* ---- Banniere ---------------------------------------------- *)

Procedure ShowBanner;
Begin
  WriteLn('CPP86 v', CPP86_VERSION, ' (', CPP86_DATE, ')');
  WriteLn('Compilateur C++ -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: CPP86 <source.cpp> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.cpp : fichier C++ source (.cpp .cxx .cc .h)');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h         : afficher cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  ShowBanner;
  ShowUsage;
End;

(* ---- Utilitaires chaines ----------------------------------- *)

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

(* ---- Initialisation des options ---------------------------- *)

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

(* ---- Analyse des arguments de la ligne de commande --------- *)

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
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('CPP86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('CPP86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('CPP86: fichier source manquant');
    ShowUsage;
  End;

  (* Verifier l extension du fichier source *)
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.cpp') And (Ext <> '.cxx') And (Ext <> '.cc') And (Ext <> '.h') Then
    WarnMsg('extension inhabituelle: ' + Ext + ' (attendu .cpp .cxx .cc .h)');

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

(* ---- Nettoyage --------------------------------------------- *)

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

(* ---- Initialisation generale des variables globales -------- *)

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
  CurFnDepth     := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  CurClassName   := '';
  CurFrameSize   := 0;
  LoopTop        := 0;
  RuntimeEmitted := False;
  LabelGenSeq    := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  CurToken.Kind      := TK_EOF;
  CurToken.Val       := '';
  CurToken.IntVal    := 0;
  CurToken.FloatVal  := 0.0;
  CurToken.Line      := 0;
  CurToken.Col       := 0;
End;

(* ============================================================
  TODO 02 - LEXEUR (TOKENS C++) [IMPLEMENTE]
  ============================================================ *)

(* ---- IsKeyword : teste si S est un mot-cle C++ ------------ *)
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'auto')       Or (S = 'bool')       Or (S = 'break')      Or
    (S = 'case')       Or (S = 'catch')      Or (S = 'char')       Or
    (S = 'class')      Or (S = 'const')      Or (S = 'continue')   Or
    (S = 'default')    Or (S = 'delete')     Or (S = 'do')         Or
    (S = 'double')     Or (S = 'else')       Or (S = 'enum')       Or
    (S = 'extern')     Or (S = 'false')      Or (S = 'float')      Or
    (S = 'for')        Or (S = 'friend')     Or (S = 'goto')       Or
    (S = 'if')         Or (S = 'inline')     Or (S = 'int')        Or
    (S = 'long')       Or (S = 'namespace')  Or (S = 'new')        Or
    (S = 'operator')   Or (S = 'private')    Or (S = 'protected')  Or
    (S = 'public')     Or (S = 'register')   Or (S = 'return')     Or
    (S = 'short')      Or (S = 'signed')     Or (S = 'sizeof')     Or
    (S = 'static')     Or (S = 'struct')     Or (S = 'switch')     Or
    (S = 'template')   Or (S = 'this')       Or (S = 'throw')      Or
    (S = 'true')       Or (S = 'try')        Or (S = 'typedef')    Or
    (S = 'union')      Or (S = 'unsigned')   Or (S = 'using')      Or
    (S = 'virtual')    Or (S = 'void')       Or (S = 'volatile')   Or
    (S = 'while')      Or (S = 'nullptr');
End;

(* ---- PrintToken : affichage debug d un token --------------- *)
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF:     Write('EOF');
    TK_INTEGER: Write('INT(', T.IntVal, ')');
    TK_FLOAT:   Write('FLOAT(', T.Val, ')');
    TK_CHAR:    Write('CHAR(', T.Val, ')');
    TK_STRING:  Write('STR("', T.Val, '")');
    TK_IDENT:   Write('IDENT(', T.Val, ')');
    TK_KEYWORD: Write('KW(', T.Val, ')');
    TK_OP:      Write('OP(', T.Val, ')');
    TK_PUNCT:   Write('PUNCT(', T.Val, ')');
    TK_PREPROC: Write('PREPROC(', T.Val, ')');
  End;
  WriteLn;
End;

(* ---- LexNextLine : lire la prochaine ligne source ---------- *)
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

(* ---- LexInit : ouvrir le fichier source et preparer le lexeur *)
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir ' + Opts.SrcFile);
  LexOpened := True;
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  LexNextLine;
End;

(* ---- LexClose : fermer le fichier source ------------------- *)
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

(* ---- LexSkipBlockComment : sauter commentaire /* ... */ ---- *)
Procedure LexSkipBlockComment;
Var
  Done : Boolean;
Begin
  Inc(LexColNo); Inc(LexColNo); (* sauter slash et etoile *)
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

(* ---- Fonctions de test sur les caracteres ------------------ *)
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_');
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

(* ---- LexScanIdent : scanner un identificateur ou mot-cle --- *)
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
  If IsKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

(* ---- LexScanNumber : scanner un litteral numerique --------- *)
(* Entiers decimaux, hexadecimaux (0x), octaux (0), flottants,  *)
(* suffixes U/L ignores, notation scientifique 1.5e3            *)
Procedure LexScanNumber;
Var
  N        : LongInt;
  Base     : Integer;
  IsFloat  : Boolean;
  NegExp   : Boolean;
  Ch       : Char;
  FracDiv  : Real;
  FracVal  : Real;
  ExpVal   : Integer;
  FltVal   : Real;
Begin
  N       := 0;
  Base    := 10;
  IsFloat := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  Ch      := LexLine[LexColNo];
  (* Detecter prefixe 0x (hex) ou 0 (octal) *)
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch >= '0') And (Ch <= '7') Then
    Begin
      Base := 8;
      Inc(LexColNo); (* sauter le 0, les chiffres suivent *)
    End;
  End;
  (* Scanner la partie entiere *)
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If (Base = 16) And IsHexDigit(Ch) Then
    Begin
      N := N * 16 + HexVal(Ch);
      Inc(LexColNo);
    End
    Else If (Base = 8) And (Ch >= '0') And (Ch <= '7') Then
    Begin
      N := N * 8 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else If (Base = 10) And (Ch >= '0') And (Ch <= '9') Then
    Begin
      N := N * 10 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else
      Break;
  End;
  (* Partie decimale .ddd *)
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); (* sauter le point *)
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
  (* Exposant e/E [+-]ddd *)
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
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
  (* Suffixes U/L/UL/LU/LL ignores *)
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] = 'U') Or (LexLine[LexColNo] = 'u') Or
         (LexLine[LexColNo] = 'L') Or (LexLine[LexColNo] = 'l') Or
         (LexLine[LexColNo] = 'F') Or (LexLine[LexColNo] = 'f')) Do
    Inc(LexColNo);
  (* Calculer la valeur finale (tronquee a entier 16 bits) *)
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else            FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
  End;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
  If IsFloat Then
    CurToken.Kind := TK_FLOAT
  Else
    CurToken.Kind := TK_INTEGER;
End;

(* ---- LexScanEscChar : traiter une sequence d echappement --- *)
(* \n \t \r \0 \a \b \f \v \\ \' \" \xNN                       *)
Function LexScanEscChar : Char;
Var
  Ch : Char;
  V  : Integer;
Begin
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscChar := '\';
    Exit;
  End;
  Ch := LexLine[LexColNo];
  Inc(LexColNo);
  Case Ch Of
    'n'  : LexScanEscChar := #10;
    't'  : LexScanEscChar := #9;
    'r'  : LexScanEscChar := #13;
    '0'  : LexScanEscChar := #0;
    'a'  : LexScanEscChar := #7;
    'b'  : LexScanEscChar := #8;
    'f'  : LexScanEscChar := #12;
    'v'  : LexScanEscChar := #11;
    '\'  : LexScanEscChar := '\';
    '''' : LexScanEscChar := '''';
    '"'  : LexScanEscChar := '"';
    '?'  : LexScanEscChar := '?';
    'x', 'X' :
    Begin
      V := 0;
      If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
      Begin
        V := HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End;
      LexScanEscChar := Chr(V And $FF);
    End;
  Else
    LexScanEscChar := Ch;
  End;
End;

(* ---- LexScanString : chaine entre guillemets doubles ------- *)
(* "abc" avec sequences d echappement                           *)
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); (* sauter guillemet ouvrant *)
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);
      Break;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      Ch := LexScanEscChar;
      If Length(S) < MAX_STR Then
        S := S + Ch;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

(* ---- LexScanCharLit : caractere entre apostrophes ---------- *)
(* 'A'  '\n'  '\x41'                                            *)
Procedure LexScanCharLit;
Var
  Ch : Char;
Begin
  Inc(LexColNo); (* sauter apostrophe ouvrante *)
  Ch := #0;
  If LexColNo <= Length(LexLine) Then
  Begin
    If LexLine[LexColNo] = '\' Then
    Begin
      Inc(LexColNo);
      Ch := LexScanEscChar;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;
  (* Sauter apostrophe fermante *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
    Inc(LexColNo);
  CurToken.Kind   := TK_CHAR;
  CurToken.Val    := Ch;
  CurToken.IntVal := Ord(Ch);
End;

(* ---- LexNextToken : dispatcher principal du lexeur --------- *)
Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    (* Fin de ligne -> passer a la suivante *)
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Exit;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    (* Espaces et tabulations *)
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    (* Commentaire ligne // *)
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
      LexColNo := Length(LexLine) + 1

    (* Commentaire bloc /* ... */ *)
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
      LexSkipBlockComment

    (* Directive preprocesseur # en debut de token *)
    Else If Ch = '#' Then
    Begin
      CurToken.Kind := TK_PREPROC;
      CurToken.Val  := Copy(LexLine, LexColNo, Length(LexLine) - LexColNo + 1);
      LexColNo := Length(LexLine) + 1;
      Scanning := False;
    End

    (* Identificateur ou mot-cle *)
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    (* Nombre decimal ou hex ou octal *)
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    (* Nombre .5 (point suivi de chiffre) *)
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    (* Chaine double-quote "abc" *)
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    (* Caractere single-quote 'A' *)
    Else If Ch = '''' Then
    Begin
      LexScanCharLit;
      Scanning := False;
    End

    (* = == *)
    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '==';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '=';
      End;
      Scanning := False;
    End

    (* ! != *)
    Else If Ch = '!' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '!=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '!';
      End;
      Scanning := False;
    End

    (* < <= << <<= *)
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '<<=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '<<';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '<=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '<';
      End;
      Scanning := False;
    End

    (* > >= >> >>= *)
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '>>=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '>>';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '>';
      End;
      Scanning := False;
    End

    (* + ++ += *)
    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '++';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '+=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '+';
      End;
      Scanning := False;
    End

    (* - -- -= -> *)
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '--';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '-=';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '->';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '-';
      End;
      Scanning := False;
    End

    (* * *= *)
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '*=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '*';
      End;
      Scanning := False;
    End

    (* / /= (les commentaires sont deja traites) *)
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '/=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '/';
      End;
      Scanning := False;
    End

    (* % %= *)
    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '%=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '%';
      End;
      Scanning := False;
    End

    (* & && &= *)
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '&') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '&&';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '&=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '&';
      End;
      Scanning := False;
    End

    (* | || |= *)
    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '|') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '||';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '|=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '|';
      End;
      Scanning := False;
    End

    (* ^ ^= *)
    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '^=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '^';
      End;
      Scanning := False;
    End

    (* ~ bitwise NOT *)
    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '~';
      Scanning := False;
    End

    (* ? ternaire *)
    Else If Ch = '?' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '?';
      Scanning := False;
    End

    (* : :: *)
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ':') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '::';
      End
      Else
      Begin
        CurToken.Kind := TK_PUNCT; CurToken.Val := ':';
      End;
      Scanning := False;
    End

    (* . acces membre ou ... *)
    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      If (LexColNo + 1 <= Length(LexLine)) And
         (LexLine[LexColNo] = '.') And (LexLine[LexColNo + 1] = '.') Then
      Begin
        Inc(LexColNo); Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '...';
      End
      Else
      Begin
        CurToken.Kind := TK_PUNCT; CurToken.Val := '.';
      End;
      Scanning := False;
    End

    (* Ponctuation simple *)
    Else If Ch = ';' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ';';
      Scanning := False;
    End
    Else If Ch = ',' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ',';
      Scanning := False;
    End
    Else If Ch = '(' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := '(';
      Scanning := False;
    End
    Else If Ch = ')' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ')';
      Scanning := False;
    End
    Else If Ch = '[' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := '[';
      Scanning := False;
    End
    Else If Ch = ']' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ']';
      Scanning := False;
    End
    Else If Ch = Chr(123) Then  (* accolade ouvrante *)
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := Chr(123);
      Scanning := False;
    End
    Else If Ch = Chr(125) Then  (* accolade fermante *)
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := Chr(125);
      Scanning := False;
    End

    (* Caractere inconnu : avancer *)
    Else
    Begin
      CompileError('caractere inattendu: ' + Ch);
      Inc(LexColNo);
    End;

  End; (* While Scanning *)
End;

(* ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ *)

(* ---- ExprMakeImm : construire une valeur immediate --------- *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeNone : expression sans valeur (void) ---------- *)
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_VOID;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeBool : valeur booleenne (0 ou 1) -------------- *)
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- LitEvalInt : convertir un token TK_INTEGER en valeur -- *)
(* IntVal est deja calcule par LexScanNumber.                   *)
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

(* ---- LitEvalFloat : convertir un token TK_FLOAT (trunc) --- *)
(* C++ traite les flottants ; en 16 bits on tronque a l entier. *)
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  If IV > 32767 Then IV := 32767;
  If IV < -32768 Then IV := -32768;
  ExprMakeImm(IV, TY_IDX_INT, Res);
End;

(* ---- LitEval : dispatcher principal pour les litteraux ----- *)
(* Types de tokens acceptes : TK_INTEGER, TK_FLOAT, TK_CHAR,   *)
(* TK_STRING, TK_KEYWORD (true/false/nullptr/NULL).             *)
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  Case T.Kind Of
    TK_INTEGER :
      LitEvalInt(T, Res);
    TK_FLOAT :
      LitEvalFloat(T, Res);
    TK_CHAR :
      ExprMakeImm(T.IntVal, TY_IDX_CHAR, Res);
    TK_STRING :
    Begin
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_PTR;
      Res.Offset  := DataCount;  (* index courant avant ajout *)
      DataAddStr(T.Val);
      Res.SymIdx  := -1;
    End;
    TK_KEYWORD :
    Begin
      If T.Val = 'true' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'false' Then
        ExprMakeBool(0, Res)
      Else If T.Val = 'nullptr' Then
        ExprMakeImm(0, TY_IDX_PTR, Res)
      Else
        ExprMakeNone(Res);
    End;
    TK_IDENT :
    Begin
      If T.Val = 'NULL' Then
        ExprMakeImm(0, TY_IDX_PTR, Res)
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

(* ---- DataAdd : ajouter une entree dans le segment DATA ----- *)
(* Retourne l index dans DataTab ou -1 si plein.                *)
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

(* ---- DataAddStr : creer un label _CC_K_N et stocker chaine - *)
(* Retourne le label genere.                                     *)
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := CC_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

(* ---- DataAddWord : ajouter un mot 16 bits dans DATA -------- *)
(* Retourne l index dans DataTab.                                *)
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

(* ---- EmitDataSeg : ecrire _DATA SEGMENT complet ------------ *)
(* Constantes C++ predefinies + DataTab (DK_WORD/DK_BYTE/DK_STR) *)
Procedure EmitDataSeg;
Var
  I : Integer;
  S : TString;
  J : Integer;
  Quote : Char;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  (* Constantes C++ predefinies *)
  EmitRaw('_CC_TRUE_S   DB  ''true'',0');
  EmitRaw('_CC_FALSE_S  DB  ''false'',0');
  EmitRaw('_CC_NULL_S   DB  ''(null)'',0');
  (* Buffer de travail pour concatenation de chaines *)
  EmitRaw('_CC_STRBUF   DB  256 DUP(0)');
  (* Entrees dynamiques de DataTab *)
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
        (* Doubler les apostrophes pour MASM *)
        S := '';
        Quote := '''';
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          If DataTab[I].StrVal[J] = Quote Then
            S := S + ''''''
          Else
            S := S + DataTab[I].StrVal[J];
        End;
        EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
      End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].ElemCount) +
                '   ; tableau (' + IntToStr(DataTab[I].ElemCount) + ' elem)');
    End;
  End;
  EmitRaw('_DATA   ENDS');
End;

(* ============================================================
  STUBS POUR TODO 04..25
  (a implementer dans les prochaines etapes)
  ============================================================ *)

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  BinOpPrec := 0; (* stub *)
End;

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := False; (* stub *)
End;

Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp := False; (* stub *)
End;

Procedure ParsePrimary(Var Res : TExprVal);
Begin
  ExprMakeNone(Res); (* stub *)
End;

Procedure ParseUnary(Var Res : TExprVal);
Begin
  ExprMakeNone(Res); (* stub *)
End;

Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Begin
  ExprMakeNone(Res); (* stub *)
End;

Procedure ParseExpr(Var Res : TExprVal);
Begin
  ExprMakeNone(Res); (* stub *)
End;

Function SymNameClean(Const Name : TString) : TString;
Begin
  SymNameClean := Name; (* stub *)
End;

Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Begin
  Case Kind Of
    SK_VAR, SK_CONST, SK_PARAM, SK_FIELD:
      SymMangle := CC_VAR_PFX + Name;
    SK_FUNC:
      SymMangle := CC_FN_PFX + Name;
    SK_CLASS, SK_TYPE:
      SymMangle := CC_CLS_PFX + Name;
    SK_NAMESPACE:
      SymMangle := CC_NS_PFX + Name;
  Else
    SymMangle := CC_VAR_PFX + Name;
  End;
End;

Function SymFind(Const Name : TString) : Integer;
Begin
  SymFind := -1; (* stub *)
End;

Function SymFindInScope(Const Name : TString; Scope : Integer) : Integer;
Begin
  SymFindInScope := -1; (* stub *)
End;

Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  SymAdd := -1; (* stub *)
End;

Procedure SymEnterScope;
Begin
  (* stub *)
End;

Procedure SymLeaveScope;
Begin
  (* stub *)
End;

Function SymNextOffset : Integer;
Begin
  SymNextOffset := 0; (* stub *)
End;

Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  TypeSizeof := 2; (* stub : defaut 16 bits *)
End;

Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  TypeMangle := 'i'; (* stub *)
End;

Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  TypeKindOf := TYK_INT; (* stub *)
End;

Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Begin
  TypeIsNumeric := True; (* stub *)
End;

Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Begin
  TypeIsPtr := False; (* stub *)
End;

Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  TypeCanCoerce := True; (* stub *)
End;

Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := CC_LBL_PFX + S;
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

Procedure EmitInstr(Const Mnem : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '        ', Mnem);
End;

Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '        ', Mnem, ' ', A1);
End;

Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '        ', Mnem, ' ', A1, ',', A2);
End;

Procedure EmitProlog;
Begin
  EmitInstr('PUSH BP');
  EmitInstrAB('MOV', 'BP', 'SP');
End;

Procedure EmitEpilog;
Begin
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP BP');
  EmitInstr('RET');
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer ' + Opts.OutFile);
  OutFOpen := True;
End;

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    EmitBlankLine;
    EmitRaw('_TEXT ENDS');
    EmitBlankLine;
    EmitDataSeg;
    EmitBlankLine;
    EmitRaw('END _main');
    Close(OutF);
    OutFOpen := False;
  End;
End;

Procedure EmitHeader;
Begin
  EmitComment('Genere par CPP86 v' + CPP86_VERSION);
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_DATA SEGMENT WORD PUBLIC ''DATA''');
  EmitRaw('_DATA ENDS');
  EmitBlankLine;
  EmitRaw('_TEXT SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('ASSUME CS:_TEXT, DS:_DATA, SS:STACK');
  EmitBlankLine;
End;

Procedure EmitRuntime;
Begin
  (* stub *)
End;

Function ExprAddrOf(SIdx : Integer) : TString;
Begin
  ExprAddrOf := ''; (* stub *)
End;

Procedure ExprFlushToAX(Const E : TExprVal);
Begin
  (* stub *)
End;

Procedure ExprStore(SIdx : Integer);
Begin
  (* stub *)
End;

Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Begin
  ExprMakeNone(Res); (* stub *)
End;

Procedure ParseDeclStmt;
Begin
  (* stub *)
End;

Procedure ParseExprStmt;
Begin
  (* stub *)
End;

Procedure ParseCoutStmt;
Begin
  (* stub *)
End;

Procedure ParseCinStmt;
Begin
  (* stub *)
End;

Procedure ParseIfStmt;
Begin
  (* stub *)
End;

Procedure ParseSwitchStmt;
Begin
  (* stub *)
End;

Procedure ParseWhileStmt;
Begin
  (* stub *)
End;

Procedure ParseDoWhileStmt;
Begin
  (* stub *)
End;

Procedure ParseForStmt;
Begin
  (* stub *)
End;

Procedure ParseFuncDecl;
Begin
  (* stub *)
End;

Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

Procedure ParseStmt;
Begin
  If CurToken.Kind <> TK_EOF Then
    ParserAdvance; (* stub : consomme un token *)
End;

Procedure TypeInit;
Begin
  TypeCount := 0; (* stub *)
End;

Procedure SymInit;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0; (* stub *)
End;

(* ---- Pipeline de compilation -------------------------------- *)

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  ParserAdvance;

  While CurToken.Kind <> TK_EOF Do
    ParseStmt;

  LexClose;
  EmitRuntime;
  EmitClose;

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

(* ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ *)
Begin
  ParseArgs;
  Run;
End.
