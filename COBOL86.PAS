{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur COBOL pour 8086/8088 - Sortie MASM/TASM
}

Program COBOL86;

{$A-}
{$I-}

Uses DOS;

{ ============================================================================ }
{ CONSTANTES GENERALES                                                         }
{ ============================================================================ }

Const
 VERSION = 'COBOL86 V1.0';

 { Colonnes COBOL format fixe }
 COL_SEQ_START    = 1;   { Colonnes 1-6  : numero de sequence (ignore) }
 COL_SEQ_END      = 6;
 COL_INDICATOR    = 7;   { Colonne 7     : indicateur (* / - espace) }
 COL_AREA_A_START = 8;   { Colonnes 8-11 : zone A (en-tetes, noms niv 01/77) }
 COL_AREA_B_START = 12;  { Colonnes 12-72: zone B (instructions, clauses) }
 COL_SOURCE_END   = 72;  { Colonne 72    : fin de la zone source }
 COL_ID_START     = 73;  { Colonnes 73-80: zone identification (ignoree) }

 { Types de tokens COBOL }
 TOK_UNKNOWN   = 0;
 TOK_WORD      = 1;   { Mot : identifiant ou mot reserve }
 TOK_NUMBER    = 2;   { Litteral numerique (entier ou decimal) }
 TOK_STRING    = 3;   { Litteral chaine entre apostrophes ou guillemets }
 TOK_PERIOD    = 4;   { . (terminateur de phrase COBOL) }
 TOK_COMMA     = 5;   { , }
 TOK_SEMICOLON = 6;   { ; }
 TOK_LPAREN    = 7;   { ( }
 TOK_RPAREN    = 8;   { ) }
 TOK_PLUS      = 9;   { + }
 TOK_MINUS     = 10;  { - }
 TOK_MULTIPLY  = 11;  { * }
 TOK_DIVIDE    = 12;  { / }
 TOK_POWER     = 13;  { ** }
 TOK_EQUAL     = 14;  { = }
 TOK_LESS      = 15;  { < }
 TOK_GREATER   = 16;  { > }
 TOK_LESSEQ    = 17;  { <= }
 TOK_GREATEREQ = 18;  { >= }
 TOK_NOTEQUAL  = 19;  { <> ou NOT = }
 TOK_COLON     = 20;  { : (reference de sous-chaine) }
 TOK_EOF       = 21;  { Fin de fichier }

 { Indicateurs de colonne 7 }
 IND_NORMAL    = ' '; { Ligne normale }
 IND_COMMENT   = '*'; { Ligne de commentaire }
 IND_PAGE      = '/'; { Saut de page (traite comme commentaire) }
 IND_CONTINUE  = '-'; { Ligne de continuation }
 IND_DEBUG     = 'D'; { Ligne de debug (traite comme commentaire) }

 MAX_TOKEN_LEN  = 255;
 MAX_LINE_LEN   = 255;
 MAX_ERRORS     = 999;

 { ---------------------------------------------------------------- }
 { Mots reserves COBOL-85 etendu (classes 100-299)                  }
 { Ajoutes par ClassifyReservedWord apres ReadWord.                 }
 { Le parseur utilise ces constantes pour dispatchwer les phrases.  }
 { ---------------------------------------------------------------- }

 { --- Divisions / Sections --- }
 SYM_IDENTIFICATION = 100; { IDENTIFICATION }
 SYM_ENVIRONMENT    = 101; { ENVIRONMENT }
 SYM_DATA           = 102; { DATA }
 SYM_PROCEDURE      = 103; { PROCEDURE }
 SYM_DIVISION       = 104; { DIVISION }
 SYM_SECTION        = 105; { SECTION }

 { --- En-tetes de paragraphes obligatoires --- }
 SYM_PROGRAM_ID     = 106; { PROGRAM-ID }
 SYM_AUTHOR         = 107; { AUTHOR }
 SYM_DATE_WRITTEN   = 108; { DATE-WRITTEN }
 SYM_DATE_COMPILED  = 109; { DATE-COMPILED }
 SYM_INSTALLATION   = 110; { INSTALLATION }
 SYM_SECURITY       = 111; { SECURITY }
 SYM_CONFIGURATION  = 112; { CONFIGURATION }
 SYM_INPUT_OUTPUT   = 113; { INPUT-OUTPUT }
 SYM_FILE_CONTROL   = 114; { FILE-CONTROL }

 { --- Sections DATA --- }
 SYM_FILE_SEC       = 115; { FILE (section) }
 SYM_WORKING_STORAGE= 116; { WORKING-STORAGE }
 SYM_LOCAL_STORAGE  = 117; { LOCAL-STORAGE }
 SYM_LINKAGE        = 118; { LINKAGE }

 { --- Clauses DATA DIVISION --- }
 SYM_PIC            = 119; { PIC }
 SYM_PICTURE        = 120; { PICTURE }
 SYM_VALUE          = 121; { VALUE }
 SYM_VALUES         = 122; { VALUES }
 SYM_REDEFINES      = 123; { REDEFINES }
 SYM_OCCURS         = 124; { OCCURS }
 SYM_TIMES          = 125; { TIMES }
 SYM_DEPENDING      = 126; { DEPENDING }
 SYM_INDEXED        = 127; { INDEXED }
 SYM_BY             = 128; { BY }
 SYM_ASCENDING      = 129; { ASCENDING }
 SYM_DESCENDING     = 130; { DESCENDING }
 SYM_KEY            = 131; { KEY }
 SYM_FILLER         = 132; { FILLER }
 SYM_USAGE          = 133; { USAGE }
 SYM_COMP           = 134; { COMP }
 SYM_COMPUTATIONAL  = 135; { COMPUTATIONAL }
 SYM_BINARY         = 136; { BINARY }
 SYM_PACKED_DECIMAL = 137; { PACKED-DECIMAL }
 SYM_BLANK          = 138; { BLANK }
 SYM_SCREEN         = 139; { SCREEN (section) }
 SYM_GLOBAL         = 140; { GLOBAL }
 SYM_EXTERNAL       = 141; { EXTERNAL }
 SYM_SELECT         = 142; { SELECT }
 SYM_ASSIGN         = 143; { ASSIGN }
 SYM_ORGANIZATION   = 144; { ORGANIZATION }
 SYM_SEQUENTIAL     = 145; { SEQUENTIAL }
 SYM_RANDOM         = 146; { RANDOM }
 SYM_ACCESS         = 147; { ACCESS }
 SYM_MODE           = 148; { MODE }
 SYM_RECORD         = 149; { RECORD }
 SYM_STATUS         = 150; { STATUS }
 SYM_FILE_STATUS    = 151; { FILE-STATUS }
 SYM_RELATIVE       = 152; { RELATIVE }
 SYM_DYNAMIC        = 153; { DYNAMIC }

 { --- Instructions de la PROCEDURE DIVISION --- }
 SYM_MOVE           = 154; { MOVE }
 SYM_TO             = 155; { TO }
 SYM_CORRESPONDING  = 156; { CORRESPONDING }
 SYM_CORR           = 157; { CORR }
 SYM_ADD            = 158; { ADD }
 SYM_SUBTRACT       = 159; { SUBTRACT }
 SYM_MULTIPLY_V     = 160; { MULTIPLY (verbe; * = TOK_MULTIPLY) }
 SYM_DIVIDE_V       = 161; { DIVIDE (verbe; / = TOK_DIVIDE) }
 SYM_COMPUTE        = 162; { COMPUTE }
 SYM_GIVING         = 163; { GIVING }
 SYM_FROM           = 164; { FROM }
 SYM_REMAINDER      = 165; { REMAINDER }
 SYM_ROUNDED        = 166; { ROUNDED }
 SYM_SIZE           = 167; { SIZE }
 SYM_ON             = 168; { ON }
 SYM_ERROR_KW       = 169; { ERROR (clause ON SIZE ERROR) }
 SYM_END_ADD        = 170; { END-ADD }
 SYM_END_SUBTRACT   = 171; { END-SUBTRACT }
 SYM_END_MULTIPLY   = 172; { END-MULTIPLY }
 SYM_END_DIVIDE     = 173; { END-DIVIDE }
 SYM_END_COMPUTE    = 174; { END-COMPUTE }

 { --- Controle --- }
 SYM_IF             = 175; { IF }
 SYM_THEN           = 176; { THEN }
 SYM_ELSE           = 177; { ELSE }
 SYM_END_IF         = 178; { END-IF }
 SYM_EVALUATE       = 179; { EVALUATE }
 SYM_WHEN          = 180; { WHEN }
 SYM_OTHER          = 181; { OTHER }
 SYM_END_EVALUATE   = 182; { END-EVALUATE }
 SYM_PERFORM        = 183; { PERFORM }
 SYM_THRU           = 184; { THRU }
 SYM_THROUGH        = 185; { THROUGH }
 SYM_VARYING        = 186; { VARYING }
 SYM_AFTER          = 187; { AFTER }
 SYM_BEFORE         = 188; { BEFORE }
 SYM_TEST           = 189; { TEST }
 SYM_UNTIL          = 190; { UNTIL }
 SYM_END_PERFORM    = 191; { END-PERFORM }
 SYM_GO             = 192; { GO }
 SYM_STOP           = 193; { STOP }
 SYM_RUN            = 194; { RUN }
 SYM_EXIT           = 195; { EXIT }
 SYM_PROGRAM        = 196; { PROGRAM }
 SYM_NEXT           = 197; { NEXT }
 SYM_SENTENCE       = 198; { SENTENCE }
 SYM_CONTINUE_KW    = 199; { CONTINUE }
 SYM_INITIALIZE     = 200; { INITIALIZE }
 SYM_SET            = 201; { SET }
 SYM_UP             = 202; { UP }
 SYM_DOWN           = 203; { DOWN }
 SYM_CALL           = 204; { CALL }
 SYM_USING          = 205; { USING }
 SYM_CANCEL         = 206; { CANCEL }
 SYM_END_CALL       = 207; { END-CALL }
 SYM_SORT           = 208; { SORT }
 SYM_MERGE          = 209; { MERGE }
 SYM_RELEASE        = 210; { RELEASE }
 SYM_RETURN_KW      = 211; { RETURN }

 { --- Fichiers --- }
 SYM_OPEN           = 212; { OPEN }
 SYM_CLOSE          = 213; { CLOSE }
 SYM_READ           = 214; { READ }
 SYM_WRITE          = 215; { WRITE }
 SYM_REWRITE        = 216; { REWRITE }
 SYM_DELETE_KW      = 217; { DELETE }
 SYM_START_KW       = 218; { START }
 SYM_INPUT          = 219; { INPUT }
 SYM_OUTPUT_KW      = 220; { OUTPUT }
 SYM_IO             = 221; { I-O }
 SYM_EXTEND         = 222; { EXTEND }
 SYM_AT             = 223; { AT }
 SYM_END_KW         = 224; { END }
 SYM_END_READ       = 225; { END-READ }
 SYM_END_WRITE      = 226; { END-WRITE }
 SYM_INVALID        = 227; { INVALID }
 SYM_WITH           = 228; { WITH }
 SYM_LOCK           = 229; { LOCK }

 { --- Affichage / Saisie --- }
 SYM_DISPLAY        = 230; { DISPLAY }
 SYM_UPON           = 231; { UPON }
 SYM_NO             = 232; { NO }
 SYM_ADVANCING      = 233; { ADVANCING }
 SYM_ACCEPT         = 234; { ACCEPT }

 { --- Chaines --- }
 SYM_STRING_KW      = 236; { STRING (instruction) }
 SYM_UNSTRING       = 237; { UNSTRING }
 SYM_INSPECT        = 238; { INSPECT }
 SYM_TALLYING       = 239; { TALLYING }
 SYM_REPLACING_KW   = 240; { REPLACING }
 SYM_DELIMITED      = 241; { DELIMITED }
 SYM_INTO           = 242; { INTO }
 SYM_OF             = 243; { OF }
 SYM_ALL            = 244; { ALL }
 SYM_LEADING        = 245; { LEADING }
 SYM_TRAILING       = 246; { TRAILING }
 SYM_FIRST          = 247; { FIRST }
 SYM_POINTER_KW     = 248; { POINTER }
 SYM_COUNT          = 249; { COUNT }
 SYM_OVERFLOW_KW    = 250; { OVERFLOW }
 SYM_END_STRING     = 251; { END-STRING }
 SYM_END_UNSTRING   = 252; { END-UNSTRING }
 SYM_END_INSPECT    = 253; { END-INSPECT }
 SYM_IN             = 254; { IN }

 { --- Logique et comparaison --- }
 SYM_NOT            = 255; { NOT }
 SYM_AND            = 256; { AND }
 SYM_OR             = 257; { OR }
 SYM_TRUE_KW        = 258; { TRUE }
 SYM_FALSE_KW       = 259; { FALSE }
 SYM_IS             = 260; { IS }
 SYM_ARE            = 261; { ARE }
 SYM_EQUAL_KW       = 262; { EQUAL }
 SYM_GREATER_KW     = 263; { GREATER }
 SYM_LESS_KW        = 264; { LESS }
 SYM_THAN           = 265; { THAN }
 SYM_NUMERIC_KW     = 266; { NUMERIC }
 SYM_ALPHABETIC_KW  = 267; { ALPHABETIC }
 SYM_ALPHA_LOWER    = 268; { ALPHABETIC-LOWER }
 SYM_ALPHA_UPPER    = 269; { ALPHABETIC-UPPER }
 SYM_POSITIVE       = 270; { POSITIVE }
 SYM_NEGATIVE       = 271; { NEGATIVE }

 { --- Litteraux figuratifs --- }
 SYM_ZERO           = 272; { ZERO }
 SYM_ZEROS          = 273; { ZEROS }
 SYM_ZEROES         = 274; { ZEROES }
 SYM_SPACE          = 275; { SPACE }
 SYM_SPACES         = 276; { SPACES }
 SYM_HIGH_VALUE     = 277; { HIGH-VALUE }
 SYM_HIGH_VALUES    = 278; { HIGH-VALUES }
 SYM_LOW_VALUE      = 279; { LOW-VALUE }
 SYM_LOW_VALUES     = 280; { LOW-VALUES }
 SYM_QUOTE_KW       = 281; { QUOTE }
 SYM_QUOTES         = 282; { QUOTES }
 SYM_NULL_KW        = 283; { NULL }
 SYM_NULLS          = 284; { NULLS }

 { --- Divers / clauses supplementaires --- }
 SYM_LENGTH         = 285; { LENGTH }
 SYM_REFERENCE      = 286; { REFERENCE }
 SYM_CONTENT        = 287; { CONTENT }
 SYM_ADDRESS        = 288; { ADDRESS }
 SYM_DEBUG_ITEM     = 289; { DEBUG-ITEM }
 SYM_DEBUGGING      = 290; { DEBUGGING }
 SYM_NATIVE         = 291; { NATIVE }
 SYM_STANDARD       = 292; { STANDARD }
 SYM_CURRENCY       = 293; { CURRENCY }
 SYM_DECIMAL_POINT  = 294; { DECIMAL-POINT }
 SYM_CLASS          = 295; { CLASS }
 SYM_OBJECT_COMPUTER= 296; { OBJECT-COMPUTER }
 SYM_SOURCE_COMPUTER= 297; { SOURCE-COMPUTER }
 SYM_SPECIAL_NAMES  = 298; { SPECIAL-NAMES }
 SYM_REPOSITORY     = 299; { REPOSITORY }

 { ---------------------------------------------------------------- }
 { Table des symboles : limites                                      }
 { ---------------------------------------------------------------- }
 MAX_DATA_ITEMS  = 2000; { Nombre max d'articles de donnees (01..77..88) }
 MAX_PARAGRAPHS  = 500;  { Nombre max de paragraphes/sections PROCEDURE   }
 MAX_FILES       = 50;   { Nombre max de fichiers declares en FILE SECTION }
 MAX_ITEM_NAME   = 30;   { Longueur max d'un nom COBOL (norme : 30)        }
 MAX_PIC_STR     = 50;   { Longueur max d'une chaine PIC brute             }
 MAX_VALUE_STR   = 255;  { Longueur max d'un litteral VALUE                }

 { Types de donnees PIC }
 TYPE_GROUP      = 0;  { Article de groupe (pas de clause PIC)           }
 TYPE_PIC_9      = 1;  { PIC 9... : numerique non signe                  }
 TYPE_PIC_S9     = 2;  { PIC S9.. : numerique signe                      }
 TYPE_PIC_X      = 3;  { PIC X... : alphanumerique                       }
 TYPE_PIC_A      = 4;  { PIC A... : alphabetique                         }
 TYPE_PIC_9V9    = 5;  { PIC 9V9. : numerique decimal implicite          }
 TYPE_PIC_S9V9   = 6;  { PIC S9V9 : numerique decimal signe              }
 TYPE_COND_88    = 7;  { Niveau 88 : nom de condition                    }

 { Sous-type USAGE (stockage interne) }
 USAGE_DISPLAY   = 0;  { USAGE DISPLAY (defaut) : 1 octet par chiffre/car }
 USAGE_COMP      = 1;  { USAGE COMP / COMPUTATIONAL : binaire 16 bits     }
 USAGE_COMP_3    = 2;  { USAGE COMP-3 / PACKED-DECIMAL : BCD tasse       }
 USAGE_BINARY    = 3;  { USAGE BINARY : synonyme COMP                    }

 { Sections de DATA DIVISION }
 SECT_NONE           = 0;
 SECT_WORKING_STORAGE= 1;
 SECT_FILE           = 2;
 SECT_LINKAGE        = 3;
 SECT_LOCAL_STORAGE  = 4;

 { Valeurs speciales VALUE (litteraux figuratifs) }
 VALTYPE_NONE     = 0;  { Pas de clause VALUE }
 VALTYPE_STRING   = 1;  { Litteral chaine }
 VALTYPE_NUMBER   = 2;  { Litteral numerique }
 VALTYPE_ZERO     = 3;  { ZERO/ZEROS/ZEROES }
 VALTYPE_SPACE    = 4;  { SPACE/SPACES }
 VALTYPE_HIGH     = 5;  { HIGH-VALUE/HIGH-VALUES }
 VALTYPE_LOW      = 6;  { LOW-VALUE/LOW-VALUES }
 VALTYPE_QUOTE    = 7;  { QUOTE/QUOTES }
 VALTYPE_NULL     = 8;  { NULL/NULLS }
 VALTYPE_TRUE_V   = 9;  { TRUE  (niveau 88) }
 VALTYPE_FALSE_V  = 10; { FALSE (niveau 88) }

{ ============================================================================ }
{ TYPES STRUCTURES                                                             }
{ ============================================================================ }

Type

 {
   TDataItem : represente un article de donnees COBOL.
   Chaque entree de la WORKING-STORAGE, FILE, LINKAGE SECTION
   est decrite par un TDataItem.

   Hierarchie :
     level    = numero de niveau COBOL (01..49, 66, 77, 88)
     parent   = index 1-base du parent dans data_table (0 = racine)
     is_group = True si l'item n'a pas de clause PIC (article de groupe)

   Mise en memoire :
     offset   = deplacement en octets depuis le debut du segment .DATA
     byte_size = taille physique en octets de cet item
               (pour un groupe = somme des feuilles; pour les tableaux * occurs)

   Pour OCCURS :
     occurs_count > 0  => tableau de occurs_count elements
     depends_on  = index de la variable DEPENDING ON (0 = taille fixe)

   Pour REDEFINES :
     redefines_idx = index de l'item redefini (0 = pas de REDEFINES)

   Pour le niveau 88 :
     data_type = TYPE_COND_88
     parent    = index de l'item auquel la condition est attachee
     val_type  = VALTYPE_xxx + val_str/val_num = la valeur de la condition
     thru_str/thru_num = valeur haute (si VALUE x THRU y)
 }
 TDataItem = Record
  name          : String[MAX_ITEM_NAME]; { Nom de l'article (FILLER si vide) }
  level         : Integer;              { Niveau COBOL : 01-49, 66, 77, 88   }
  data_type     : Integer;              { TYPE_xxx   }
  usage         : Integer;              { USAGE_xxx  }
  section       : Integer;              { SECT_xxx   }
  parent        : Integer;              { Index du parent (0 = top-level)     }
  is_group      : Boolean;              { Pas de PIC : article de groupe      }
  pic_str       : String[MAX_PIC_STR];  { Chaine PIC brute ex: '9(5)V99'     }
  pic_digits    : Integer;              { Nombre total de chiffres entiers    }
  pic_decimals  : Integer;              { Chiffres apres la virgule (V)       }
  pic_size      : Integer;              { Largeur totale en caracteres/chif.  }
  is_signed     : Boolean;              { S devant le PIC                     }
  byte_size     : Integer;              { Octets en memoire (apres USAGE)     }
  offset        : Integer;             { Offset depuis debut de DATA segment  }
  occurs_count  : Integer;              { 0 = pas de tableau ; N = N elem.    }
  depends_on    : Integer;              { Index de la var DEPENDING ON (0=non)}
  redefines_idx : Integer;              { Index de l'item redefini (0=non)    }
  has_value     : Boolean;              { Clause VALUE presente               }
  val_type      : Integer;              { VALTYPE_xxx                         }
  val_str       : String[MAX_VALUE_STR];{ Valeur litterale chaine             }
  val_num       : LongInt;              { Valeur litterale numerique          }
  has_thru      : Boolean;              { VALUE x THRU y (niveau 88)         }
  thru_str      : String[MAX_VALUE_STR];{ Borne haute THRU (chaine)          }
  thru_num      : LongInt;              { Borne haute THRU (numerique)       }
  asm_label     : String[MAX_ITEM_NAME];{ Etiquette ASM generee (ex: WS_NOM) }
  file_idx      : Integer;              { Index dans file_table (SECT_FILE)  }
  defined       : Boolean;              { True une fois l'article complet    }
 End;
 PDataItem = ^TDataItem;

 {
   TParagraph : represente un paragraphe ou une section de la PROCEDURE DIVISION.
   Chaque etiquette cible d'un PERFORM ou GO TO doit etre dans cette table.
 }
 TParagraph = Record
  name         : String[MAX_ITEM_NAME]; { Nom du paragraphe }
  section_name : String[MAX_ITEM_NAME]; { Section proprietaire (vide = global)}
  label_id     : Integer;              { Numero unique => etiquette ASM PARA_nnn }
  defined      : Boolean;              { True si le paragraphe a ete vu      }
 End;
 PParagraph = ^TParagraph;

 {
   TFileEntry : represente un fichier declare dans la FILE-CONTROL
   (SELECT ... ASSIGN TO ...).
 }
 TFileEntry = Record
  name         : String[MAX_ITEM_NAME]; { Nom logique COBOL (FD name)     }
  assign_to    : String[MAX_VALUE_STR]; { Nom physique (ASSIGN TO '...')  }
  organization : Integer;              { 0=SEQUENTIAL, 1=RANDOM, 2=RELATIVE }
  access_mode  : Integer;              { 0=SEQUENTIAL, 1=RANDOM, 2=DYNAMIC  }
  file_status  : String[MAX_ITEM_NAME]; { Variable FILE-STATUS (ou vide)  }
  fd_item_idx  : Integer;              { Premier item de l'FD (01 level)  }
  handle_label : String[MAX_ITEM_NAME]; { Etiquette ASM du handle DOS      }
  defined      : Boolean;
 End;
 PFileEntry = ^TFileEntry;

{ ============================================================================ }
{ VARIABLES GLOBALES DU TOKENISEUR                                             }
{ ============================================================================ }

Var
 { Fichiers }
 input_file     : Text;
 output_file    : Text;
 source_filename: String;
 output_filename: String;

 { Etat du lecteur de lignes }
 raw_line       : String;   { Ligne brute lue depuis le fichier }
 source_line    : String;   { Zone source effective (cols 8-72) }
 indicator_char : Char;     { Caractere indicateur (col 7) }
 line_number    : Integer;  { Numero de ligne courante }
 line_pos       : Integer;  { Position courante dans source_line (1-base) }
 current_char   : Char;     { Caractere courant }
 in_continuation: Boolean;  { Vrai si on est en continuation de chaine }
 cont_quote     : Char;     { Caractere de quote de la chaine en continuation }

 { Etat du tokeniseur }
 current_token  : String;   { Valeur textuelle du token courant }
 current_symbol : Integer;  { Type du token courant (TOK_xxx) }
 current_value  : LongInt;  { Valeur numerique si TOK_NUMBER }
 token_column   : Integer;  { Colonne de debut du token dans la ligne source }
 error_count    : Integer;  { Nombre d'erreurs rencontrees }
 eof_reached    : Boolean;  { Vrai quand le fichier est entierement lu }

{ ============================================================================ }
{ VARIABLES GLOBALES DE LA TABLE DES SYMBOLES                                  }
{ ============================================================================ }

 { Table des articles de donnees COBOL }
 data_table     : Array[1..MAX_DATA_ITEMS] of PDataItem;
 data_count     : Integer;   { Nombre d'articles enregistres }
 data_offset    : Integer;   { Offset courant dans le segment DATA }

 { Table des paragraphes / sections PROCEDURE DIVISION }
 para_table     : Array[1..MAX_PARAGRAPHS] of PParagraph;
 para_count     : Integer;   { Nombre de paragraphes enregistres }
 next_para_id   : Integer;   { Compteur pour les etiquettes ASM uniques }

 { Table des fichiers (FILE-CONTROL) }
 file_table     : Array[1..MAX_FILES] of PFileEntry;
 file_count     : Integer;

 { Nom du programme COBOL (PROGRAM-ID) }
 program_name   : String;

 { Section DATA DIVISION active lors du parsing }
 current_section: Integer;  { SECT_xxx }

{ ============================================================================ }
{ UTILITAIRES                                                                  }
{ ============================================================================ }

{ Convertir une chaine en majuscules }
Function UpperStr(s: String): String;
Var
 i: Integer;
 r: String;
Begin
 r := s;
 For i := 1 to Length(s) do
  If (s[i] >= 'a') and (s[i] <= 'z') Then
   r[i] := Chr(Ord(s[i]) - 32);
 UpperStr := r;
End;

{ Afficher une erreur avec le numero de ligne }
Procedure Error(msg: String);
Begin
 WriteLn('ERREUR ligne ', line_number, ' col ', token_column + 7,
         ': ', msg);
 Inc(error_count);
 If error_count >= MAX_ERRORS Then
 Begin
  WriteLn('Trop d''erreurs - compilation arretee.');
  Close(input_file);
  Halt(1);
 End;
End;

{ Afficher un avertissement }
Procedure Warning(msg: String);
Begin
 WriteLn('ATTENTION ligne ', line_number, ' col ', token_column + 7,
         ': ', msg);
End;

{ ============================================================================ }
{ LECTURE DES LIGNES COBOL (FORMAT FIXE)                                      }
{ ============================================================================ }

{
  Format fixe COBOL traditionnel :
    Cols  1- 6 : zone numerotation (ignoree)
    Col   7    : zone indicateur
                   ' ' = ligne normale
                   '*' = commentaire entier
                   '/' = saut de page (commentaire)
                   '-' = continuation de la ligne precedente
                   'D' = ligne de debug (commentaire ici)
    Cols  8-11 : zone A (en-tetes de divisions/sections, niveaux 01/77/88)
    Cols 12-72 : zone B (corps des instructions et clauses)
    Cols 73-80 : zone identification du programme (ignoree)

  source_line contient toujours le contenu des colonnes 8 a 72 (donc
  jusqu'a 65 caracteres) ; line_pos et current_char pointent dedans.
}

{ Lire la prochaine ligne physique depuis le fichier }
Function ReadPhysicalLine: Boolean;
Begin
 If Eof(input_file) Then
 Begin
  ReadPhysicalLine := False;
  Exit;
 End;
 ReadLn(input_file, raw_line);
 Inc(line_number);
 ReadPhysicalLine := True;
End;

{ Extraire la zone source (cols 8-72) et l'indicateur (col 7) }
Procedure ExtractSourceZone;
Var
 len: Integer;
Begin
 len := Length(raw_line);

 { Indicateur col 7 }
 If len >= COL_INDICATOR Then
  indicator_char := raw_line[COL_INDICATOR]
 Else
  indicator_char := IND_NORMAL;

 { Zone source : cols 8 a 72 (ou fin de ligne si plus courte) }
 If len >= COL_AREA_A_START Then
 Begin
  If len > COL_SOURCE_END Then len := COL_SOURCE_END;
  source_line := Copy(raw_line, COL_AREA_A_START,
                       len - COL_AREA_A_START + 1);
  { Supprimer les espaces de fin }
  While (Length(source_line) > 0) and
        (source_line[Length(source_line)] = ' ') do
   Delete(source_line, Length(source_line), 1);
 End
 Else
  source_line := '';
End;

{ Avancer d'un caractere dans source_line (declaration anticipee) }
Procedure NextChar; Forward;

Procedure LoadNextLine;
Label retry;
Begin
retry:
 If not ReadPhysicalLine Then
 Begin
  eof_reached    := True;
  source_line    := '';
  line_pos       := 1;
  current_char   := #0;
  indicator_char := IND_NORMAL;
  Exit;
 End;

 ExtractSourceZone;

 { Ignorer les lignes de commentaire }
 If (indicator_char = IND_COMMENT) or
    (indicator_char = IND_PAGE)    or
    (indicator_char = IND_DEBUG)   Then
  Goto retry;

 { Ligne de continuation : signaler l'etat }
 If indicator_char = IND_CONTINUE Then
  in_continuation := True
 Else
  in_continuation := False;

 line_pos := 1;

 If Length(source_line) > 0 Then
  current_char := source_line[1]
 Else
  current_char := ' ';
End;

{ Avancer d'un caractere dans source_line }
Procedure NextChar;
Begin
 Inc(line_pos);
 If line_pos > Length(source_line) Then
 Begin
  If eof_reached Then
  Begin
   current_char := #0;
   Exit;
  End;
  LoadNextLine;
 End
 Else
  current_char := source_line[line_pos];
End;

{ Retourner le caractere SUIVANT sans avancer (regarder en avant) }
Function PeekChar: Char;
Begin
 If line_pos + 1 <= Length(source_line) Then
  PeekChar := source_line[line_pos + 1]
 Else
  PeekChar := ' ';
End;

{ ============================================================================ }
{ ANALYSEUR LEXICAL (TOKENISEUR COBOL)                                         }
{ ============================================================================ }

{ Ignorer les espaces et tabulations dans la zone source courante }
Procedure SkipSpaces;
Begin
 While (current_char = ' ') or (current_char = #9) do
 Begin
  If line_pos >= Length(source_line) Then
  Begin
   If eof_reached Then
   Begin
    current_char := #0;
    Exit;
   End;
   LoadNextLine;
  End
  Else
   NextChar;
 End;
End;

{
  Lire un mot COBOL (identifiant ou mot reserve).
  Un mot COBOL est compose de lettres, chiffres et traits d'union.
  Il ne peut pas commencer ni finir par un trait d'union.
  Longueur max : 30 caracteres (norme), on accepte jusqu'a MAX_TOKEN_LEN.
}
{
  Classifier un mot lu par ReadWord comme mot reserve COBOL ou identifiant.
  Positionne current_symbol sur la constante SYM_xxx correspondante,
  ou laisse TOK_WORD si c'est un identifiant utilisateur.
  La chaine current_token est deja en majuscules a ce stade.
}
Procedure ClassifyReservedWord;
Begin
 { On utilise des blocs If/Else groupes par lettres pour la performance }
 Case current_token[1] of

  'A':
   If current_token = 'ACCEPT'           Then current_symbol := SYM_ACCEPT
   Else If current_token = 'ACCESS'      Then current_symbol := SYM_ACCESS
   Else If current_token = 'ADD'         Then current_symbol := SYM_ADD
   Else If current_token = 'ADVANCING'   Then current_symbol := SYM_ADVANCING
   Else If current_token = 'AFTER'       Then current_symbol := SYM_AFTER
   Else If current_token = 'ALL'         Then current_symbol := SYM_ALL
   Else If current_token = 'ALPHABETIC'  Then current_symbol := SYM_ALPHABETIC_KW
   Else If current_token = 'ALPHABETIC-LOWER' Then current_symbol := SYM_ALPHA_LOWER
   Else If current_token = 'ALPHABETIC-UPPER' Then current_symbol := SYM_ALPHA_UPPER
   Else If current_token = 'AND'         Then current_symbol := SYM_AND
   Else If current_token = 'ARE'         Then current_symbol := SYM_ARE
   Else If current_token = 'ASCENDING'   Then current_symbol := SYM_ASCENDING
   Else If current_token = 'ASSIGN'      Then current_symbol := SYM_ASSIGN
   Else If current_token = 'AT'          Then current_symbol := SYM_AT
   Else If current_token = 'AUTHOR'      Then current_symbol := SYM_AUTHOR
   Else If current_token = 'ADDRESS'     Then current_symbol := SYM_ADDRESS;

  'B':
   If current_token = 'BEFORE'           Then current_symbol := SYM_BEFORE
   Else If current_token = 'BINARY'      Then current_symbol := SYM_BINARY
   Else If current_token = 'BLANK'       Then current_symbol := SYM_BLANK
   Else If current_token = 'BY'          Then current_symbol := SYM_BY;

  'C':
   If current_token = 'CALL'             Then current_symbol := SYM_CALL
   Else If current_token = 'CANCEL'      Then current_symbol := SYM_CANCEL
   Else If current_token = 'CLASS'       Then current_symbol := SYM_CLASS
   Else If current_token = 'CLOSE'       Then current_symbol := SYM_CLOSE
   Else If current_token = 'COMP'        Then current_symbol := SYM_COMP
   Else If current_token = 'COMPUTATIONAL' Then current_symbol := SYM_COMPUTATIONAL
   Else If current_token = 'COMPUTE'     Then current_symbol := SYM_COMPUTE
   Else If current_token = 'CONFIGURATION' Then current_symbol := SYM_CONFIGURATION
   Else If current_token = 'CONTENT'     Then current_symbol := SYM_CONTENT
   Else If current_token = 'CONTINUE'    Then current_symbol := SYM_CONTINUE_KW
   Else If current_token = 'CORRESPONDING' Then current_symbol := SYM_CORRESPONDING
   Else If current_token = 'CORR'        Then current_symbol := SYM_CORR
   Else If current_token = 'COUNT'       Then current_symbol := SYM_COUNT
   Else If current_token = 'CURRENCY'    Then current_symbol := SYM_CURRENCY;

  'D':
   If current_token = 'DATA'             Then current_symbol := SYM_DATA
   Else If current_token = 'DATE-COMPILED' Then current_symbol := SYM_DATE_COMPILED
   Else If current_token = 'DATE-WRITTEN' Then current_symbol := SYM_DATE_WRITTEN
   Else If current_token = 'DEBUGGING'   Then current_symbol := SYM_DEBUGGING
   Else If current_token = 'DECIMAL-POINT' Then current_symbol := SYM_DECIMAL_POINT
   Else If current_token = 'DELETE'      Then current_symbol := SYM_DELETE_KW
   Else If current_token = 'DELIMITED'   Then current_symbol := SYM_DELIMITED
   Else If current_token = 'DEPENDING'   Then current_symbol := SYM_DEPENDING
   Else If current_token = 'DESCENDING'  Then current_symbol := SYM_DESCENDING
   Else If current_token = 'DISPLAY'     Then current_symbol := SYM_DISPLAY
   Else If current_token = 'DIVISION'    Then current_symbol := SYM_DIVISION
   Else If current_token = 'DOWN'        Then current_symbol := SYM_DOWN
   Else If current_token = 'DYNAMIC'     Then current_symbol := SYM_DYNAMIC;

  'E':
   If current_token = 'ELSE'             Then current_symbol := SYM_ELSE
   Else If current_token = 'END'         Then current_symbol := SYM_END_KW
   Else If current_token = 'END-ADD'     Then current_symbol := SYM_END_ADD
   Else If current_token = 'END-CALL'    Then current_symbol := SYM_END_CALL
   Else If current_token = 'END-COMPUTE' Then current_symbol := SYM_END_COMPUTE
   Else If current_token = 'END-DIVIDE'  Then current_symbol := SYM_END_DIVIDE
   Else If current_token = 'END-EVALUATE' Then current_symbol := SYM_END_EVALUATE
   Else If current_token = 'END-IF'      Then current_symbol := SYM_END_IF
   Else If current_token = 'END-INSPECT' Then current_symbol := SYM_END_INSPECT
   Else If current_token = 'END-MULTIPLY' Then current_symbol := SYM_END_MULTIPLY
   Else If current_token = 'END-PERFORM' Then current_symbol := SYM_END_PERFORM
   Else If current_token = 'END-READ'    Then current_symbol := SYM_END_READ
   Else If current_token = 'END-RETURN'  Then current_symbol := TOK_WORD
   Else If current_token = 'END-STRING'  Then current_symbol := SYM_END_STRING
   Else If current_token = 'END-SUBTRACT' Then current_symbol := SYM_END_SUBTRACT
   Else If current_token = 'END-UNSTRING' Then current_symbol := SYM_END_UNSTRING
   Else If current_token = 'END-WRITE'   Then current_symbol := SYM_END_WRITE
   Else If current_token = 'ENVIRONMENT' Then current_symbol := SYM_ENVIRONMENT
   Else If current_token = 'EQUAL'       Then current_symbol := SYM_EQUAL_KW
   Else If current_token = 'ERROR'       Then current_symbol := SYM_ERROR_KW
   Else If current_token = 'EVALUATE'    Then current_symbol := SYM_EVALUATE
   Else If current_token = 'EXIT'        Then current_symbol := SYM_EXIT
   Else If current_token = 'EXTEND'      Then current_symbol := SYM_EXTEND
   Else If current_token = 'EXTERNAL'    Then current_symbol := SYM_EXTERNAL;

  'F':
   If current_token = 'FALSE'            Then current_symbol := SYM_FALSE_KW
   Else If current_token = 'FILE'        Then current_symbol := SYM_FILE_SEC
   Else If current_token = 'FILE-CONTROL' Then current_symbol := SYM_FILE_CONTROL
   Else If current_token = 'FILE-STATUS' Then current_symbol := SYM_FILE_STATUS
   Else If current_token = 'FILLER'      Then current_symbol := SYM_FILLER
   Else If current_token = 'FIRST'       Then current_symbol := SYM_FIRST
   Else If current_token = 'FROM'        Then current_symbol := SYM_FROM;

  'G':
   If current_token = 'GIVING'           Then current_symbol := SYM_GIVING
   Else If current_token = 'GLOBAL'      Then current_symbol := SYM_GLOBAL
   Else If current_token = 'GO'          Then current_symbol := SYM_GO;

  'H':
   If current_token = 'HIGH-VALUE'       Then current_symbol := SYM_HIGH_VALUE
   Else If current_token = 'HIGH-VALUES' Then current_symbol := SYM_HIGH_VALUES;

  'I':
   If current_token = 'IDENTIFICATION'   Then current_symbol := SYM_IDENTIFICATION
   Else If current_token = 'IF'          Then current_symbol := SYM_IF
   Else If current_token = 'IN'          Then current_symbol := SYM_IN
   Else If current_token = 'INDEXED'     Then current_symbol := SYM_INDEXED
   Else If current_token = 'INITIALIZE'  Then current_symbol := SYM_INITIALIZE
   Else If current_token = 'INPUT'       Then current_symbol := SYM_INPUT
   Else If current_token = 'INPUT-OUTPUT' Then current_symbol := SYM_INPUT_OUTPUT
   Else If current_token = 'INSPECT'     Then current_symbol := SYM_INSPECT
   Else If current_token = 'INSTALLATION' Then current_symbol := SYM_INSTALLATION
   Else If current_token = 'INTO'        Then current_symbol := SYM_INTO
   Else If current_token = 'INVALID'     Then current_symbol := SYM_INVALID
   Else If current_token = 'I-O'         Then current_symbol := SYM_IO
   Else If current_token = 'IS'          Then current_symbol := SYM_IS;

  'K':
   If current_token = 'KEY'              Then current_symbol := SYM_KEY;

  'L':
   If current_token = 'LEADING'          Then current_symbol := SYM_LEADING
   Else If current_token = 'LENGTH'      Then current_symbol := SYM_LENGTH
   Else If current_token = 'LESS'        Then current_symbol := SYM_LESS_KW
   Else If current_token = 'LINKAGE'     Then current_symbol := SYM_LINKAGE
   Else If current_token = 'LOCAL-STORAGE' Then current_symbol := SYM_LOCAL_STORAGE
   Else If current_token = 'LOCK'        Then current_symbol := SYM_LOCK
   Else If current_token = 'LOW-VALUE'   Then current_symbol := SYM_LOW_VALUE
   Else If current_token = 'LOW-VALUES'  Then current_symbol := SYM_LOW_VALUES;

  'M':
   If current_token = 'MERGE'            Then current_symbol := SYM_MERGE
   Else If current_token = 'MODE'        Then current_symbol := SYM_MODE
   Else If current_token = 'MOVE'        Then current_symbol := SYM_MOVE
   Else If current_token = 'MULTIPLY'    Then current_symbol := SYM_MULTIPLY_V;

  'N':
   If current_token = 'NATIVE'           Then current_symbol := SYM_NATIVE
   Else If current_token = 'NEGATIVE'    Then current_symbol := SYM_NEGATIVE
   Else If current_token = 'NEXT'        Then current_symbol := SYM_NEXT
   Else If current_token = 'NO'          Then current_symbol := SYM_NO
   Else If current_token = 'NOT'         Then current_symbol := SYM_NOT
   Else If current_token = 'NULL'        Then current_symbol := SYM_NULL_KW
   Else If current_token = 'NULLS'       Then current_symbol := SYM_NULLS
   Else If current_token = 'NUMERIC'     Then current_symbol := SYM_NUMERIC_KW;

  'O':
   If current_token = 'OBJECT-COMPUTER' Then current_symbol := SYM_OBJECT_COMPUTER
   Else If current_token = 'OCCURS'      Then current_symbol := SYM_OCCURS
   Else If current_token = 'OF'          Then current_symbol := SYM_OF
   Else If current_token = 'ON'          Then current_symbol := SYM_ON
   Else If current_token = 'OPEN'        Then current_symbol := SYM_OPEN
   Else If current_token = 'OR'          Then current_symbol := SYM_OR
   Else If current_token = 'ORGANIZATION' Then current_symbol := SYM_ORGANIZATION
   Else If current_token = 'OTHER'       Then current_symbol := SYM_OTHER
   Else If current_token = 'OUTPUT'      Then current_symbol := SYM_OUTPUT_KW
   Else If current_token = 'OVERFLOW'    Then current_symbol := SYM_OVERFLOW_KW;

  'P':
   If current_token = 'PACKED-DECIMAL'   Then current_symbol := SYM_PACKED_DECIMAL
   Else If current_token = 'PERFORM'     Then current_symbol := SYM_PERFORM
   Else If current_token = 'PIC'         Then current_symbol := SYM_PIC
   Else If current_token = 'PICTURE'     Then current_symbol := SYM_PICTURE
   Else If current_token = 'POINTER'     Then current_symbol := SYM_POINTER_KW
   Else If current_token = 'POSITIVE'    Then current_symbol := SYM_POSITIVE
   Else If current_token = 'PROCEDURE'   Then current_symbol := SYM_PROCEDURE
   Else If current_token = 'PROGRAM'     Then current_symbol := SYM_PROGRAM
   Else If current_token = 'PROGRAM-ID'  Then current_symbol := SYM_PROGRAM_ID;

  'Q':
   If current_token = 'QUOTE'            Then current_symbol := SYM_QUOTE_KW
   Else If current_token = 'QUOTES'      Then current_symbol := SYM_QUOTES;

  'R':
   If current_token = 'RANDOM'           Then current_symbol := SYM_RANDOM
   Else If current_token = 'READ'        Then current_symbol := SYM_READ
   Else If current_token = 'RECORD'      Then current_symbol := SYM_RECORD
   Else If current_token = 'REDEFINES'   Then current_symbol := SYM_REDEFINES
   Else If current_token = 'REFERENCE'   Then current_symbol := SYM_REFERENCE
   Else If current_token = 'RELATIVE'    Then current_symbol := SYM_RELATIVE
   Else If current_token = 'RELEASE'     Then current_symbol := SYM_RELEASE
   Else If current_token = 'REMAINDER'   Then current_symbol := SYM_REMAINDER
   Else If current_token = 'REPLACING'   Then current_symbol := SYM_REPLACING_KW
   Else If current_token = 'REPOSITORY'  Then current_symbol := SYM_REPOSITORY
   Else If current_token = 'RETURN'      Then current_symbol := SYM_RETURN_KW
   Else If current_token = 'REWRITE'     Then current_symbol := SYM_REWRITE
   Else If current_token = 'ROUNDED'     Then current_symbol := SYM_ROUNDED
   Else If current_token = 'RUN'         Then current_symbol := SYM_RUN;

  'S':
   If current_token = 'SCREEN'           Then current_symbol := SYM_SCREEN
   Else If current_token = 'SECTION'     Then current_symbol := SYM_SECTION
   Else If current_token = 'SECURITY'    Then current_symbol := SYM_SECURITY
   Else If current_token = 'SELECT'      Then current_symbol := SYM_SELECT
   Else If current_token = 'SENTENCE'    Then current_symbol := SYM_SENTENCE
   Else If current_token = 'SEQUENTIAL'  Then current_symbol := SYM_SEQUENTIAL
   Else If current_token = 'SET'         Then current_symbol := SYM_SET
   Else If current_token = 'SIZE'        Then current_symbol := SYM_SIZE
   Else If current_token = 'SORT'        Then current_symbol := SYM_SORT
   Else If current_token = 'SOURCE-COMPUTER' Then current_symbol := SYM_SOURCE_COMPUTER
   Else If current_token = 'SPACE'       Then current_symbol := SYM_SPACE
   Else If current_token = 'SPACES'      Then current_symbol := SYM_SPACES
   Else If current_token = 'SPECIAL-NAMES' Then current_symbol := SYM_SPECIAL_NAMES
   Else If current_token = 'STANDARD'    Then current_symbol := SYM_STANDARD
   Else If current_token = 'START'       Then current_symbol := SYM_START_KW
   Else If current_token = 'STATUS'      Then current_symbol := SYM_STATUS
   Else If current_token = 'STOP'        Then current_symbol := SYM_STOP
   Else If current_token = 'STRING'      Then current_symbol := SYM_STRING_KW
   Else If current_token = 'SUBTRACT'    Then current_symbol := SYM_SUBTRACT;

  'T':
   If current_token = 'TALLYING'         Then current_symbol := SYM_TALLYING
   Else If current_token = 'TEST'        Then current_symbol := SYM_TEST
   Else If current_token = 'THAN'        Then current_symbol := SYM_THAN
   Else If current_token = 'THEN'        Then current_symbol := SYM_THEN
   Else If current_token = 'THROUGH'     Then current_symbol := SYM_THROUGH
   Else If current_token = 'THRU'        Then current_symbol := SYM_THRU
   Else If current_token = 'TIMES'       Then current_symbol := SYM_TIMES
   Else If current_token = 'TO'          Then current_symbol := SYM_TO
   Else If current_token = 'TRAILING'    Then current_symbol := SYM_TRAILING
   Else If current_token = 'TRUE'        Then current_symbol := SYM_TRUE_KW;

  'U':
   If current_token = 'UNTIL'            Then current_symbol := SYM_UNTIL
   Else If current_token = 'UNSTRING'    Then current_symbol := SYM_UNSTRING
   Else If current_token = 'UP'          Then current_symbol := SYM_UP
   Else If current_token = 'UPON'        Then current_symbol := SYM_UPON
   Else If current_token = 'USAGE'       Then current_symbol := SYM_USAGE
   Else If current_token = 'USING'       Then current_symbol := SYM_USING;

  'V':
   If current_token = 'VALUE'            Then current_symbol := SYM_VALUE
   Else If current_token = 'VALUES'      Then current_symbol := SYM_VALUES
   Else If current_token = 'VARYING'     Then current_symbol := SYM_VARYING;

  'W':
   If current_token = 'WHEN'             Then current_symbol := SYM_WHEN
   Else If current_token = 'WITH'        Then current_symbol := SYM_WITH
   Else If current_token = 'WORKING-STORAGE' Then current_symbol := SYM_WORKING_STORAGE
   Else If current_token = 'WRITE'       Then current_symbol := SYM_WRITE;

  'Z':
   If current_token = 'ZERO'             Then current_symbol := SYM_ZERO
   Else If current_token = 'ZEROES'      Then current_symbol := SYM_ZEROES
   Else If current_token = 'ZEROS'       Then current_symbol := SYM_ZEROS;

 { Si aucun mot reserve ne correspond : reste TOK_WORD (identifiant user) }
 End; { Case }
End;

Procedure ReadWord;
Begin
 current_token := '';
 token_column  := line_pos;
 While ((current_char >= 'A') and (current_char <= 'Z')) or
       ((current_char >= 'a') and (current_char <= 'z')) or
       ((current_char >= '0') and (current_char <= '9')) or
       (current_char = '-') do
 Begin
  { Un tiret suivi d'un espace ou fin de ligne = operateur, pas partie du mot }
  If (current_char = '-') Then
  Begin
   If (PeekChar = ' ') or (PeekChar = #0) or
      (line_pos >= Length(source_line)) Then
    Break;
  End;
  current_token := current_token + current_char;
  NextChar;
 End;

 { Supprimer un eventuel tiret de fin (interdit par la norme) }
 While (Length(current_token) > 0) and
       (current_token[Length(current_token)] = '-') do
  Delete(current_token, Length(current_token), 1);

 current_token  := UpperStr(current_token);
 { Classifier comme mot reserve ou identifiant utilisateur }
 current_symbol := TOK_WORD;   { valeur par defaut }
 ClassifyReservedWord;          { peut surcharger current_symbol }
End;

{
  Lire un litteral numerique COBOL.
  Forme : chiffres [. chiffres]
}
Procedure ReadNumber;
Var
 temp : String;
 code : Integer;
Begin
 temp     := '';
 token_column := line_pos;

 While ((current_char >= '0') and (current_char <= '9')) do
 Begin
  temp := temp + current_char;
  NextChar;
 End;

 { Partie decimale }
 If (current_char = '.') and (PeekChar >= '0') and (PeekChar <= '9') Then
 Begin
  temp := temp + '.';
  NextChar;
  While ((current_char >= '0') and (current_char <= '9')) do
  Begin
   temp := temp + current_char;
   NextChar;
  End;
 End;

 current_token  := temp;
 current_symbol := TOK_NUMBER;
 Val(temp, current_value, code);
 If code <> 0 Then current_value := 0;
End;

{
  Lire un litteral chaine COBOL.
  Delimiteur : apostrophe (') ou guillemet (").
  Doublement du delimiteur = caracterel litteral dans la chaine.
  Continuation possible sur la ligne suivante (indicateur '-').
}
Procedure ReadString;
Var
 quote_char: Char;
 done      : Boolean;
Begin
 quote_char     := current_char;
 current_token  := '';
 current_symbol := TOK_STRING;
 token_column   := line_pos;
 NextChar; { Sauter le delimiteur ouvrant }

 done := False;
 While not done do
 Begin
  If current_char = #0 Then
  Begin
   Error('Fin de fichier dans un litteral chaine non ferme');
   done := True;
  End
  Else If (current_char = quote_char) Then
  Begin
   NextChar;
   If current_char = quote_char Then
   Begin
    current_token := current_token + quote_char;
    NextChar;
   End
   Else
    done := True;
  End
  Else If line_pos > Length(source_line) Then
  Begin
   If eof_reached Then
   Begin
    Error('Chaine non fermee avant fin de fichier');
    done := True;
   End
   Else
   Begin
    LoadNextLine;
    If indicator_char = IND_CONTINUE Then
    Begin
     While (current_char = ' ') or (current_char = #9) do
      NextChar;
     If current_char = quote_char Then
      NextChar
     Else
      done := True;
    End
    Else
    Begin
     Warning('Chaine non fermee sur la ligne - fermeture implicite');
     done := True;
    End;
   End;
  End
  Else
  Begin
   current_token := current_token + current_char;
   NextChar;
  End;
 End;
End;

{
  Obtenir le prochain token COBOL.
  Gere : mots, nombres, chaines, operateurs, et le point terminateur.
}
Procedure NextToken;
Begin
 SkipSpaces;

 If (current_char = #0) or eof_reached Then
 Begin
  current_token  := '';
  current_symbol := TOK_EOF;
  Exit;
 End;

 token_column := line_pos;

 { Mot (identifiant ou mot reserve) }
 If ((current_char >= 'A') and (current_char <= 'Z')) or
    ((current_char >= 'a') and (current_char <= 'z')) Then
 Begin
  ReadWord;
  Exit;
 End;

 { Nombre }
 If (current_char >= '0') and (current_char <= '9') Then
 Begin
  ReadNumber;
  Exit;
 End;

 { Litteral chaine }
 If (current_char = '''') or (current_char = '"') Then
 Begin
  ReadString;
  Exit;
 End;

 { Caracteres speciaux }
 Case current_char of
  '.':
   Begin
    If (PeekChar >= '0') and (PeekChar <= '9') Then
    Begin
     { Nombre commencant par un point decimal }
     current_token  := '0';
     current_symbol := TOK_NUMBER;
     current_value  := 0;
     NextChar;
     While (current_char >= '0') and (current_char <= '9') do
     Begin
      current_token := current_token + current_char;
      NextChar;
     End;
    End
    Else
    Begin
     current_token  := '.';
     current_symbol := TOK_PERIOD;
     NextChar;
    End;
   End;
  ',':
   Begin
    current_token := ','; current_symbol := TOK_COMMA; NextChar;
   End;
  ';':
   Begin
    current_token := ';'; current_symbol := TOK_SEMICOLON; NextChar;
   End;
  '(':
   Begin
    current_token := '('; current_symbol := TOK_LPAREN; NextChar;
   End;
  ')':
   Begin
    current_token := ')'; current_symbol := TOK_RPAREN; NextChar;
   End;
  '+':
   Begin
    current_token := '+'; current_symbol := TOK_PLUS; NextChar;
   End;
  '-':
   Begin
    current_token := '-'; current_symbol := TOK_MINUS; NextChar;
   End;
  '*':
   Begin
    NextChar;
    If current_char = '*' Then
    Begin
     current_token := '**'; current_symbol := TOK_POWER; NextChar;
    End
    Else
    Begin
     current_token := '*'; current_symbol := TOK_MULTIPLY;
    End;
   End;
  '/':
   Begin
    current_token := '/'; current_symbol := TOK_DIVIDE; NextChar;
   End;
  '=':
   Begin
    current_token := '='; current_symbol := TOK_EQUAL; NextChar;
   End;
  '<':
   Begin
    NextChar;
    If current_char = '=' Then
    Begin
     current_token := '<='; current_symbol := TOK_LESSEQ; NextChar;
    End
    Else If current_char = '>' Then
    Begin
     current_token := '<>'; current_symbol := TOK_NOTEQUAL; NextChar;
    End
    Else
    Begin
     current_token := '<'; current_symbol := TOK_LESS;
    End;
   End;
  '>':
   Begin
    NextChar;
    If current_char = '=' Then
    Begin
     current_token := '>='; current_symbol := TOK_GREATEREQ; NextChar;
    End
    Else
    Begin
     current_token := '>'; current_symbol := TOK_GREATER;
    End;
   End;
  ':':
   Begin
    current_token := ':'; current_symbol := TOK_COLON; NextChar;
   End;
 Else
  Error('Caractere inattendu: ''' + current_char + '''');
  current_token  := current_char;
  current_symbol := TOK_UNKNOWN;
  NextChar;
 End;
End;

{ ============================================================================ }
{ INITIALISATION DU TOKENISEUR                                                 }
{ ============================================================================ }

Procedure InitTokenizer;
Begin
 line_number     := 0;
 line_pos        := 1;
 current_char    := ' ';
 raw_line        := '';
 source_line     := '';
 indicator_char  := IND_NORMAL;
 in_continuation := False;
 cont_quote      := '''';
 current_token   := '';
 current_symbol  := TOK_UNKNOWN;
 current_value   := 0;
 token_column    := 0;
 error_count     := 0;
 eof_reached     := False;

 LoadNextLine;
 NextToken;
End;

{ ============================================================================ }
{ API PUBLIQUE DU TOKENISEUR                                                   }
{ ============================================================================ }

{ Vrai si le token courant est le mot (reserve ou identifiant) w }
Function TokenIs(w: String): Boolean;
Begin
 { On compare uniquement le texte : fonctionne pour les mots reserves
   (qui ont un SYM_xxx > TOK_WORD) et les identifiants utilisateur. }
 TokenIs := current_token = UpperStr(w);
End;

{ Vrai si le token courant est un identifiant utilisateur (pas un mot reserve) }
Function IsIdentifier: Boolean;
Begin
 IsIdentifier := current_symbol = TOK_WORD;
End;

{ ============================================================================ }
{ GESTION DE LA TABLE DES SYMBOLES                                             }
{ ============================================================================ }

{ ---- Utilitaires de noms ASM ---- }

{
  Convertir un nom COBOL en etiquette ASM valide.
  Regles : majuscules, tirets '-' -> '_', max 30 chars, prefixe de section.
  Ex: 'WS-NOM-CLIENT' -> 'WS_NOM_CLIENT'
      'DETAIL-RECORD' (FILE) -> 'FD_DETAIL_RECORD'
}
Function CobolNameToAsm(s: String; sect: Integer): String;
Var
 i: Integer;
 r: String;
Begin
 r := '';
 Case sect of
  SECT_WORKING_STORAGE: r := 'WS_';
  SECT_FILE:            r := 'FD_';
  SECT_LINKAGE:         r := 'LK_';
  SECT_LOCAL_STORAGE:   r := 'LS_';
 Else r := 'DT_';
 End;
 If s = 'FILLER' Then
 Begin
  { Les FILLER recoivent un label unique base sur data_count }
  Str(data_count, s);
  r := r + 'FILL_' + s;
  CobolNameToAsm := r;
  Exit;
 End;
 For i := 1 to Length(s) do
 Begin
  If s[i] = '-' Then r := r + '_'
  Else If ((s[i] >= 'A') and (s[i] <= 'Z')) or
           ((s[i] >= '0') and (s[i] <= '9')) Then r := r + s[i]
  Else r := r + '_';
 End;
 CobolNameToAsm := r;
End;

{ ---- Calcul de la taille d'un article ---- }

{
  Calculer la taille en octets d'un item selon son type PIC et son USAGE.

  USAGE DISPLAY (defaut) :
    PIC 9(n)    -> n octets (1 char par chiffre en zone decimale)
    PIC 9(n)V9(d) -> n+d octets
    PIC X(n)    -> n octets
    PIC A(n)    -> n octets
  USAGE COMP (BINARY) :
    1-4  chiffres  -> 2 octets (WORD)
    5-9  chiffres  -> 4 octets (DWORD) -- simplifie : on garde 2 (16 bits 8086)
  USAGE COMP-3 (PACKED) :
    (n+1) div 2 octets
}
Function CalcByteSize(dtype, usage, pic_digits, pic_decimals: Integer): Integer;
Var
 total_digits: Integer;
Begin
 total_digits := pic_digits + pic_decimals;
 Case usage of

  USAGE_COMP, USAGE_BINARY:
   Begin
    { 8086 : on utilise des WORD (2 octets) pour les nombres binaires }
    If total_digits <= 4 Then CalcByteSize := 2
    Else CalcByteSize := 4; { DWORD pour > 4 chiffres }
   End;

  USAGE_COMP_3:
   { PACKED-DECIMAL : (n+1) div 2 }
   CalcByteSize := (total_digits + 1) div 2;

 Else { USAGE_DISPLAY }
  Case dtype of
   TYPE_PIC_9, TYPE_PIC_S9:       CalcByteSize := pic_digits;
   TYPE_PIC_9V9, TYPE_PIC_S9V9:   CalcByteSize := total_digits;
   TYPE_PIC_X, TYPE_PIC_A:        CalcByteSize := pic_digits; { pic_digits = largeur X }
   TYPE_COND_88:                   CalcByteSize := 0; { Pas de stockage }
   TYPE_GROUP:                     CalcByteSize := 0; { Calcule apres agregation }
  Else CalcByteSize := 1;
  End;
 End;
End;

{ ---- Operations sur la table des articles ---- }

{ Ajouter un article de donnees ; retourne son index (1-base) }
Function AddDataItem(the_name: String; the_level, the_type, the_sect: Integer): Integer;
Var
 p: PDataItem;
Begin
 If data_count >= MAX_DATA_ITEMS Then
 Begin
  Error('Trop d''articles de donnees (max ' + Chr(Ord('0') + MAX_DATA_ITEMS div 1000) + '000)');
  AddDataItem := 0;
  Exit;
 End;
 New(p);
 Inc(data_count);
 data_table[data_count] := p;

 p^.name          := the_name;
 p^.level         := the_level;
 p^.data_type     := the_type;
 p^.usage         := USAGE_DISPLAY;
 p^.section       := the_sect;
 p^.parent        := 0;
 p^.is_group      := (the_type = TYPE_GROUP);
 p^.pic_str       := '';
 p^.pic_digits    := 0;
 p^.pic_decimals  := 0;
 p^.pic_size      := 0;
 p^.is_signed     := False;
 p^.byte_size     := 0;
 p^.offset        := 0;
 p^.occurs_count  := 0;
 p^.depends_on    := 0;
 p^.redefines_idx := 0;
 p^.has_value     := False;
 p^.val_type      := VALTYPE_NONE;
 p^.val_str       := '';
 p^.val_num       := 0;
 p^.has_thru      := False;
 p^.thru_str      := '';
 p^.thru_num      := 0;
 p^.asm_label     := CobolNameToAsm(the_name, the_sect);
 p^.file_idx      := 0;
 p^.defined       := False;

 AddDataItem := data_count;
End;

{
  Rechercher un article par nom (insensible a la casse).
  Si section_hint <> SECT_NONE, on cherche d'abord dans cette section.
  Retourne l'index 1-base ou 0 si non trouve.
}
Function FindDataItem(the_name: String; section_hint: Integer): Integer;
Var
 i, found_any: Integer;
Begin
 the_name  := UpperStr(the_name);
 found_any := 0;

 { Premier passage : chercher dans la section demandee }
 If section_hint <> SECT_NONE Then
  For i := 1 to data_count do
   If (data_table[i]^.name = the_name) and
      (data_table[i]^.section = section_hint) Then
   Begin
    FindDataItem := i;
    Exit;
   End;

 { Deuxieme passage : toutes les sections (premier trouve) }
 For i := 1 to data_count do
  If data_table[i]^.name = the_name Then
  Begin
   found_any := i;
   Break;
  End;

 FindDataItem := found_any;
End;

{
  Remonter la chaine de parents pour calculer l'indentation / la hierarchie.
  Retourne le niveau de profondeur (0 = article racine 01/77).
}
Function DataItemDepth(idx: Integer): Integer;
Var
 d: Integer;
Begin
 d := 0;
 While (idx > 0) and (data_table[idx]^.parent > 0) do
 Begin
  Inc(d);
  idx := data_table[idx]^.parent;
 End;
 DataItemDepth := d;
End;

{
  Apres avoir parse tous les items d'un groupe, calculer la taille du groupe
  comme la somme des tailles de ses enfants directs.
  Appeler a la fin de chaque article de groupe (quand on rencontre un item
  de niveau egal ou inferieur).
}
Procedure RecalcGroupSize(group_idx: Integer);
Var
 i, total: Integer;
Begin
 total := 0;
 For i := 1 to data_count do
  If data_table[i]^.parent = group_idx Then
  Begin
   If data_table[i]^.occurs_count > 0 Then
    Inc(total, data_table[i]^.byte_size * data_table[i]^.occurs_count)
   Else
    Inc(total, data_table[i]^.byte_size);
  End;
 data_table[group_idx]^.byte_size := total;
End;

{ ---- Operations sur la table des paragraphes ---- }

{ Ajouter un paragraphe ; retourne son index }
Function AddParagraph(the_name, the_section: String): Integer;
Var
 p: PParagraph;
Begin
 If para_count >= MAX_PARAGRAPHS Then
 Begin
  Error('Trop de paragraphes (max ' + Chr(Ord('0') + MAX_PARAGRAPHS div 100) + '00)');
  AddParagraph := 0;
  Exit;
 End;
 New(p);
 Inc(para_count);
 para_table[para_count] := p;
 Inc(next_para_id);

 p^.name         := UpperStr(the_name);
 p^.section_name := UpperStr(the_section);
 p^.label_id     := next_para_id;
 p^.defined      := False;

 AddParagraph := para_count;
End;

{ Rechercher un paragraphe par nom ; retourne index ou 0 }
Function FindParagraph(the_name: String): Integer;
Var
 i: Integer;
Begin
 the_name := UpperStr(the_name);
 For i := 1 to para_count do
  If para_table[i]^.name = the_name Then
  Begin
   FindParagraph := i;
   Exit;
  End;
 FindParagraph := 0;
End;

{ Retourner l'etiquette ASM d'un paragraphe (ex: PARA_0042) }
Function ParaAsmLabel(idx: Integer): String;
Var
 s: String;
Begin
 If (idx < 1) or (idx > para_count) Then
 Begin
  ParaAsmLabel := 'PARA_UNDEF';
  Exit;
 End;
 Str(para_table[idx]^.label_id, s);
 While Length(s) < 4 do s := '0' + s;
 ParaAsmLabel := 'PARA_' + s;
End;

{ ---- Fichiers (FILE SECTION) ---- }

{ Ajouter un fichier ; retourne son index }
Function AddFileEntry(the_name: String): Integer;
Var
 f: PFileEntry;
Begin
 If file_count >= MAX_FILES Then
 Begin
  Error('Trop de fichiers declares (max 50)');
  AddFileEntry := 0;
  Exit;
 End;
 New(f);
 Inc(file_count);
 file_table[file_count] := f;

 f^.name         := UpperStr(the_name);
 f^.assign_to    := '';
 f^.organization  := 0;
 f^.access_mode  := 0;
 f^.file_status  := '';
 f^.fd_item_idx  := 0;
 f^.handle_label := 'FH_' + UpperStr(the_name);
 f^.defined      := False;

 AddFileEntry := file_count;
End;

{ Rechercher un fichier par nom ; retourne index ou 0 }
Function FindFileEntry(the_name: String): Integer;
Var
 i: Integer;
Begin
 the_name := UpperStr(the_name);
 For i := 1 to file_count do
  If file_table[i]^.name = the_name Then
  Begin
   FindFileEntry := i;
   Exit;
  End;
 FindFileEntry := 0;
End;

{ ---- Initialisation ---- }

Procedure InitSymbolTable;
Begin
 data_count     := 0;
 data_offset    := 0;
 para_count     := 0;
 next_para_id   := 0;
 file_count     := 0;
 current_section:= SECT_NONE;
 program_name   := 'PROGRAM';
End;

{ ---- Debug : afficher la table des symboles (mode /S) ---- }

{ Creer une chaine de n espaces }
Function Spaces(n: Integer): String;
Var
 s: String;
 i: Integer;
Begin
 s := '';
 For i := 1 to n do s := s + ' ';
 Spaces := s;
End;

{ Cadrer une chaine a gauche dans un champ de largeur w }
Function PadR(s: String; w: Integer): String;
Begin
 While Length(s) < w do s := s + ' ';
 If Length(s) > w Then s := Copy(s, 1, w);
 PadR := s;
End;

Procedure DumpSymbolTable;
Const
 TYPE_NAMES: Array[0..7] of String[10] =
  ('GROUP','PIC9','PICS9','PICX','PICA','PIC9V9','PICS9V9','COND88');
 SECT_NAMES: Array[0..4] of String[8] =
  ('NONE','WRKSTG','FILE','LINK','LOCAL');
Var
 i: Integer;
 p: PDataItem;
 szs, offs: String;
Begin
 WriteLn('=== TABLE DES DONNEES (', data_count, ' articles) ===');
 WriteLn('Idx  Lv  Nom                    Type     Sect     Sz  Off  Asm-label');
 WriteLn('---- --  ---------------------- -------- -------- --  ---  ----------');
 For i := 1 to data_count do
 Begin
  p := data_table[i];
  Str(p^.byte_size, szs);
  Str(p^.offset, offs);
  WriteLn(i:4, ' ', p^.level:2, '  ',
          PadR(p^.name, 22),
          PadR(TYPE_NAMES[p^.data_type], 9),
          PadR(SECT_NAMES[p^.section], 9),
          PadR(szs, 4),
          PadR(offs, 5),
          p^.asm_label);
 End;
 WriteLn;
 WriteLn('=== PARAGRAPHES (', para_count, ') ===');
 For i := 1 to para_count do
  WriteLn(i:4, '  [', ParaAsmLabel(i), ']  ',
          PadR(para_table[i]^.name, 22),
          'section: ', para_table[i]^.section_name);
 WriteLn;
 WriteLn('=== FICHIERS (', file_count, ') ===');
 For i := 1 to file_count do
  WriteLn(i:4, '  ', PadR(file_table[i]^.name, 20),
          ' ASSIGN TO: ', file_table[i]^.assign_to);
End;

{ Consommer le token courant }
Procedure Consume;
Begin
 NextToken;
End;

{ Consommer un mot reserve, erreur si different }
Procedure Expect(w: String);
Begin
 If not TokenIs(w) Then
  Error('Attendu ''' + UpperStr(w) + ''', trouve ''' + current_token + '''')
 Else
  NextToken;
End;

{ Consommer un type de token specifique }
Procedure ExpectSym(sym: Integer; desc: String);
Begin
 If current_symbol <> sym Then
  Error('Attendu ' + desc + ', trouve ''' + current_token + '''')
 Else
  NextToken;
End;

{ Sauter jusqu'au prochain point terminateur (inclus) }
Procedure SkipToPeriod;
Begin
 While (current_symbol <> TOK_PERIOD) and (current_symbol <> TOK_EOF) do
  NextToken;
 If current_symbol = TOK_PERIOD Then NextToken;
End;

{ Sauter jusqu'au prochain mot w (inclus) }
Procedure SkipToWord(w: String);
Begin
 While not TokenIs(w) and (current_symbol <> TOK_EOF) do
  NextToken;
 If TokenIs(w) Then NextToken;
End;

{ ============================================================================ }
{ DEBOGAGE : DECHARGE DES TOKENS (mode /T)                                     }
{ ============================================================================ }

Function TokenTypeName(sym: Integer): String;
Begin
 Case sym of
  TOK_UNKNOWN        : TokenTypeName := 'UNKNOWN';
  TOK_WORD           : TokenTypeName := 'IDENT';
  TOK_NUMBER         : TokenTypeName := 'NOMBRE';
  TOK_STRING         : TokenTypeName := 'CHAINE';
  TOK_PERIOD         : TokenTypeName := 'POINT';
  TOK_COMMA          : TokenTypeName := 'VIRGULE';
  TOK_SEMICOLON      : TokenTypeName := 'POINTVIRGULE';
  TOK_LPAREN         : TokenTypeName := 'PARGAUCHE';
  TOK_RPAREN         : TokenTypeName := 'PARDROITE';
  TOK_PLUS           : TokenTypeName := 'PLUS';
  TOK_MINUS          : TokenTypeName := 'MOINS';
  TOK_MULTIPLY       : TokenTypeName := 'OP_MUL';
  TOK_DIVIDE         : TokenTypeName := 'OP_DIV';
  TOK_POWER          : TokenTypeName := 'PUISSANCE';
  TOK_EQUAL          : TokenTypeName := 'OP_EQ';
  TOK_LESS           : TokenTypeName := 'OP_INF';
  TOK_GREATER        : TokenTypeName := 'OP_SUP';
  TOK_LESSEQ         : TokenTypeName := 'OP_INF_EG';
  TOK_GREATEREQ      : TokenTypeName := 'OP_SUP_EG';
  TOK_NOTEQUAL       : TokenTypeName := 'OP_DIFF';
  TOK_COLON          : TokenTypeName := 'DEUXPOINTS';
  TOK_EOF            : TokenTypeName := 'FIN_FICHIER';
  { Mots reserves COBOL (100-299) }
  SYM_IDENTIFICATION : TokenTypeName := 'KW_IDENTIFICATION';
  SYM_ENVIRONMENT    : TokenTypeName := 'KW_ENVIRONMENT';
  SYM_DATA           : TokenTypeName := 'KW_DATA';
  SYM_PROCEDURE      : TokenTypeName := 'KW_PROCEDURE';
  SYM_DIVISION       : TokenTypeName := 'KW_DIVISION';
  SYM_SECTION        : TokenTypeName := 'KW_SECTION';
  SYM_PROGRAM_ID     : TokenTypeName := 'KW_PROGRAM-ID';
  SYM_AUTHOR         : TokenTypeName := 'KW_AUTHOR';
  SYM_WORKING_STORAGE: TokenTypeName := 'KW_WORKING-STORAGE';
  SYM_FILE_SEC       : TokenTypeName := 'KW_FILE';
  SYM_LINKAGE        : TokenTypeName := 'KW_LINKAGE';
  SYM_PIC            : TokenTypeName := 'KW_PIC';
  SYM_PICTURE        : TokenTypeName := 'KW_PICTURE';
  SYM_VALUE          : TokenTypeName := 'KW_VALUE';
  SYM_VALUES         : TokenTypeName := 'KW_VALUES';
  SYM_REDEFINES      : TokenTypeName := 'KW_REDEFINES';
  SYM_OCCURS         : TokenTypeName := 'KW_OCCURS';
  SYM_FILLER         : TokenTypeName := 'KW_FILLER';
  SYM_MOVE           : TokenTypeName := 'KW_MOVE';
  SYM_TO             : TokenTypeName := 'KW_TO';
  SYM_ADD            : TokenTypeName := 'KW_ADD';
  SYM_SUBTRACT       : TokenTypeName := 'KW_SUBTRACT';
  SYM_MULTIPLY_V     : TokenTypeName := 'KW_MULTIPLY';
  SYM_DIVIDE_V       : TokenTypeName := 'KW_DIVIDE';
  SYM_COMPUTE        : TokenTypeName := 'KW_COMPUTE';
  SYM_GIVING         : TokenTypeName := 'KW_GIVING';
  SYM_FROM           : TokenTypeName := 'KW_FROM';
  SYM_ROUNDED        : TokenTypeName := 'KW_ROUNDED';
  SYM_IF             : TokenTypeName := 'KW_IF';
  SYM_THEN           : TokenTypeName := 'KW_THEN';
  SYM_ELSE           : TokenTypeName := 'KW_ELSE';
  SYM_END_IF         : TokenTypeName := 'KW_END-IF';
  SYM_EVALUATE       : TokenTypeName := 'KW_EVALUATE';
  SYM_WHEN           : TokenTypeName := 'KW_WHEN';
  SYM_OTHER          : TokenTypeName := 'KW_OTHER';
  SYM_END_EVALUATE   : TokenTypeName := 'KW_END-EVALUATE';
  SYM_PERFORM        : TokenTypeName := 'KW_PERFORM';
  SYM_THRU           : TokenTypeName := 'KW_THRU';
  SYM_THROUGH        : TokenTypeName := 'KW_THROUGH';
  SYM_VARYING        : TokenTypeName := 'KW_VARYING';
  SYM_UNTIL          : TokenTypeName := 'KW_UNTIL';
  SYM_END_PERFORM    : TokenTypeName := 'KW_END-PERFORM';
  SYM_GO             : TokenTypeName := 'KW_GO';
  SYM_STOP           : TokenTypeName := 'KW_STOP';
  SYM_RUN            : TokenTypeName := 'KW_RUN';
  SYM_EXIT           : TokenTypeName := 'KW_EXIT';
  SYM_PROGRAM        : TokenTypeName := 'KW_PROGRAM';
  SYM_OPEN           : TokenTypeName := 'KW_OPEN';
  SYM_CLOSE          : TokenTypeName := 'KW_CLOSE';
  SYM_READ           : TokenTypeName := 'KW_READ';
  SYM_WRITE          : TokenTypeName := 'KW_WRITE';
  SYM_REWRITE        : TokenTypeName := 'KW_REWRITE';
  SYM_DISPLAY        : TokenTypeName := 'KW_DISPLAY';
  SYM_ACCEPT         : TokenTypeName := 'KW_ACCEPT';
  SYM_NOT            : TokenTypeName := 'KW_NOT';
  SYM_AND            : TokenTypeName := 'KW_AND';
  SYM_OR             : TokenTypeName := 'KW_OR';
  SYM_TRUE_KW        : TokenTypeName := 'KW_TRUE';
  SYM_FALSE_KW       : TokenTypeName := 'KW_FALSE';
  SYM_IS             : TokenTypeName := 'KW_IS';
  SYM_EQUAL_KW       : TokenTypeName := 'KW_EQUAL';
  SYM_GREATER_KW     : TokenTypeName := 'KW_GREATER';
  SYM_LESS_KW        : TokenTypeName := 'KW_LESS';
  SYM_THAN           : TokenTypeName := 'KW_THAN';
  SYM_ZERO           : TokenTypeName := 'KW_ZERO';
  SYM_ZEROS          : TokenTypeName := 'KW_ZEROS';
  SYM_ZEROES         : TokenTypeName := 'KW_ZEROES';
  SYM_SPACE          : TokenTypeName := 'KW_SPACE';
  SYM_SPACES         : TokenTypeName := 'KW_SPACES';
  SYM_HIGH_VALUE     : TokenTypeName := 'KW_HIGH-VALUE';
  SYM_HIGH_VALUES    : TokenTypeName := 'KW_HIGH-VALUES';
  SYM_LOW_VALUE      : TokenTypeName := 'KW_LOW-VALUE';
  SYM_LOW_VALUES     : TokenTypeName := 'KW_LOW-VALUES';
  SYM_INTO           : TokenTypeName := 'KW_INTO';
  SYM_OF             : TokenTypeName := 'KW_OF';
  SYM_IN             : TokenTypeName := 'KW_IN';
  SYM_BY             : TokenTypeName := 'KW_BY';
  SYM_ON             : TokenTypeName := 'KW_ON';
  SYM_AT             : TokenTypeName := 'KW_AT';
  SYM_CALL           : TokenTypeName := 'KW_CALL';
  SYM_USING          : TokenTypeName := 'KW_USING';
  SYM_SET            : TokenTypeName := 'KW_SET';
  SYM_INITIALIZE     : TokenTypeName := 'KW_INITIALIZE';
  SYM_SELECT         : TokenTypeName := 'KW_SELECT';
  SYM_ASSIGN         : TokenTypeName := 'KW_ASSIGN';
  SYM_ORGANIZATION   : TokenTypeName := 'KW_ORGANIZATION';
  SYM_SEQUENTIAL     : TokenTypeName := 'KW_SEQUENTIAL';
  SYM_ALL            : TokenTypeName := 'KW_ALL';
  SYM_STRING_KW      : TokenTypeName := 'KW_STRING';
  SYM_UNSTRING       : TokenTypeName := 'KW_UNSTRING';
  SYM_INSPECT        : TokenTypeName := 'KW_INSPECT';
 Else
  If sym >= 100 Then TokenTypeName := 'KW_RESERVE'
  Else TokenTypeName := '???';
 End;
End;

Procedure DumpTokens;
Begin
 WriteLn('=== DECHARGE DES TOKENS COBOL ===');
 WriteLn('Format: [ligne:col] TYPE  "valeur"');
 WriteLn;
 While current_symbol <> TOK_EOF do
 Begin
  WriteLn('[', line_number:4, ':', (token_column + COL_INDICATOR):2, '] ',
          TokenTypeName(current_symbol), #9,
          '"', current_token, '"');
  NextToken;
 End;
 WriteLn;
 WriteLn('=== FIN DECHARGE ===');
End;

{ ============================================================================ }
{ PROGRAMME PRINCIPAL                                                          }
{ ============================================================================ }

Procedure ShowHelp;
Begin
 WriteLn(VERSION, ' - Compilateur COBOL pour 8086/8088');
 WriteLn;
 WriteLn('Syntaxe: COBOL86 [options] <fichier.cbl> [fichier.asm]');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  /T   Decharge des tokens (debug tokeniseur)');
 WriteLn('  /S   Decharge la table des symboles (debug parseur)');
 WriteLn('  /?   Afficher cette aide');
 WriteLn;
 WriteLn('Exemples:');
 WriteLn('  COBOL86 HELLO.CBL');
 WriteLn('  COBOL86 HELLO.CBL HELLO.ASM');
 WriteLn('  COBOL86 /T HELLO.CBL');
End;

Var
 i            : Integer;
 opt_dump_tok : Boolean;
 opt_dump_sym : Boolean;
 arg          : String;

Begin
 opt_dump_tok    := False;
 opt_dump_sym    := False;
 source_filename := '';
 output_filename := '';

 For i := 1 to ParamCount do
 Begin
  arg := ParamStr(i);
  If (arg = '/?') or (arg = '-h') or (arg = '--help') Then
  Begin
   ShowHelp;
   Halt(0);
  End
  Else If (UpperStr(arg) = '/T') or (UpperStr(arg) = '-T') Then
   opt_dump_tok := True
  Else If (UpperStr(arg) = '/S') or (UpperStr(arg) = '-S') Then
   opt_dump_sym := True
  Else If source_filename = '' Then
   source_filename := arg
  Else If output_filename = '' Then
   output_filename := arg;
 End;

 If source_filename = '' Then
 Begin
  ShowHelp;
  Halt(1);
 End;

 { Nom de sortie par defaut : meme nom, extension .ASM }
 If output_filename = '' Then
 Begin
  output_filename := source_filename;
  i := Length(output_filename);
  While (i > 0) and (output_filename[i] <> '.') and
        (output_filename[i] <> '\') and (output_filename[i] <> '/') do
   Dec(i);
  If (i > 0) and (output_filename[i] = '.') Then
   output_filename := Copy(output_filename, 1, i - 1) + '.ASM'
  Else
   output_filename := output_filename + '.ASM';
 End;

 { Ouvrir le fichier source }
 Assign(input_file, source_filename);
 Reset(input_file);
 If IOResult <> 0 Then
 Begin
  WriteLn('ERREUR: Impossible d''ouvrir le fichier: ', source_filename);
  Halt(1);
 End;

 WriteLn(VERSION, ' - Compilation de: ', source_filename);

 InitSymbolTable;
 InitTokenizer;

 If opt_dump_tok Then
 Begin
  DumpTokens;
  Close(input_file);
  WriteLn('Termine. Erreurs: ', error_count);
  Halt(0);
 End;

 { TODO: Appel au parseur principal (prochaines etapes) }
 WriteLn('INFO: Parseur non encore implemente.');

 If opt_dump_sym Then DumpSymbolTable;

 Close(input_file);
 WriteLn('Termine. Erreurs: ', error_count);
 If error_count > 0 Then Halt(1);
END.