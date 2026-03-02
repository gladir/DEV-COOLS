{ ============================================================================
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

  ============================================================================ }

Program JAVAC86;
Begin
  { TODO 01 a 25 : a implementer }
  WriteLn('JAVAC86 v1.0 - compilateur Java Lite -> MASM 8086');
  WriteLn('(non implemente - voir les 25 TODOs dans les commentaires)');
End.
