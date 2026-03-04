{ ================================================================
  MASM.PAS - Macro Assembleur 8086 compatible MASM 5.x
  ================================================================

  Clone de Microsoft Macro Assembler (MASM) pour DOS 8086.
  Produit des fichiers .OBJ au format Intel Object Module Format
  (OMF) compatibles avec :
    - Microsoft LINK (MASM 5.x / 6.x)
    - IBM Macro Assembler
    - Turbo C / Turbo Pascal TLINK
    - Borland TLINK
    - Watcom WLINK
  L'assembleur effectue un assemblage en deux passes pour
  resoudre toutes les references avant.

  @author:   Sylvain Maltais (support@gladir.com)
  @created:  2026
  @website:  https://www.gladir.com/dev-cools
  @abstract: Target: Turbo Pascal 7 / Free Pascal 3.2 (-Mtp)
  @output:   Intel OMF .OBJ (MASM 5.x compatible)

  ================================================================
  PLAN D IMPLEMENTATION - 25 TODOS
  ================================================================

  TODO 01 - INFRASTRUCTURE DE BASE
    Types fondamentaux : TString (String[127]), TByte, TWord,
    TLong (LongInt). Constantes : VERSION='1.0', MAX_SYM=4096,
    MAX_SEG=16, MAX_GRP=8, MAX_FIXUP=8192, MAX_MACRO=256,
    MAX_STRUCT=64, MAX_IF_DEPTH=32. Enumerations TTokenKind
    (TK_IDENT, TK_NUMBER, TK_STRING, TK_PUNCT, TK_NEWLINE,
    TK_EOF), TSymKind (SK_LABEL, SK_PUBLIC, SK_EXTERN, SK_EQU,
    SK_GROUP, SK_SEG, SK_MACRO, SK_STRUCT), TDataSize
    (DS_BYTE, DS_WORD, DS_DWORD, DS_QWORD, DS_TBYTE, DS_UNKNOWN).
    Record TToken (kind, val, num_val, line_num). Tableaux globaux
    sym_table, seg_table, grp_table. Variables globales :
    pass_num (1 ou 2), err_count, warn_count, lc (location counter),
    cur_seg (indice segment courant). Procedure InitTables.
    Procedure ErrorMsg / WarnMsg. Programme principal stub.

  TODO 02 - LECTEUR DE SOURCE ET GESTIONNAIRE D INCLUSION
    Pile d inclusion : max 8 niveaux (INCLUDE imbriques).
    SrcPush(fname) : ouvre le fichier, empile context (File,
    lineno, fname). SrcPop : depile et ferme. SrcReadLine :
    retourne la prochaine ligne sans le CR/LF ; gere la
    continuation de ligne (barre oblique en dernier caractere
    non-espace). SrcAtEnd : True si pile vide. Compteur
    phys_lineno global pour messages d erreur. Pre-traitement :
    supprimer le commentaire (point-virgule jusqu a fin de ligne)
    de chaque ligne lue, SAUF dans les chaines litterales et les
    operateurs de texte entre chevrons.

  TODO 03 - LEXER (ANALYSEUR LEXICAL)
    LexInit, LexNext, LexPeek. Tokens produits : identificateurs
    (alphanumeriques + _ $), nombres (decimaux 123, hex 0ABCh /
    0xABC, octal 777o/777q, binaire 1010b), chaines litterales
    simple ou double guillemets, operateurs et ponctuations
    ( ) [ ] + - * / . : , < > = & | ^ ~ ! ?). Suffixes
    de base numerique : H/h hex, B/b binaire, O/Q/o/q octal,
    D/d decimal, 0x prefixe hex. Nombres flottants reconnus mais
    non supportes en phase 1 (warning). LexIsDirective : teste
    si le token est une directive MASM connue (liste de 80+
    directives). LexIsRegister : AX BX CX DX SI DI SP BP
    AL AH BL BH CL CH DL DH CS DS ES SS. Retourne toujours
    en majuscules (mode case-insensitive par defaut).

  TODO 04 - TABLE DES SYMBOLES
    SymFind(name) -> index ou 0. SymEnter(name, kind, seg,
    offset, size) -> index. SymSetValue(idx, val). Verification
    de doublon en passe 1 (warning si redefini). Symboles
    predetermines : @DATA, @CODE, @STACK, @FILENAME, @VERSION,
    @CURSEG, @WORDSIZE, @MODEL, TRUE (-1), FALSE (0),
    OFFSET et SEG comme operateurs (non symboles). Hachage
    simple (modulo MAX_SYM) pour performance. Verification
    reference avant en passe 1 : marquer SK_UNDEF ; en passe 2
    verifier que tous les SK_UNDEF ont ete resolus. Gestion
    des alias (ALIAS directive) et des etiquettes locales
    prefixees par @@ (portee : jusqu au prochain label global).

  TODO 05 - FORMAT .OBJ INTEL OMF (RECORDS DE BASE)
    Structure d un fichier .OBJ : suite de records OMF.
    Chaque record = TypeByte + Length:Word + Data[] + Checksum.
    Checksum = 256 - (TypeByte + L_lo + L_hi + somme Data) mod 256.
    Buffer de sortie : tableau de Byte (max 65536), flushe dans
    out_file a la fin. Procedures d emission :
      ObjByte(b), ObjWord(w), ObjDWord(d), ObjBeginRecord(typ),
      ObjEndRecord (calcule longueur + checksum, ecrit le record).
    Types de records de base :
      80h THEADR  : nom du module source
      88h COMENT  : commentaire (date, compilateur, info)
      8Ah MODEND  : fin du module (bit 6 = main entry point)
      96h LNAMES  : liste de noms de segments/groupes (index 1..N)
      98h SEGDEF  : definition de segment (USE16, combine, align, nom)
      9Ah GRPDEF  : definition de groupe (ex : DGROUP = .DATA+.BSS)
      90h PUBDEF  : symboles publics (nom, offset, type index)
      8Ch EXTDEF  : symboles externes (nom, type index)

  TODO 06 - FORMAT .OBJ INTEL OMF (DONNEES ET FIXUPS)
    Records de donnees et de relocation :
      A0h LEDATA  : donnees objets locales (seg index, offset, data)
      A2h LIDATA  : donnees repetees (iterated data - DB 100 DUP(0))
      9Ch FIXUPP  : enregistrements de correction d adresse
    Structure FIXUPP : liste de Thread et de Fixup.
    Fixup comprend LOCAT (LOBYTE/OFFSET/BASE/...), FIX_DAT,
    et Target (SEG/GRP/EXT index + displacement).
    Gestion du buffer LEDATA : max 1024 octets par record ; si
    plein, fermer le record courant et en ouvrir un nouveau.
    FlushLEDATA : ecrire le buffer courant.
    GenFixup(type, is_seg_relative, seg_or_ext_idx, displacement).

  TODO 07 - GESTION DES SEGMENTS ET DES MODELES MEMOIRE
    Directives de modele : .MODEL TINY/SMALL/COMPACT/MEDIUM/
    LARGE/HUGE. Effets : taille du groupe DGROUP, type de CALL
    (NEAR/FAR), type de PTR par defaut. Segments standards
    crees automatiquement selon le modele :
      _TEXT  : code (combine PUBLIC, align WORD)
      _DATA  : donnees initialisees (combine PUBLIC, align WORD)
      _BSS   : donnees non initialisees (combine PUBLIC, align WORD)
      STACK  : pile (combine STACK, align PARA, size 512)
      CONST  : constantes en lecture seule
    Directives .CODE [nom], .DATA, .DATA?, .CONST, .STACK [size].
    SEGMENT nom [align] [combine] [class] ... ENDS nom :
    segments explicites (compatibilite MASM 5).
    ASSUME reg:seg : association registre/segment pour encodage
    des prefixes de segment (generes automatiquement si besoin).
    Directive ORG val : positionner le LC dans le segment courant.

  TODO 08 - EXPRESSIONS ET CALCUL D ADRESSES
    Evaluateur d expressions complet (deux passes).
    Operandes : literal numerique, identificateur (symbole),
    $ (LC courant), SEG sym, OFFSET sym, TYPE sym, SIZE sym,
    LENGTH sym, SHORT expr, NEAR PTR expr, FAR PTR expr,
    BYTE PTR expr, WORD PTR expr, DWORD PTR expr.
    Operateurs par ordre de priorite decroissante :
      1. Parentheses, crochets (groupement, indirection)
      2. OFFSET SEG TYPE SIZE LENGTH (operateurs unaires)
      3. PTR (transtypage de pointeur)
      4. * / MOD SHL SHR (multiplicatifs)
      5. + - unaire et binaire (additifs)
      6. NOT (complement bitwise)
      7. AND OR XOR (logiques bitwise)
      8. EQ NE LT LE GT GE (relationnels, resultat -1 ou 0)
    TExpr = Record val:LongInt; is_relocatable:Boolean;
      seg_idx:Integer pour gerer les expressions relocalisables.
    EvalExpr -> TExpr. Erreur si non evaluable en passe 1
    sauf si contient une reference avant (reporter en passe 2).

  TODO 09 - DIRECTIVES DE DONNEES (DB DW DD DQ DT)
    Directives DB (byte), DW (word), DD (dword), DQ (qword),
    DT (tbyte = 10 octets). Syntaxe :
      [label] Dx val [, val, ...]
      [label] Dx N DUP(val [, val, ...])
      [label] DB 'chaine ASCII'
    val peut etre : expression, ?, liste dans DUP,
    chaine litterale (DB uniquement, chaque octet = code ASCII).
    N DUP(?) : allouer N*size octets sans initialisation
    (utiliser LIDATA record OMF pour les blocs nuls repetes).
    Emettre les octets via EmitByte/EmitWord/EmitDWord.
    DUP imbriques supportes (max 8 niveaux).
    Mettre a jour le LC et la taille du segment courant.
    Alignement : ALIGN n (pad 90h NOP en .CODE, 00h en .DATA).

  TODO 10 - DIRECTIVES SYMBOLIQUES (EQU = LABEL ORG)
    EQU : nom EQU expr -> valeur constante (non reassignable).
    = : nom = expr -> valeur constante reassignable (equate).
    LABEL : nom LABEL type -> creer un label du type donne
    sans emettre de donnees (alias a la position courante).
    ORG : ORG expr -> repositionner le LC (aucun fixup emis).
    EVEN : aligner sur word (equivalent ALIGN 2 en .CODE).
    ALIGN n : n = 1, 2, 4, 8, 16, 256.
    $ : symbole dollar = LC courant dans le segment courant.
    LOCAL label [, label ...] dans MACRO : noms uniques
      generes a chaque expansion (suffixe @@0000, @@0001...).
    RECORD nom : definition de structure de bits ; champs emballes
    dans un BYTE ou WORD, masques et decalages calcules auto.

  TODO 11 - DIRECTIVES DE VISIBILITE (PUBLIC EXTRN GLOBAL)
    PUBLIC nom [, nom ...] : exporter le symbole dans le
    fichier .OBJ (record PUBDEF). Peut apparaitre avant ou
    apres la definition du symbole (reference avant valide).
    EXTRN nom:type [, nom:type ...] : declarer un symbole
    externe (record EXTDEF). type = BYTE WORD DWORD NEAR FAR
    ABS PROC. Plusieurs EXTRN dans le meme fichier : OK.
    GLOBAL nom:type [, ...] : PUBLIC si defini localement,
    EXTRN si non defini (MASM 6.x seulement).
    Enregistrements PUBDEF : un par segment, groupes par SEGDEF.
    Gestion des fixups vers les EXTRN : FIXUPP avec
    Target = EXT + index EXTDEF.
    COMM nom:type[:count] : variable commune (BSS non initialisee)
    pour link commun style C (COMDEF record, type B ou F).

  TODO 12 - ENCODAGE DES INSTRUCTIONS 8086 (MOV ADD SUB AND OR)
    Encodage binaire complet des instructions 8086 de base.
    Modes d adressage : registre (r/r), immediat (r/imm),
    memoire directe (r/[addr]), indirecte (r/[BX+SI+disp]).
    Octet ModRM : mod(2 bits) reg(3 bits) r/m(3 bits).
      mod=00 : [r/m] (sauf r/m=110 -> disp16 direct)
      mod=01 : [r/m + disp8 signe]
      mod=10 : [r/m + disp16]
      mod=11 : registre direct
    Table d adressage 8086 : [BX+SI]=0, [BX+DI]=1, [BP+SI]=2,
    [BP+DI]=3, [SI]=4, [DI]=5, [disp16]=6, [BX]=7.
    Prefixes de segment (26h=ES 2Eh=CS 36h=SS 3Eh=DS).
    Instructions : MOV r,r/m/imm ; ADD/SUB/AND/OR/XOR/CMP r,r/m/imm ;
    INC/DEC/NOT/NEG r/m ; XCHG r,r/m ; LEA r,m ; LDS/LES r,m.
    TEST r/m,r/imm. Encodage sign-extend (83h) si imm8 signe.

  TODO 13 - ENCODAGE DES SAUTS ET APPELS (JMP CALL RET)
    JMP SHORT label    : EBh + cb (deplacement 8 bits signe)
    JMP NEAR PTR label : E9h + cw (deplacement 16 bits signe)
    JMP FAR PTR label  : EAh + ptr16:16 (segment:offset)
    JMP r/m16          : FFh /4
    CALL NEAR PTR label: E8h + cw
    CALL FAR PTR label : 9Ah + ptr16:16
    CALL r/m16         : FFh /2
    RET [n]  : C3h ou C2h + iw (NEAR)
    RETF [n] : CBh ou CAh + iw (FAR)
    Sauts conditionnels Jcc label : 70h..7Fh + cb (SHORT seulement
    en 8086 ; NEAR necessite inversion + JMP SHORT autour).
    JCXZ label : E3h + cb.
    LOOP/LOOPE/LOOPNE label : E2/E1/E0 + cb.
    Resolution des forwards : en passe 1, reserver 2 octets NOP ;
    en passe 2, calculer le deplacement et patcher le buffer.

  TODO 14 - ENCODAGE DES INSTRUCTIONS ARITHMETIQUES ET LOGIQUES
    MUL r/m8 : F6h /4     IMUL r/m8 : F6h /5
    MUL r/m16: F7h /4     IMUL r/m16: F7h /5
    IMUL r16,imm (186+, pas 8086 pur) : warning si .8086 actif.
    DIV r/m8 : F6h /6     IDIV r/m8 : F6h /7
    DIV r/m16: F7h /6     IDIV r/m16: F7h /7
    CBW : 98h   CWD : 99h
    AAA : 37h   AAS : 3Fh   DAA : 27h   DAS : 2Fh
    AAM : D4h 0Ah  AAD : D5h 0Ah
    ROL/ROR/RCL/RCR/SHL/SAL/SHR/SAR : D0h-D3h selon operandes
      (D0=r/m8,1 ; D1=r/m16,1 ; D2=r/m8,CL ; D3=r/m16,CL).
    Shifts par imm8 (D0/D1 + 0Ch) pour 80186+ (warning).
    Instructions flag : STC CLC CMC STD CLD STI CLI.
    PUSHF : 9Ch   POPF : 9Dh   SAHF : 9Eh   LAHF : 9Fh.
    XLAT : D7h.

  TODO 15 - ENCODAGE PILE, CHAINES ET E/S
    PUSH r16 : 50h+r    POP r16 : 58h+r
    PUSH r/m16 : FFh /6  POP r/m16 : 8Fh /0
    PUSH imm (186+, warning) : encodage sign-extend si imm8.
    PUSH CS/DS/ES/SS : 0E/1E/06/16  POP DS/ES/SS : 1F/07/17
    PUSHA/POPA (80186+, warning en mode .8086).
    PUSHF : 9Ch   POPF : 9Dh.
    Instructions de chaines (prefixes REP/REPE/REPZ/REPNE/REPNZ):
      MOVSB/MOVSW : A4h/A5h
      CMPSB/CMPSW : A6h/A7h
      SCASB/SCASW : AEh/AFh
      STOSB/STOSW : AAh/ABh
      LODSB/LODSW : ACh/ADh
    Ports E/S : IN AL,imm8 ; IN AL,DX ; IN AX,DX ;
      OUT imm8,AL ; OUT DX,AL ; OUT DX,AX (E4/E5/EC/ED/EE/EF).
    INT n : CDh n.  INT3 : CCh.  INTO : CEh.  IRET : CFh.
    HLT : F4h.  NOP : 90h.  WAIT : 9Bh.  LOCK : F0h.
    XCHG AX,r16 : 90h+r (encode comme NOP pour AX,AX).
    ESC cop,src : D8h-DFh (interface coprocesseur 8087).

  TODO 16 - STRUCTURES (STRUC / ENDS)
    Syntaxe :
      nom STRUC
        champ1 DB/DW/DD valeur_par_defaut
        champ2 DB/DW/DD ?
      nom ENDS
    Enregistrement dans struct_table : nom, liste de champs
    (nom, offset, taille, valeur par defaut). Calcul de
    SIZE nom (= total octets), OFFSET nom.champ.
    Instanciation : var_name nom <val1, val2, ...>.
      val peut etre vide (valeur par defaut) ou une expression.
      Emettre les octets initialises.
    Tableau de structures : var_name nom N DUP(<>).
    Acces a un champ : [BX].champ -> [BX + offset_champ].
    RECORD (structure de bits) : champs de bits emballes dans
    un BYTE ou WORD, masques et decalages calcules automatiquement.

  TODO 17 - MACROS (MACRO ENDM LOCAL EXITM PURGE)
    Syntaxe :
      nom MACRO [param1 [, param2 ...]]
        corps de la macro
      ENDM
    Stockage du corps dans macro_table (liste de lignes texte).
    Substitution des parametres : &param dans le corps de macro.
    LOCAL label : generer un label unique par expansion
    (@@0000, @@0001 ..., incrementes globalement).
    Expansion recursive : appel de macro dans une macro
    (profondeur max configurable, ex 32 niveaux).
    Directives a l interieur d une macro :
      EXITM : sortir de la macro en cours d expansion.
      REPT n ... ENDM : repeter n fois le corps du bloc.
      IRP param, <liste> ... ENDM : iterer sur une liste.
      IRPC param, chaine ... ENDM : iterer sur chaque char.
    PURGE nom [, nom ...] : supprimer une macro existante.
    Operateurs de substitution d arguments :
      & (concatenation), % (evaluation expression), ! (escape).

  TODO 18 - ASSEMBLAGE CONDITIONNEL (IF IFDEF ELSE ENDIF)
    Blocs conditionnels (jusqu a IF_DEPTH = 32 niveaux):
      IF expr     : si expr <> 0, assembler le bloc
      IFE expr    : si expr = 0
      IFDEF nom   : si nom est defini (non SK_UNDEF)
      IFNDEF nom  : si nom n est pas defini
      IFB <arg>   : si argument macro est vide
      IFNB <arg>  : si argument macro n est pas vide
      IFIDN <a>,<b> / IFIDNI <a>,<b> (insensible a la casse)
      IFDIF <a>,<b>
      IF1 / IF2   : vrai en passe 1 uniquement / passe 2 uniquement
      ELSE / ELSEIF expr
      ENDIF
    En passe 1, les blocs false doivent quand meme etre empiles
    pour maintenir la profondeur de nidification correcte.
    Directives d erreur d assemblage conditionnel :
    .ERR .ERR1 .ERR2 .ERRDEF .ERRNDEF .ERRB .ERRNB
    .ERRIDN .ERRDIF .ERRGE .ERRLE .ERRGT .ERRLT .ERRE .ERRNZ.

  TODO 19 - PROCEDURES ET CONVENTIONS D APPEL (PROC ENDP)
    Syntaxe MASM 5.x de base :
      nom PROC [NEAR | FAR]
        corps de la procedure
      nom ENDP
    Extensions MASM 6.x (optionnelles) :
      nom PROC [NEAR|FAR] [LANG: C | PASCAL | FORTRAN | SYSCALL]
               [USES reg1 reg2 ...]
               [param1:TYPE [, param2:TYPE ...]]
    Effets de USES : emettre PUSH reg... en entree / POP reg... en sortie.
    Effets des parametres (ARG) : creer labels locaux avec offset BP
    selon la convention d appel (C = ordre inverse, PASCAL = ordre direct).
    ENTER n,0 et LEAVE (80186+, warning en mode .8086).
    Verification que ENDP correspond au dernier PROC ouvert.
    Symbole associe : type = NEAR ou FAR, SK_LABEL. Si declare PUBLIC
    avant ou apres le PROC, enregistrer dans PUBDEF.
    INVOKE (MASM 6.x) : generer automatiquement le code d appel
    en empilant les arguments selon la convention de la procedure.

  TODO 20 - DEUX PASSES D ASSEMBLAGE ET GESTION DES FIXUPS
    Passe 1 : lire tout le source sans emettre dans le .OBJ ;
    construire la table des symboles, calculer les offsets (LC)
    de tous les labels. Pour les references avant, noter la
    position et le type de fixup attendu dans une table interne.
    Resultat : table des symboles complete (sauf EXTRN).
    Passe 2 : re-lire le source ; emettre les octets du code
    et des donnees dans les buffers LEDATA par segment ; calculer
    toutes les expressions ; remplir les records FIXUPP. Pour
    les sauts SHORT, verifier que le deplacement tient en 8 bits
    signe ; sinon promouvoir en NEAR (modifie le LC -> relancer
    la passe 2 si necessaire, max 3 iterations pour convergence).
    Table de fixups interne : liste de [offset_dans_ledata,
    type (OFFSET/SEG/SHORT), symbole_cible]. Emit FIXUPP OMF a
    la fin de chaque LEDATA si la table n est pas vide.
    Fixups pour EXTRN : FIXUPP avec Target = EXT + index EXTDEF.

  TODO 21 - FICHIER DE LISTING (.LST)
    Option /L ou ligne de commande 4eme parametre : generer .LST.
    Format du listing (compatible MASM 5.x) :
      [numero_ligne] [offset hexa] [octets hex max 8] [source]
    Continuer sur la ligne suivante si plus de 8 octets generes.
    Sections supplementaires en fin de listing :
      Table des symboles : nom, type, valeur, segment, portee.
      Table des macros : nom, nb parametres, nb expansions.
      Statistiques : lignes lues, erreurs, avertissements,
      octets de code, octets de donnees.
    Directives de listing :
      .LIST / .NOLIST : activer/desactiver l emission du listing.
      .LISTALL : lister aussi les blocs conditionnels inactifs.
      .XLIST : synonyme de .NOLIST.
      PAGE [lignes],[colonnes] : saut de page / dimensionnement.
      TITLE texte / SUBTTL texte : titres et sous-titres de page.
    Option /X : lister les expansions de macros (MASM 5.x).
    Option /C : lister les cross-references symboles/lignes.

  TODO 22 - GESTION DES GROUPES (GROUP ASSUME)
    GROUP nom, seg1 [, seg2 ...] : regrouper plusieurs segments
    en un seul groupe (meme valeur de registre de segment).
    Groupe standard DGROUP = _DATA + _BSS + CONST + STACK.
    Emission du record GRPDEF OMF.
    ASSUME reg:group/seg/NOTHING : indiquer a l assembleur
    quel segment est associe a DS/CS/ES/SS pour calcul
    automatique des prefixes de segment.
    Calcul du deplacement d un symbole par rapport a son groupe
    (OFFSET dans DGROUP vs OFFSET dans _DATA).
    Fixup de type GROUP dans FIXUPP : target = GRP + index.
    Verification de coherence : si un symbole est dans un segment
    faisant partie d un groupe, son offset dans PUBDEF doit etre
    relatif au debut du groupe.
    @STACK, @DATA, @CODE : symboles predefinis representant la
    base des groupes correspondants dans le modele memoire courant.

  TODO 23 - DIRECTIVE INCLUDE ET SYMBOLES PREDEFINIS
    INCLUDE fichier : inserer le fichier a la position courante
    (SrcPush). Recherche dans : repertoire courant, puis les
    repertoires /I specifies sur la ligne de commande, puis
    la variable d environnement INCLUDE. Max 8 niveaux.
    Symboles predetermines du contexte d assemblage :
      @CUR_LINE   : numero de ligne courante
      @FILENAME   : nom du fichier source courant
      @DATE       : date de l assemblage (ex 'MM/DD/YY')
      @TIME       : heure de l assemblage (ex 'HH:MM:SS')
      @CURSEG     : nom du segment courant (chaine)
      @WORDSIZE   : 2 (16-bit) ou 4 (32-bit, extension)
    Directives de module :
      INCLUDELIB nom : emettre un record COMENT OMF type A3h
        contenant le nom de la librairie .LIB a passer a LINK.
      OPTION CASEMAP:NONE/ALL/NOTPUBLIC (MASM 6.x).
      NAME module_name : remplacer THEADR par le nom fourni.
    .RADIX n : changer la base de numerotation par defaut
    (2 a 16) pour les litteraux numeriques sans suffixe.

  TODO 24 - TRAITEMENT DE LA LIGNE DE COMMANDE ET OPTIONS
    Syntaxe :
      MASM [options] source[.ASM] [obj[.OBJ] [lst[.LST] [crf[.CRF]]]]
    Options MASM 5.x (compatibilite) :
      /A      : trier les segments par ordre alphabetique
      /B n    : taille du buffer source (parametre ignore)
      /C      : generer une table de cross-reference (.CRF)
      /D      : mode double-pass (toujours actif dans MASM.PAS)
      /L      : generer un fichier listing (.LST)
      /ML     : labels sensibles a la casse (garder min/maj)
      /MU     : convertir tout en majuscules (comportement defaut)
      /MX     : symboles publics et externes sensibles a la casse
      /N      : supprimer les tables de symboles du listing
      /S      : trier les segments par ordre de definition (defaut)
      /T      : mode silencieux (pas d affichage sauf erreurs)
      /W0 /W1 /W2 : niveau d avertissement (0=aucun, 2=tous)
      /X      : lister les blocs conditionnels inactifs
      /Z      : afficher les lignes sources avec erreur en sortie
      /Zi /Zd : infos CodeView dans le .OBJ (records de debug)
      /I chem : ajouter repertoire de recherche pour INCLUDE
      /Dsym[=val] : definir un symbole sur la ligne de commande
    ParseArgs : analyser ParamStr(1..ParamCount).
    Si aucun parametre ou /? : afficher l aide et terminer.

  TODO 25 - INTEGRATION FINALE, VALIDATION ET TESTS
    Programme principal : ParseArgs -> Passe1 -> Passe2 -> EcritOBJ.
    Ecriture du fichier .OBJ dans l ordre OMF standard :
      1. THEADR  (nom module derive du nom de fichier source)
      2. COMENT  (date, version de l assembleur)
      3. LNAMES  (noms de segments et de classes)
      4. SEGDEF  (un record par segment defini)
      5. GRPDEF  (DGROUP et autres groupes)
      6. EXTDEF  (symboles externes EXTRN)
      7. PUBDEF  (symboles publics PUBLIC par segment)
      8. LEDATA + FIXUPP (donnees + relocations par segment)
      9. MODEND  (point d entree si END label, sinon terminaison)
    Fichiers de test a assembler et valider :
      hello.asm   : .MODEL SMALL / .CODE + .DATA / INT 21h / INT 20h
      arith.asm   : ADD SUB MUL DIV, resultats stockes en memoire
      callsub.asm : PROC/ENDP, CALL/RET, convention C avec USES
      macro.asm   : MACRO, LOCAL, expansion multiple avec REPT/IRP
      extern.asm  : PUBLIC/EXTRN, FIXUPP vers sous-programme externe
      fibo.asm    : boucle LOOP, etiquettes locales @@
    Validation : linker avec TLINK (Turbo C 2.0) et LINK 3.x/4.x.
    Rapport de fin : lignes, symboles, octets code/data,
    erreurs, avertissements, temps d assemblage approximatif.

  ================================================================ }

Program MASM;

Begin
  Writeln('MASM.PAS - Macro Assembleur 8086 -> .OBJ Intel OMF');
  Writeln('A implementer selon les TODOs 01 a 25.');
End.
