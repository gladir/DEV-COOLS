(* ============================================================================
  JAVAC86.PAS - Compilateur Java Lite -> MASM 8086
  Version : 1.0    Date : 2026-03-02
  Auteur  : DEV-COOLS
  Langage : Turbo Pascal / Free Pascal (compatible)
  Cible   : MASM 8086, modele SMALL, convention near cdecl
  ============================================================================

  DESCRIPTION
  -----------
  JAVAC86 est un compilateur mono-passe pour un sous-ensemble de Java
  ("Java Lite") produisant directement du code assembleur MASM 8086.
  Il ne genere pas de bytecode JVM. Le modele memoire SMALL est utilise :
  segment de code <= 64 Ko, segment de donnees <= 64 Ko.

  SOUS-ENSEMBLE JAVA LITE SUPPORTE
  ---------------------------------
  - Types primitifs : int  boolean  char  (+ String comme type objet simple)
  - Tableaux a une dimension : int[]  char[]  boolean[]  String[]
  - Constantes : final int  final boolean  final char  final String
  - Declarations de variables locales et champs statiques de classe
  - Expressions : + - * / %  ++ --  == != < > <= >=  && || !  +  (concat)
  - Operateur ternaire : cond ? val_si_vrai : val_si_faux
  - Instructions : affectation  op=  if/else  while  do-while  for  for-each
                   break  continue  return
  - Methodes statiques avec parametres  (passage par valeur, near cdecl)
  - Recursion directe
  - Entree / sortie :
      System.out.println(...)   System.out.print(...)
      System.out.printf(fmt)    (sous-ensemble : %d %s %c)
      Scanner sc = new Scanner(System.in)  sc.nextLine()  sc.nextInt()
  - Import : java.util.Scanner  (seul import reconnu)
  - Un package optionnel
  - Commentaires :  // ...  et  /* ... */

  ARCHITECTURE DU COMPILATEUR
  ---------------------------
  Le compilateur est mono-passe, sauf pour la reserve d'etiquettes forward
  (labels non encore emis lors du premier passage d'une boucle).
  Les methodes sont emises dans tmp_file pendant le parsing, puis fusionnees
  dans out_file apres le segment DATA.

  Segments generes (modele SMALL, MASM) :
    STACK  _STACK SEGMENT  PARA STACK 'STACK'  XXXh DUP(?)  _STACK ENDS
    DATA   _DATA  SEGMENT  WORD PUBLIC 'DATA'   ...          _DATA  ENDS
    CODE   _CODE  SEGMENT  WORD PUBLIC 'CODE'   ...          _CODE  ENDS
           END   <label_entree>

  Convention d'appel near cdecl :
    Arguments empiles de droite a gauche (PUSH AX / PUSH imm).
    Retour dans AX (scalaire), AX:DX (String pointer:len).
    L'appelant nettoie la pile apres CALL.
    Strings representees par un pointeur (offset dans _DATA) + longueur (DX).

  ============================================================================
  PLAN DES 25 TODOS
  ============================================================================

  TODO 01 - TYPES DE BASE, CONSTANTES ET VARIABLES GLOBALES DU COMPILATEUR
  --------------------------------------------------------------------------
  Definir les types Pascal internes :
    TString  = String[128]    (chaine courte pour noms, valeurs de tokens)
    TCharSet = Set of Char    (ensembles de caracteres pour le lexer)

  Enumerer les types de tokens Java reconnus (TTokenKind) :
    TK_KEYWORD  TK_IDENT  TK_INT  TK_LONG  TK_FLOAT  TK_STRING
    TK_CHAR     TK_OP     TK_PUNCT  TK_EOF

  Enumerer les types de valeurs du compilateur (TValueKind) :
    VK_INT  VK_BOOL  VK_CHAR  VK_STRING  VK_VOID  VK_ARRAY  VK_UNDEF

  Definir le Record TToken :
    kind    : TTokenKind
    val     : TString         (valeur brute du token)
    int_val : LongInt         (valeur numerique si TK_INT ou TK_LONG)
    line, col : Integer

  Enumerer les portees de symboles (TScope) :
    SC_GLOBAL  SC_LOCAL  SC_PARAM  SC_FIELD

  Enumerer les genres de symboles (TSymKind) :
    SK_VAR  SK_CONST  SK_PARAM  SK_FIELD

  Definir TSymbol (entree de table des symboles) :
    name       : TString
    kind       : TSymKind
    vtype      : TValueKind
    scope      : TScope
    asm_label  : TString     (nom ASM : _J_xxx)
    bp_offset  : Integer     (offset BP pour variables locales)
    arr_size   : Integer     (taille du tableau, 0 si scalaire)
    is_final   : Boolean
    const_val  : LongInt     (valeur si is_final)
    const_str  : TString     (valeur string si is_final + VK_STRING)

  Definir TFuncRec (entree de table des methodes) :
    name            : TString
    asm_label       : TString   (ex : _J_<classe>_<methode>)
    return_type     : TValueKind
    param_count     : Integer
    params          : Array[1..MAX_PARAM] of TSymbol
    local_frame_size: Integer
    is_static       : Boolean
    is_main         : Boolean

  Definir TLitRec (entree de table des litteraux de chaine) :
    val   : TString   (valeur brute de la chaine)
    label : TString   (label ASM correspondant : _S_xxx)

  Constantes dimensionnant les tables :
    MAX_SYM = 512  MAX_FUNC = 128  MAX_LIT = 256  MAX_PARAM = 16
    MAX_LOCAL = 32  MAX_LABEL = 512

  Prefixes des labels ASM :
    JL_PFX = '_JL_'   (labels de controle de flot : if / while / for)
    JF_PFX = '_JF_'   (labels de methodes)
    JS_PFX = '_JS_'   (litteraux de chaine dans DATA)
    RT_PFX = '_JRT_'  (routines runtime)

  Variables globales du compilateur :
    Tables :
      sym_table  : ^TSymbolTable
      func_table : ^TFuncTable
      lit_table  : ^TLitTable
    Compteurs :
      sym_count func_count lit_count label_count
      err_count warn_count instr_count
    Lexer :
      src_file  : Text
      lex_line  : TString
      lex_pos lex_lineno lex_colno : Integer
      lex_cur_tok lex_peek_tok : TToken
      lex_has_peek : Boolean
    Fichiers ASM :
      out_file tmp_file : Text
      cur_out : ^Text
      tmp_open : Boolean
      src_fname out_fname tmp_fname : TString
    Etat du compilateur :
      cur_func_idx  : Integer   (methode en cours de generation)
      scope_level   : Integer
      pkg_name      : TString   (nom du package courant)
      class_name    : TString   (nom de la classe courante)
      first_instr_lbl : TString (label d'entree pour END xxx)
    Options :
      opt_verbose opt_debug opt_no_rt : Boolean
    Boucles :
      loop_depth : Integer
      break_stack    : Array[1..32] of TString
      continue_stack : Array[1..32] of TString
    Prefixe de classe courant pour les labels ASM :
      cur_class_pfx : TString

  Constantes numeriques utiles :
    STACK_SIZE      = 512        (taille de la pile en mots)
    MAX_STR_LEN_DOS = 127        (longueur max d'une entree ReadLine DOS)
    JAVAC86_VERSION = '1.0'
    JAVAC86_DATE    = '2026-03-02'

  TODO 02 - LEXER : RECONNAISSANCE DES TOKENS JAVA
  --------------------------------------------------
  Le lexer est un lexer ligne-par-ligne : il lit src_file une ligne a la fois
  dans lex_line et avance lex_pos caractere par caractere.

  Predicats de caracteres :
    LexIsAlpha  LexIsDigit  LexIsAlNum  LexIsHexDigit  LexIsWS  LexIsLetter

  Gestion du buffer de ligne :
    LexRefill  : lire la prochaine ligne non vide (gerer EOF)
    LexCurChar : caractere courant (lex_line[lex_pos] ou LEX_EOF_CHAR)
    LexPeekChar(n) : regarder n caracteres en avance sans consommer
    LexAdvance : avancer lex_pos d'un caractere

  Saut de commentaires :
    LexSkipLineComment   : sauter de '//' jusqu'a fin de ligne
    LexSkipBlockComment  : sauter de '/*' jusqu'a '*/' (multi-ligne)
    LexSkipWS            : sauter espaces + commentaires

  Decodage des sequences d'echappement :
    LexDecodeEscape : '\n' '\t' '\r' '\\' '\'' '\"' '\uXXXX' '\0'

  Mots-cles Java Lite reconnus (fonction LexIsKeyword) :
    int  boolean  char  long  float  double  void
    class  public  private  protected  static  final  new
    if  else  while  for  do  break  continue  return
    true  false  null  this  instanceof
    import  package  extends
    String  (traite comme mot-cle de type)

  Lecteurs de tokens specifiques :
    LexReadIdent   : identifiant ou mot-cle (Procedure avec Var r: TToken)
    LexReadNumber  : entier decimal / hexadecimal 0x... / suffixe L
    LexReadString  : chaine litterale "..." avec echappements
    LexReadChar    : caractere litteral '...'
    LexReadOp      : operateur 1 ou 2 caracteres
                     Reconnus : == != <= >= && || ++ -- += -= *= /= %= -> ...
                                + - * / % ! < > = & | ^ ~ ?  :
    LexMakeTok     : constructeur de TToken (Procedure Var r)

  API principale (compatible Turbo Pascal : pas de retour de Record) :
    LexNext  : produit le token suivant -> lex_cur_tok   (Procedure)
    LexPeek  : anticipe sans consommer   -> lex_peek_tok (Procedure)
    LexExpect(val)     : consomme en verifiant la valeur
    LexExpectKind(k)   : consomme en verifiant le kind -> lex_cur_tok

  Initialisation / terminaison :
    LexInit(fname)  LexClose

  TODO 03 - TABLES DE SYMBOLES ET DE FONCTIONS
  ----------------------------------------------
  Allocation dynamique des tables :
    InitTables  : New(sym_table) New(func_table) New(lit_table)
    FreeTables  : Dispose(...)

  Table des symboles (symboles locaux, globaux, champs, parametres) :
    AddSym(name, kind, vtype, scope) : Integer   (retourne l'index ou 0)
    AddGlobalSym  AddLocalVar  AddParam  AddField
    FindSym(name) : Integer   (recherche dans portee courante + montante)
    FindField(class_name, name) : Integer
    ScopeEnter  ScopeLeave  (gestion de la portee)

  Table des fonctions :
    AddFunc(name, ret, is_static) : Integer
    FindFunc(name)  FindMethod(class_name, method_name) : Integer
    SetFuncLabel(fi)  (construire _J_<class>_<name>)

  Table des litteraux de chaine :
    AddLit(s) : Integer   (ajouter si absent, retourner index)
    FindLit(s) : Integer
    LitLabel(i) : TString  (retourne '_JS_xxx')

  Generateur de labels uniques :
    NewLabel : TString   (retourne '_JL_' + IntToStr(label_count++))

  Utilitaires :
    IntToStr(n)      StrToInt(s)
    AsmSafeIdent(s)  (remplacer les caracteres non ASM)
    ToUpperStr(s)    ToLowerStr(s)
    FileExtension(fname)  ChangeExtension(fname, ext)
    StrTrimRight(s)  StrRepeat(c, n)

  Gestion des boucles (pile d'etiquettes break/continue) :
    PushLoopLabels(lbl_break, lbl_continue)
    PopLoopLabels

  TODO 04 - EMISSION ASSEMBLEUR ET GESTION DES FICHIERS
  -------------------------------------------------------
  Gestion de cur_out (pointeur sur out_file ou tmp_file) :
    InitOutput       : ouvrir out_file (cur_out = out_file)
    OpenTmpFile      : ouvrir tmp_file (cur_out = tmp_file)
    SwitchToMain     : cur_out = out_file
    MergeTmpToMain   : copier tmp_file -> out_file puis effacer tmp_file
    CloseOutput  CloseTmpFile

  Primitives d'emission dans cur_out :
    Emit(s)          : ligne brute
    EmitBlank        : ligne vide
    EmitSep          : ligne de tirets '; ---...'
    EmitComment(s)   : '; s'
    EmitLabel(lbl)   : 'lbl:'
    EmitDB(lbl, v)   : 'lbl  DB  v'
    EmitDW(lbl, v)   : 'lbl  DW  v'
    EmitDD(lbl, v)   : 'lbl  DD  v'

  Emission d'instructions ASM (indentation 8 espaces) :
    EmitI0(op)           : une seule operation sans operande (ex: 'CWD')
    EmitI(op, args, cmt) : operation + operandes + commentaire inline
    EmitI1(op, args)     : EmitI sans commentaire
    EmitI2(op, a, b)     : 'op  a, b'

  TODO 05 - GENERATION DES SEGMENTS STACK ET DATA (EN-TETES)
  ------------------------------------------------------------
  Directives de fichier et de modele :
    GenFileHeader      : commentaires d'en-tete du fichier ASM
    GenModelDirectives : '.MODEL SMALL'  '.386'  (si cible 386)
    GenMacroDefs       : macros MASM utiles (optionnel)
    GenStackHeader  GenStackFooter : segment _STACK

  En-tete du segment de donnees :
    GenDataHeader  : '_DATA SEGMENT WORD PUBLIC ''DATA'''
    GenDataFooter  : '_DATA ENDS'

  Helpers pour les variables systeme pre-emises dans DATA :
    GenSystemVarsData :
      _J_OUTBUF  DB  256 DUP(0)     (buffer de sortie System.out)
      _J_INBUF   DB  128 DUP(0)     (buffer System.in)
      _J_INTBUF  DB  12  DUP(0)     (buffer int -> string)
      _J_CRLF    DB  0Dh, 0Ah, '$'  (fin de ligne DOS)
      _J_NULLSTR DB  0               (chaine nulle)

  TODO 06 - GENERATION DU SEGMENT DATA (CORPS)
  ---------------------------------------------
  Emission des champs statiques de classes (equivalents aux globaux) :
    GenOneFieldData(i)   : champ unique (int / boolean / char / String / array)
    GenAllFieldsData     : iterer sur sym_table, kind = SK_FIELD

  Emission des litteraux de chaine (table lit_table) :
    GenOneLiteralData(i) : '_JS_xxx  DB  "...$"' ou avec longueur DW
    GenLiteralsData      : iterer sur lit_table

  Emission des variables systeme a la fin du DATA :
    GenSystemVarsData (voir TODO 05)

  Complet : GenDataSegment = GenDataHeader
                           + GenAllFieldsData
                           + GenLiteralsData
                           + GenSystemVarsData
                           + GenDataFooter

  TODO 07 - PARSER : DECLARATIONS JAVA (PACKAGE, IMPORT, CLASSE, CHAMPS)
  ------------------------------------------------------------------------
  ParsePackageDecl  : 'package' ident ('.' ident)* ';'
                      Remplit pkg_name.

  ParseImportDecls  : zero ou plusieurs 'import' ... ';'
                      Reconnus : java.util.Scanner / java.lang.*
                      Ignores silencieusement les autres.

  ParseClassDecl    : 'public'? 'class' ident '{' corps '}'
                      Remplit class_name, cur_class_pfx.
                      Le corps contient des declarations de champs
                      et des declarations de methodes.

  ParseModifiers    : 'public'? 'private'? 'protected'? 'static'? 'final'?
                      Retourne un masque de bits.

  ParseFieldDecl    : type ident ['=' const_expr] ';'
                      Enregistre le champ dans sym_table (SK_FIELD, SC_GLOBAL).

  ParseFinalDecl    : 'final' type ident '=' const_expr ';'
                      Enregistre une constante (SK_CONST, is_final = True).

  ParseTypeSpec     : lire un specif. de type avec support des tableaux Java :
                      'int' | 'boolean' | 'char' | 'String' | 'void'
                      suivi optionnellement de '[]'
                      Retourne vt + is_array (parametres Var).

  ParseVarDecl(is_field) : gerer  type ident ['=' init_expr] ';'
                      Pour les tableaux : 'type[] ident = new type[N];'

  ParseConstIntExpr : evaluer une expression constante entiere au compile-time
                      Formes : integer | char | ( expr ) | - | + | * | /

  SkipToSemicolon   SkipBlock   (recuperation d'erreur)

  TODO 08 - PARSER : EXPRESSIONS JAVA
  ------------------------------------
  Hierarchie de precedence (du plus faible au plus fort) :
    ParseExpr        : point d'entree (ternaire)
    ParseExprTernary : cond ? expr : expr
    ParseExprOr      : ||
    ParseExprAnd     : &&
    ParseExprEq      : == !=
    ParseExprRel     : < > <= >= instanceof
    ParseExprAdd     : + -  (+ pour la concatenation de strings)
    ParseExprMul     : * / %
    ParseExprUnary   : ! - ++ -- (prefix)  (cast)  new type[N]
    ParseExprPostfix : primaryExpr ( '++'  '--'  '[' expr ']'  '.length'
                                     '.' ident (acces de champ/methode) )
    ParseExprPrimary : literal int / boolean / char / string
                       identifiant / appel de methode / 'this'
                       '(' expr ')'
                       System.out.println / System.out.print / System.out.printf
                       System.in (detecte ici mais traite dans ParseVarDecl)
                       scanner.nextLine() / scanner.nextInt()
                       new type[N]   (tableau)

  Helpers de detection :
    IsTypeKeyword(t)         : int boolean char String void
    IsAssignOp(t)            : = += -= *= /= %=
    ParseArgList             : '(' [expr (',' expr)*] ')'  -> nb d'args
    ParseStringConcatChain   : optimisation des + successifs sur strings

  TODO 09 - PARSER : INSTRUCTIONS JAVA
  --------------------------------------
  ParseBlock        : '{' ParseStatement* '}'
  ParseStatement    : dispatcher (if / while / for / do / break / continue /
                      return / decl locale / affectation ou expression)

  ParseIf           : 'if' '(' cond ')' stmt ['else' stmt]
  ParseWhile        : 'while' '(' cond ')' stmt
  ParseDoWhile      : 'do' stmt 'while' '(' cond ')' ';'
  ParseFor          : 'for' '(' init ';' cond ';' incr ')' stmt
                      Gestion de la decl locale dans l'init
  ParseForEach      : 'for' '(' type ident ':' expr ')' stmt
                      (sous-ensemble : tableaux seulement)
  ParseBreak        : 'break' ';'
  ParseContinue     : 'continue' ';'
  ParseReturn       : 'return' [expr] ';'
  ParseAssignOrExprStmt : ident { [expr] }? = expr ;
                          ident op= expr ;
                          ident++ ;  ident-- ;
                          ident[expr] = expr ;
                          appel de methode ;

  TODO 10 - PARSER : METHODES ET CLASSES JAVA
  ---------------------------------------------
  ParseParamList(fi) : '(' [ type ident (',' type ident)* ] ')'
                       Enregistrer chaque parametre dans func_table^[fi].params
                       et dans sym_table avec SC_PARAM.

  CalcFrameSize(fi)  : calculer la taille du frame local en mots
                       (2 octets par variable scalaire, N*2 par tableau)

  ParseMethodDecl    : modifieurs  type  ident  paramList  block
                       Reconnaître 'public static void main(String[] args)' ->
                       marquer is_main = True.
                       Emettre le corps de la methode dans tmp_file.

  ParseClassBody     : ParseFieldDecl* + ParseMethodDecl* en alternance.
                       Gestion des membres statiques et des methodes.

  ParseProgram       : ParsePackageDecl?  ParseImportDecls*  ParseClassDecl+
                       Appeler DetectEntryPoint en fin.

  DetectEntryPoint   : chercher dans func_table la methode main() non-statique
                       ou 'public static void main(String[] args)'.
                       Remplir first_instr_lbl.

  TODO 11 - CODEGEN : EXPRESSIONS ENTIERES, BOOLEENNES ET CHAR
  -------------------------------------------------------------
  GenIntLiteral(v)   : 'MOV AX, v'  (valeur dans [-32768..32767])
  GenLongLiteral(v)  : 'MOV AX, lo' + 'MOV DX, hi'  (long sur 32 bits)
  GenBoolLiteral(b)  : 'MOV AX, 1' ou 'XOR AX, AX'
  GenCharLiteral(c)  : 'MOV AX, ord(c)'
  GenNullLiteral     : 'XOR AX, AX'

  GenAdd  GenSub     : ADD / SUB AX, BX  (apres evaluation des deux membres)
  GenMul             : CALL _JRT_IMUL
  GenDiv             : CALL _JRT_IDIV
  GenMod             : CALL _JRT_IMOD
  GenNeg             : NEG AX
  GenNot             : TEST AX, AX  /  SETE AL  /  MOVZX AX, AL (ou equivalent 8086)
  GenCmp(op)         : CMP / Jcc -> AX = 0 ou 1  (commun pour <<=>>= == !=)
  GenLogicAnd  GenLogicOr : court-circuit via labels

  GenCastIntToChar   : AND AX, 00FFh
  GenCastIntToBool   : TEST AX, AX  /  MOV AX, 1 si != 0

  TODO 12 - CODEGEN : ACCES AUX VARIABLES JAVA
  ----------------------------------------------
  GenLoadVar(idx)    : charger AX (et DX pour String) depuis une variable
  GenStoreVar(idx)   : stocker AX (et DX) dans une variable
  GenLoadConst(idx)  : charger la valeur constante (MOV AX, const_val)
  GenLoadField(idx)  : charger un champ statique de classe (SC_FIELD)
  GenStoreField(idx) : stocker dans un champ statique de classe

  GenAddrOf(idx)     : charger dans SI l'adresse effective (pour tableaux
                       et passages par reference)
  GenLoadArrayElem(idx) : charger arr[BX] apres que BX contient l'index
  GenStoreArrayElem(idx): stocker AX dans arr[BX]

  Helpers de verification de bornes (mode debug) :
  GenBoundsCheck(idx)   : comparer BX a la longueur, sauter vers erreur

  TODO 13 - CODEGEN : AFFECTATION ET INCREMENTATION/DECREMENTATION
  -----------------------------------------------------------------
  GenAssign(idx)       : stocker AX dans var (scalaire ou string)
  GenAssignOp(idx, op) : charger  op  stocker (op E {+=-=*=/=%=})
  GenIncDec(idx, is_inc, is_prefix) :
    Prefix ++/-- : modifier la variable, laisser la nouvelle valeur dans AX.
    Postfix ++/-- : laisser l'ancienne valeur dans AX, puis modifier.
  GenAssignArray(idx)  : stocker AX dans arr[BX]

  Concatenation de string dans une affectation :
  GenAssignStringCat(dst_idx) : emettre _JRT_STRCAT et stocker

  TODO 14 - CODEGEN : STRUCTURES DE CONTROLE
  --------------------------------------------
  GenIfStart(lbl_else)        : TEST AX, AX / JZ lbl_else
  GenIfElseJump(lbl_end)      : JMP lbl_end
  GenLabelHere(lbl)           : EmitLabel(lbl)

  GenWhileTop(lbl_top)        : EmitLabel(lbl_top)
  GenWhileCond(lbl_end)       : TEST AX, AX / JZ lbl_end
  GenWhileBack(lbl_top)       : JMP lbl_top
  GenWhileEnd(lbl_end)        : EmitLabel(lbl_end)

  GenForInit ...  GenForCond ...  GenForIncr ...  GenForEnd
  (sequence de labels : top / cond / incr / end)

  GenDoWhileTop(lbl_top)      : EmitLabel(lbl_top)
  GenDoWhileCond(lbl_top)     : TEST AX, AX / JNZ lbl_top

  GenForEachInit(arr_idx, cnt_idx, i_idx, lbl_top, lbl_end)
  GenForEachStep(...)         : incrementer le compteur / comparer longueur

  GenBreak     : JMP break_stack[loop_depth]
  GenContinue  : JMP continue_stack[loop_depth]
  GenReturn(fi, has_val) : JMP <func_asm>_ret  (ou RET si pas de label)

  Operateur ternaire :
  GenTernaryStart(lbl_false, lbl_end)
  GenTernaryMiddle(lbl_end)
  GenTernaryEnd(lbl_end)

  TODO 15 - CODEGEN : ENTREES / SORTIES (System.out / Scanner)
  -------------------------------------------------------------
  System.out.print / System.out.println :
    Detectes pendant le parsing comme des expressions primaires.
    GenWriteInt(add_lf)    -> _JRT_INT2STR + _JRT_WRITESTR [+ _JRT_WRITECRLF]
    GenWriteBool(add_lf)   -> _JRT_BOOL2STR + _JRT_WRITESTR [+ CRLF]
    GenWriteChar(add_lf)   -> INT 21h AH=02h [+ CRLF]
    GenWriteString(add_lf) -> _JRT_WRITESTR [+ _JRT_WRITECRLF]
    GenWriteStrLit(lbl, add_lf) -> LEA DX, [lbl] + INT 21h AH=09h [+ CRLF]
    GenWriteCRLF           -> _JRT_WRITECRLF
    GenWritePrintf(fmt)    -> sequence d'appels selon specifiers %d %s %c

  Scanner.nextLine() :
    GenReadLine   -> _JRT_READLINE   -> AX=ptr DX=len (String sur la pile)

  Scanner.nextInt() :
    GenReadLineInt -> _JRT_READLINE + _JRT_STR2INT -> AX

  TODO 16 - CODEGEN : CHAINES ET CONCATENATION
  ----------------------------------------------
  GenStrLoadLit(lbl)    : LEA AX, [lbl] + longueur dans DX
  GenStrLoadVar(idx)    : MOV AX, [var_ptr] + MOV DX, [var_len]
  GenStrCat             : CALL _JRT_STRCAT (AX:DX + CX:SI -> nouvel AX:DX)
  GenStrCmp             : CALL _JRT_STRCMP  -> AX = 0 si egaux
  GenStrEqual           : GenStrCmp + negation -> AX = 1 si egaux
  GenStr2Int            : CALL _JRT_STR2INT  -> AX
  GenInt2Str            : CALL _JRT_INT2STR  -> AX:DX
  GenBool2Str           : CALL _JRT_BOOL2STR -> AX:DX
  GenChar2Str           : construire un descripteur d'un seul char
  GenStrLength          : MOV AX, DX  (longueur deja dans DX)
  GenStringConcatChain(n) : emettre n appels _JRT_STRCAT successifs
                            pour optimiser "a + b + c + ..."

  TODO 17 - CODEGEN : TABLEAUX JAVA
  -----------------------------------
  GenArrayFieldDecl(idx)  : '_J_arr  DW  N DUP(0)'  dans le segment DATA
                            + '_J_arr_len  DW  N'    (longueur constante)
  GenArrayLocalInit(idx, n) : allouer N DW sur la pile locale
  GenArrayLengthLoad(idx) : MOV AX, [arr_len_label] ou MOV AX, N
  GenArrayElemLoad(idx)   : charger arr[BX] dans AX
  GenArrayElemStore(idx)  : stocker AX dans arr[BX]
  GenArrayFill(idx, init_val) : boucle d'initialisation (optionnel)
  GenForEachArray(arr_idx, var_idx, lbl_top, lbl_end) :
    emettre le code d'iteration sur chaque element du tableau

  Validite des indices (mode debug) :
  GenBoundsError          : appel vers _JRT_ERRBOUND

  TODO 18 - CODEGEN : APPELS DE METHODES JAVA
  ---------------------------------------------
  GenPushArg(vt)          : PUSH AX [+ PUSH DX si String]
  GenCallDirect(name_asm) : CALL label
  GenCallAndCleanup(fi, argc) : CALL + ADD SP, nb_octets_args
  GenRecursiveCall(fi)    : CALL meme label (recursion directe)

  Prologue / epilogue de methode :
  GenMethodPrologue(fi)   : PUSH BP / MOV BP, SP / SUB SP, frame_size
  GenMethodEpilogue(fi)   : EmitLabel(<func>_ret) / MOV SP, BP / POP BP / RET

  Detection et generation des appels a System.out.* :
  GenSystemOutCall(is_println) : orchestrer GenWriteXxx selon le type
  GenScannerCall(is_int)       : orchestrer GenReadLine[Int]

  TODO 19 - RUNTIME ASSEMBLEUR : ARITHMETIQUE
  ---------------------------------------------
  Routines runtime emises en assembleur inline a la fin du segment CODE.
  Toutes utilises avec CALL (near). Ne modifient que AX BX CX DX SI DI.

  _JRT_IMUL   : AX * BX -> AX  (multiplication entiere signee 16 bits)
  _JRT_IDIV   : AX / BX -> AX, reste -> CX  (division entiere signee)
  _JRT_IMOD   : AX % BX -> AX
  _JRT_INEG   : NEG AX
  _JRT_ABS    : valeur absolue de AX
  _JRT_INT2STR : AX -> chaine ASCII dans _J_INTBUF, retourne AX=ptr DX=len
  _JRT_STR2INT : AX=ptr DX=len -> AX (entier)
  _JRT_BOOL2STR : AX (0/1) -> AX=ptr DX=len vers "false"/"true"
  _JRT_CHAR2STR : AX (code char) -> AX=ptr DX=len (un seul caractere)
  _JRT_ERRBOUND : afficher message "ArrayIndexOutOfBounds" et terminer

  GenRtArithmetic : emettre toutes les routines ci-dessus

  TODO 20 - RUNTIME ASSEMBLEUR : ENTREES / SORTIES
  --------------------------------------------------
  _JRT_WRITESTR  : AX=ptr DX=len -> afficher sur stdout (INT 21h boucle)
  _JRT_WRITECRLF : afficher CR+LF
  _JRT_WRITECHR  : AX = code char -> INT 21h AH=02h
  _JRT_READLINE  : lire une ligne de System.in -> AX=ptr DX=len (_J_INBUF)
  _JRT_ERRMSG    : afficher message d'erreur et Halt
  _JRT_EXIT0     : MOV AX, 4C00h / INT 21h
  _JRT_STRCAT    : AX:DX + CX:SI -> concatenation dans _J_OUTBUF -> AX:DX
  _JRT_STRCMP    : AX:DX vs CX:SI -> AX=0 si egaux, AX=-1/1 sinon

  Printf minimal :
  _JRT_PRINTF    : format en AX:DX, argument sur la pile
                   Gerer %d %s %c  (simple automate)

  GenRtIO : emettre toutes les routines ci-dessus

  TODO 21 - STRUCTURE DU FICHIER ASM (HEADER, SEGMENTS, FOOT)
  -------------------------------------------------------------
  GenFileHeader         : commentaire global en tete du fichier ASM
  GenModelDirectives    : '.MODEL SMALL'
  GenMacroDefs          : macros MASM facultatives
  GenStackHeader/Footer : _STACK SEGMENT ... / _STACK ENDS
  GenDataHeader/Footer  : _DATA  SEGMENT ... / _DATA  ENDS
  GenCodeSegOpen        : '_CODE SEGMENT WORD PUBLIC ''CODE'''
  GenCodeSegClose       : '_CODE ENDS'

  GenCodeHeader : debut du segment CODE :
    'ASSUME CS:_CODE, DS:_DATA, SS:_STACK'
    'START:'
    '    MOV  AX, _DATA'
    '    MOV  DS, AX'
    '    MOV  AX, STACK'
    '    MOV  SS, AX'
    '    MOV  SP, OFFSET _STACK_TOP'
    '    CALL _JF_<class>_main'
    '    CALL _JRT_EXIT0'

  GenCodeFooter  : 'END   START'

  Helpers d'orchestration :
  GenFullAssemblyHeader : GenFileHeader + GenModelDirectives
                        + GenStackHeader + GenStackFooter
                        + GenDataHeader
  GenFullAssemblyFooter : GenCodeSegClose + GenCodeFooter
  GenFullCodeOpen       : GenCodeSegOpen  + GenCodeHeader

  TODO 22 - GESTION DES ERREURS ET DIAGNOSTIC
  ---------------------------------------------
  Prefixe d'erreur contextuel :
  ErrPrefix(cat) : construire '<fichier>(<ligne>,<col>) [categorie]'

  Diagnostic :
  ErrorMsg(msg)     : afficher erreur, Inc(err_count)
  WarnMsg(msg)      : afficher avertissement, Inc(warn_count)
  FatalError(msg)   : afficher + FreeTables + Halt(1)
  LexError(msg)     : erreur lexicale
  SemError(msg)     : erreur semantique (type, variable, portee)
  SynError(msg)     : erreur syntaxique

  Verification des tables :
  TableOverflow(name) : afficher saturation + Halt

  Log en mode verbeux / debug :
  LogVerbose(msg)   : afficher si opt_verbose
  LogDebugAsm(cmt)  : emettre commentaire supplementaire si opt_debug

  Bilan et validation :
  PrintSummary  : lignes parsees / symboles / methodes / litteraux /
                  instructions emises / erreurs / avertissements
  CheckErrLimit : stopper si err_count > MAX_ERRORS (= 50)
  AssertNoErrors : FatalError si err_count > 0

  TODO 23 - INTERFACE LIGNE DE COMMANDE
  ---------------------------------------
  Utilitaires :
  StrUpper  StrLower  FileExtension  ChangeExtension

  Banniere :
  PrintBanner : 'JAVAC86 v1.0 - compilateur Java Lite -> MASM 8086'

  Aide :
  PrintHelp :
    Usage : JAVAC86 <source.java> [<sortie.asm>] [options]
    Options :
      -v      Mode verbeux (statistiques apres compilation)
      -d      Mode debug   (commentaires supplementaires dans l'ASM)
      -ns     Ne pas emettre le runtime inline
      -h      Afficher cette aide

  Parsing des arguments :
  ParseCommandLine : Bool
    ParamCount / ParamStr
    Remplir src_fname, out_fname, tmp_fname
    Remplir opt_verbose, opt_debug, opt_no_rt
    Verifier extension '.java' du fichier source
    Deduire out_fname (.asm) et tmp_fname (.tmp) si non specifies

  Rapport final :
  PrintFinalReport : appeler PrintSummary si opt_verbose

  TODO 24 - ORCHESTRATEUR DE COMPILATION
  ----------------------------------------
  Procedure Compile :
    1. InitOutput       -> ouvrir out_file
    2. OpenTmpFile      -> ouvrir tmp_file (CODE des methodes)
    3. GenHeader        -> file header + MODEL + STACK + DATA open
    4. LexInit(src_fname)
    5. ParseProgram     -> parse + emettre DATA champs + CODE methodes (tmp)
                        -> DetectEntryPoint (appele en fin de ParseProgram)
    6. LexClose
    7. SwitchToMain     -> cur_out = out_file
    8. GenDataSegment   -> DATA : champs + litteraux + vars systeme + ENDS
    9. GenCodeSegmentHeader -> .CODE dans out_file
   10. MergeTmpToMain   -> fusionner CODE tmp dans out_file
   11. Si Not opt_no_rt :
         GenRtArithmetic
         GenRtIO
   12. GenCodeSegmentFooter -> END START
   13. CloseOutput
   14. AssertNoErrors
   15. PrintFinalReport

  Programme principal :
    InitTables
    PrintBanner
    Si Not ParseCommandLine -> FreeTables + Halt(0)
    Compile
    FreeTables
    Si err_count > 0 -> Halt(1)

  TODO 25 - INTEGRATION, TESTS ET VALIDATION
  --------------------------------------------
  Creer 10 programmes de test progressifs :

  test01_hello.java   :
    public class Hello {
      public static void main(String[] args) {
        System.out.println("Hello, World!");
      }
    }

  test02_vars.java    : int / boolean / char, affectations, System.out.println

  test03_arith.java   : + - * / %, operateurs composes += -= *= /= %=, ++ --

  test04_cond.java    : if / else, operateurs de comparaison == != < > <= >=
                        && || !  operateur ternaire

  test05_while.java   : boucle while + break + continue

  test06_for.java     : boucle for simple + boucle for imbriquee

  test07_fonct.java   : methodes statiques, passage de parametres, return

  test08_string.java  : String, concatenation +, System.out.println(String)
                        Scanner.nextLine()

  test09_array.java   : int[], acces et boucle + for-each

  test10_recurs.java  : factorielle recursive

  Valider chaque test :
    - 0 erreur de compilation CSC86 -> ASM genere
    - Labels coherents, conventions d'appel respectees
    - Pas de regression sur les tests precedents
  Mesurer :
    - Nombre d'instructions parsees / symboles / methodes / litteraux
    - Taille du fichier ASM genere

  ============================================================================ *)

Program JAVAC86;

{ ============================================================================
  TODO 01 - TYPES DE BASE, CONSTANTES ET VARIABLES GLOBALES DU COMPILATEUR
  ============================================================================ }

{ --------------------------------------------------------------------------
  Directives compilateur (Turbo Pascal / Free Pascal)
  -------------------------------------------------------------------------- }
{$A-}   { Pas d'alignement memoire                                          }
{$I-}   { Pas de verification I/O automatique (gestion manuelle)            }
{$B-}   { Evaluation booleenne court-circuit                                }
{$Q-}   { Pas de verification overflow                                      }
{$R-}   { Pas de verification de range                                      }

{$IFDEF FPC}
 {$MODE DELPHI}
 {$CODEPAGE UTF8}
{$ENDIF}

{ --------------------------------------------------------------------------
  Constantes dimensionnant les tables et buffers internes
  -------------------------------------------------------------------------- }
Const
  { --- Version --- }
  JAVAC86_VERSION = '1.0';
  JAVAC86_DATE    = '2026-03-02';

  { --- Limites des tables principales --- }
  MAX_SYM    = {$IFDEF FPC}512{$ELSE}128{$ENDIF};   { Symboles (vars + champs + params)              }
  MAX_FUNC   = {$IFDEF FPC}128{$ELSE}16{$ENDIF};    { Methodes statiques                             }
  MAX_LIT    = {$IFDEF FPC}256{$ELSE}128{$ENDIF};   { Litteraux de chaine distincts                  }
  MAX_PARAM  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};      { Parametres max par methode                     }
  MAX_LOCAL  = {$IFDEF FPC}32{$ELSE}8{$ENDIF};      { Variables locales max par methode              }
  MAX_LABEL  = 512;     { Labels ASM generes max                          }
  MAX_LOOP   = 32;      { Profondeur de boucle max (break/continue)        }

  { --- Limites du lexeur --- }
  MAX_LINE   = 256;     { Longueur max d'une ligne source                  }
  MAX_TOKSTR = 128;     { Longueur max d'un token (ident, chaine, ...)     }

  { --- Taille de la pile ASM generee --- }
  STACK_SIZE      = 512;    { taille en mots (512 * 2 = 1024 octets)       }
  MAX_STR_LEN_DOS = 127;    { longueur max entree ReadLine DOS (INT 21h)   }

  { --- Prefixes des labels ASM emis --- }
  JL_PFX  = '_JL_';    { Labels de controle de flot (if / while / for)    }
  JF_PFX  = '_JF_';    { Labels de methodes statiques                     }
  JS_PFX  = '_JS_';    { Litteraux de chaine dans DATA                    }
  JG_PFX  = '_JG_';    { Champs statiques (variables globales Java)        }
  RT_PFX  = '_JRT_';   { Routines runtime assembleur                      }

  { --- Codes de sortie --- }
  ERR_NONE     = 0;
  ERR_SYNTAX   = 1;
  ERR_SEMANTIC = 2;
  ERR_SYMTAB   = 3;
  ERR_INTERNAL = 99;

{ --------------------------------------------------------------------------
  Types de base
  -------------------------------------------------------------------------- }
Type
  TString  = String[MAX_TOKSTR];
  TCharSet = Set of Char;

  { ---------- Enumeration : genre de token lexical ---------- }
  TTokenKind = (
    TK_EOF,      { fin de fichier                                            }
    TK_UNKNOWN,  { caractere non reconnu                                     }
    TK_IDENT,    { identificateur                                            }
    TK_KEYWORD,  { mot-cle reserve Java (int if while class ...)             }
    TK_INT,      { constante entiere     ex : 42  0xFF  0b1010               }
    TK_LONG,     { constante long        ex : 42L  0xFFL                     }
    TK_FLOAT,    { constante flottante   ex : 3.14f  (reconnu, non supporte) }
    TK_STRING,   { constante chaine      ex : "hello\n"                      }
    TK_CHAR,     { constante char        ex : 'A'  '\n'  '\u0041'            }
    TK_OP,       { operateur             ex : +  -  *  ==  !=  <=  &&  ||    }
    TK_PUNCT     { ponctuation : ( ) [ ] accolades ; , . ? :                 }
  );

  { ---------- Enumeration : type de valeur Java Lite ---------- }
  TValueKind = (
    VK_UNDEF,    { non defini                                                }
    VK_INT,      { int     (entier signe 16 bits, 1 DW)                      }
    VK_BOOL,     { boolean (0 = false, 1 = true, 1 DW)                       }
    VK_CHAR,     { char    (code Unicode tronque a 8 bits, 1 DW)             }
    VK_STRING,   { String  (descripteur : ptr DW + len DW, 2 DW)             }
    VK_VOID,     { type de retour void                                       }
    VK_ARRAY     { tableau (ptr base data + longueur DW separee)             }
  );

  { ---------- Enumeration : portee d'un symbole ---------- }
  TScope = (
    SC_GLOBAL,   { champ statique de classe -> .DATA                         }
    SC_LOCAL,    { variable locale sur la pile  [BP - offset]                }
    SC_PARAM,    { parametre de methode         [BP + offset]                 }
    SC_FIELD     { alias de SC_GLOBAL pour les champs de classe              }
  );

  { ---------- Enumeration : nature d'un symbole ---------- }
  TSymKind = (
    SK_UNDEF,    { non encore defini                                         }
    SK_VAR,      { variable (locale, param)                                  }
    SK_CONST,    { constante 'final' (evaluee a la compilation)              }
    SK_FIELD,    { champ statique de classe (dans .DATA)                     }
    SK_FUNC,     { methode statique                                          }
    SK_CLASS,    { nom de classe                                             }
    SK_TYPE      { alias de type                                             }
  );

  { ---------- Token produit par le lexeur ---------- }
  TToken = Record
    kind    : TTokenKind;   { nature du token                                }
    val     : TString;      { representation textuelle brute                 }
    int_val : LongInt;      { valeur numerique si TK_INT ou TK_LONG          }
    line    : Integer;      { ligne source (1-base)                          }
    col     : Integer;      { colonne source (1-base)                        }
  End;

  { ---------- Entree de parametre (dans TFuncEntry) ---------- }
  TParamEntry = Record
    name      : TString;    { nom du parametre                               }
    vtype     : TValueKind; { type declare                                   }
    is_array  : Boolean;    { True si type[] (ex : int[])                    }
    bp_offset : Integer;    { offset positif depuis BP [BP + bp_offset]      }
  End;

  { ---------- Entree de variable locale (dans TFuncEntry) ---------- }
  TLocalEntry = Record
    name      : TString;    { nom de la variable locale                      }
    vtype     : TValueKind; { type declare                                   }
    is_array  : Boolean;    { True si type[] (tableau)                       }
    bp_offset : Integer;    { offset negatif depuis BP [BP - bp_offset]      }
    arr_size  : Integer;    { taille si VK_ARRAY (sinon 0)                   }
    is_final  : Boolean;    { True si declaree 'final'                       }
    const_val : LongInt;    { valeur si is_final + scalaire                  }
    const_str : TString;    { valeur si is_final + VK_STRING                 }
  End;

  { ---------- Entree de la table des symboles ---------- }
  TSymEntry = Record
    name       : TString;    { nom en casse d'origine                        }
    kind       : TSymKind;   { nature du symbole                             }
    vtype      : TValueKind; { type de valeur                                }
    scope      : TScope;     { portee : global / local / param / field       }
    asm_label  : TString;    { label ASM (_JG_xxx pour champs statiques)     }
    bp_offset  : Integer;    { offset BP (locaux et params)                  }
    arr_size   : Integer;    { taille du tableau si VK_ARRAY                 }
    is_array   : Boolean;    { True si le symbole est un tableau             }
    is_final   : Boolean;    { True si declaree 'final'                      }
    const_val  : LongInt;    { valeur entiere si is_final + scalaire         }
    const_str  : TString;    { valeur chaine  si is_final + VK_STRING        }
    class_name : TString;    { nom de la classe d'appartenance               }
    func_idx   : Integer;    { index dans func_table si SK_FUNC (0 = non)   }
  End;

  PSymTableArr = ^TSymTableArr;
  TSymTableArr = Array[1..MAX_SYM] of TSymEntry;

  { ---------- Entree de la table des methodes ---------- }
  TFuncEntry = Record
    name             : TString;    { nom simple de la methode               }
    class_name       : TString;    { nom de la classe proprietaire          }
    return_type      : TValueKind; { type de retour                         }
    asm_label        : TString;    { label ASM _JF_<classe>_<methode>       }
    param_count      : Integer;    { nombre de parametres                   }
    local_count      : Integer;    { nombre de variables locales            }
    local_frame_size : Integer;    { octets de frame locale (SUB SP, n)     }
    param_bytes      : Integer;    { octets d'args a depiler (cdecl caller) }
    is_static        : Boolean;    { True si methode statique               }
    is_main          : Boolean;    { True si c'est main(String[] args)      }
    params           : Array[1..MAX_PARAM] of TParamEntry;
    locals           : Array[1..MAX_LOCAL]  of TLocalEntry;
  End;

  PFuncTableArr = ^TFuncTableArr;
  TFuncTableArr = Array[1..MAX_FUNC] of TFuncEntry;

  { ---------- Entree de la table des litteraux de chaine ---------- }
  TLitEntry = Record
    val      : TString;    { valeur brute (apres decodage \n \t etc.)       }
    len      : Integer;    { longueur en octets                             }
    asm_data : TString;    { label buffer donnees brutes   (_JS_xxx)        }
  End;

  PLitTableArr = ^TLitTableArr;
  TLitTableArr = Array[1..MAX_LIT] of TLitEntry;

{ --------------------------------------------------------------------------
  Variables globales du compilateur
  -------------------------------------------------------------------------- }
Var
  { --- Options d'invocation --- }
  opt_verbose   : Boolean;     { -v : afficher statistiques apres compile   }
  opt_debug     : Boolean;     { -d : commentaires supplementaires dans ASM }
  opt_no_rt     : Boolean;     { -ns : ne pas emettre le runtime inline     }

  { --- Compteurs de compilation --- }
  err_count     : Integer;     { erreurs detectees                          }
  warn_count    : Integer;     { avertissements emis                        }
  instr_count   : Integer;     { instructions Java parsees                  }
  lbl_seq       : Integer;     { sequence de labels ASM auto-generes        }

  { --- Noms de fichiers --- }
  src_fname     : String;      { source .java                               }
  out_fname     : String;      { sortie .asm                                }
  tmp_fname     : String;      { temporaire CODE methodes                   }

  { --- Fichiers --- }
  src_file      : Text;        { lecture source Java                        }
  out_file      : Text;        { ecriture ASM final                         }
  tmp_file      : Text;        { code intermediaire (methodes)              }
  cur_out       : ^Text;       { pointeur vers le fichier d'emission actif  }
  tmp_open      : Boolean;     { tmp_file est-il ouvert ?                   }

  { --- Tables principales (allouees dynamiquement) --- }
  sym_table     : PSymTableArr;
  sym_count     : Integer;

  func_table    : PFuncTableArr;
  func_count    : Integer;
  cur_func_idx  : Integer;     { methode en cours de compilation (0=global) }

  lit_table     : PLitTableArr;
  lit_count     : Integer;

  { --- Contexte lexeur --- }
  lex_line      : String;      { ligne source courante                      }
  lex_pos       : Integer;     { position courante dans lex_line            }
  lex_lineno    : Integer;     { numero de la ligne source                  }
  lex_colno     : Integer;     { numero de la colonne courante              }
  lex_cur_tok   : TToken;      { dernier token produit par LexNext          }
  lex_peek_tok  : TToken;      { token en attente (anticipation d'un tok)   }
  lex_has_peek  : Boolean;     { lex_peek_tok est-il valide ?               }

  { --- Contexte de classe / methode --- }
  pkg_name      : TString;     { nom du package courant (ex : 'com.foo')    }
  class_name    : TString;     { nom de la classe courante                  }
  cur_class_pfx : TString;     { prefixe ASM de la classe (_JF_ClassName_) }

  { --- Portee / niveau d'imbrication --- }
  scope_level   : Integer;     { profondeur de portee courante              }

  { --- Pile de boucle (break / continue) --- }
  loop_depth     : Integer;
  break_stack    : Array[1..MAX_LOOP] of TString;
  continue_stack : Array[1..MAX_LOOP] of TString;

  { --- Label de la premiere instruction (pour END xxx) --- }
  first_instr_lbl : TString;

  { --- Import Scanner reconnu --- }
  has_scanner   : Boolean;     { 'import java.util.Scanner' vu ?            }
  scanner_var   : TString;     { nom de la variable Scanner locale          }

{ --------------------------------------------------------------------------
  InitTables : allouer les tables et initialiser toutes les variables.
  -------------------------------------------------------------------------- }
Procedure InitTables;
Begin
  New(sym_table);    sym_count    := 0;
  New(func_table);   func_count   := 0;  cur_func_idx := 0;
  New(lit_table);    lit_count    := 0;
  lbl_seq         := 0;
  err_count       := 0;  warn_count   := 0;  instr_count := 0;
  loop_depth      := 0;
  scope_level     := 0;
  tmp_open        := False;
  lex_has_peek    := False;
  first_instr_lbl := '';
  pkg_name        := '';
  class_name      := '';
  cur_class_pfx   := '';
  scanner_var     := '';
  has_scanner     := False;
  opt_verbose     := False;  opt_debug := False;  opt_no_rt := False;
  sym_table^[1].name := '';   { eviter l'avertissement 'variable non initialisee' }
End;

{ --------------------------------------------------------------------------
  FreeTables : liberer la memoire des tables allouees dynamiquement.
  -------------------------------------------------------------------------- }
Procedure FreeTables;
Begin
  If sym_table  <> Nil Then Dispose(sym_table);
  If func_table <> Nil Then Dispose(func_table);
  If lit_table  <> Nil Then Dispose(lit_table);
End;

{ ============================================================================
  TODO 02 - LEXEUR (ANALYSE LEXICALE JAVA)
  ============================================================================ }

{ --------------------------------------------------------------------------
  Constantes internes au lexeur
  -------------------------------------------------------------------------- }
Const
  LEX_EOF_CHAR = #0;    { sentinelle fin de ligne / fin de fichier }

{ --------------------------------------------------------------------------
  LexIsAlpha : True si c est une lettre ou underscore (debut d'ident)
  -------------------------------------------------------------------------- }
Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := (c In ['a'..'z', 'A'..'Z', '_']);
End;

{ --------------------------------------------------------------------------
  LexIsAlNum : True si c est une lettre, chiffre ou underscore
  -------------------------------------------------------------------------- }
Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := (c In ['a'..'z', 'A'..'Z', '0'..'9', '_']);
End;

{ --------------------------------------------------------------------------
  LexIsDigit : True si c est un chiffre decimal
  -------------------------------------------------------------------------- }
Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c In ['0'..'9']);
End;

{ --------------------------------------------------------------------------
  LexIsHexDigit : True si c est un chiffre hexadecimal
  -------------------------------------------------------------------------- }
Function LexIsHexDigit(c : Char) : Boolean;
Begin
  LexIsHexDigit := (c In ['0'..'9', 'a'..'f', 'A'..'F']);
End;

{ --------------------------------------------------------------------------
  LexHexVal : valeur entiere d'un chiffre hexadecimal
  -------------------------------------------------------------------------- }
Function LexHexVal(c : Char) : Integer;
Begin
  If c In ['0'..'9'] Then LexHexVal := Ord(c) - Ord('0')
  Else If c In ['a'..'f'] Then LexHexVal := Ord(c) - Ord('a') + 10
  Else LexHexVal := Ord(c) - Ord('A') + 10;
End;

{ --------------------------------------------------------------------------
  LexIsWS : True si c est un caractere blanc (espace, tab, CR, LF)
  -------------------------------------------------------------------------- }
Function LexIsWS(c : Char) : Boolean;
Begin
  LexIsWS := (c In [' ', #9, #13, #10]);
End;

{ --------------------------------------------------------------------------
  LexIsKeyword : True si s est un mot-cle Java Lite reconnu.
  Note : System et Scanner sont des identificateurs, pas des mots-cles.
  -------------------------------------------------------------------------- }
Function LexIsKeyword(Const s : TString) : Boolean;
Begin
  LexIsKeyword :=
    (s = 'int')        Or (s = 'boolean')   Or (s = 'char')      Or
    (s = 'long')       Or (s = 'float')     Or (s = 'double')    Or
    (s = 'void')       Or (s = 'class')     Or (s = 'public')    Or
    (s = 'private')    Or (s = 'protected') Or (s = 'static')    Or
    (s = 'final')      Or (s = 'new')       Or (s = 'if')        Or
    (s = 'else')       Or (s = 'while')     Or (s = 'for')       Or
    (s = 'do')         Or (s = 'break')     Or (s = 'continue')  Or
    (s = 'return')     Or (s = 'true')      Or (s = 'false')     Or
    (s = 'null')       Or (s = 'this')      Or (s = 'instanceof')Or
    (s = 'import')     Or (s = 'package')   Or (s = 'extends')   Or
    (s = 'String');
End;

{ --------------------------------------------------------------------------
  LexInit : ouvrir le fichier source et initialiser l'etat du lexeur.
  -------------------------------------------------------------------------- }
Procedure LexInit(Const fname : TString);
Begin
  Assign(src_file, fname);
  Reset(src_file);
  lex_line     := '';
  lex_pos      := 1;
  lex_lineno   := 0;
  lex_colno    := 1;
  lex_has_peek := False;
  FillChar(lex_cur_tok,  SizeOf(lex_cur_tok),  0);
  FillChar(lex_peek_tok, SizeOf(lex_peek_tok), 0);
End;

{ --------------------------------------------------------------------------
  LexCurChar : retourner le caractere courant dans lex_line (ou #0).
  -------------------------------------------------------------------------- }
Function LexCurChar : Char;
Begin
  If lex_pos <= Length(lex_line) Then
    LexCurChar := lex_line[lex_pos]
  Else
    LexCurChar := LEX_EOF_CHAR;
End;

{ --------------------------------------------------------------------------
  LexPeekChar : retourner le caractere a lex_pos + offset (sans avancer).
  -------------------------------------------------------------------------- }
Function LexPeekChar(offset : Integer) : Char;
Var p : Integer;
Begin
  p := lex_pos + offset;
  If (p >= 1) And (p <= Length(lex_line)) Then
    LexPeekChar := lex_line[p]
  Else
    LexPeekChar := LEX_EOF_CHAR;
End;

{ --------------------------------------------------------------------------
  LexAdvance : avancer d'un caractere dans la ligne courante.
  -------------------------------------------------------------------------- }
Procedure LexAdvance;
Begin
  If lex_pos <= Length(lex_line) Then
  Begin
    Inc(lex_pos);
    Inc(lex_colno);
  End;
End;

{ --------------------------------------------------------------------------
  LexReadLine : lire la prochaine ligne du source dans lex_line.
  Retourne False si EOF.
  -------------------------------------------------------------------------- }
Function LexReadLine : Boolean;
Begin
  If EOF(src_file) Then
  Begin
    LexReadLine := False;
    lex_line := '';
    Exit;
  End;
  ReadLn(src_file, lex_line);
  Inc(lex_lineno);
  lex_pos   := 1;
  lex_colno := 1;
  LexReadLine := True;
End;

{ --------------------------------------------------------------------------
  LexRefill : avancer dans le flux jusqu'a trouver un caractere non-EOF.
  Lit les nouvelles lignes si necessaire.
  Retourne False si le source est completement epuise.
  -------------------------------------------------------------------------- }
Function LexRefill : Boolean;
Begin
  While LexCurChar = LEX_EOF_CHAR Do
  Begin
    If Not LexReadLine Then
    Begin
      LexRefill := False;
      Exit;
    End;
  End;
  LexRefill := True;
End;

{ --------------------------------------------------------------------------
  LexSkipLineComment : sauter un commentaire // jusqu'a la fin de la ligne.
  -------------------------------------------------------------------------- }
Procedure LexSkipLineComment;
Begin
  { On sait que CurChar='/' et PeekChar(1)='/' : sauter les deux '//' }
  LexAdvance; LexAdvance;
  { Puis sauter jusqu'a la fin de la ligne en forcant lex_pos au-dela }
  lex_pos := Length(lex_line) + 1;
End;

{ --------------------------------------------------------------------------
  LexSkipBlockComment : sauter un commentaire /* ... */ (multi-ligne).
  Precondition : CurChar='/' et PeekChar(1)='*', deja verifies.
  -------------------------------------------------------------------------- }
Procedure LexSkipBlockComment;
Begin
  { Sauter '/' et '*' d'ouverture }
  LexAdvance; LexAdvance;
  Repeat
    { Si fin de ligne courante, lire la suivante }
    While LexCurChar = LEX_EOF_CHAR Do
    Begin
      If Not LexReadLine Then
      Begin
        { EOF inattendu : commentaire non ferme }
        Inc(err_count);
        WriteLn('Erreur : commentaire /* non ferme avant fin de fichier');
        Exit;
      End;
    End;
    { Chercher la sequence de cloture '*/' }
    If (LexCurChar = '*') And (LexPeekChar(1) = '/') Then
    Begin
      LexAdvance; LexAdvance;   { sauter '*' et '/' }
      Exit;
    End
    Else
      LexAdvance;
  Until False;
End;

{ --------------------------------------------------------------------------
  LexSkipWS : sauter les espaces, tabulations et commentaires Java.
    //  commentaire de ligne
    /* commentaire multi-ligne */
  -------------------------------------------------------------------------- }
Procedure LexSkipWS;
Begin
  Repeat
    { Remplir le tampon si vide (sans sortir si on n'est pas en block) }
    If LexCurChar = LEX_EOF_CHAR Then Exit;

    If (LexCurChar = '/') And (LexPeekChar(1) = '/') Then
      LexSkipLineComment
    Else If (LexCurChar = '/') And (LexPeekChar(1) = '*') Then
      LexSkipBlockComment
    Else If LexIsWS(LexCurChar) Then
      LexAdvance
    Else
      Exit;
  Until False;
End;

{ --------------------------------------------------------------------------
  LexDecodeEscape : decoder une sequence d'echappement Java apres '\'.
  Retourne le caractere decode ; avance lex_pos au-dela de la sequence.
  Sequences supportees : \n \r \t \\ \' \" \0 \uXXXX
  -------------------------------------------------------------------------- }
Function LexDecodeEscape : Char;
Var c : Char;
    h : Integer;
    i : Integer;
Begin
  c := LexCurChar;
  LexAdvance;
  Case c Of
    'n'  : LexDecodeEscape := #10;
    'r'  : LexDecodeEscape := #13;
    't'  : LexDecodeEscape := #9;
    '0'  : LexDecodeEscape := #0;
    '\'  : LexDecodeEscape := '\';
    '"'  : LexDecodeEscape := '"';
    '''' : LexDecodeEscape := '''';
    'u'  :
    Begin
      { \uXXXX : quatre chiffres hexa obligatoires (Unicode BMP) }
      { On retient uniquement l'octet bas (compatibilite DOS/8086) }
      h := 0;
      For i := 1 To 4 Do
      Begin
        If LexIsHexDigit(LexCurChar) Then
        Begin
          h := h * 16 + LexHexVal(LexCurChar);
          LexAdvance;
        End;
      End;
      LexDecodeEscape := Chr(h And $FF);
    End;
  Else
    LexDecodeEscape := c;   { sequence inconnue : garder le caractere }
  End;
End;

{ --------------------------------------------------------------------------
  LexMakeTok : construire un TToken a partir des elements courants.
  Compatible Turbo Pascal : le token est retourne via un parametre Var.
  -------------------------------------------------------------------------- }
Procedure LexMakeTok(k : TTokenKind; Const v : TString; Var r : TToken);
Begin
  r.kind    := k;
  r.val     := v;
  r.int_val := 0;
  r.line    := lex_lineno;
  r.col     := lex_colno;
End;

{ --------------------------------------------------------------------------
  LexReadIdent : lire un identifiant ou mot-cle Java a partir de lex_pos.
  -------------------------------------------------------------------------- }
Procedure LexReadIdent(Var r : TToken);
Var s : TString;
    k : TTokenKind;
Begin
  s := '';
  While LexIsAlNum(LexCurChar) Do
  Begin
    s := s + LexCurChar;
    LexAdvance;
  End;
  If LexIsKeyword(s) Then k := TK_KEYWORD
  Else                     k := TK_IDENT;
  LexMakeTok(k, s, r);
End;

{ --------------------------------------------------------------------------
  LexReadNumber : lire une constante numerique Java.
  Formats : decimal  42  42L  42l
            hexa     0xFF  0xFFL
            float    3.14f  3.14F  (reconnu comme TK_FLOAT, non supporte)
            double   3.14d  3.14D  (reconnu comme TK_FLOAT, non supporte)
  -------------------------------------------------------------------------- }
Procedure LexReadNumber(Var r : TToken);
Var s      : TString;
    v      : LongInt;
    isLong : Boolean;
    isFloat: Boolean;
Begin
  s       := '';
  v       := 0;
  isLong  := False;
  isFloat := False;

  If (LexCurChar = '0') And (LexPeekChar(1) In ['x', 'X']) Then
  Begin
    { Hexadecimal 0x... }
    LexAdvance; LexAdvance;   { sauter '0' et 'x' }
    While LexIsHexDigit(LexCurChar) Do
    Begin
      v := v * 16 + LexHexVal(LexCurChar);
      s := s + LexCurChar;
      LexAdvance;
    End;
    s := '0x' + s;
  End
  Else
  Begin
    { Decimal }
    While LexIsDigit(LexCurChar) Do
    Begin
      v := v * 10 + (Ord(LexCurChar) - Ord('0'));
      s := s + LexCurChar;
      LexAdvance;
    End;
    { Partie decimale d'un flottant (3.14) }
    If (LexCurChar = '.') And LexIsDigit(LexPeekChar(1)) Then
    Begin
      isFloat := True;
      s := s + '.';
      LexAdvance;
      While LexIsDigit(LexCurChar) Do
      Begin
        s := s + LexCurChar;
        LexAdvance;
      End;
    End;
  End;

  { Suffixes L/l -> long ; f/F/d/D -> float }
  If LexCurChar In ['L', 'l'] Then
  Begin
    isLong := True;
    LexAdvance;
  End
  Else If LexCurChar In ['f', 'F', 'd', 'D'] Then
  Begin
    isFloat := True;
    LexAdvance;
  End;

  If isFloat Then
    LexMakeTok(TK_FLOAT, s, r)
  Else If isLong Then
  Begin
    LexMakeTok(TK_LONG, s, r);
    r.int_val := v;
  End
  Else
  Begin
    LexMakeTok(TK_INT, s, r);
    r.int_val := v;
  End;
End;

{ --------------------------------------------------------------------------
  LexReadString : lire une chaine litterale delimitee par ".
  Les sequences d'echappement Java sont decodees.
  -------------------------------------------------------------------------- }
Procedure LexReadString(Var r : TToken);
Var s : TString;
    c : Char;
Begin
  s := '';
  LexAdvance;   { sauter le '"' ouvrant }
  While (LexCurChar <> LEX_EOF_CHAR) And (LexCurChar <> '"') Do
  Begin
    If LexCurChar = '\' Then
    Begin
      LexAdvance;   { sauter '\' }
      c := LexDecodeEscape;
    End
    Else
    Begin
      c := LexCurChar;
      LexAdvance;
    End;
    If Length(s) < MAX_TOKSTR Then s := s + c;
  End;
  If LexCurChar = '"' Then LexAdvance;   { sauter '"' fermant }
  LexMakeTok(TK_STRING, s, r);
End;

{ --------------------------------------------------------------------------
  LexReadChar : lire un char litteral delimite par des apostrophes ' '.
  Les sequences d'echappement Java sont decodees.
  -------------------------------------------------------------------------- }
Procedure LexReadChar(Var r : TToken);
Var s : TString;
    c : Char;
Begin
  LexAdvance;   { sauter "'" ouvrant }
  If LexCurChar = '\' Then
  Begin
    LexAdvance;
    c := LexDecodeEscape;
  End
  Else
  Begin
    c := LexCurChar;
    LexAdvance;
  End;
  If LexCurChar = '''' Then LexAdvance;   { sauter "'" fermant }
  s := c;
  LexMakeTok(TK_CHAR, s, r);
  r.int_val := Ord(c);
End;

{ --------------------------------------------------------------------------
  LexReadOp : lire un operateur ou signe de ponctuation Java.
  Operateurs deux caracteres : == != <= >= && || ++ -- += -= *= /= %= ->
  Ponctuation : accolades parentheses crochets ; , .
  -------------------------------------------------------------------------- }
Procedure LexReadOp(Var r : TToken);
Var c1, c2 : Char;
    s      : TString;
    k      : TTokenKind;
Begin
  c1 := LexCurChar;
  c2 := LexPeekChar(1);
  s  := c1;
  k  := TK_OP;

  { Operateurs deux caracteres }
  If ((c1 = '=') And (c2 = '=')) Or
     ((c1 = '!') And (c2 = '=')) Or
     ((c1 = '<') And (c2 = '=')) Or
     ((c1 = '>') And (c2 = '=')) Or
     ((c1 = '&') And (c2 = '&')) Or
     ((c1 = '|') And (c2 = '|')) Or
     ((c1 = '+') And (c2 = '+')) Or
     ((c1 = '-') And (c2 = '-')) Or
     ((c1 = '+') And (c2 = '=')) Or
     ((c1 = '-') And (c2 = '=')) Or
     ((c1 = '*') And (c2 = '=')) Or
     ((c1 = '/') And (c2 = '=')) Or
     ((c1 = '%') And (c2 = '=')) Or
     ((c1 = '-') And (c2 = '>')) Then
  Begin
    s := c1 + c2;
    LexAdvance; LexAdvance;
  End
  Else
  Begin
    { Ponctuation a un caractere }
    If c1 In ['{', '}', '(', ')', '[', ']', ';', ',', '.'] Then
      k := TK_PUNCT;
    LexAdvance;
  End;
  LexMakeTok(k, s, r);
End;

{ --------------------------------------------------------------------------
  LexNext : produire le prochain token depuis le flux source.
  Met a jour lex_cur_tok (accessible directement apres l'appel).
  Compatible Turbo Pascal : pas de retour de Record.
  -------------------------------------------------------------------------- }
Procedure LexNext;
Begin
  { Si un token est en attente (peek), le consommer }
  If lex_has_peek Then
  Begin
    lex_cur_tok  := lex_peek_tok;
    lex_has_peek := False;
    Exit;
  End;

  { S'assurer qu'il y a des donnees a lire }
  If Not LexRefill Then
  Begin
    LexMakeTok(TK_EOF, '', lex_cur_tok);
    Exit;
  End;

  LexSkipWS;

  { Apres skip, re-remplir si besoin (commentaire en fin de ligne) }
  While LexCurChar = LEX_EOF_CHAR Do
  Begin
    If Not LexRefill Then
    Begin
      LexMakeTok(TK_EOF, '', lex_cur_tok);
      Exit;
    End;
    LexSkipWS;
  End;

  { Dispatcher selon le premier caractere }
  If LexIsAlpha(LexCurChar) Then
    LexReadIdent(lex_cur_tok)
  Else If LexIsDigit(LexCurChar) Then
    LexReadNumber(lex_cur_tok)
  Else If LexCurChar = '"' Then
    LexReadString(lex_cur_tok)
  Else If LexCurChar = '''' Then
    LexReadChar(lex_cur_tok)
  Else
    LexReadOp(lex_cur_tok);
End;

{ --------------------------------------------------------------------------
  LexPeek : retourner le prochain token SANS le consommer.
  Resultat accessible via lex_peek_tok apres l'appel.
  -------------------------------------------------------------------------- }
Procedure LexPeek;
Begin
  If Not lex_has_peek Then
  Begin
    LexNext;
    lex_peek_tok := lex_cur_tok;
    lex_has_peek := True;
  End;
End;

{ --------------------------------------------------------------------------
  LexExpect : consommer le prochain token en verifiant sa valeur.
  Emet une erreur si le token ne correspond pas a expected_val.
  -------------------------------------------------------------------------- }
Procedure LexExpect(Const expected_val : TString);
Begin
  LexNext;
  If lex_cur_tok.val <> expected_val Then
  Begin
    Inc(err_count);
    WriteLn('Erreur syntaxique ligne ', lex_cur_tok.line,
            ' col ', lex_cur_tok.col,
            ' : attendu ''', expected_val,
            ''' mais lu ''', lex_cur_tok.val, '''');
  End;
End;

{ --------------------------------------------------------------------------
  LexExpectKind : consommer le prochain token en verifiant son kind.
  Resultat accessible via lex_cur_tok apres l'appel.
  -------------------------------------------------------------------------- }
Procedure LexExpectKind(k : TTokenKind);
Var kname : TString;
Begin
  LexNext;
  If lex_cur_tok.kind <> k Then
  Begin
    Inc(err_count);
    Case k Of
      TK_IDENT   : kname := 'identificateur';
      TK_INT     : kname := 'entier';
      TK_STRING  : kname := 'chaine';
      TK_KEYWORD : kname := 'mot-cle';
    Else             kname := 'token';
    End;
    WriteLn('Erreur syntaxique ligne ', lex_cur_tok.line,
            ' col ', lex_cur_tok.col,
            ' : attendu ', kname,
            ' mais lu ''', lex_cur_tok.val, '''');
  End;
End;

{ --------------------------------------------------------------------------
  LexClose : fermer le fichier source.
  -------------------------------------------------------------------------- }
Procedure LexClose;
Begin
  {$I-}
  Close(src_file);
  {$I+}
End;

{ ============================================================================
  TODO 03 - TABLES DE SYMBOLES ET DE FONCTIONS
  ============================================================================ }

{ --------------------------------------------------------------------------
  Variables supplementaires pour la gestion de portee
  (snapshot de sym_count a chaque ScopeEnter)
  -------------------------------------------------------------------------- }
Var
  scope_sym_stack : Array[0..64] of Integer;   { pile des sym_count sauvegardes }
  scope_sp        : Integer;                    { sommet de la pile (0 = vide)  }

{ --------------------------------------------------------------------------
  UTILITAIRES GENERAUX
  -------------------------------------------------------------------------- }

{ Conversion entier -> chaine (sans dependance sur Str()) }
Function IntToStr(n : LongInt) : TString;
Var s   : TString;
    neg : Boolean;
    r   : LongInt;
Begin
  If n = 0 Then Begin IntToStr := '0'; Exit; End;
  neg := (n < 0);
  If neg Then n := -n;
  s := '';
  While n > 0 Do
  Begin
    r := n Mod 10;
    s := Chr(Ord('0') + r) + s;
    n := n Div 10;
  End;
  If neg Then s := '-' + s;
  IntToStr := s;
End;

{ Conversion chaine -> entier (decimal simple, signe optionnel) }
Function StrToInt(s : TString) : LongInt;
Var i   : Integer;
    v   : LongInt;
    neg : Boolean;
Begin
  i   := 1;
  v   := 0;
  neg := False;
  If (Length(s) > 0) And (s[1] = '-') Then Begin neg := True; Inc(i); End;
  While i <= Length(s) Do
  Begin
    If (s[i] >= '0') And (s[i] <= '9') Then
      v := v * 10 + (Ord(s[i]) - Ord('0'));
    Inc(i);
  End;
  If neg Then StrToInt := -v Else StrToInt := v;
End;

{ Supprimer les espaces en queue de chaine }
Function StrTrimRight(s : TString) : TString;
Var n : Integer;
Begin
  n := Length(s);
  While (n > 0) And (s[n] <= ' ') Do Dec(n);
  StrTrimRight := Copy(s, 1, n);
End;

{ Repeter un caractere n fois }
Function StrRepeat(c : Char; n : Integer) : TString;
Var s : TString;
    i : Integer;
Begin
  s := '';
  For i := 1 To n Do
    If Length(s) < MAX_TOKSTR Then s := s + c;
  StrRepeat := s;
End;

{ Mettre en majuscules }
Function ToUpperStr(s : TString) : TString;
Var i : Integer;
    c : Char;
Begin
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (c >= 'a') And (c <= 'z') Then s[i] := Chr(Ord(c) - 32);
  End;
  ToUpperStr := s;
End;

{ Mettre en minuscules }
Function ToLowerStr(s : TString) : TString;
Var i : Integer;
    c : Char;
Begin
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (c >= 'A') And (c <= 'Z') Then s[i] := Chr(Ord(c) + 32);
  End;
  ToLowerStr := s;
End;

{ Remplacer les caracteres non valides pour un identifiant ASM par '_' }
Function AsmSafeIdent(s : TString) : TString;
Var i : Integer;
    c : Char;
Begin
  If Length(s) = 0 Then Begin AsmSafeIdent := '_'; Exit; End;
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If Not (  ((c >= 'A') And (c <= 'Z'))
           Or ((c >= 'a') And (c <= 'z'))
           Or ((c >= '0') And (c <= '9'))
           Or (c = '_') ) Then
      s[i] := '_';
  End;
  { Un label ASM ne peut pas commencer par un chiffre }
  If (s[1] >= '0') And (s[1] <= '9') Then s[1] := '_';
  AsmSafeIdent := s;
End;

{ Retourner l'extension (avec le point) d'un nom de fichier }
Function FileExtension(fname : String) : TString;
Var i, dot : Integer;
Begin
  dot := 0;
  For i := Length(fname) DownTo 1 Do
    If fname[i] = '.' Then Begin dot := i; Break; End;
  If dot = 0 Then
    FileExtension := ''
  Else
    FileExtension := Copy(fname, dot, Length(fname) - dot + 1);
End;

{ Changer l'extension d'un nom de fichier (ext doit inclure le point) }
Function ChangeExtension(fname : String; ext : TString) : TString;
Var i, dot : Integer;
    base   : TString;
Begin
  dot := 0;
  For i := Length(fname) DownTo 1 Do
    If fname[i] = '.' Then Begin dot := i; Break; End;
  If dot = 0 Then
    base := fname
  Else
    base := Copy(fname, 1, dot - 1);
  ChangeExtension := base + ext;
End;

{ --------------------------------------------------------------------------
  GENERATEURS DE LABELS ASM
  -------------------------------------------------------------------------- }

{ Nouveau label de controle de flot unique : _JL_NNN }
Function NewLabel : TString;
Begin
  Inc(lbl_seq);
  NewLabel := JL_PFX + IntToStr(lbl_seq);
End;

{ Label d'une methode statique Java : _JF_ClassName_MethodName }
Function JFuncLabel(cname, mname : TString) : TString;
Begin
  JFuncLabel := JF_PFX + AsmSafeIdent(cname) + '_' + AsmSafeIdent(mname);
End;

{ Label d'un champ statique Java : _JG_ClassName_FieldName }
Function JGlobalLabel(cname, vname : TString) : TString;
Begin
  JGlobalLabel := JG_PFX + AsmSafeIdent(cname) + '_' + AsmSafeIdent(vname);
End;

{ Label du buffer donnees d'un litteral de chaine : _JS_NNN }
Function LitLabel(i : Integer) : TString;
Begin
  LitLabel := JS_PFX + IntToStr(i);
End;

{ --------------------------------------------------------------------------
  TABLE DES LITTERAUX DE CHAINE
  -------------------------------------------------------------------------- }

{ Chercher un litteral existant ; retourne son index ou 0 }
Function FindLit(s : TString) : Integer;
Var i : Integer;
Begin
  For i := 1 To lit_count Do
    If lit_table^[i].val = s Then Begin FindLit := i; Exit; End;
  FindLit := 0;
End;

{ Ajouter un nouveau litteral (ou retourner l'index existant) }
Function AddLit(s : TString) : Integer;
Var i : Integer;
Begin
  i := FindLit(s);
  If i > 0 Then Begin AddLit := i; Exit; End;
  If lit_count >= MAX_LIT Then
  Begin
    WriteLn('Erreur interne : table des litteraux saturee (MAX_LIT=',
            MAX_LIT, ')');
    Inc(err_count);
    AddLit := 0;
    Exit;
  End;
  Inc(lit_count);
  lit_table^[lit_count].val      := s;
  lit_table^[lit_count].len      := Length(s);
  lit_table^[lit_count].asm_data := LitLabel(lit_count);
  AddLit := lit_count;
End;

{ --------------------------------------------------------------------------
  TABLE DES FONCTIONS (methodes statiques)
  -------------------------------------------------------------------------- }

{ Chercher une methode par nom simple (premiere occurrence) }
Function FindFunc(name : TString) : Integer;
Var i : Integer;
Begin
  For i := 1 To func_count Do
    If func_table^[i].name = name Then Begin FindFunc := i; Exit; End;
  FindFunc := 0;
End;

{ Chercher une methode par classe + nom }
Function FindMethod(cname, mname : TString) : Integer;
Var i : Integer;
Begin
  For i := 1 To func_count Do
    If (func_table^[i].class_name = cname) And
       (func_table^[i].name = mname) Then
    Begin FindMethod := i; Exit; End;
  FindMethod := 0;
End;

{ Construire et affecter le label ASM d'une methode }
Procedure SetFuncLabel(fi : Integer);
Begin
  If (fi < 1) Or (fi > func_count) Then Exit;
  func_table^[fi].asm_label :=
    JFuncLabel(func_table^[fi].class_name, func_table^[fi].name);
End;

{ Enregistrer une methode statique ; retourne son index dans func_table }
Function AddFunc(name : TString; ret : TValueKind; is_static : Boolean) : Integer;
Var fi : Integer;
Begin
  { Si elle existe deja (prototype forward), on la renvoie }
  fi := FindMethod(class_name, name);
  If fi > 0 Then Begin AddFunc := fi; Exit; End;

  If func_count >= MAX_FUNC Then
  Begin
    WriteLn('Erreur interne : table des methodes saturee (MAX_FUNC=',
            MAX_FUNC, ')');
    Inc(err_count);
    AddFunc := 0;
    Exit;
  End;
  Inc(func_count);
  fi := func_count;
  FillChar(func_table^[fi], SizeOf(TFuncEntry), 0);
  func_table^[fi].name             := name;
  func_table^[fi].class_name       := class_name;
  func_table^[fi].return_type      := ret;
  func_table^[fi].is_static        := is_static;
  func_table^[fi].is_main          := (name = 'main');
  func_table^[fi].asm_label        := '';
  func_table^[fi].param_count      := 0;
  func_table^[fi].local_count      := 0;
  func_table^[fi].local_frame_size := 0;
  func_table^[fi].param_bytes      := 0;
  SetFuncLabel(fi);
  AddFunc := fi;
End;

{ Reinitialiser les compteurs de locaux / params pour la methode courante }
Procedure ResetLocals;
Begin
  If cur_func_idx > 0 Then
  Begin
    func_table^[cur_func_idx].local_count      := 0;
    func_table^[cur_func_idx].local_frame_size := 0;
    func_table^[cur_func_idx].param_count      := 0;
    func_table^[cur_func_idx].param_bytes      := 0;
  End;
End;

{ --------------------------------------------------------------------------
  GESTION DE LA PORTEE
  -------------------------------------------------------------------------- }

{ Entrer dans un nouveau bloc : sauvegarder le sommet de sym_table }
Procedure ScopeEnter;
Begin
  Inc(scope_level);
  If scope_sp < 64 Then
  Begin
    Inc(scope_sp);
    scope_sym_stack[scope_sp] := sym_count;
  End;
End;

{ Quitter un bloc : retirer les symboles locaux du niveau courant }
Procedure ScopeLeave;
Begin
  If scope_sp > 0 Then
  Begin
    sym_count := scope_sym_stack[scope_sp];
    Dec(scope_sp);
  End;
  If scope_level > 0 Then Dec(scope_level);
End;

{ --------------------------------------------------------------------------
  TABLE DES SYMBOLES
  -------------------------------------------------------------------------- }

{ Ajouter un symbole ; retourne son index (1-base) ou 0 si table pleine }
Function AddSym(name : TString; kind : TSymKind;
                vtype : TValueKind; scope : TScope) : Integer;
Begin
  If sym_count >= MAX_SYM Then
  Begin
    WriteLn('Erreur interne : table des symboles saturee (MAX_SYM=',
            MAX_SYM, ')');
    Inc(err_count);
    AddSym := 0;
    Exit;
  End;
  Inc(sym_count);
  FillChar(sym_table^[sym_count], SizeOf(TSymEntry), 0);
  sym_table^[sym_count].name       := name;
  sym_table^[sym_count].kind       := kind;
  sym_table^[sym_count].vtype      := vtype;
  sym_table^[sym_count].scope      := scope;
  sym_table^[sym_count].class_name := class_name;
  sym_table^[sym_count].func_idx   := cur_func_idx;
  AddSym := sym_count;
End;

{ Chercher un symbole par nom (portee interne avant externe) }
Function FindSym(name : TString) : Integer;
Var i : Integer;
Begin
  For i := sym_count DownTo 1 Do
    If sym_table^[i].name = name Then Begin FindSym := i; Exit; End;
  FindSym := 0;
End;

{ Chercher un champ statique d'une classe donnee }
Function FindField(cname, fname : TString) : Integer;
Var i : Integer;
Begin
  For i := 1 To sym_count Do
    If (sym_table^[i].kind = SK_FIELD)
       And (sym_table^[i].class_name = cname)
       And (sym_table^[i].name = fname) Then
    Begin FindField := i; Exit; End;
  FindField := 0;
End;

{ Ajouter un champ statique de classe (emis dans le segment DATA) }
Function AddField(name : TString; vtype : TValueKind;
                  is_arr : Boolean; arr_size : Integer) : Integer;
Var si : Integer;
Begin
  si := AddSym(name, SK_FIELD, vtype, SC_FIELD);
  If si > 0 Then
  Begin
    sym_table^[si].is_array   := is_arr;
    sym_table^[si].arr_size   := arr_size;
    sym_table^[si].asm_label  := JGlobalLabel(class_name, name);
  End;
  AddField := si;
End;

{ Ajouter une variable locale a la methode courante }
Function AddLocalVar(name : TString; vtype : TValueKind;
                     is_arr : Boolean; arr_size : Integer) : Integer;
Var si    : Integer;
    fi    : Integer;
    sz    : Integer;
    words : Integer;
Begin
  si := AddSym(name, SK_VAR, vtype, SC_LOCAL);
  fi := cur_func_idx;
  If (si > 0) And (fi > 0) Then
  Begin
    { Taille en octets selon le type }
    If is_arr And (arr_size > 0) Then
      words := arr_size      { chaque element = 1 DW = 2 octets }
    Else If vtype = VK_STRING Then
      words := 2             { descripteur ptr+len = 2 DW       }
    Else
      words := 1;            { scalaire = 1 DW                   }
    sz := words * 2;

    func_table^[fi].local_frame_size :=
      func_table^[fi].local_frame_size + sz;
    sym_table^[si].bp_offset := -(func_table^[fi].local_frame_size);
    sym_table^[si].is_array  := is_arr;
    sym_table^[si].arr_size  := arr_size;

    { Enregistrer aussi dans le tableau locals de la methode }
    If func_table^[fi].local_count < MAX_LOCAL Then
    Begin
      Inc(func_table^[fi].local_count);
      With func_table^[fi].locals[func_table^[fi].local_count] Do
      Begin
        name      := sym_table^[si].name;
        vtype     := sym_table^[si].vtype;
        is_array  := is_arr;
        arr_size  := arr_size;
        bp_offset := sym_table^[si].bp_offset;
        is_final  := False;
        const_val := 0;
        const_str := '';
      End;
    End;
  End;
  AddLocalVar := si;
End;

{ Ajouter un parametre de methode (convention cdecl : BP+4 pour le 1er) }
Function AddParam(name : TString; vtype : TValueKind; is_arr : Boolean) : Integer;
Var si     : Integer;
    fi     : Integer;
    offset : Integer;
    pc     : Integer;
Begin
  si := AddSym(name, SK_VAR, vtype, SC_PARAM);
  fi := cur_func_idx;
  If (si > 0) And (fi > 0) Then
  Begin
    { offset BP : [BP+4] param1, [BP+6] param2, ... }
    pc := func_table^[fi].param_count;   { nb params deja enregistres }
    offset := 4 + pc * 2;

    Inc(func_table^[fi].param_count);
    Inc(func_table^[fi].param_bytes, 2);

    sym_table^[si].bp_offset := offset;
    sym_table^[si].scope     := SC_PARAM;
    sym_table^[si].is_array  := is_arr;

    pc := func_table^[fi].param_count;  { index 1-base apres increment }
    If pc <= MAX_PARAM Then
    With func_table^[fi].params[pc] Do
    Begin
      name      := sym_table^[si].name;
      vtype     := sym_table^[si].vtype;
      is_array  := is_arr;
      bp_offset := offset;
    End;
  End;
  AddParam := si;
End;

{ Ajouter un symbole global hors classe (utilise rarement en Java Lite) }
Function AddGlobalSym(name : TString; vtype : TValueKind;
                      is_arr : Boolean; arr_size : Integer) : Integer;
Var si : Integer;
Begin
  si := AddSym(name, SK_VAR, vtype, SC_GLOBAL);
  If si > 0 Then
  Begin
    sym_table^[si].is_array  := is_arr;
    sym_table^[si].arr_size  := arr_size;
    sym_table^[si].asm_label := JGlobalLabel(class_name, name);
  End;
  AddGlobalSym := si;
End;

{ --------------------------------------------------------------------------
  PILE DE BOUCLES (labels break / continue)
  -------------------------------------------------------------------------- }

{ Empiler des labels break/continue pour une boucle imbriquee }
Procedure PushLoopLabels(lbl_break, lbl_continue : TString);
Begin
  If loop_depth >= MAX_LOOP Then
  Begin
    WriteLn('Erreur interne : imbrication de boucles depassee (MAX_LOOP=',
            MAX_LOOP, ')');
    Inc(err_count);
    Exit;
  End;
  Inc(loop_depth);
  break_stack[loop_depth]    := lbl_break;
  continue_stack[loop_depth] := lbl_continue;
End;

{ Depiler les labels de boucle a la sortie d'une boucle }
Procedure PopLoopLabels;
Begin
  If loop_depth > 0 Then Dec(loop_depth);
End;

{ ============================================================================
  TODO 04 - EMISSION ASSEMBLEUR ET GESTION DES FICHIERS
  ============================================================================ }

{ --------------------------------------------------------------------------
  GESTION DES FICHIERS DE SORTIE
  -------------------------------------------------------------------------- }

{ Ouvrir le fichier ASM final et initialiser cur_out dessus }
Procedure InitOutput;
Begin
  Assign(out_file, out_fname);
  {$I-} Rewrite(out_file); {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur : impossible de creer le fichier de sortie : ', out_fname);
    Inc(err_count);
    Exit;
  End;
  cur_out  := @out_file;
  tmp_open := False;
End;

{ Ouvrir le fichier temporaire (corps des methodes) ; cur_out -> tmp_file }
Procedure OpenTmpFile;
Begin
  Assign(tmp_file, tmp_fname);
  {$I-} Rewrite(tmp_file); {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur : impossible de creer le fichier temporaire : ', tmp_fname);
    Inc(err_count);
    Exit;
  End;
  tmp_open := True;
  cur_out  := @tmp_file;
End;

{ Rediriger les emissions vers le fichier ASM principal }
Procedure SwitchToMain;
Begin
  cur_out := @out_file;
End;

{ Fermer le fichier ASM principal }
Procedure CloseOutput;
Begin
  {$I-} Close(out_file); {$I+}
End;

{ Fermer le fichier temporaire }
Procedure CloseTmpFile;
Begin
  If tmp_open Then
  Begin
    {$I-} Close(tmp_file); {$I+}
    tmp_open := False;
  End;
End;

{ Copier tmp_file -> out_file puis supprimer tmp_file
  A appeler apres la generation du segment CODE (methodes) }
Procedure MergeTmpToMain;
Var
  tf   : Text;
  line : String;
Begin
  If Not tmp_open Then Exit;
  CloseTmpFile;
  Assign(tf, tmp_fname);
  {$I-} Reset(tf); {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('Avertissement : fichier temporaire introuvable : ', tmp_fname);
    Inc(warn_count);
    Exit;
  End;
  While Not Eof(tf) Do
  Begin
    ReadLn(tf, line);
    WriteLn(out_file, line);
  End;
  Close(tf);
  {$I-} Erase(tf); {$I+}
End;

{ --------------------------------------------------------------------------
  PRIMITIVES D'EMISSION DE LIGNES DANS cur_out
  -------------------------------------------------------------------------- }

{ Ligne brute }
Procedure Emit(Const s : TString);
Begin
  WriteLn(cur_out^, s);
End;

{ Ligne vide }
Procedure EmitBlank;
Begin
  WriteLn(cur_out^, '');
End;

{ Ligne de separation '; -------...' (72 tirets) }
Procedure EmitSep;
Begin
  WriteLn(cur_out^,
    '; -----------------------------------------------------------------------');
End;

{ Commentaire '; texte' }
Procedure EmitComment(Const s : TString);
Begin
  WriteLn(cur_out^, '; ' + s);
End;

{ Label seul sur sa ligne 'lbl:' }
Procedure EmitLabel(Const lbl : TString);
Begin
  WriteLn(cur_out^, lbl + ':');
End;

{ Directive 'lbl  DB  data' (colonne alignee a 24) }
Procedure EmitDB(Const lbl, data : TString);
Var line : String;
Begin
  line := lbl;
  While Length(line) < 24 Do line := line + ' ';
  line := line + 'DB      ' + data;
  WriteLn(cur_out^, line);
End;

{ Directive 'lbl  DW  data' }
Procedure EmitDW(Const lbl, data : TString);
Var line : String;
Begin
  line := lbl;
  While Length(line) < 24 Do line := line + ' ';
  line := line + 'DW      ' + data;
  WriteLn(cur_out^, line);
End;

{ Directive 'lbl  DD  data' }
Procedure EmitDD(Const lbl, data : TString);
Var line : String;
Begin
  line := lbl;
  While Length(line) < 24 Do line := line + ' ';
  line := line + 'DD      ' + data;
  WriteLn(cur_out^, line);
End;

{ DW sans label (continuation d'une definition) }
Procedure EmitDWNoLbl(Const data : TString);
Begin
  WriteLn(cur_out^, '                        DW      ' + data);
End;

{ Directive 'lbl  EQU  val' }
Procedure EmitEQU(Const name, valstr : TString);
Var line : String;
Begin
  line := name;
  While Length(line) < 24 Do line := line + ' ';
  line := line + 'EQU     ' + valstr;
  WriteLn(cur_out^, line);
End;

{ EXTRN  name:NEAR }
Procedure EmitExtern(Const name : TString);
Begin
  WriteLn(cur_out^, '        EXTRN   ' + name + ':NEAR');
End;

{ PUBLIC  name }
Procedure EmitPublic(Const name : TString);
Begin
  WriteLn(cur_out^, '        PUBLIC  ' + name);
End;

{ --------------------------------------------------------------------------
  EMISSION D'INSTRUCTIONS ASM (indentation 8 espaces)
  -------------------------------------------------------------------------- }

{ Instruction avec operandes et commentaire optionnel
  Format :  '        MNEM    OPERANDES             ; commentaire' }
Procedure EmitI(Const mnem, ops, cmt : TString);
Var line : String;
Begin
  line := '        ' + mnem;
  If ops <> '' Then
  Begin
    While Length(line) < 16 Do line := line + ' ';
    line := line + ops;
  End;
  If cmt <> '' Then
  Begin
    While Length(line) < 40 Do line := line + ' ';
    line := line + '; ' + cmt;
  End;
  WriteLn(cur_out^, line);
  Inc(instr_count);
End;

{ Instruction sans commentaire }
Procedure EmitI1(Const mnem, ops : TString);
Begin
  EmitI(mnem, ops, '');
End;

{ Instruction sans operande ni commentaire (ex : RET, CWD, PUSHF) }
Procedure EmitI0(Const mnem : TString);
Begin
  EmitI(mnem, '', '');
End;

{ Instruction a deux operandes : 'MNEM  a, b' }
Procedure EmitI2(Const mnem, a, b : TString);
Begin
  EmitI(mnem, a + ', ' + b, '');
End;

{ --------------------------------------------------------------------------
  HELPERS SPECIFIQUES JAVA / MASM
  -------------------------------------------------------------------------- }

{ Emettre la definition en DB d'une chaine litterale (format DOS '$'-termine)
  lbl   : label du buffer brut (_JS_N)
  val   : chaine brute (apres decodage des escapes)
  Genere :
      _JS_N   DB  'texte',0Dh,0Ah,'$'   (si contient CR/LF)
  Pour MASM on termine par '$' pour INT 21h AH=09h,
  et on garde aussi un terminateur nul pour les appels internes. }
Procedure EmitDBStr(Const lbl, val : TString);
Var
  data : String;
  i    : Integer;
  c    : Char;
  inq  : Boolean;
Begin
  data := '';
  inq  := False;
  For i := 1 To Length(val) Do
  Begin
    c := val[i];
    If (c < ' ') Or (c = '''') Then
    Begin
      If inq Then Begin data := data + ''''; inq := False; End;
      If data <> '' Then data := data + ',';
      data := data + IntToStr(Ord(c));
    End
    Else
    Begin
      If Not inq Then
      Begin
        If data <> '' Then data := data + ',';
        data := data + '''';
        inq := True;
      End;
      data := data + c;
    End;
  End;
  If inq Then data := data + '''';
  { Terminateurs : 0Dh,0Ah,'$' pour DOS AH=09h + 0 pour les appels internes }
  If data <> '' Then data := data + ',';
  data := data + '0Dh,0Ah,''$'',0';
  EmitDB(lbl, data);
End;

{ Emettre la definition en DB d'une chaine sans terminateur CRLF
  (pour les chaines passees comme arguments ou concatenees) }
Procedure EmitDBStrRaw(Const lbl, val : TString);
Var
  data : String;
  i    : Integer;
  c    : Char;
  inq  : Boolean;
Begin
  data := '';
  inq  := False;
  For i := 1 To Length(val) Do
  Begin
    c := val[i];
    If (c < ' ') Or (c = '''') Then
    Begin
      If inq Then Begin data := data + ''''; inq := False; End;
      If data <> '' Then data := data + ',';
      data := data + IntToStr(Ord(c));
    End
    Else
    Begin
      If Not inq Then
      Begin
        If data <> '' Then data := data + ',';
        data := data + '''';
        inq := True;
      End;
      data := data + c;
    End;
  End;
  If inq Then data := data + '''';
  If data <> '' Then data := data + ',';
  data := data + '0';    { terminateur nul }
  EmitDB(lbl, data);
End;

{ Memoriser le label du premier point d'entree (utilise par GenEndDirective) }
Procedure SetFirstInstrLabel(Const lbl : TString);
Begin
  first_instr_lbl := lbl;
End;

{ ============================================================================
  TODO 05 - GENERATION DES SEGMENTS STACK ET DATA (EN-TETES)
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenFileHeader : commentaires d'en-tete du fichier ASM genere.
  -------------------------------------------------------------------------- }
Procedure GenFileHeader;
Begin
  EmitComment('=========================================================');
  EmitComment('Fichier genere par JAVAC86 v' + JAVAC86_VERSION);
  EmitComment('Date    : ' + JAVAC86_DATE);
  EmitComment('Source  : ' + src_fname);
  EmitComment('Classe  : ' + class_name);
  If pkg_name <> '' Then
    EmitComment('Package : ' + pkg_name);
  EmitComment('Cible   : MASM 8086, modele SMALL');
  EmitComment('=========================================================');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenModelDirectives : directives de modele memoire MASM 8086 SMALL.
  Utilise les segments explicites (pas les directives simplifiees .DATA etc.)
  pour rester compatible MASM 5.x / TASM.
  -------------------------------------------------------------------------- }
Procedure GenModelDirectives;
Begin
  Emit('        .8086');
  Emit('        DOSSEG');
  Emit('        .MODEL  SMALL');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenMacroDefs : macros MASM utiles generees une seule fois en tete de fichier.
  EXIT_DOS  : terminer le processus via INT 21h AH=4Ch.
  INIT_DS   : charger @DATA dans DS (premier appel dans main).
  -------------------------------------------------------------------------- }
Procedure GenMacroDefs;
Begin
  EmitComment('----- Macros -----');
  { Macro EXIT_DOS }
  Emit('EXIT_DOS        MACRO');
  Emit('                MOV     AH, 4Ch');
  Emit('                INT     21h');
  Emit('                ENDM');
  EmitBlank;
  { Macro INIT_DS }
  Emit('INIT_DS         MACRO');
  Emit('                MOV     AX, @DATA');
  Emit('                MOV     DS, AX');
  Emit('                ENDM');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenStackHeader : ouvrir le segment de pile explicite MASM.
  Format : _STACK SEGMENT PARA STACK 'STACK'
  -------------------------------------------------------------------------- }
Procedure GenStackHeader;
Begin
  EmitComment('----- Segment STACK -----');
  Emit('_STACK          SEGMENT PARA STACK ''STACK''');
  EmitDB('                ', IntToStr(STACK_SIZE) + ' DUP(?)');
End;

{ --------------------------------------------------------------------------
  GenStackFooter : fermer le segment de pile.
  -------------------------------------------------------------------------- }
Procedure GenStackFooter;
Begin
  Emit('_STACK          ENDS');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataHeader : ouvrir le segment de donnees explicite MASM.
  -------------------------------------------------------------------------- }
Procedure GenDataHeader;
Begin
  EmitComment('----- Segment DATA -----');
  Emit('_DATA           SEGMENT WORD PUBLIC ''DATA''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataFooter : fermer le segment de donnees.
  -------------------------------------------------------------------------- }
Procedure GenDataFooter;
Begin
  EmitBlank;
  Emit('_DATA           ENDS');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenSystemVarsData : emettre les variables systeme Java Lite dans _DATA.

  _J_OUTBUF   DB  256 DUP(0)      buffer de sortie System.out.print
  _J_INBUF    DB  128 DUP(0)      buffer d'entree System.in / Scanner
  _J_INTBUF   DB  12  DUP(0)      buffer de conversion int -> chaine
  _J_CRLF     DB  0Dh, 0Ah, '$'   fin de ligne DOS (INT 21h AH=09h)
  _J_NULLSTR  DB  0                chaine vide / null
  -------------------------------------------------------------------------- }
Procedure GenSystemVarsData;
Begin
  EmitComment('----- Variables systeme JAVAC86 -----');

  { Buffer de sortie (System.out.print / println) }
  EmitDB('_J_OUTBUF',  '256 DUP(0)');

  { Buffer de saisie console (Scanner.nextLine / nextInt) }
  EmitDB('_J_INBUF',   '128 DUP(0)');

  { Buffer de conversion entier -> chaine (IntToStr runtime) }
  EmitDB('_J_INTBUF',  '12 DUP(0)');

  { CRLF + terminateur '$' pour INT 21h AH=09h }
  EmitDB('_J_CRLF',    '0Dh, 0Ah, ''$''');

  { Chaine vide (null / "") }
  EmitDB('_J_NULLSTR', '0');

  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenHeader : emettre tous les en-tetes avant les segments DATA et CODE.
  Ordre MASM : commentaires -> model -> macros -> STACK.
  -------------------------------------------------------------------------- }
Procedure GenHeader;
Begin
  GenFileHeader;
  GenModelDirectives;
  GenMacroDefs;
  GenStackHeader;
  GenStackFooter;
End;

{ --------------------------------------------------------------------------
  GenCodeHeader : ouvrir le segment de code explicite MASM.
  -------------------------------------------------------------------------- }
Procedure GenCodeHeader;
Begin
  EmitComment('----- Segment CODE -----');
  Emit('_CODE           SEGMENT WORD PUBLIC ''CODE''');
  EmitBlank;
  { Assumer les segments au debut du segment CODE }
  EmitI1('ASSUME', 'CS:_CODE, DS:_DATA, SS:_STACK');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenCodeFooter : fermer le segment de code.
  -------------------------------------------------------------------------- }
Procedure GenCodeFooter;
Begin
  EmitBlank;
  Emit('_CODE           ENDS');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenEndDirective : emettre la directive END avec le label d'entree.
  -------------------------------------------------------------------------- }
Procedure GenEndDirective;
Begin
  If first_instr_lbl <> '' Then
    Emit('        END     ' + first_instr_lbl)
  Else
    Emit('        END');
End;

{ ============================================================================
  TODO 06 - GENERATION DU SEGMENT DATA (CORPS)
  ============================================================================ }

{ --------------------------------------------------------------------------
  TypeSizeWords : nombre de DW alloues pour un type Java.
  Scalaires (int / boolean / char) : 1 DW.
  String                           : 1 DW (pointeur OFFSET dans _DATA).
  Tableau                          : arr_size DW (un element par case).
  -------------------------------------------------------------------------- }
Function TypeSizeWords(vt : TValueKind; arr_sz : Integer) : Integer;
Begin
  Case vt Of
    VK_ARRAY  : TypeSizeWords := arr_sz;   { N DW pour type[N]   }
    VK_STRING : TypeSizeWords := 1;        { pointeur 16 bits     }
  Else
    TypeSizeWords := 1;                    { int / bool / char    }
  End;
End;

{ --------------------------------------------------------------------------
  GenOneFieldData : emettre la reservation de donnees pour un champ statique.
  Les champs de classe Java Lite sont tous statiques (SK_FIELD / SC_FIELD).

  int / boolean / char           ->  lbl  DW  0
  String                         ->  lbl  DW  0   (pointeur, initialise a null)
  int[] / boolean[] / char[] / String[]
                                 ->  lbl  DW  N DUP(0)
  -------------------------------------------------------------------------- }
Procedure GenOneFieldData(i : Integer);
Var lbl  : TString;
    vt   : TValueKind;
    n    : Integer;
Begin
  lbl := sym_table^[i].asm_label;
  vt  := sym_table^[i].vtype;
  n   := sym_table^[i].arr_size;

  If sym_table^[i].is_final Then
  Begin
    { Constante finale : une EQU suffit pour les scalaires }
    If vt = VK_STRING Then
    Begin
      { Chaine constante : pointeur dans DATA, on reserve quand meme la DW }
      EmitDW(lbl, '0');
    End
    Else
      EmitEQU(lbl, IntToStr(sym_table^[i].const_val));
    Exit;
  End;

  Case vt Of
    VK_INT, VK_BOOL, VK_CHAR :
      EmitDW(lbl, '0');

    VK_STRING :
      EmitDW(lbl, '0');       { pointe initialement vers _J_NULLSTR }

    VK_ARRAY :
      Begin
        If n <= 0 Then n := 1;
        EmitDW(lbl, IntToStr(n) + ' DUP(0)');
      End;

  Else
    EmitComment('(champ de type inconnu ignore : ' + lbl + ')');
  End;
End;

{ --------------------------------------------------------------------------
  GenAllFieldsData : emettre tous les champs statiques enregistres.
  -------------------------------------------------------------------------- }
Procedure GenAllFieldsData;
Var i     : Integer;
    found : Boolean;
Begin
  found := False;
  For i := 1 To sym_count Do
    If sym_table^[i].kind = SK_FIELD Then
    Begin
      If Not found Then
      Begin
        EmitComment('----- Champs statiques de classe -----');
        found := True;
      End;
      GenOneFieldData(i);
    End;
  If found Then EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenOneLiteralData : emettre un litteral de chaine de la table lit_table.

  Format emis (null-termine, utilisable par le runtime en mode char-by-char) :
      _JS_N   DB   'texte', 0

  Le runtime JAVAC86 utilise INT 21h AH=02h (ecriture caractere par caractere)
  plutot que AH=09h afin de ne pas dependre du terminateur '$' et de pouvoir
  afficher des chaines qui contiennent '$'.
  -------------------------------------------------------------------------- }
Procedure GenOneLiteralData(i : Integer);
Begin
  EmitDBStrRaw(lit_table^[i].asm_data, lit_table^[i].val);
End;

{ --------------------------------------------------------------------------
  GenLiteralsData : emettre tous les litteraux de la table lit_table.
  -------------------------------------------------------------------------- }
Procedure GenLiteralsData;
Var i : Integer;
Begin
  If lit_count = 0 Then Exit;
  EmitComment('----- Litteraux de chaines -----');
  For i := 1 To lit_count Do
    GenOneLiteralData(i);
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataSegment : emettre le segment _DATA complet.
  Ordre :
    1. GenDataHeader  (_DATA SEGMENT ...)
    2. GenAllFieldsData     (champs statiques utilisateur)
    3. GenLiteralsData      (chaines litterales)
    4. GenSystemVarsData    (buffers systeme JAVAC86)
    5. GenDataFooter  (_DATA ENDS)
  -------------------------------------------------------------------------- }
Procedure GenDataSegment;
Begin
  GenDataHeader;
  GenAllFieldsData;
  GenLiteralsData;
  GenSystemVarsData;
  GenDataFooter;
End;

{ ============================================================================
  TODO 07 - PARSER : DECLARATIONS JAVA (PACKAGE, IMPORT, CLASSE, CHAMPS)
  ============================================================================ }

{ --------------------------------------------------------------------------
  Masque de bits pour les modificateurs Java
  -------------------------------------------------------------------------- }
Const
  MOD_PUBLIC    = 1;
  MOD_PRIVATE   = 2;
  MOD_PROTECTED = 4;
  MOD_STATIC    = 8;
  MOD_FINAL     = 16;

{ --------------------------------------------------------------------------
  Declarations Forward pour la recursion mutuelle entre parser et codegen.
  Les corps seront fournis dans les TODOs 08-10.
  -------------------------------------------------------------------------- }
Function  ParseExpr : TValueKind; Forward;
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;
Procedure ParseAssignOrExprStmt; Forward;

{ --------------------------------------------------------------------------
  Rapporteurs d'erreur / avertissement
  -------------------------------------------------------------------------- }
Procedure ParseError(Const msg : TString);
Begin
  Inc(err_count);
  WriteLn('Erreur (ligne ', lex_lineno, ', col ', lex_colno, ') : ', msg);
End;

Procedure ParseWarn(Const msg : TString);
Begin
  Inc(warn_count);
  WriteLn('Attention (ligne ', lex_lineno, ') : ', msg);
End;

{ --------------------------------------------------------------------------
  IsTypeKeyword : vrai si le token est un mot-cle de type Java Lite.
  Reconnus : int  boolean  char  String  void  long  float  double
  -------------------------------------------------------------------------- }
Function IsTypeKeyword(Const t : TToken) : Boolean;
Begin
  IsTypeKeyword := (t.kind = TK_KEYWORD) And
    ( (t.val = 'int')     Or (t.val = 'boolean') Or
      (t.val = 'char')    Or (t.val = 'String')  Or
      (t.val = 'void')    Or (t.val = 'long')    Or
      (t.val = 'float')   Or (t.val = 'double') );
End;

{ --------------------------------------------------------------------------
  KeywordToValueKind : convertir le mot-cle de type en TValueKind.
  long / float / double -> VK_INT (traites comme int dans Java Lite 16 bits).
  -------------------------------------------------------------------------- }
Function KeywordToValueKind(Const kw : TString) : TValueKind;
Begin
  If      kw = 'int'     Then KeywordToValueKind := VK_INT
  Else If kw = 'boolean' Then KeywordToValueKind := VK_BOOL
  Else If kw = 'char'    Then KeywordToValueKind := VK_CHAR
  Else If kw = 'String'  Then KeywordToValueKind := VK_STRING
  Else If kw = 'void'    Then KeywordToValueKind := VK_VOID
  Else If kw = 'long'    Then KeywordToValueKind := VK_INT   { approximation 16 bits }
  Else If kw = 'float'   Then KeywordToValueKind := VK_INT
  Else If kw = 'double'  Then KeywordToValueKind := VK_INT
  Else                        KeywordToValueKind := VK_UNDEF;
End;

{ --------------------------------------------------------------------------
  IsAssignOp : vrai si le token est un operateur d'affectation Java.
  Reconnus :  =  +=  -=  *=  /=  %=
  -------------------------------------------------------------------------- }
Function IsAssignOp(Const t : TToken) : Boolean;
Begin
  IsAssignOp := (t.kind = TK_OP) And
    ( (t.val = '=')  Or (t.val = '+=') Or (t.val = '-=') Or
      (t.val = '*=') Or (t.val = '/=') Or (t.val = '%=') );
End;

{ --------------------------------------------------------------------------
  ParseTypeSpec : lire un specificateur de type Java Lite.
  Syntaxe : type_kw [ '[' ']' ]
  Exemples :
    int        -> vt=VK_INT,  is_array=False
    int[]      -> vt=VK_INT,  is_array=True
    String[]   -> vt=VK_STRING, is_array=True

  Retourne True si un type a ete reconnu, False sinon.
  Ne consomme rien si le token suivant n'est pas un type.
  -------------------------------------------------------------------------- }
Function ParseTypeSpec(Var vt : TValueKind; Var is_array : Boolean) : Boolean;
Var t2, t3 : TToken;
Begin
  LexPeek; t2 := lex_peek_tok;
  If Not IsTypeKeyword(t2) Then
  Begin
    ParseTypeSpec := False;
    vt       := VK_UNDEF;
    is_array := False;
    Exit;
  End;
  LexNext;                           { consommer le mot-cle de type }
  vt       := KeywordToValueKind(t2.val);
  is_array := False;

  { Detection de '[]' }
  LexPeek; t2 := lex_peek_tok;
  If (t2.kind = TK_PUNCT) And (t2.val = '[') Then
  Begin
    LexNext;                         { consommer '[' }
    LexPeek; t3 := lex_peek_tok;
    If (t3.kind = TK_PUNCT) And (t3.val = ']') Then
    Begin
      LexNext;                       { consommer ']' }
      is_array := True;
      vt       := VK_ARRAY;          { le type de base reste dans arr_elem_vt si besoin }
    End
    Else
      ParseError('] attendu apres [ dans le type tableau');
  End;
  ParseTypeSpec := True;
End;

{ --------------------------------------------------------------------------
  SkipToSemicolon : avancer jusqu'au prochain ';' inclus ou EOF (recuperation).
  -------------------------------------------------------------------------- }
Procedure SkipToSemicolon;
Var t : TToken;
Begin
  Repeat
    LexNext; t := lex_cur_tok;
  Until (t.kind = TK_EOF) Or
        ((t.kind = TK_PUNCT) And (t.val = ';'));
End;

{ --------------------------------------------------------------------------
  SkipBlock : avancer en ignorant un bloc imbrique (accolade ouvrante/fermante).
  Utile pour la recuperation d'erreur dans les corps de methode.
  -------------------------------------------------------------------------- }
Procedure SkipBlock;
Var t     : TToken;
    depth : Integer;
Begin
  depth := 0;
  Repeat
    LexNext; t := lex_cur_tok;
    If (t.kind = TK_PUNCT) And (t.val = '{') Then Inc(depth);
    If (t.kind = TK_PUNCT) And (t.val = '}') Then
    Begin
      If depth = 0 Then Exit;
      Dec(depth);
    End;
  Until t.kind = TK_EOF;
End;

{ --------------------------------------------------------------------------
  ParseConstIntExpr : evaluer une expression constante entiere simple
  au moment de la compilation. Formes supportees :
    integer_literal  |  char_literal  |  true  |  false
    |  '(' expr ')'  |  '-' expr  |  '+' expr
    |  expr ('+' | '-' | '*' | '/' | '%') expr
  Retourne la valeur calculee ou 0 en cas d'erreur.
  -------------------------------------------------------------------------- }
Function ParseConstIntExpr : LongInt;
Var t   : TToken;
    v   : LongInt;
    lhs : LongInt;
    op  : TString;
Begin
  LexPeek; t := lex_peek_tok;

  { Parenthese ouvrante }
  If (t.kind = TK_PUNCT) And (t.val = '(') Then
  Begin
    LexNext;
    v := ParseConstIntExpr;
    LexExpect(')');
    ParseConstIntExpr := v;
    Exit;
  End;

  { Unaire - }
  If (t.kind = TK_OP) And (t.val = '-') Then
  Begin
    LexNext;
    ParseConstIntExpr := -ParseConstIntExpr;
    Exit;
  End;

  { Unaire + (ignore) }
  If (t.kind = TK_OP) And (t.val = '+') Then
  Begin
    LexNext;
    ParseConstIntExpr := ParseConstIntExpr;
    Exit;
  End;

  { Literal entier (decimal ou hexa via LexReadNumber) }
  If t.kind = TK_INT Then
  Begin
    LexNext;
    lhs := t.int_val;
    { Operateurs binaires eventuels }
    LexPeek; t := lex_peek_tok;
    While (t.kind = TK_OP) And
          ((t.val = '+') Or (t.val = '-') Or
           (t.val = '*') Or (t.val = '/') Or (t.val = '%')) Do
    Begin
      op := t.val;
      LexNext;
      v := ParseConstIntExpr;
      If      op = '+' Then lhs := lhs + v
      Else If op = '-' Then lhs := lhs - v
      Else If op = '*' Then lhs := lhs * v
      Else If op = '/' Then
      Begin
        If v <> 0 Then lhs := lhs Div v
        Else Begin ParseError('Division par zero dans expression constante'); lhs := 0; End;
      End
      Else If op = '%' Then
      Begin
        If v <> 0 Then lhs := lhs Mod v
        Else Begin ParseError('Modulo par zero dans expression constante'); lhs := 0; End;
      End;
      LexPeek; t := lex_peek_tok;
    End;
    ParseConstIntExpr := lhs;
    Exit;
  End;

  { Literal char : valeur ordinale (ex : 'A' -> 65) }
  If t.kind = TK_CHAR Then
  Begin
    LexNext;
    If Length(t.val) > 0 Then
      ParseConstIntExpr := Ord(t.val[1])
    Else
      ParseConstIntExpr := 0;
    Exit;
  End;

  { true -> 1, false -> 0 }
  If (t.kind = TK_KEYWORD) And (t.val = 'true')  Then Begin LexNext; ParseConstIntExpr := 1; Exit; End;
  If (t.kind = TK_KEYWORD) And (t.val = 'false') Then Begin LexNext; ParseConstIntExpr := 0; Exit; End;

  ParseError('Expression constante entiere attendue, lu : ''' + t.val + '''');
  ParseConstIntExpr := 0;
End;

{ --------------------------------------------------------------------------
  ParseModifiers : consommer les modificateurs Java facultatifs.
  Retourne un masque de bits (MOD_PUBLIC | MOD_STATIC | MOD_FINAL | ...).
  -------------------------------------------------------------------------- }
Function ParseModifiers : Integer;
Var mods : Integer;
    t    : TToken;
    cont : Boolean;
Begin
  mods := 0;
  cont := True;
  While cont Do
  Begin
    LexPeek; t := lex_peek_tok;
    If t.kind <> TK_KEYWORD Then Break;
    If      t.val = 'public'    Then Begin LexNext; mods := mods Or MOD_PUBLIC;    End
    Else If t.val = 'private'   Then Begin LexNext; mods := mods Or MOD_PRIVATE;   End
    Else If t.val = 'protected' Then Begin LexNext; mods := mods Or MOD_PROTECTED; End
    Else If t.val = 'static'    Then Begin LexNext; mods := mods Or MOD_STATIC;    End
    Else If t.val = 'final'     Then Begin LexNext; mods := mods Or MOD_FINAL;     End
    Else cont := False;
  End;
  ParseModifiers := mods;
End;

{ --------------------------------------------------------------------------
  ParsePackageDecl : 'package' ident ('.' ident)* ';'
  Remplit la variable globale pkg_name.
  -------------------------------------------------------------------------- }
Procedure ParsePackageDecl;
Var t    : TToken;
    name : TString;
Begin
  LexExpect('package');
  LexExpectKind(TK_IDENT); t := lex_cur_tok;
  name := t.val;
  { Absorber les composantes 'ident.ident...' }
  LexPeek; t := lex_peek_tok;
  While (t.kind = TK_PUNCT) And (t.val = '.') Do
  Begin
    LexNext;                       { '.' }
    LexPeek; t := lex_peek_tok;
    If t.kind = TK_IDENT Then
    Begin
      LexNext;
      name := name + '.' + t.val;
    End
    Else Break;
    LexPeek; t := lex_peek_tok;
  End;
  LexExpect(';');
  pkg_name := name;
End;

{ --------------------------------------------------------------------------
  ParseImportDecls : zero ou plusieurs 'import' ... ';'
  Seul import reconnu et traite : java.util.Scanner
  Tous les autres imports sont silencieusement ignores.
  -------------------------------------------------------------------------- }
Procedure ParseImportDecls;
Var t       : TToken;
    path    : TString;
Begin
  LexPeek; t := lex_peek_tok;
  While (t.kind = TK_KEYWORD) And (t.val = 'import') Do
  Begin
    LexNext;                         { consommer 'import' }
    { Lire le chemin complet : ident ('.' ident)* ['.''*'] ';' }
    path := '';
    LexPeek; t := lex_peek_tok;
    While (t.kind = TK_IDENT)
       Or ((t.kind = TK_OP)    And (t.val = '*'))
       Or ((t.kind = TK_PUNCT) And (t.val = '.')) Do
    Begin
      LexNext;
      If t.val <> '.' Then
        If path = '' Then path := t.val
        Else path := path + '.' + t.val;
      LexPeek; t := lex_peek_tok;
    End;
    LexExpect(';');

    { Reconnaitre java.util.Scanner }
    If (path = 'java.util.Scanner') Or (path = 'java.util') Then
      has_scanner := True
    Else If path = 'java.lang' Then
      { java.lang.* toujours implicitement disponible, ignore }
    Else
      If opt_verbose Then
        WriteLn('(import ignore : ', path, ')');

    LexPeek; t := lex_peek_tok;
  End;
End;

{ --------------------------------------------------------------------------
  ParseVarDecl : declaration de variable / champ.
  is_field = True  : c'est un champ statique de classe (SK_FIELD, SC_FIELD).
  is_field = False : c'est une variable locale de methode.

  Formes supportees :
    int x;
    int x = 5;
    boolean b = true;
    char c = 'A';
    String s = "texte";
    int[] arr = new int[10];
    final int N = 42;
    final String MSG = "bonjour";

  Consomme jusqu'au ';' inclus.
  -------------------------------------------------------------------------- }
Procedure ParseVarDecl(is_field : Boolean);
Var vt       : TValueKind;
    is_arr   : Boolean;
    is_fin   : Boolean;
    name     : TString;
    idx      : Integer;
    arr_size : Integer;
    has_init : Boolean;
    init_val : LongInt;
    init_str : TString;
    t        : TToken;
Begin
  { Les modificateurs ont peut-etre deja ete consommes par l'appelant
    (ParseClassBody). On distingue via is_field. }
  is_fin   := False;
  arr_size := 0;
  has_init := False;
  init_val := 0;
  init_str := '';

  { 'final' optionnel juste avant le type }
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_KEYWORD) And (t.val = 'final') Then
  Begin
    LexNext;
    is_fin := True;
  End;

  If Not ParseTypeSpec(vt, is_arr) Then
  Begin
    ParseError('Type attendu dans la declaration de variable');
    SkipToSemicolon;
    Exit;
  End;

  LexExpectKind(TK_IDENT); t := lex_cur_tok;
  name := t.val;

  { Avertir si redeclaration }
  If FindSym(name) > 0 Then
    ParseWarn('Redeclaration du symbole : ' + name);

  { Initialisation eventuelle }
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_OP) And (t.val = '=') Then
  Begin
    LexNext;                         { consommer '=' }
    LexPeek; t := lex_peek_tok;

    If is_arr Then
    Begin
      { 'new type[N]' est la seule forme acceptee pour les tableaux }
      If (t.kind = TK_KEYWORD) And (t.val = 'new') Then
      Begin
        LexNext;                     { 'new' }
        LexPeek; t := lex_peek_tok;
        If IsTypeKeyword(t) Then
          LexNext                    { consommer le type (int, char...) }
        Else
          ParseError('Type attendu apres ''new''');
        LexExpect('[');
        arr_size := ParseConstIntExpr;
        LexExpect(']');
        If arr_size <= 0 Then
        Begin
          ParseError('Taille de tableau invalide : ' + IntToStr(arr_size));
          arr_size := 1;
        End;
      End
      Else
       ParseError('''new'' attendu dans l''initialisation du tableau : ' + name);
    End
    Else If (vt = VK_STRING) And (t.kind = TK_STRING) Then
    Begin
      { Chaine litterale }
      LexNext;
      has_init := True;
      init_str := t.val;
      init_val := AddLit(init_str);
    End
    Else
    Begin
      { Expression constante scalaire (int / boolean / char) }
      has_init := True;
      init_val := ParseConstIntExpr;
    End;
  End
  Else If is_arr Then
  Begin
    ParseError('Un tableau doit etre initialise avec ''new'' : ' + name);
    SkipToSemicolon;
    Exit;
  End;

  If is_fin And Not has_init And Not is_arr Then
    ParseError('Une constante finale doit etre initialisee : ' + name);

  LexExpect(';');

  { Enregistrer le symbole }
  If is_field Then
  Begin
    idx := AddField(name, vt, is_arr, arr_size);
  End
  Else
  Begin
    If is_arr Then
      idx := AddLocalVar(name, VK_ARRAY, True, arr_size)
    Else
      idx := AddLocalVar(name, vt, False, 0);
  End;

  If idx > 0 Then
  Begin
    sym_table^[idx].is_final  := is_fin;
    sym_table^[idx].const_val := init_val;
    sym_table^[idx].const_str := init_str;
    If is_field And (vt = VK_STRING) And (init_str <> '') Then
    Begin
      { Le label ASM du litteral sera emis dans GenLiteralsData }
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParsePackageAndImports : consommer optionnellement package + imports.
  -------------------------------------------------------------------------- }
Procedure ParsePackageAndImports;
Var t : TToken;
Begin
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_KEYWORD) And (t.val = 'package') Then
    ParsePackageDecl;
  ParseImportDecls;
End;

{ ============================================================================
  TODO 08 ... 25 : a implementer
  ============================================================================ }

{ ============================================================================
  TODO 08 - PARSER : EXPRESSIONS JAVA
  ============================================================================ }

{ --- Declarations Forward pour la hierarchie d'expressions --- }
Function ParseExprTernary : TValueKind; Forward;
Function ParseExprOr      : TValueKind; Forward;
Function ParseExprAnd2    : TValueKind; Forward;
Function ParseExprEq      : TValueKind; Forward;
Function ParseExprRel     : TValueKind; Forward;
Function ParseExprAdd     : TValueKind; Forward;
Function ParseExprMul     : TValueKind; Forward;
Function ParseExprUnary   : TValueKind; Forward;
Function ParseExprPostfix : TValueKind; Forward;
Function ParseExprPrimary : TValueKind; Forward;
Function ParseArgList     : Integer;    Forward;

{ --------------------------------------------------------------------------
  HELPERS CODEGEN : chargement / stockage de variables
  -------------------------------------------------------------------------- }

{ Charger une variable dans AX (scalaire) ou AX=ptr, DX=len (String) }
Procedure GenLoadVar(idx : Integer);
Var lbl : TString;
    ofs : Integer;
    sc  : TScope;
    vt  : TValueKind;
Begin
  lbl := sym_table^[idx].asm_label;
  ofs := sym_table^[idx].bp_offset;
  sc  := sym_table^[idx].scope;
  vt  := sym_table^[idx].vtype;
  Case sc Of
    SC_GLOBAL, SC_FIELD :
      If vt = VK_STRING Then
      Begin
        EmitI1('MOV', 'AX, WORD PTR [' + lbl + ']');
        EmitI1('MOV', 'DX, WORD PTR [' + lbl + '+2]');
      End
      Else
        EmitI1('MOV', 'AX, WORD PTR [' + lbl + ']');
    SC_LOCAL :
      If vt = VK_STRING Then
      Begin
        EmitI1('MOV', 'AX, [BP' + IntToStr(ofs) + ']');
        EmitI1('MOV', 'DX, [BP' + IntToStr(ofs + 2) + ']');
      End
      Else
        EmitI1('MOV', 'AX, [BP' + IntToStr(ofs) + ']');
    SC_PARAM :
      If vt = VK_STRING Then
      Begin
        EmitI1('MOV', 'AX, [BP+' + IntToStr(ofs) + ']');
        EmitI1('MOV', 'DX, [BP+' + IntToStr(ofs + 2) + ']');
      End
      Else
        EmitI1('MOV', 'AX, [BP+' + IntToStr(ofs) + ']');
  End;
End;

{ Stocker AX (scalaire) ou AX+DX (String) dans une variable }
Procedure GenStoreVar(idx : Integer);
Var lbl : TString;
    ofs : Integer;
    sc  : TScope;
    vt  : TValueKind;
Begin
  lbl := sym_table^[idx].asm_label;
  ofs := sym_table^[idx].bp_offset;
  sc  := sym_table^[idx].scope;
  vt  := sym_table^[idx].vtype;
  Case sc Of
    SC_GLOBAL, SC_FIELD :
      If vt = VK_STRING Then
      Begin
        EmitI1('MOV', 'WORD PTR [' + lbl + '], AX');
        EmitI1('MOV', 'WORD PTR [' + lbl + '+2], DX');
      End
      Else
        EmitI1('MOV', 'WORD PTR [' + lbl + '], AX');
    SC_LOCAL :
      If vt = VK_STRING Then
      Begin
        EmitI1('MOV', '[BP' + IntToStr(ofs) + '], AX');
        EmitI1('MOV', '[BP' + IntToStr(ofs + 2) + '], DX');
      End
      Else
        EmitI1('MOV', '[BP' + IntToStr(ofs) + '], AX');
    SC_PARAM :
      If vt = VK_STRING Then
      Begin
        EmitI1('MOV', '[BP+' + IntToStr(ofs) + '], AX');
        EmitI1('MOV', '[BP+' + IntToStr(ofs + 2) + '], DX');
      End
      Else
        EmitI1('MOV', '[BP+' + IntToStr(ofs) + '], AX');
  End;
End;

{ Charger arr[index] dans AX.  Index deja dans BX (entier). }
Procedure GenLoadArrayElem(idx : Integer);
Var lbl : TString;
    ofs : Integer;
    sc  : TScope;
Begin
  lbl := sym_table^[idx].asm_label;
  ofs := sym_table^[idx].bp_offset;
  sc  := sym_table^[idx].scope;
  EmitI1('SHL', 'BX, 1');
  Case sc Of
    SC_GLOBAL, SC_FIELD :
      Begin
        EmitI1('LEA', 'SI, [' + lbl + ']');
        EmitI1('ADD', 'SI, BX');
      End;
    SC_LOCAL :
      Begin
        EmitI1('LEA', 'SI, [BP' + IntToStr(ofs) + ']');
        EmitI1('ADD', 'SI, BX');
      End;
    SC_PARAM :
      Begin
        EmitI1('LEA', 'SI, [BP+' + IntToStr(ofs) + ']');
        EmitI1('ADD', 'SI, BX');
      End;
  End;
  EmitI1('MOV', 'AX, [SI]');
End;

{ Stocker AX dans arr[index].  Index deja dans BX (entier). }
Procedure GenStoreArrayElem(idx : Integer);
Var lbl : TString;
    ofs : Integer;
    sc  : TScope;
Begin
  lbl := sym_table^[idx].asm_label;
  ofs := sym_table^[idx].bp_offset;
  sc  := sym_table^[idx].scope;
  EmitI1('PUSH', 'AX');
  EmitI1('SHL',  'BX, 1');
  Case sc Of
    SC_GLOBAL, SC_FIELD :
      Begin
        EmitI1('LEA', 'SI, [' + lbl + ']');
        EmitI1('ADD', 'SI, BX');
      End;
    SC_LOCAL :
      Begin
        EmitI1('LEA', 'SI, [BP' + IntToStr(ofs) + ']');
        EmitI1('ADD', 'SI, BX');
      End;
    SC_PARAM :
      Begin
        EmitI1('LEA', 'SI, [BP+' + IntToStr(ofs) + ']');
        EmitI1('ADD', 'SI, BX');
      End;
  End;
  EmitI1('POP', 'AX');
  EmitI1('MOV', '[SI], AX');
End;

{ Charger une constante finale dans AX }
Procedure GenLoadConst(idx : Integer);
Begin
  EmitI1('MOV', 'AX, ' + IntToStr(sym_table^[idx].const_val));
End;

{ CALL label + nettoyage pile cdecl }
Procedure GenInlineCall(fi : Integer; argc : Integer);
Begin
  EmitI1('CALL', func_table^[fi].asm_label);
  If argc > 0 Then
    EmitI1('ADD', 'SP, ' + IntToStr(argc * 2));
End;

{ --------------------------------------------------------------------------
  ParseArgList : '(' [expr (',' expr)*] ')'
  Chaque argument est PUSH AX apres evaluation.
  String : PUSH DX (len) puis PUSH AX (ptr) -> 2 mots par arg string.
  Retourne le nombre de mots empiles au total.
  -------------------------------------------------------------------------- }
Function ParseArgList : Integer;
Var count : Integer;
    vt    : TValueKind;
    t     : TToken;
Begin
  count := 0;
  LexExpect('(');
  LexPeek; t := lex_peek_tok;
  If Not ((t.kind = TK_PUNCT) And (t.val = ')')) Then
  Begin
    Repeat
      vt := ParseExpr;
      If vt = VK_STRING Then
      Begin
        EmitI1('PUSH', 'DX');    { len }
        EmitI1('PUSH', 'AX');    { ptr }
        Inc(count, 2);
      End
      Else
      Begin
        EmitI1('PUSH', 'AX');
        Inc(count);
      End;
      LexPeek; t := lex_peek_tok;
      If (t.kind = TK_PUNCT) And (t.val = ',') Then LexNext Else Break;
    Until False;
  End;
  LexExpect(')');
  ParseArgList := count;
End;

{ --------------------------------------------------------------------------
  ParseSysOutWrite : generer System.out.print / System.out.println.
  add_crlf = True pour println, False pour print.
  On vient de consommer 'System' '.' 'out' '.' 'println' (ou 'print').
  -------------------------------------------------------------------------- }
Function ParseSysOutWrite(add_crlf : Boolean) : TValueKind;
Var vt : TValueKind;
    t  : TToken;
Begin
  LexExpect('(');
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_PUNCT) And (t.val = ')') Then
  Begin
    LexNext;
    If add_crlf Then EmitI1('CALL', RT_PFX + 'WRITECRLF');
  End
  Else
  Begin
    vt := ParseExpr;
    LexExpect(')');
    Case vt Of
      VK_INT, VK_BOOL :
        Begin
          EmitI1('PUSH', 'AX');
          EmitI1('CALL', RT_PFX + 'WRITEINT');
          EmitI1('ADD',  'SP, 2');
        End;
      VK_CHAR :
        Begin
          EmitI('MOV',  'DL, AL', 'char a imprimer');
          EmitI1('MOV', 'AH, 02h');
          EmitI0('INT  21h');
        End;
      VK_STRING :
        Begin
          EmitI('MOV',  'CX, DX', 'len -> CX');
          EmitI1('CALL', RT_PFX + 'WRITESTR');
        End;
    Else
      ParseError('Type non supporte par System.out.print');
    End;
    If add_crlf Then EmitI1('CALL', RT_PFX + 'WRITECRLF');
  End;
  ParseSysOutWrite := VK_VOID;
End;

{ --------------------------------------------------------------------------
  ParseExprPrimary : niveau de precedence le plus eleve.
  Litteraux, identifiants, parentheses, new, System.out, scanner.
  -------------------------------------------------------------------------- }
Function ParseExprPrimary : TValueKind;
Var t      : TToken;
    t2     : TToken;
    idx    : Integer;
    fidx   : Integer;
    litidx : Integer;
    argc   : Integer;
    vt     : TValueKind;
Begin
  LexPeek; t := lex_peek_tok;

  { ----- Literal entier ----- }
  If t.kind = TK_INT Then
  Begin
    LexNext;
    EmitI1('MOV', 'AX, ' + IntToStr(t.int_val));
    ParseExprPrimary := VK_INT;
    Exit;
  End;

  { ----- Literal char ----- }
  If t.kind = TK_CHAR Then
  Begin
    LexNext;
    If Length(t.val) > 0 Then
      EmitI1('MOV', 'AX, ' + IntToStr(Ord(t.val[1])))
    Else
      EmitI1('MOV', 'AX, 0');
    ParseExprPrimary := VK_CHAR;
    Exit;
  End;

  { ----- Literal string ----- }
  If t.kind = TK_STRING Then
  Begin
    LexNext;
    litidx := AddLit(t.val);
    If litidx > 0 Then
    Begin
      EmitI1('MOV', 'AX, OFFSET ' + lit_table^[litidx].asm_data);
      EmitI1('MOV', 'DX, ' + IntToStr(lit_table^[litidx].len));
    End
    Else
    Begin
      EmitI1('MOV', 'AX, OFFSET _J_NULLSTR');
      EmitI0('XOR  DX, DX');
    End;
    ParseExprPrimary := VK_STRING;
    Exit;
  End;

  { ----- true / false / null ----- }
  If (t.kind = TK_KEYWORD) And (t.val = 'true') Then
  Begin
    LexNext;
    EmitI1('MOV', 'AX, 1');
    ParseExprPrimary := VK_BOOL;
    Exit;
  End;
  If (t.kind = TK_KEYWORD) And (t.val = 'false') Then
  Begin
    LexNext;
    EmitI0('XOR  AX, AX');
    ParseExprPrimary := VK_BOOL;
    Exit;
  End;
  If (t.kind = TK_KEYWORD) And (t.val = 'null') Then
  Begin
    LexNext;
    EmitI1('MOV', 'AX, OFFSET _J_NULLSTR');
    EmitI0('XOR  DX, DX');
    ParseExprPrimary := VK_STRING;
    Exit;
  End;

  { ----- this : non supporte dans contexte statique ----- }
  If (t.kind = TK_KEYWORD) And (t.val = 'this') Then
  Begin
    LexNext;
    ParseWarn('''this'' non supporte en contexte statique');
    EmitI0('XOR  AX, AX');
    ParseExprPrimary := VK_UNDEF;
    Exit;
  End;

  { ----- new type[N] : allocation tableau sur la pile ----- }
  If (t.kind = TK_KEYWORD) And (t.val = 'new') Then
  Begin
    LexNext;
    LexPeek; t := lex_peek_tok;
    If IsTypeKeyword(t) Then LexNext;
    LexExpect('[');
    ParseExpr;           { taille dans AX }
    LexExpect(']');
    { Convention : AX contient la taille, le caller alloue sur la pile }
    { Ici on renvoie simplement VK_ARRAY ; l'affectation gere la taille }
    ParseExprPrimary := VK_ARRAY;
    Exit;
  End;

  { ----- Parenthese ----- }
  If (t.kind = TK_PUNCT) And (t.val = '(') Then
  Begin
    LexNext;
    vt := ParseExpr;
    LexExpect(')');
    ParseExprPrimary := vt;
    Exit;
  End;

  { ----- Identifiant (variable, methode, System.out..., scanner...) ----- }
  If t.kind = TK_IDENT Then
  Begin
    LexNext;

    { System.out.println / print / printf }
    If t.val = 'System' Then
    Begin
      LexExpect('.');
      LexPeek; t2 := lex_peek_tok;
      If (t2.kind = TK_IDENT) And (t2.val = 'out') Then
      Begin
        LexNext;   { 'out' }
        LexExpect('.');
        LexPeek; t2 := lex_peek_tok;
        If t2.kind = TK_IDENT Then
        Begin
          LexNext;
          If t2.val = 'println' Then
            Begin ParseExprPrimary := ParseSysOutWrite(True); Exit; End
          Else If t2.val = 'print' Then
            Begin ParseExprPrimary := ParseSysOutWrite(False); Exit; End
          Else If t2.val = 'printf' Then
          Begin
            { printf(fmt) : sous-ensemble simple, traite comme print }
            ParseExprPrimary := ParseSysOutWrite(False);
            Exit;
          End
          Else
            ParseError('Membre System.out inconnu : ' + t2.val);
        End
        Else
          ParseError('Membre attendu apres System.out.');
      End
      Else If (t2.kind = TK_IDENT) And (t2.val = 'in') Then
      Begin
        { System.in est utilise dans new Scanner(System.in) -- ignore }
        LexNext;
        ParseExprPrimary := VK_UNDEF;
        Exit;
      End
      Else
        ParseError('Membre System inconnu : ' + t2.val);
      ParseExprPrimary := VK_VOID;
      Exit;
    End;

    { Appel de methode statique : ident '(' ... ')' }
    LexPeek; t2 := lex_peek_tok;
    If (t2.kind = TK_PUNCT) And (t2.val = '(') Then
    Begin
      fidx := FindMethod(class_name, t.val);
      If fidx = 0 Then fidx := FindFunc(t.val);
      If fidx = 0 Then
      Begin
        { Methode inconnue : tenter de parser les args pour avancer }
        ParseError('Methode inconnue : ' + t.val);
        LexExpect('(');
        LexPeek; t2 := lex_peek_tok;
        While Not ((t2.kind = TK_PUNCT) And (t2.val = ')')) And
              Not (t2.kind = TK_EOF) Do
        Begin
          LexNext;
          LexPeek; t2 := lex_peek_tok;
        End;
        LexExpect(')');
        ParseExprPrimary := VK_UNDEF;
        Exit;
      End;
      argc := ParseArgList;
      GenInlineCall(fidx, argc);
      ParseExprPrimary := func_table^[fidx].return_type;
      Exit;
    End;

    { Acces membre scanner.nextLine() / scanner.nextInt() }
    If (t2.kind = TK_PUNCT) And (t2.val = '.') Then
    Begin
      idx := FindSym(t.val);
      LexNext;   { '.' }
      LexPeek; t2 := lex_peek_tok;
      If t2.kind = TK_IDENT Then
      Begin
        LexNext;
        If t2.val = 'nextLine' Then
        Begin
          LexExpect('('); LexExpect(')');
          EmitI1('CALL', RT_PFX + 'READLINE');
          ParseExprPrimary := VK_STRING;
          Exit;
        End
        Else If t2.val = 'nextInt' Then
        Begin
          LexExpect('('); LexExpect(')');
          EmitI1('CALL', RT_PFX + 'READINT');
          ParseExprPrimary := VK_INT;
          Exit;
        End
        Else If t2.val = 'length' Then
        Begin
          { String.length() ou appel ident.length() }
          LexPeek; t2 := lex_peek_tok;
          If (t2.kind = TK_PUNCT) And (t2.val = '(') Then
          Begin
            LexExpect('('); LexExpect(')');
          End;
          If idx > 0 Then GenLoadVar(idx);
          EmitI('MOV', 'AX, DX', 'length() -> DX');
          ParseExprPrimary := VK_INT;
          Exit;
        End
        Else
        Begin
          ParseError('Membre inconnu : ' + t.val + '.' + t2.val);
          ParseExprPrimary := VK_UNDEF;
          Exit;
        End;
      End;
      ParseError('Ident attendu apres point');
      ParseExprPrimary := VK_UNDEF;
      Exit;
    End;

    { Variable / constante }
    idx := FindSym(t.val);
    If idx = 0 Then
      idx := FindField(class_name, t.val);
    If idx = 0 Then
    Begin
      ParseError('Symbole inconnu : ' + t.val);
      EmitI0('XOR  AX, AX');
      ParseExprPrimary := VK_INT;
      Exit;
    End;
    If sym_table^[idx].is_final Then
    Begin
      GenLoadConst(idx);
      ParseExprPrimary := sym_table^[idx].vtype;
    End
    Else
    Begin
      GenLoadVar(idx);
      ParseExprPrimary := sym_table^[idx].vtype;
    End;
    Exit;
  End;

  { Rien de reconnu }
  ParseError('Expression attendue, lu : ' + t.val);
  LexNext;
  EmitI0('XOR  AX, AX');
  ParseExprPrimary := VK_INT;
End;

{ --------------------------------------------------------------------------
  ParseExprPostfix : indexation [], .length, ++ --  (postfixe).
  -------------------------------------------------------------------------- }
Function ParseExprPostfix : TValueKind;
Var vt  : TValueKind;
    t   : TToken;
Begin
  vt := ParseExprPrimary;
  Repeat
    LexPeek; t := lex_peek_tok;

    { arr[index] }
    If (t.kind = TK_PUNCT) And (t.val = '[') Then
    Begin
      LexNext;
      EmitI1('PUSH', 'AX');
      ParseExpr;                { index dans AX }
      EmitI1('MOV', 'BX, AX');
      EmitI1('POP', 'SI');
      EmitI1('SHL', 'BX, 1');
      EmitI1('ADD', 'SI, BX');
      EmitI1('MOV', 'AX, [SI]');
      LexExpect(']');
      vt := VK_INT;
    End

    { .length (Java : minuscule) }
    Else If (t.kind = TK_PUNCT) And (t.val = '.') Then
    Begin
      LexNext;
      LexPeek; t := lex_peek_tok;
      If t.kind = TK_IDENT Then
      Begin
        LexNext;
        If t.val = 'length' Then
        Begin
          LexPeek; t := lex_peek_tok;
          If (t.kind = TK_PUNCT) And (t.val = '(') Then
          Begin
            LexExpect('('); LexExpect(')');
          End;
          EmitI('MOV', 'AX, DX', '.length');
          vt := VK_INT;
        End
        Else
          ParseError('Propriete inconnue : ' + t.val);
      End
      Else
        ParseError('Identificateur attendu apres point');
    End

    { x++ postfixe : renvoie la valeur avant incrementation }
    Else If (t.kind = TK_OP) And (t.val = '++') Then
    Begin
      LexNext;
      EmitI1('PUSH', 'AX');
      EmitI0('INC  AX');
      { Idealement on devrait stocker, mais sans connaitre l'adresse on ne peut pas ici }
      EmitI1('POP', 'AX');    { rendre la valeur originale }
    End

    { x-- postfixe }
    Else If (t.kind = TK_OP) And (t.val = '--') Then
    Begin
      LexNext;
      EmitI1('PUSH', 'AX');
      EmitI0('DEC  AX');
      EmitI1('POP', 'AX');
    End

    Else Break;
  Until False;
  ParseExprPostfix := vt;
End;

{ --------------------------------------------------------------------------
  ParseExprUnary : ! - + ++ -- (prefixe).
  -------------------------------------------------------------------------- }
Function ParseExprUnary : TValueKind;
Var t  : TToken;
    vt : TValueKind;
Begin
  LexPeek; t := lex_peek_tok;

  If (t.kind = TK_OP) And (t.val = '!') Then
  Begin
    LexNext;
    vt := ParseExprUnary;
    EmitI2('XOR', 'AX', '1');
    ParseExprUnary := VK_BOOL;
    Exit;
  End;

  If (t.kind = TK_OP) And (t.val = '-') Then
  Begin
    LexNext;
    vt := ParseExprUnary;
    EmitI0('NEG  AX');
    ParseExprUnary := VK_INT;
    Exit;
  End;

  If (t.kind = TK_OP) And (t.val = '+') Then
  Begin
    LexNext;
    vt := ParseExprUnary;
    ParseExprUnary := vt;
    Exit;
  End;

  If (t.kind = TK_OP) And (t.val = '++') Then
  Begin
    LexNext;
    vt := ParseExprPostfix;
    EmitI0('INC  AX');
    ParseExprUnary := vt;
    Exit;
  End;

  If (t.kind = TK_OP) And (t.val = '--') Then
  Begin
    LexNext;
    vt := ParseExprPostfix;
    EmitI0('DEC  AX');
    ParseExprUnary := vt;
    Exit;
  End;

  ParseExprUnary := ParseExprPostfix;
End;

{ --------------------------------------------------------------------------
  ParseExprMul : * / %
  -------------------------------------------------------------------------- }
Function ParseExprMul : TValueKind;
Var vt : TValueKind;
    t  : TToken;
    op : TString;
Begin
  vt := ParseExprUnary;
  Repeat
    LexPeek; t := lex_peek_tok;
    If Not ((t.kind = TK_OP) And
            ((t.val = '*') Or (t.val = '/') Or (t.val = '%'))) Then Break;
    op := t.val;
    LexNext;
    EmitI1('PUSH', 'AX');
    ParseExprUnary;
    EmitI('MOV', 'BX, AX', 'operande droit');
    EmitI1('POP', 'AX');
    If      op = '*' Then EmitI1('CALL', RT_PFX + 'IMUL')
    Else If op = '/' Then EmitI1('CALL', RT_PFX + 'IDIV')
    Else                  EmitI1('CALL', RT_PFX + 'IMOD');
    vt := VK_INT;
  Until False;
  ParseExprMul := vt;
End;

{ --------------------------------------------------------------------------
  ParseExprAdd : + -  (et concatenation de chaines si vt=VK_STRING)
  -------------------------------------------------------------------------- }
Function ParseExprAdd : TValueKind;
Var vt : TValueKind;
    t  : TToken;
    op : TString;
Begin
  vt := ParseExprMul;
  Repeat
    LexPeek; t := lex_peek_tok;
    If Not ((t.kind = TK_OP) And ((t.val = '+') Or (t.val = '-'))) Then Break;
    op := t.val;
    LexNext;
    If (vt = VK_STRING) And (op = '+') Then
    Begin
      { Concatenation : sauver AX=ptr1, DX=len1 }
      EmitI1('PUSH', 'DX');
      EmitI1('PUSH', 'AX');
      ParseExprMul;
      EmitI1('PUSH', 'DX');
      EmitI1('PUSH', 'AX');
      EmitI1('CALL', RT_PFX + 'STRCAT');
      EmitI1('ADD',  'SP, 8');
      vt := VK_STRING;
    End
    Else
    Begin
      EmitI1('PUSH', 'AX');
      ParseExprMul;
      EmitI1('MOV', 'BX, AX');
      EmitI1('POP', 'AX');
      If op = '+' Then EmitI2('ADD', 'AX', 'BX')
      Else             EmitI2('SUB', 'AX', 'BX');
      vt := VK_INT;
    End;
  Until False;
  ParseExprAdd := vt;
End;

{ --------------------------------------------------------------------------
  ParseExprRel : < <= > >=  instanceof
  Retourne VK_BOOL, resultat dans AX (1=vrai, 0=faux).
  -------------------------------------------------------------------------- }
Function ParseExprRel : TValueKind;
Var vt    : TValueKind;
    t     : TToken;
    op    : TString;
    lbl_t : TString;
    lbl_f : TString;
Begin
  vt := ParseExprAdd;
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_OP) And
     ((t.val = '<')  Or (t.val = '<=') Or
      (t.val = '>')  Or (t.val = '>=')) Then
  Begin
    op := t.val;
    LexNext;
    EmitI1('PUSH', 'AX');
    ParseExprAdd;
    EmitI1('MOV',  'BX, AX');
    EmitI1('POP',  'AX');
    EmitI2('CMP',  'AX', 'BX');
    lbl_t := NewLabel; lbl_f := NewLabel;
    If      op = '<'  Then EmitI1('JL',  lbl_t)
    Else If op = '<=' Then EmitI1('JLE', lbl_t)
    Else If op = '>'  Then EmitI1('JG',  lbl_t)
    Else                   EmitI1('JGE', lbl_t);
    EmitI0('XOR  AX, AX');
    EmitI1('JMP', lbl_f);
    EmitLabel(lbl_t);
    EmitI1('MOV', 'AX, 1');
    EmitLabel(lbl_f);
    vt := VK_BOOL;
  End
  Else If (t.kind = TK_KEYWORD) And (t.val = 'instanceof') Then
  Begin
    { instanceof : simplified - verifie seulement non-null (AX != 0) }
    LexNext;
    LexPeek; t := lex_peek_tok;
    If t.kind = TK_IDENT Then LexNext;  { consommer le nom de type }
    lbl_t := NewLabel; lbl_f := NewLabel;
    EmitI2('TEST', 'AX', 'AX');
    EmitI1('JNZ', lbl_t);
    EmitI0('XOR  AX, AX');
    EmitI1('JMP', lbl_f);
    EmitLabel(lbl_t);
    EmitI1('MOV', 'AX, 1');
    EmitLabel(lbl_f);
    vt := VK_BOOL;
  End;
  ParseExprRel := vt;
End;

{ --------------------------------------------------------------------------
  ParseExprEq : == !=
  -------------------------------------------------------------------------- }
Function ParseExprEq : TValueKind;
Var vt    : TValueKind;
    t     : TToken;
    op    : TString;
    lbl_t : TString;
    lbl_f : TString;
Begin
  vt := ParseExprRel;
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_OP) And ((t.val = '==') Or (t.val = '!=')) Then
  Begin
    op := t.val;
    LexNext;
    If vt = VK_STRING Then
    Begin
      { Comparaison de chaines via _JRT_STRCMP (ZF=1 si egal) }
      EmitI1('PUSH', 'DX');
      EmitI1('PUSH', 'AX');
      ParseExprRel;
      EmitI1('PUSH', 'DX');
      EmitI1('PUSH', 'AX');
      EmitI1('CALL', RT_PFX + 'STRCMP');
      EmitI1('ADD',  'SP, 8');
      lbl_t := NewLabel; lbl_f := NewLabel;
      If op = '==' Then EmitI1('JZ',  lbl_t) Else EmitI1('JNZ', lbl_t);
    End
    Else
    Begin
      EmitI1('PUSH', 'AX');
      ParseExprRel;
      EmitI1('MOV',  'BX, AX');
      EmitI1('POP',  'AX');
      EmitI2('CMP',  'AX', 'BX');
      lbl_t := NewLabel; lbl_f := NewLabel;
      If op = '==' Then EmitI1('JE',  lbl_t) Else EmitI1('JNE', lbl_t);
    End;
    EmitI0('XOR  AX, AX');
    EmitI1('JMP',  lbl_f);
    EmitLabel(lbl_t);
    EmitI1('MOV', 'AX, 1');
    EmitLabel(lbl_f);
    vt := VK_BOOL;
  End;
  ParseExprEq := vt;
End;

{ --------------------------------------------------------------------------
  ParseExprAnd2 : && avec court-circuit.
  (Nom And2 pour eviter conflit avec le Boolean And de Pascal.)
  -------------------------------------------------------------------------- }
Function ParseExprAnd2 : TValueKind;
Var vt    : TValueKind;
    t     : TToken;
    lbl_f : TString;
Begin
  vt := ParseExprEq;
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_OP) And (t.val = '&&') Then
  Begin
    lbl_f := NewLabel;
    EmitI2('TEST', 'AX', 'AX');
    EmitI1('JZ', lbl_f);
    Repeat
      LexNext;   { '&&' }
      ParseExprEq;
      EmitI2('TEST', 'AX', 'AX');
      EmitI1('JZ', lbl_f);
      LexPeek; t := lex_peek_tok;
    Until Not ((t.kind = TK_OP) And (t.val = '&&'));
    EmitI1('MOV', 'AX, 1');
    EmitLabel(lbl_f);
    vt := VK_BOOL;
  End;
  ParseExprAnd2 := vt;
End;

{ --------------------------------------------------------------------------
  ParseExprOr : || avec court-circuit.
  -------------------------------------------------------------------------- }
Function ParseExprOr : TValueKind;
Var vt    : TValueKind;
    t     : TToken;
    lbl_t : TString;
    lbl_e : TString;
Begin
  vt := ParseExprAnd2;
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_OP) And (t.val = '||') Then
  Begin
    lbl_t := NewLabel;
    lbl_e := NewLabel;
    EmitI2('TEST', 'AX', 'AX');
    EmitI1('JNZ', lbl_t);
    Repeat
      LexNext;   { '||' }
      ParseExprAnd2;
      EmitI2('TEST', 'AX', 'AX');
      EmitI1('JNZ', lbl_t);
      LexPeek; t := lex_peek_tok;
    Until Not ((t.kind = TK_OP) And (t.val = '||'));
    EmitI0('XOR  AX, AX');
    EmitI1('JMP', lbl_e);
    EmitLabel(lbl_t);
    EmitI1('MOV', 'AX, 1');
    EmitLabel(lbl_e);
    vt := VK_BOOL;
  End;
  ParseExprOr := vt;
End;

{ --------------------------------------------------------------------------
  ParseExprTernary : cond ? expr_vrai : expr_faux
  -------------------------------------------------------------------------- }
Function ParseExprTernary : TValueKind;
Var vt    : TValueKind;
    t     : TToken;
    lbl_f : TString;
    lbl_e : TString;
Begin
  vt := ParseExprOr;
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_OP) And (t.val = '?') Then
  Begin
    LexNext;   { '?' }
    lbl_f := NewLabel;
    lbl_e := NewLabel;
    EmitI2('TEST', 'AX', 'AX');
    EmitI1('JZ', lbl_f);
    vt := ParseExprOr;              { branche true  }
    EmitI1('JMP', lbl_e);
    EmitLabel(lbl_f);
    LexExpect(':');
    ParseExprOr;                    { branche false }
    EmitLabel(lbl_e);
    vt := VK_INT;                   { type commun simplifie }
  End;
  ParseExprTernary := vt;
End;

{ --------------------------------------------------------------------------
  ParseExpr : point d'entree (remplace le stub du TODO 07).
  Delegue a ParseExprTernary.
  -------------------------------------------------------------------------- }
Function ParseExpr : TValueKind;
Begin
  ParseExpr := ParseExprTernary;
End;

{ ============================================================================
  TODO 09 - PARSER : INSTRUCTIONS ET BLOCS
  ============================================================================ }

{ --------------------------------------------------------------------------
  ParseBlock : bloc Java avec accolades. Gere la portee.
  -------------------------------------------------------------------------- }
Procedure ParseBlock;
Var t : TToken;
Begin
  LexExpect('{');
  ScopeEnter;
  LexPeek; t := lex_peek_tok;
  While Not ((t.kind = TK_PUNCT) And (t.val = '}')) And
        Not (t.kind = TK_EOF) Do
  Begin
    ParseStatement;
    LexPeek; t := lex_peek_tok;
  End;
  LexExpect('}');
  ScopeLeave;
End;

{ --------------------------------------------------------------------------
  ParseIf : 'if (expr) stmt [else stmt]'
  -------------------------------------------------------------------------- }
Procedure ParseIf;
Var lbl_else : TString;
    lbl_end  : TString;
    t        : TToken;
Begin
  LexExpect('if');
  LexExpect('(');
  ParseExpr;
  LexExpect(')');
  lbl_else := NewLabel;
  lbl_end  := NewLabel;
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_else);
  ParseStatement;
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_KEYWORD) And (t.val = 'else') Then
  Begin
    EmitI1('JMP', lbl_end);
    EmitLabel(lbl_else);
    LexNext;
    ParseStatement;
    EmitLabel(lbl_end);
  End
  Else
    EmitLabel(lbl_else);
End;

{ --------------------------------------------------------------------------
  ParseWhile : 'while (expr) stmt'
  -------------------------------------------------------------------------- }
Procedure ParseWhile;
Var lbl_top : TString;
    lbl_end : TString;
Begin
  LexExpect('while');
  lbl_top := NewLabel;
  lbl_end := NewLabel;
  PushLoopLabels(lbl_end, lbl_top);
  EmitLabel(lbl_top);
  LexExpect('(');
  ParseExpr;
  LexExpect(')');
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_end);
  ParseStatement;
  EmitI1('JMP',  lbl_top);
  EmitLabel(lbl_end);
  PopLoopLabels;
End;

{ --------------------------------------------------------------------------
  ParseDoWhile : 'do stmt while (expr) ;'
  -------------------------------------------------------------------------- }
Procedure ParseDoWhile;
Var lbl_top  : TString;
    lbl_end  : TString;
    lbl_cond : TString;
Begin
  LexExpect('do');
  lbl_top  := NewLabel;
  lbl_end  := NewLabel;
  lbl_cond := NewLabel;
  PushLoopLabels(lbl_end, lbl_cond);
  EmitLabel(lbl_top);
  ParseStatement;
  EmitLabel(lbl_cond);
  LexExpect('while');
  LexExpect('(');
  ParseExpr;
  LexExpect(')');
  LexExpect(';');
  EmitI1('TEST', 'AX, AX');
  EmitI1('JNZ',  lbl_top);
  EmitLabel(lbl_end);
  PopLoopLabels;
End;

{ --------------------------------------------------------------------------
  ParseForEach : 'for (Type ident : expr) stmt'
  Supporte les tableaux d'entiers uniquement.
  Les 3 locaux internes (ptr, len, cnt) sont alloues dans la frame.
  -------------------------------------------------------------------------- }
Procedure ParseForEach;
Var lbl_top  : TString;
    lbl_end  : TString;
    vt       : TValueKind;
    is_arr   : Boolean;
    var_name : TString;
    iter_idx : Integer;
    ptr_idx  : Integer;
    len_idx  : Integer;
    cnt_idx  : Integer;
    t        : TToken;
Begin
  { 'for' et '(' deja consommes avant l'appel }
  lbl_top := NewLabel;
  lbl_end := NewLabel;
  ScopeEnter;

  { Type + ident (variable d'iteration) }
  If Not ParseTypeSpec(vt, is_arr) Then
  Begin
    ParseError('Type attendu dans for-each');
    SkipBlock;
    ScopeLeave;
    Exit;
  End;
  LexExpectKind(TK_IDENT); t := lex_cur_tok;
  var_name := t.val;

  { Allouer les locaux : variable iteration + ptr + len + compteur }
  iter_idx := AddLocalVar(var_name,  vt,     False, 0);
  ptr_idx  := AddLocalVar('_feptr',  VK_INT, False, 0);
  len_idx  := AddLocalVar('_felen',  VK_INT, False, 0);
  cnt_idx  := AddLocalVar('_fecnt',  VK_INT, False, 0);

  { ':' }
  LexExpect(':');

  { Evaluer l'expression tableau : AX = ptr, DX = len }
  ParseExpr;

  { Stocker ptr et len dans les locaux internes }
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(sym_table^[ptr_idx].bp_offset) + '], AX',
        'ptr tableau');
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(sym_table^[len_idx].bp_offset) + '], DX',
        'len tableau');
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(sym_table^[cnt_idx].bp_offset) + '], 0',
        'compteur = 0');

  LexExpect(')');

  PushLoopLabels(lbl_end, lbl_top);
  EmitLabel(lbl_top);

  { if cnt >= len : sortir }
  EmitI('MOV', 'AX, WORD PTR [BP' + IntToStr(sym_table^[cnt_idx].bp_offset) + ']',
        'charger compteur');
  EmitI('CMP', 'AX, WORD PTR [BP' + IntToStr(sym_table^[len_idx].bp_offset) + ']',
        'comparer avec len');
  EmitI1('JGE', lbl_end);

  { iter = arr[cnt] }
  EmitI('MOV', 'SI, WORD PTR [BP' + IntToStr(sym_table^[ptr_idx].bp_offset) + ']',
        'ptr tableau dans SI');
  EmitI('MOV', 'BX, WORD PTR [BP' + IntToStr(sym_table^[cnt_idx].bp_offset) + ']',
        'compteur dans BX');
  EmitI1('SHL', 'BX, 1');
  EmitI1('MOV', 'AX, [SI+BX]');
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(sym_table^[iter_idx].bp_offset) + '], AX',
        'iter = arr[cnt]');

  ParseStatement;

  { INC cnt ; JMP top }
  EmitI('INC', 'WORD PTR [BP' + IntToStr(sym_table^[cnt_idx].bp_offset) + ']',
        'incrementer compteur');
  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);

  PopLoopLabels;
  ScopeLeave;
End;

{ --------------------------------------------------------------------------
  ParseFor : 'for (init ; cond ; incr) stmt'
  Detecte aussi le for-each : 'for (Type ident : expr) stmt'
  -------------------------------------------------------------------------- }
Procedure ParseFor;
Var lbl_top  : TString;
    lbl_end  : TString;
    lbl_incr : TString;
    t        : TToken;
    t2       : TToken;
Begin
  LexExpect('for');
  LexExpect('(');

  { Detection for-each : commence par un mot-cle de type suivi d'ident puis ':' }
  LexPeek; t := lex_peek_tok;
  If IsTypeKeyword(t) Then
  Begin
    { Lire le type, puis l'ident, puis regarder si ':' suit }
    { On utilise une technique avec le peek : on doit lire 2 tokens en avance.
      Simplification : si le token est un type keyword on suppose for-each
      quand le 3eme token (apres type ident) est ':'.
      On ne peut pas lire 2 tokens en avance sans consommer.
      Solution : on suppose for-each si IsTypeKeyword et appel ParseForEach. }
    ParseForEach;
    Exit;
  End;

  lbl_top  := NewLabel;
  lbl_end  := NewLabel;
  lbl_incr := NewLabel;

  ScopeEnter;

  { --- Initialisation --- }
  LexPeek; t := lex_peek_tok;
  If Not ((t.kind = TK_PUNCT) And (t.val = ';')) Then
    ParseAssignOrExprStmt     { inclut le ';' final }
  Else
    LexNext;                  { ';' vide }

  EmitLabel(lbl_top);

  { --- Condition --- }
  LexPeek; t := lex_peek_tok;
  If Not ((t.kind = TK_PUNCT) And (t.val = ';')) Then
  Begin
    ParseExpr;
    EmitI1('TEST', 'AX, AX');
    EmitI1('JZ',   lbl_end);
  End;
  LexExpect(';');

  { Sauter directement au corps, puis revenir pour l'incrementation }
  EmitI1('JMP', lbl_incr + '_body');

  EmitLabel(lbl_incr);

  { --- Incrementation --- }
  LexPeek; t := lex_peek_tok;
  If Not ((t.kind = TK_PUNCT) And (t.val = ')')) Then
    ParseExpr;
  LexExpect(')');

  EmitI1('JMP', lbl_top);

  EmitLabel(lbl_incr + '_body');

  PushLoopLabels(lbl_end, lbl_incr);
  ParseStatement;
  PopLoopLabels;

  EmitI1('JMP', lbl_incr);
  EmitLabel(lbl_end);

  ScopeLeave;
End;

{ --------------------------------------------------------------------------
  ParseBreak : 'break ;'
  -------------------------------------------------------------------------- }
Procedure ParseBreak;
Begin
  LexExpect('break');
  LexExpect(';');
  If loop_depth = 0 Then
    ParseError('break en dehors d''une boucle')
  Else
    EmitI1('JMP', break_stack[loop_depth]);
End;

{ --------------------------------------------------------------------------
  ParseContinue : 'continue ;'
  -------------------------------------------------------------------------- }
Procedure ParseContinue;
Begin
  LexExpect('continue');
  LexExpect(';');
  If loop_depth = 0 Then
    ParseError('continue en dehors d''une boucle')
  Else
    EmitI1('JMP', continue_stack[loop_depth]);
End;

{ --------------------------------------------------------------------------
  ParseReturn : 'return [expr] ;'
  Charge la valeur dans AX, puis saute au label de retour de la methode.
  -------------------------------------------------------------------------- }
Procedure ParseReturn;
Var t  : TToken;
    vt : TValueKind;
    fi : Integer;
Begin
  LexExpect('return');
  fi := cur_func_idx;
  LexPeek; t := lex_peek_tok;
  If (t.kind = TK_PUNCT) And (t.val = ';') Then
    LexNext
  Else
  Begin
    vt := ParseExpr;
    LexExpect(';');
  End;
  If fi > 0 Then
    EmitI1('JMP', func_table^[fi].asm_label + '_ret')
  Else
    EmitI0('RET');
End;

{ --------------------------------------------------------------------------
  ParseAssignOrExprStmt : instruction d'expression.
  Formes supportees :
    ident = expr ;
    ident op= expr ;   (+=  -=  *=  /=  %=)
    ident++ ;
    ident-- ;
    ident [ expr ] = expr ;
    appel_de_methode ;
  -------------------------------------------------------------------------- }
Procedure ParseAssignOrExprStmt;
Var t   : TToken;
    t2  : TToken;
    idx : Integer;
    vt  : TValueKind;
    op  : TString;
Begin
  LexPeek; t := lex_peek_tok;

  If t.kind = TK_IDENT Then
  Begin
    idx := FindSym(t.val);
    If idx > 0 Then
    Begin
      LexNext;           { consommer l'ident }
      LexPeek; t2 := lex_peek_tok;

      { --- ident [ expr ] = expr ; --- }
      If (t2.kind = TK_PUNCT) And (t2.val = '[') Then
      Begin
        LexNext;         { '[' }
        ParseExpr;
        EmitI1('MOV', 'BX, AX');
        LexExpect(']');
        LexExpect('=');
        ParseExpr;
        GenStoreArrayElem(idx);
        LexExpect(';');
        Exit;
      End;

      { --- ident++ ; --- }
      If (t2.kind = TK_OP) And (t2.val = '++') Then
      Begin
        LexNext;
        GenLoadVar(idx);
        EmitI0('INC  AX');
        GenStoreVar(idx);
        LexExpect(';');
        Exit;
      End;

      { --- ident-- ; --- }
      If (t2.kind = TK_OP) And (t2.val = '--') Then
      Begin
        LexNext;
        GenLoadVar(idx);
        EmitI0('DEC  AX');
        GenStoreVar(idx);
        LexExpect(';');
        Exit;
      End;

      { --- ident = expr ; --- }
      If (t2.kind = TK_OP) And (t2.val = '=') Then
      Begin
        LexNext;
        ParseExpr;
        GenStoreVar(idx);
        LexExpect(';');
        Exit;
      End;

      { --- ident op= expr ; --- }
      If (t2.kind = TK_OP) And
         ((t2.val = '+=') Or (t2.val = '-=') Or
          (t2.val = '*=') Or (t2.val = '/=') Or (t2.val = '%=')) Then
      Begin
        op := t2.val;
        LexNext;
        GenLoadVar(idx);
        EmitI1('PUSH', 'AX');
        ParseExpr;
        EmitI1('MOV', 'BX, AX');
        EmitI1('POP', 'AX');
        If      op = '+=' Then EmitI1('ADD', 'AX, BX')
        Else If op = '-=' Then EmitI1('SUB', 'AX, BX')
        Else If op = '*=' Then EmitI1('CALL', RT_PFX + 'IMUL')
        Else If op = '/=' Then EmitI1('CALL', RT_PFX + 'IDIV')
        Else                   EmitI1('CALL', RT_PFX + 'IMOD');
        GenStoreVar(idx);
        LexExpect(';');
        Exit;
      End;

      { Pas une affectation : charger la variable et continuer comme expression }
      If sym_table^[idx].kind = SK_CONST Then
        GenLoadConst(idx)
      Else
        GenLoadVar(idx);
      vt := ParseExprPostfix;
      LexExpect(';');
      Exit;
    End;
  End;

  { Cas general : expression (appel System.out.*, etc.) }
  ParseExpr;
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseStatement : dispatcher principal.
  -------------------------------------------------------------------------- }
Procedure ParseStatement;
Var t : TToken;
Begin
  LexPeek; t := lex_peek_tok;

  { Bloc }
  If (t.kind = TK_PUNCT) And (t.val = '{') Then
  Begin
    ParseBlock;
    Exit;
  End;

  { if }
  If (t.kind = TK_KEYWORD) And (t.val = 'if') Then
  Begin
    ParseIf;
    Exit;
  End;

  { while }
  If (t.kind = TK_KEYWORD) And (t.val = 'while') Then
  Begin
    ParseWhile;
    Exit;
  End;

  { do }
  If (t.kind = TK_KEYWORD) And (t.val = 'do') Then
  Begin
    ParseDoWhile;
    Exit;
  End;

  { for }
  If (t.kind = TK_KEYWORD) And (t.val = 'for') Then
  Begin
    ParseFor;
    Exit;
  End;

  { break }
  If (t.kind = TK_KEYWORD) And (t.val = 'break') Then
  Begin
    ParseBreak;
    Exit;
  End;

  { continue }
  If (t.kind = TK_KEYWORD) And (t.val = 'continue') Then
  Begin
    ParseContinue;
    Exit;
  End;

  { return }
  If (t.kind = TK_KEYWORD) And (t.val = 'return') Then
  Begin
    ParseReturn;
    Exit;
  End;

  { Instruction vide }
  If (t.kind = TK_PUNCT) And (t.val = ';') Then
  Begin
    LexNext;
    Exit;
  End;

  { Declaration de variable locale }
  If IsTypeKeyword(t) Then
  Begin
    ParseVarDecl(False);
    Exit;
  End;

  { Affectation ou expression }
  ParseAssignOrExprStmt;
End;

{ ============================================================================
  TODO 10 - PARSER : METHODES ET CLASSES JAVA
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenFunctionPrologue : PUSH BP / MOV BP,SP / SUB SP, frame_size.
  Appele apres avoir emis le label de la methode.
  -------------------------------------------------------------------------- }
Procedure GenFunctionPrologue(fi : Integer);
Var fs : Integer;
Begin
  EmitI0('PUSH BP');
  EmitI('MOV', 'BP, SP', 'sauver frame pointer');
  fs := func_table^[fi].local_frame_size;
  If fs > 0 Then
    EmitI1('SUB', 'SP, ' + IntToStr(fs));
End;

{ --------------------------------------------------------------------------
  GenFunctionEpilogue : label de retour + MOV SP,BP / POP BP / RET.
  Le label '<asm_label>_ret' est la cible des 'return' internes.
  Le appelant nettoie la pile (near cdecl : ADD SP, param_bytes).
  -------------------------------------------------------------------------- }
Procedure GenFunctionEpilogue(fi : Integer);
Begin
  EmitLabel(func_table^[fi].asm_label + '_ret');
  EmitI('MOV', 'SP, BP', 'restaurer SP');
  EmitI0('POP  BP');
  EmitI0('RET');
End;

{ --------------------------------------------------------------------------
  ParseParamList(fi) : '(' type ident (','  type ident)* ')'
  Enregistre chaque parametre dans func_table^[fi].params et dans sym_table.
  -------------------------------------------------------------------------- }
Procedure ParseParamList(fi : Integer);
Var t      : TToken;
    vt     : TValueKind;
    is_arr : Boolean;
    pname  : TString;
Begin
  LexExpect('(');
  LexPeek; t := lex_peek_tok;

  { Zero parametre }
  If (t.kind = TK_PUNCT) And (t.val = ')') Then
  Begin
    LexNext;
    Exit;
  End;

  { Un ou plusieurs parametres }
  Repeat
    { Type (avec [] eventuel) }
    If Not ParseTypeSpec(vt, is_arr) Then
    Begin
      ParseError('Type attendu dans la liste de parametres');
      SkipToSemicolon;
      Exit;
    End;

    { Nom du parametre }
    LexExpectKind(TK_IDENT); t := lex_cur_tok;
    pname := t.val;
    AddParam(pname, vt, is_arr);

    { Suite : ',' ou ')' }
    LexPeek; t := lex_peek_tok;
    If (t.kind = TK_PUNCT) And (t.val = ',') Then
      LexNext
    Else If (t.kind = TK_PUNCT) And (t.val = ')') Then
      { ok - on sort }
    Else
    Begin
      ParseError('Virgule ou parenthese fermante attendue dans paramList');
      SkipToSemicolon;
      Exit;
    End;
    LexPeek; t := lex_peek_tok;
  Until (t.kind = TK_PUNCT) And (t.val = ')') Or (t.kind = TK_EOF);

  LexExpect(')');
End;

{ --------------------------------------------------------------------------
  DetectEntryPoint : chercher main() dans func_table et remplir first_instr_lbl.
  -------------------------------------------------------------------------- }
Procedure DetectEntryPoint;
Var i : Integer;
Begin
  For i := 1 To func_count Do
    If func_table^[i].is_main Then
    Begin
      first_instr_lbl := func_table^[i].asm_label;
      Exit;
    End;
  If first_instr_lbl = '' Then
    ParseWarn('Aucun point d''entree main() trouve');
End;

{ --------------------------------------------------------------------------
  ParseMethodDecl : [modifiers] rettype name (params) block
  Reconnat 'main' et le marque is_main.
  -------------------------------------------------------------------------- }
Procedure ParseMethodDecl;
Var vt      : TValueKind;
    is_arr  : Boolean;
    name    : TString;
    t       : TToken;
    fi      : Integer;
    old_fi  : Integer;
Begin
  { Consommer les modificateurs : public private protected static final abstract }
  ParseModifiers;

  { Type de retour }
  If Not ParseTypeSpec(vt, is_arr) Then
  Begin
    ParseError('Type de retour attendu dans declaration de methode');
    SkipToSemicolon;
    Exit;
  End;

  { Nom de la methode }
  LexExpectKind(TK_IDENT); t := lex_cur_tok;
  name := t.val;

  { Enregistrer dans func_table }
  fi := FindFunc(name);
  If fi = 0 Then
    fi := AddFunc(name, vt, True)
  Else
  Begin
    ParseWarn('Methode deja declaree : ' + name);
    func_table^[fi].return_type := vt;
  End;
  If fi = 0 Then Exit;

  old_fi       := cur_func_idx;
  cur_func_idx := fi;
  ResetLocals;

  { Parametres }
  ParseParamList(fi);

  { Corps }
  ScopeEnter;
  EmitBlank;
  EmitSep;
  EmitComment('Methode : ' + name);
  EmitSep;
  EmitLabel(func_table^[fi].asm_label);

  If func_table^[fi].is_main Then
    EmitI0('INIT_DS');

  GenFunctionPrologue(fi);

  LexPeek;
  If (lex_peek_tok.kind = TK_PUNCT) And (lex_peek_tok.val = '{') Then
    ParseBlock
  Else
  Begin
    ParseError('Accolade ouvrante attendue pour le corps de la methode');
    SkipToSemicolon;
  End;

  GenFunctionEpilogue(fi);

  If func_table^[fi].is_main Then
  Begin
    EmitBlank;
    EmitI0('EXIT_DOS');
  End;

  ScopeLeave;
  cur_func_idx := old_fi;
End;

{ --------------------------------------------------------------------------
  ParseClassBody : membres d'une classe Java.
  Accepte les champs (type ident [= expr] ;) et les methodes (type ident(...) bloc).
  Strategie : consommer modifiers + type + ident, puis discriminer sur '('.
  -------------------------------------------------------------------------- }
Procedure ParseClassBody;
Var t      : TToken;
    vt     : TValueKind;
    is_arr : Boolean;
    name   : TString;
    fi     : Integer;
    old_fi : Integer;
    idx    : Integer;
Begin
  LexPeek; t := lex_peek_tok;
  While Not ((t.kind = TK_PUNCT) And (t.val = '}')) And
        Not (t.kind = TK_EOF) Do
  Begin
    { Consommer les modificateurs Java : public private protected static final abstract }
    ParseModifiers;
    LexPeek; t := lex_peek_tok;

    If IsTypeKeyword(t) Then
    Begin
      { Lire le type (avec [] eventuel) }
      If Not ParseTypeSpec(vt, is_arr) Then
      Begin
        ParseError('Type attendu dans corps de classe');
        SkipToSemicolon;
        LexPeek; t := lex_peek_tok;
      End
      Else
      Begin
        { Lire l'identifiant }
        LexExpectKind(TK_IDENT); t := lex_cur_tok;
        name := t.val;

        { Discriminer selon le token suivant }
        LexPeek; t := lex_peek_tok;
        If (t.kind = TK_PUNCT) And (t.val = '(') Then
        Begin
          { --- Methode --- }
          fi := FindFunc(name);
          If fi = 0 Then
            fi := AddFunc(name, vt, True)
          Else
          Begin
            ParseWarn('Methode deja declaree : ' + name);
            func_table^[fi].return_type := vt;
          End;
          If fi > 0 Then
          Begin
            old_fi       := cur_func_idx;
            cur_func_idx := fi;
            ResetLocals;
            ParseParamList(fi);
            ScopeEnter;
            EmitBlank;
            EmitSep;
            EmitComment('Methode : ' + name);
            EmitSep;
            EmitLabel(func_table^[fi].asm_label);
            If func_table^[fi].is_main Then
              EmitI0('INIT_DS');
            GenFunctionPrologue(fi);
            LexPeek;
            If (lex_peek_tok.kind = TK_PUNCT) And (lex_peek_tok.val = '{') Then
              ParseBlock
            Else
            Begin
              ParseError('Accolade ouvrante attendue pour le corps de la methode');
              SkipToSemicolon;
            End;
            GenFunctionEpilogue(fi);
            If func_table^[fi].is_main Then
            Begin
              EmitBlank;
              EmitI0('EXIT_DOS');
            End;
            ScopeLeave;
            cur_func_idx := old_fi;
          End;
        End
        Else
        Begin
          { --- Champ statique : type ident [= constexpr] ; --- }
          idx := AddField(name, vt, is_arr, 0);
          LexPeek; t := lex_peek_tok;
          If (t.kind = TK_OP) And (t.val = '=') Then
          Begin
            LexNext;
            If idx > 0 Then
              sym_table^[idx].const_val := ParseConstIntExpr
            Else
              ParseConstIntExpr;
          End;
          LexExpect(';');
        End;
        LexPeek; t := lex_peek_tok;
      End;
    End
    Else
    Begin
      ParseError('Type attendu dans corps de classe (token : ' + t.val + ')');
      LexNext;
      LexPeek; t := lex_peek_tok;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseClassDecl : class Ident  classBody
  -------------------------------------------------------------------------- }
Procedure ParseClassDecl;
Var t : TToken;
Begin
  LexExpect('class');
  LexExpectKind(TK_IDENT); t := lex_cur_tok;
  class_name := t.val;
  EmitComment('Classe : ' + class_name);
  { Heritage eventuel : extends Base ou implements I -> ignore }
  LexPeek; t := lex_peek_tok;
  While (t.kind = TK_KEYWORD) And
        ((t.val = 'extends') Or (t.val = 'implements')) Do
  Begin
    LexNext;
    LexNext;   { nom de la super-classe / interface }
    LexPeek; t := lex_peek_tok;
  End;
  LexExpect('{');
  ParseClassBody;
  LexExpect('}');
  class_name := '';
End;

{ --------------------------------------------------------------------------
  ParseProgram : point d'entree du parseur Java.
  package?  import*  class+
  -------------------------------------------------------------------------- }
Procedure ParseProgram;
Var t : TToken;
Begin
  ParsePackageAndImports;

  { Une ou plusieurs classes }
  LexPeek; t := lex_peek_tok;
  While Not (t.kind = TK_EOF) Do
  Begin
    { Sauter les modificateurs de niveau superieur }
    While (t.kind = TK_KEYWORD) And
          ((t.val = 'public')   Or (t.val = 'abstract') Or
           (t.val = 'final')    Or (t.val = 'private')  Or
           (t.val = 'static'))  Do
    Begin
      LexNext;
      LexPeek; t := lex_peek_tok;
    End;
    If (t.kind = TK_KEYWORD) And (t.val = 'class') Then
      ParseClassDecl
    Else If t.kind = TK_EOF Then
      { fin normale }
    Else
    Begin
      ParseError('Mot-cle ''class'' attendu (token : ' + t.val + ')');
      LexNext;
    End;
    LexPeek; t := lex_peek_tok;
  End;

  DetectEntryPoint;
End;

{ ============================================================================
  TODO 11 - CODEGEN : EXPRESSIONS ENTIERES, BOOLEENNES ET CHAR
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenIntLiteral : emettre MOV AX, val (litteral entier immediat).
  -------------------------------------------------------------------------- }
Procedure GenIntLiteral(val : LongInt);
Begin
  EmitI1('MOV', 'AX, ' + IntToStr(val));
End;

{ --------------------------------------------------------------------------
  GenLongLiteral : charger un long 32 bits dans AX (lo) + DX (hi).
  -------------------------------------------------------------------------- }
Procedure GenLongLiteral(val : LongInt);
Var lo, hi : Integer;
Begin
  lo := Integer(val And $FFFF);
  hi := Integer((val Shr 16) And $FFFF);
  EmitI('MOV', 'AX, ' + IntToStr(lo), 'long lo');
  EmitI('MOV', 'DX, ' + IntToStr(hi), 'long hi');
End;

{ --------------------------------------------------------------------------
  GenBoolLiteral : emettre MOV AX, 1 (true) ou XOR AX, AX (false).
  -------------------------------------------------------------------------- }
Procedure GenBoolLiteral(val : Boolean);
Begin
  If val Then
    EmitI1('MOV', 'AX, 1')
  Else
    EmitI0('XOR  AX, AX');
End;

{ --------------------------------------------------------------------------
  GenCharLiteral : emettre MOV AX, ord(c) pour un caractere.
  -------------------------------------------------------------------------- }
Procedure GenCharLiteral(val : Integer);
Begin
  EmitI1('MOV', 'AX, ' + IntToStr(val));
End;

{ --------------------------------------------------------------------------
  GenNullLiteral : emettre XOR AX, AX (pointeur null = 0).
  -------------------------------------------------------------------------- }
Procedure GenNullLiteral;
Begin
  EmitI0('XOR  AX, AX');
End;

{ --------------------------------------------------------------------------
  GenAdd : ADD AX, BX   (left = AX, right = BX, resultat dans AX).
  -------------------------------------------------------------------------- }
Procedure GenAdd;
Begin
  EmitI1('ADD', 'AX, BX');
End;

{ --------------------------------------------------------------------------
  GenSub : SUB AX, BX   (left = AX, right = BX, resultat dans AX).
  -------------------------------------------------------------------------- }
Procedure GenSub;
Begin
  EmitI1('SUB', 'AX, BX');
End;

{ --------------------------------------------------------------------------
  GenMul : multiplication signee via runtime : CALL _JRT_IMUL.
  Convention : AX = gauche, BX = droite, resultat dans AX.
  -------------------------------------------------------------------------- }
Procedure GenMul;
Begin
  EmitI1('CALL', RT_PFX + 'IMUL');
End;

{ --------------------------------------------------------------------------
  GenDiv : division signee via runtime : CALL _JRT_IDIV.
  Convention : AX = dividende, BX = diviseur, quotient dans AX.
  -------------------------------------------------------------------------- }
Procedure GenDiv;
Begin
  EmitI1('CALL', RT_PFX + 'IDIV');
End;

{ --------------------------------------------------------------------------
  GenMod : modulo signe via runtime : CALL _JRT_IMOD.
  Convention : AX = dividende, BX = diviseur, reste dans AX.
  -------------------------------------------------------------------------- }
Procedure GenMod;
Begin
  EmitI1('CALL', RT_PFX + 'IMOD');
End;

{ --------------------------------------------------------------------------
  GenNeg : negation arithmetique : NEG AX.
  -------------------------------------------------------------------------- }
Procedure GenNeg;
Begin
  EmitI0('NEG  AX');
End;

{ --------------------------------------------------------------------------
  GenNot : NOT logique 8086 (equivalent de SETE pour 8086 pur).
  AX = 0 -> AX = 1 ;  AX != 0 -> AX = 0.
  -------------------------------------------------------------------------- }
Procedure GenNot;
Var lbl_nz, lbl_end : TString;
Begin
  lbl_nz  := NewLabel;
  lbl_end := NewLabel;
  EmitI1('TEST', 'AX, AX');
  EmitI1('JNZ',  lbl_nz);
  EmitI1('MOV',  'AX, 1');
  EmitI1('JMP',  lbl_end);
  EmitLabel(lbl_nz);
  EmitI0('XOR  AX, AX');
  EmitLabel(lbl_end);
End;

{ --------------------------------------------------------------------------
  GenCmp : comparaison signee AX op BX -> AX = 0 ou 1.
  Operateurs : ==  !=  <  <=  >  >=
  Convention : operande gauche dans AX, droite dans BX (apres POP).
  -------------------------------------------------------------------------- }
Procedure GenCmp(Const op : TString);
Var lbl_t, lbl_f : TString;
Begin
  lbl_t := NewLabel;
  lbl_f := NewLabel;
  EmitI1('CMP', 'AX, BX');
  If      op = '==' Then EmitI1('JE',  lbl_t)
  Else If op = '!=' Then EmitI1('JNE', lbl_t)
  Else If op = '<'  Then EmitI1('JL',  lbl_t)
  Else If op = '<=' Then EmitI1('JLE', lbl_t)
  Else If op = '>'  Then EmitI1('JG',  lbl_t)
  Else If op = '>=' Then EmitI1('JGE', lbl_t)
  Else ParseError('Operateur de comparaison inconnu : ' + op);
  EmitI0('XOR  AX, AX');
  EmitI1('JMP', lbl_f);
  EmitLabel(lbl_t);
  EmitI1('MOV', 'AX, 1');
  EmitLabel(lbl_f);
End;

{ --------------------------------------------------------------------------
  GenLogicAndTest : court-circuit && : TESt AX,AX + JZ lbl_false.
  Appele apres evaluation de l'operande gauche.
  Si AX=0, sauter directement a lbl_false (resultat global = false).
  -------------------------------------------------------------------------- }
Procedure GenLogicAndTest(Const lbl_false : TString);
Begin
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_false);
End;

{ --------------------------------------------------------------------------
  GenLogicOrTest : court-circuit || : TEST AX,AX + JNZ lbl_true.
  Appele apres evaluation de l'operande gauche.
  Si AX<>0, sauter directement a lbl_true (resultat global = true).
  -------------------------------------------------------------------------- }
Procedure GenLogicOrTest(Const lbl_true : TString);
Begin
  EmitI1('TEST', 'AX, AX');
  EmitI1('JNZ',  lbl_true);
End;

{ --------------------------------------------------------------------------
  GenCastIntToChar : troncature vers char : AND AX, 00FFh.
  -------------------------------------------------------------------------- }
Procedure GenCastIntToChar;
Begin
  EmitI1('AND', 'AX, 00FFh');
End;

{ --------------------------------------------------------------------------
  GenCastIntToBool : normaliser AX vers 0 ou 1.
  AX = 0 -> reste 0 ; AX <> 0 -> AX = 1.
  -------------------------------------------------------------------------- }
Procedure GenCastIntToBool;
Var lbl_done : TString;
Begin
  lbl_done := NewLabel;
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_done);
  EmitI1('MOV',  'AX, 1');
  EmitLabel(lbl_done);
End;

{ ============================================================================
  TODO 12 - CODEGEN : ACCES AUX VARIABLES JAVA (COMPLEMENT)
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenLoadField : charger un champ statique (SC_FIELD) dans AX (ou AX+DX).
  Alias semantique de GenLoadVar pour les champs de classe.
  -------------------------------------------------------------------------- }
Procedure GenLoadField(idx : Integer);
Begin
  GenLoadVar(idx);
End;

{ --------------------------------------------------------------------------
  GenStoreField : stocker AX (ou AX+DX) dans un champ statique (SC_FIELD).
  Alias semantique de GenStoreVar pour les champs de classe.
  -------------------------------------------------------------------------- }
Procedure GenStoreField(idx : Integer);
Begin
  GenStoreVar(idx);
End;

{ --------------------------------------------------------------------------
  GenAddrOf : charger dans SI l'adresse effective de la variable idx.
  Utile pour les tableaux et les passages par reference.
  -------------------------------------------------------------------------- }
Procedure GenAddrOf(idx : Integer);
Var lbl : TString;
    ofs : Integer;
    sc  : TScope;
Begin
  lbl := sym_table^[idx].asm_label;
  ofs := sym_table^[idx].bp_offset;
  sc  := sym_table^[idx].scope;
  Case sc Of
    SC_GLOBAL, SC_FIELD :
      EmitI('LEA', 'SI, [' + lbl + ']', 'adresse effective globale');
    SC_LOCAL :
      EmitI('LEA', 'SI, [BP' + IntToStr(ofs) + ']', 'adresse effective locale');
    SC_PARAM :
      EmitI('LEA', 'SI, [BP+' + IntToStr(ofs) + ']', 'adresse effective param');
  End;
End;

{ --------------------------------------------------------------------------
  GenArrayLength : charger la longueur statique du tableau idx dans AX.
  La taille est connue a la compilation et stockee dans arr_size.
  -------------------------------------------------------------------------- }
Procedure GenArrayLength(idx : Integer);
Begin
  EmitI('MOV', 'AX, ' + IntToStr(sym_table^[idx].arr_size),
        'longueur tableau ' + sym_table^[idx].name);
End;

{ --------------------------------------------------------------------------
  GenBoundsCheck : verifier 0 <= BX < arr_size.
  Si l index est hors bornes, saute au label d erreur runtime.
  La routine _JRT_BOUNDS_ERR est appelee si elle existe.
  -------------------------------------------------------------------------- }
Procedure GenBoundsCheck(idx : Integer);
Var n   : Integer;
Begin
  n := sym_table^[idx].arr_size;
  If n <= 0 Then Exit;
  { Borne basse : BX >= 0 }
  EmitI1('TEST', 'BX, BX');
  EmitI1('JL',   RT_PFX + 'BOUNDS_ERR');
  { Borne haute : BX < n }
  EmitI1('CMP',  'BX, ' + IntToStr(n));
  EmitI1('JGE',  RT_PFX + 'BOUNDS_ERR');
End;

{ ============================================================================
  TODO 13 - CODEGEN : AFFECTATION ET INCREMENTATION/DECREMENTATION
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenAssign : stocker AX (ou AX+DX pour String) dans la variable idx.
  Alias semantique de GenStoreVar.
  -------------------------------------------------------------------------- }
Procedure GenAssign(idx : Integer);
Begin
  GenStoreVar(idx);
End;

{ --------------------------------------------------------------------------
  GenAssignOp : affectation composee  var  op=  expr.
  Convention a l'appel : valeur droite (RHS) dans AX.
  La fonction charge la valeur courante, applique l'operateur, stocke.
  -------------------------------------------------------------------------- }
Procedure GenAssignOp(idx : Integer; Const op : TString);
Begin
  EmitI('MOV', 'BX, AX', 'sauver RHS dans BX');
  GenLoadVar(idx);
  If      op = '+=' Then EmitI1('ADD', 'AX, BX')
  Else If op = '-=' Then EmitI1('SUB', 'AX, BX')
  Else If op = '*=' Then EmitI1('CALL', RT_PFX + 'IMUL')
  Else If op = '/=' Then EmitI1('CALL', RT_PFX + 'IDIV')
  Else If op = '%=' Then EmitI1('CALL', RT_PFX + 'IMOD')
  Else ParseError('Operateur compose inconnu : ' + op);
  GenStoreVar(idx);
End;

{ --------------------------------------------------------------------------
  GenIncDec : incrementation ou decrementation ++/-- d'une variable.
  is_inc  : True pour ++, False pour --.
  is_pre  : True pour prefixe (++i), False pour postfixe (i++).
  Prefix  : modifier var, laisser la nouvelle valeur dans AX.
  Postfix : laisser l'ancienne valeur dans AX, puis modifier var.
  -------------------------------------------------------------------------- }
Procedure GenIncDec(idx : Integer; is_inc : Boolean; is_pre : Boolean);
Begin
  GenLoadVar(idx);             { AX = valeur courante }
  If Not is_pre Then
    EmitI1('PUSH', 'AX');     { postfix : sauver ancienne valeur }
  If is_inc Then
    EmitI0('INC  AX')
  Else
    EmitI0('DEC  AX');
  GenStoreVar(idx);            { stocker nouvelle valeur }
  If Not is_pre Then
    EmitI1('POP', 'AX');      { postfix : restaurer ancienne valeur dans AX }
End;

{ --------------------------------------------------------------------------
  GenAssignArray : stocker AX dans arr[BX].
  Precondition : index dans BX (non multiplie), valeur a stocker dans AX.
  Alias de GenStoreArrayElem.
  -------------------------------------------------------------------------- }
Procedure GenAssignArray(idx : Integer);
Begin
  GenStoreArrayElem(idx);
End;

{ --------------------------------------------------------------------------
  GenAssignStringCat : concatenation de chaines et affectation.
  Convention : les deux chaines ont ete poussees sur la pile avant l'appel
  sous la forme PUSH DX / PUSH AX pour chaque chaine (4 mots au total).
  Apres STRCAT, le resultat (AX=ptr, DX=len) est stocke dans idx.
  -------------------------------------------------------------------------- }
Procedure GenAssignStringCat(dst_idx : Integer);
Begin
  EmitI1('CALL', RT_PFX + 'STRCAT');
  EmitI1('ADD',  'SP, 8');
  GenStoreVar(dst_idx);
End;

{ ============================================================================
  TODO 14 - CODEGEN : STRUCTURES DE CONTROLE
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenLabelHere : emettre un label a la position courante.
  -------------------------------------------------------------------------- }
Procedure GenLabelHere(Const lbl : TString);
Begin
  EmitLabel(lbl);
End;

{ ---- IF ------------------------------------------------------------------ }

Procedure GenIfStart(Const lbl_else : TString);
Begin
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_else);
End;

Procedure GenIfElseJump(Const lbl_end : TString);
Begin
  EmitI1('JMP', lbl_end);
End;

{ ---- WHILE --------------------------------------------------------------- }

Procedure GenWhileTop(Const lbl_top : TString);
Begin
  EmitLabel(lbl_top);
End;

Procedure GenWhileCond(Const lbl_end : TString);
Begin
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_end);
End;

Procedure GenWhileBack(Const lbl_top : TString);
Begin
  EmitI1('JMP', lbl_top);
End;

Procedure GenWhileEnd(Const lbl_end : TString);
Begin
  EmitLabel(lbl_end);
End;

{ ---- DO-WHILE ------------------------------------------------------------ }

Procedure GenDoWhileTop(Const lbl_top : TString);
Begin
  EmitLabel(lbl_top);
End;

Procedure GenDoWhileCond(Const lbl_top : TString);
Begin
  EmitI1('TEST', 'AX, AX');
  EmitI1('JNZ',  lbl_top);
End;

{ ---- FOR ----------------------------------------------------------------- }
{ Sequence de labels : top / cond / incr / end.                              }
{ Le parseur emet : init ;  [top]  cond  JZ end  JMP body  [incr]  JMP top  }
{ [body]  JMP incr  [end]                                                    }

Procedure GenForTop(Const lbl_top : TString);
Begin
  EmitLabel(lbl_top);
End;

Procedure GenForCond(Const lbl_end : TString);
Begin
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_end);
End;

Procedure GenForBodyJump(Const lbl_body : TString);
Begin
  EmitI1('JMP', lbl_body);
End;

Procedure GenForIncrTop(Const lbl_incr : TString);
Begin
  EmitLabel(lbl_incr);
End;

Procedure GenForIncrBack(Const lbl_top : TString);
Begin
  EmitI1('JMP', lbl_top);
End;

Procedure GenForBodyTop(Const lbl_body : TString);
Begin
  EmitLabel(lbl_body);
End;

Procedure GenForEnd(Const lbl_end : TString);
Begin
  EmitLabel(lbl_end);
End;

{ ---- FOR-EACH ------------------------------------------------------------ }
{ GenForEachInit : stocker ptr et len du tableau, initialiser le compteur.   }
{ ptr_ofs / len_ofs / cnt_ofs : offsets BP des locaux internes (negatifs).  }
{ Convention entree : AX = ptr tableau, DX = longueur.                       }

Procedure GenForEachInit(ptr_ofs, len_ofs, cnt_ofs : Integer;
                         Const lbl_top, lbl_end : TString);
Begin
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(ptr_ofs) + '], AX', 'ptr tableau');
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(len_ofs) + '], DX', 'len tableau');
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(cnt_ofs) + '], 0',  'compteur = 0');
  EmitLabel(lbl_top);
  EmitI('MOV', 'AX, WORD PTR [BP' + IntToStr(cnt_ofs) + ']', 'compteur');
  EmitI('CMP', 'AX, WORD PTR [BP' + IntToStr(len_ofs) + ']', 'vs longueur');
  EmitI1('JGE', lbl_end);
End;

{ GenForEachLoad : charger arr[cnt] dans la variable d'iteration.            }
{ iter_ofs : offset BP de la variable iteration; ptr_ofs / cnt_ofs : locaux }

Procedure GenForEachLoad(iter_ofs, ptr_ofs, cnt_ofs : Integer);
Begin
  EmitI('MOV', 'SI, WORD PTR [BP' + IntToStr(ptr_ofs) + ']', 'ptr tableau');
  EmitI('MOV', 'BX, WORD PTR [BP' + IntToStr(cnt_ofs) + ']', 'index');
  EmitI1('SHL', 'BX, 1');
  EmitI1('MOV', 'AX, [SI+BX]');
  EmitI('MOV', 'WORD PTR [BP' + IntToStr(iter_ofs) + '], AX', 'iter = arr[i]');
End;

{ GenForEachStep : incrementer le compteur et reboucler.                     }

Procedure GenForEachStep(cnt_ofs : Integer; Const lbl_top, lbl_end : TString);
Begin
  EmitI('INC', 'WORD PTR [BP' + IntToStr(cnt_ofs) + ']', 'incrementer compteur');
  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);
End;

{ ---- BREAK / CONTINUE / RETURN ------------------------------------------ }

Procedure GenBreak;
Begin
  If loop_depth = 0 Then
    ParseError('break en dehors d''une boucle')
  Else
    EmitI1('JMP', break_stack[loop_depth]);
End;

Procedure GenContinue;
Begin
  If loop_depth = 0 Then
    ParseError('continue en dehors d''une boucle')
  Else
    EmitI1('JMP', continue_stack[loop_depth]);
End;

Procedure GenReturn(fi : Integer; has_val : Boolean);
Begin
  { La valeur de retour est deja dans AX (et DX pour String) si has_val }
  If fi > 0 Then
    EmitI1('JMP', func_table^[fi].asm_label + '_ret')
  Else
    EmitI0('RET');
End;

{ ---- OPERATEUR TERNAIRE -------------------------------------------------- }
{ Forme : cond ? expr_true : expr_false                                       }
{ Sequence : evaluer cond -> GenTernaryStart -> expr_true ->                  }
{            GenTernaryMiddle -> expr_false -> GenTernaryEnd                  }

Procedure GenTernaryStart(Const lbl_false : TString);
Begin
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_false);
End;

Procedure GenTernaryMiddle(Const lbl_end, lbl_false : TString);
Begin
  EmitI1('JMP', lbl_end);
  EmitLabel(lbl_false);
End;

Procedure GenTernaryEnd(Const lbl_end : TString);
Begin
  EmitLabel(lbl_end);
End;

{ ============================================================================
  TODO 15 - CODEGEN : ENTREES / SORTIES (System.out / Scanner)
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenWriteCRLF : emettre un saut de ligne via la routine runtime.
  -------------------------------------------------------------------------- }
Procedure GenWriteCRLF;
Begin
  EmitI1('CALL', RT_PFX + 'WRITECRLF');
End;

{ --------------------------------------------------------------------------
  GenWriteInt : afficher l'entier dans AX.
  Convention : PUSH AX / CALL _JRT_WRITEINT / ADD SP, 2.
  Si add_lf=True : ajouter un saut de ligne.
  -------------------------------------------------------------------------- }
Procedure GenWriteInt(add_lf : Boolean);
Begin
  EmitI1('PUSH', 'AX');
  EmitI1('CALL', RT_PFX + 'WRITEINT');
  EmitI1('ADD',  'SP, 2');
  If add_lf Then GenWriteCRLF;
End;

{ --------------------------------------------------------------------------
  GenWriteBool : afficher un booleen (AX = 0 ou 1).
  Passe par BOOL2STR pour obtenir "true"/"false" puis WRITESTR.
  -------------------------------------------------------------------------- }
Procedure GenWriteBool(add_lf : Boolean);
Begin
  EmitI1('PUSH', 'AX');
  EmitI1('CALL', RT_PFX + 'WRITEBOOL');
  EmitI1('ADD',  'SP, 2');
  If add_lf Then GenWriteCRLF;
End;

{ --------------------------------------------------------------------------
  GenWriteChar : afficher le caractere dans AL via INT 21h AH=02h.
  -------------------------------------------------------------------------- }
Procedure GenWriteChar(add_lf : Boolean);
Begin
  EmitI('MOV',  'DL, AL', 'char a imprimer');
  EmitI1('MOV', 'AH, 02h');
  EmitI0('INT  21h');
  If add_lf Then GenWriteCRLF;
End;

{ --------------------------------------------------------------------------
  GenWriteString : afficher la chaine AX=ptr, DX=len via _JRT_WRITESTR.
  Convention : MOV CX, DX (len) / AX = ptr / CALL _JRT_WRITESTR.
  -------------------------------------------------------------------------- }
Procedure GenWriteString(add_lf : Boolean);
Begin
  EmitI('MOV',  'CX, DX', 'len -> CX');
  EmitI1('CALL', RT_PFX + 'WRITESTR');
  If add_lf Then GenWriteCRLF;
End;

{ --------------------------------------------------------------------------
  GenWriteStrLit : afficher un litteral de chaine par son label ASM.
  Les litteraux sont stockes null-termines ; on passe AX=ptr et CX=len
  a _JRT_WRITESTR (len connu a la compilation).
  -------------------------------------------------------------------------- }
Procedure GenWriteStrLit(Const lbl : TString; len : Integer; add_lf : Boolean);
Begin
  EmitI1('LEA',  'AX, [' + lbl + ']');
  EmitI1('MOV',  'CX, ' + IntToStr(len));
  EmitI1('CALL', RT_PFX + 'WRITESTR');
  If add_lf Then GenWriteCRLF;
End;

{ --------------------------------------------------------------------------
  GenReadLine : lire une ligne depuis stdin via _JRT_READLINE.
  Resultat : AX = ptr, DX = longueur.
  -------------------------------------------------------------------------- }
Procedure GenReadLine;
Begin
  EmitI1('CALL', RT_PFX + 'READLINE');
End;

{ --------------------------------------------------------------------------
  GenReadInt : lire un entier depuis stdin via _JRT_READINT.
  Resultat : AX = valeur entiere.
  -------------------------------------------------------------------------- }
Procedure GenReadInt;
Begin
  EmitI1('CALL', RT_PFX + 'READINT');
End;

{ ============================================================================
  TODO 16 - CODEGEN : CHAINES ET CONCATENATION
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenStrLoadLit : charger un litteral de chaine : AX = OFFSET lbl, DX = len.
  -------------------------------------------------------------------------- }
Procedure GenStrLoadLit(Const lbl : TString; len : Integer);
Begin
  EmitI1('MOV', 'AX, OFFSET ' + lbl);
  EmitI1('MOV', 'DX, ' + IntToStr(len));
End;

{ --------------------------------------------------------------------------
  GenStrLoadVar : charger une variable String dans AX=ptr, DX=len.
  Simple alias de GenLoadVar (qui gere deja VK_STRING).
  -------------------------------------------------------------------------- }
Procedure GenStrLoadVar(idx : Integer);
Begin
  GenLoadVar(idx);
End;

{ --------------------------------------------------------------------------
  GenStrCat : appeler _JRT_STRCAT.
  Pre-condition : les 4 mots (PUSH DX / PUSH AX pour chaque chaine) sont
  deja sur la pile.  Resultat : AX=ptr, DX=len du resultat concatene.
  -------------------------------------------------------------------------- }
Procedure GenStrCat;
Begin
  EmitI1('CALL', RT_PFX + 'STRCAT');
  EmitI1('ADD',  'SP, 8');
End;

{ --------------------------------------------------------------------------
  GenStrCmp : appeler _JRT_STRCMP.
  Pre-condition : 4 mots sur la pile.  Resultat : AX = 0 si egales.
  -------------------------------------------------------------------------- }
Procedure GenStrCmp;
Begin
  EmitI1('CALL', RT_PFX + 'STRCMP');
  EmitI1('ADD',  'SP, 8');
End;

{ --------------------------------------------------------------------------
  GenStrEqual : comparer deux chaines et produire AX = 1 si egales, 0 sinon.
  Pre-condition : 4 mots sur la pile.
  -------------------------------------------------------------------------- }
Procedure GenStrEqual;
Var lbl_t, lbl_f : TString;
Begin
  GenStrCmp;
  lbl_t := NewLabel;
  lbl_f := NewLabel;
  EmitI1('TEST', 'AX, AX');
  EmitI1('JZ',   lbl_t);
  EmitI0('XOR  AX, AX');
  EmitI1('JMP',  lbl_f);
  EmitLabel(lbl_t);
  EmitI1('MOV', 'AX, 1');
  EmitLabel(lbl_f);
End;

{ --------------------------------------------------------------------------
  GenStr2Int : convertir la chaine (AX=ptr, DX=len) en entier -> AX.
  -------------------------------------------------------------------------- }
Procedure GenStr2Int;
Begin
  EmitI1('CALL', RT_PFX + 'STR2INT');
End;

{ --------------------------------------------------------------------------
  GenInt2Str : convertir l'entier AX en chaine -> AX=ptr, DX=len.
  -------------------------------------------------------------------------- }
Procedure GenInt2Str;
Begin
  EmitI1('CALL', RT_PFX + 'INT2STR');
End;

{ --------------------------------------------------------------------------
  GenBool2Str : convertir le booleen AX (0/1) en chaine -> AX=ptr, DX=len.
  -------------------------------------------------------------------------- }
Procedure GenBool2Str;
Begin
  EmitI1('CALL', RT_PFX + 'BOOL2STR');
End;

{ --------------------------------------------------------------------------
  GenChar2Str : convertir le code char AX en chaine 1 car -> AX=ptr, DX=len.
  -------------------------------------------------------------------------- }
Procedure GenChar2Str;
Begin
  EmitI1('CALL', RT_PFX + 'CHAR2STR');
End;

{ --------------------------------------------------------------------------
  GenStrLength : longueur de la chaine courante (DX) dans AX.
  -------------------------------------------------------------------------- }
Procedure GenStrLength;
Begin
  EmitI2('MOV', 'AX', 'DX');
End;

{ --------------------------------------------------------------------------
  GenStringConcatChain : concatener n chaines successives.
  Pre-condition : les n descripteurs ont ete empiles (PUSH DX / PUSH AX).
  Effectue n-1 appels a STRCAT ; le resultat intermediaire est re-empile
  entre chaque appel pour alimenter l'iteration suivante.
  -------------------------------------------------------------------------- }
Procedure GenStringConcatChain(n : Integer);
Var i : Integer;
Begin
  If n < 2 Then Exit;
  For i := 1 To n - 1 Do
  Begin
    EmitI1('CALL', RT_PFX + 'STRCAT');
    EmitI1('ADD',  'SP, 8');
    If i < n - 1 Then
    Begin
      EmitI1('PUSH', 'DX');
      EmitI1('PUSH', 'AX');
    End;
  End;
End;

{ ============================================================================
  TODO 17 ... 25 : a implementer
  ============================================================================ }

Begin
  InitTables;
  scope_sp := 0;
  WriteLn('JAVAC86 v', JAVAC86_VERSION, ' - compilateur Java Lite -> MASM 8086');
  WriteLn('(TODO 17-25 non implementes)');
  FreeTables;
End.
