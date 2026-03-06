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

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.cpp [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .cpp ou .cxx ou .cc ou .h
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS C++)
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

  TODO 03 - LITTERAUX ET CONSTANTES
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

Begin
End.
