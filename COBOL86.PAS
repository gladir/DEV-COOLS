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
 { Supplementaires (> 299) }
 SYM_FD            = 300; { FD (File Description)   }
 SYM_COMP_3        = 301; { COMP-3 / COMPUTATIONAL-3 }

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
 VALTYPE_ALL      = 11; { ALL literal        }

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
   Else If current_token = 'COMP'           Then current_symbol := SYM_COMP
   Else If current_token = 'COMP-3'         Then current_symbol := SYM_COMP_3
   Else If current_token = 'COMP-1'         Then current_symbol := SYM_COMP
   Else If current_token = 'COMP-2'         Then current_symbol := SYM_COMP
   Else If current_token = 'COMPUTATIONAL'  Then current_symbol := SYM_COMPUTATIONAL
   Else If current_token = 'COMPUTATIONAL-3' Then current_symbol := SYM_COMP_3
   Else If current_token = 'COMPUTE'        Then current_symbol := SYM_COMPUTE
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
   If current_token = 'FD'              Then current_symbol := SYM_FD
   Else If current_token = 'FALSE'      Then current_symbol := SYM_FALSE_KW
   Else If current_token = 'FILE'       Then current_symbol := SYM_FILE_SEC
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

{ ============================================================================ }
{ PARSEUR IDENTIFICATION DIVISION                                              }
{ ============================================================================ }

{
  Grammaire simplifiee de l'IDENTIFICATION DIVISION (COBOL-85) :

    IDENTIFICATION DIVISION .
    PROGRAM-ID . program-name [ IS [ INITIAL ] PROGRAM ] .
    [ AUTHOR . text-words* . ]
    [ INSTALLATION . text-words* . ]
    [ DATE-WRITTEN . text-words* . ]
    [ DATE-COMPILED . text-words* . ]
    [ SECURITY . text-words* . ]

  Tous les paragraphes apres PROGRAM-ID sont optionnels et leur contenu
  est libre (texte commentaire) : on les lit jusqu'au prochain point.
  La fin de la division est detectee quand le token courant est :
    - ENVIRONMENT ou DATA ou PROCEDURE (le debut de la division suivante)
    - ou EOF.
}

Procedure ParseIdentificationDivision;
Begin

 { --- En-tete IDENTIFICATION DIVISION . --- }
 { On arrive ici avec current_token = 'IDENTIFICATION' }
 Consume; { IDENTIFICATION }

 If current_symbol <> SYM_DIVISION Then
  Error('Attendu DIVISION apres IDENTIFICATION, trouve ''' + current_token + '''')
 Else
  Consume; { DIVISION }

 If current_symbol <> TOK_PERIOD Then
  Error('Attendu ''.'' apres IDENTIFICATION DIVISION, trouve ''' + current_token + '''')
 Else
  Consume; { . }

 { --- PROGRAM-ID . program-name . --- }
 If current_symbol <> SYM_PROGRAM_ID Then
 Begin
  Error('Attendu PROGRAM-ID, trouve ''' + current_token + '''');
  SkipToPeriod;
 End
 Else
 Begin
  Consume; { PROGRAM-ID }

  If current_symbol <> TOK_PERIOD Then
   Error('Attendu ''.'' apres PROGRAM-ID, trouve ''' + current_token + '''')
  Else
   Consume; { . }

  { Nom du programme : identifiant ou mot reserve utilise comme nom }
  If (current_symbol = TOK_WORD) or (current_symbol >= 100) Then
  Begin
   program_name := current_token;
   Consume;
  End
  Else
   Error('Attendu un nom de programme, trouve ''' + current_token + '''');

  { Clause optionnelle : IS [INITIAL] PROGRAM }
  If current_symbol = SYM_IS Then
  Begin
   Consume; { IS }
   { INITIAL optionnel }
   If TokenIs('INITIAL') Then Consume;
   If current_symbol = SYM_PROGRAM Then
    Consume { PROGRAM }
   Else
    Error('Attendu PROGRAM dans IS [INITIAL] PROGRAM');
  End;

  { Le point terminateur de PROGRAM-ID }
  If current_symbol <> TOK_PERIOD Then
   Error('Attendu ''.'' apres le nom du programme, trouve ''' + current_token + '''')
  Else
   Consume; { . }
 End;

 { --- Paragraphes optionnels (contenu libre jusqu'au '.') --- }
 While True do
 Begin
  { Detection de fin de division }
  If (current_symbol = SYM_ENVIRONMENT) or
     (current_symbol = SYM_DATA)        or
     (current_symbol = SYM_PROCEDURE)   or
     (current_symbol = TOK_EOF) Then
   Break;

  { Paragraphes reconnus : on ignore leur contenu (commentaires COBOL) }
  If (current_symbol = SYM_AUTHOR)       or
     (current_symbol = SYM_INSTALLATION) or
     (current_symbol = SYM_DATE_WRITTEN) or
     (current_symbol = SYM_DATE_COMPILED)or
     (current_symbol = SYM_SECURITY)     Then
  Begin
   Consume; { nom du paragraphe }
   { Consommer le '.' apres le nom du paragraphe }
   If current_symbol = TOK_PERIOD Then Consume;
   { Lire le contenu (texte libre) jusqu'au prochain '.' }
   SkipToPeriod;
  End
  Else
  Begin
   { Token inattendu dans IDENTIFICATION DIVISION }
   Warning('Paragraphe inconnu dans IDENTIFICATION DIVISION: ''' + current_token + '''');
   SkipToPeriod;
  End;
 End;

 WriteLn('INFO: IDENTIFICATION DIVISION parsed. PROGRAM-ID = ', program_name);
End;

{ ============================================================================ }
{ PARSEUR ENVIRONMENT DIVISION                                                 }
{ ============================================================================ }

{
  Grammaire de l'ENVIRONMENT DIVISION (COBOL-85) :

    ENVIRONMENT DIVISION .
      [ CONFIGURATION SECTION .
          [ SOURCE-COMPUTER . computer-name [WITH DEBUGGING MODE] . ]
          [ OBJECT-COMPUTER  . computer-name
              [ MEMORY SIZE n (WORDS|CHARACTERS|MODULES) ]
              [ PROGRAM COLLATING SEQUENCE IS alphabet-name ] . ]
          [ SPECIAL-NAMES .
              [ implementor-name IS mnemonic-name ]
              [ DECIMAL-POINT IS COMMA ] ... ] ]
      [ INPUT-OUTPUT SECTION .
          [ FILE-CONTROL .
              ( SELECT [OPTIONAL] file-name
                ASSIGN TO implementor-name-or-literal
                [ORGANIZATION IS (SEQUENTIAL|RANDOM|RELATIVE)]
                [ACCESS MODE IS (SEQUENTIAL|RANDOM|DYNAMIC)]
                [RELATIVE KEY IS data-name]
                [FILE STATUS IS data-name] . )... ] ]

  On arrive ici avec current_token = 'ENVIRONMENT'.
  La FILE-CONTROL est la seule partie qui alimente la table des symboles
  (file_table). Tout le reste est lu et ignore ou stocke a titre informatif.
}

{ Consommer un identifiant ou un mot reserve quelconque (nom libre COBOL) }
Function ParseWordOrReserved: String;
Begin
 If (current_symbol = TOK_WORD) or (current_symbol >= 100) Then
 Begin
  ParseWordOrReserved := current_token;
  Consume;
 End
 Else
 Begin
  Error('Attendu un identifiant, trouve ''' + current_token + '''');
  ParseWordOrReserved := '';
 End;
End;

{ ---- CONFIGURATION SECTION ---- }

Procedure ParseConfigurationSection;
Begin
 { On arrive apres 'CONFIGURATION SECTION .' }

 { SOURCE-COMPUTER optionnel }
 If current_symbol = SYM_SOURCE_COMPUTER Then
 Begin
  Consume; { SOURCE-COMPUTER }
  If current_symbol = TOK_PERIOD Then Consume; { . }
  { Nom de l'ordinateur source (libre) }
  While (current_symbol <> TOK_PERIOD) and (current_symbol <> TOK_EOF) and
        (current_symbol <> SYM_OBJECT_COMPUTER) and
        (current_symbol <> SYM_SPECIAL_NAMES) do
   Consume;
  If current_symbol = TOK_PERIOD Then Consume;
 End;

 { OBJECT-COMPUTER optionnel }
 If current_symbol = SYM_OBJECT_COMPUTER Then
 Begin
  Consume; { OBJECT-COMPUTER }
  If current_symbol = TOK_PERIOD Then Consume; { . }
  { Tout jusqu'au prochain point : MEMORY SIZE, COLLATING SEQUENCE... }
  SkipToPeriod;
 End;

 { SPECIAL-NAMES optionnel }
 If current_symbol = SYM_SPECIAL_NAMES Then
 Begin
  Consume; { SPECIAL-NAMES }
  If current_symbol = TOK_PERIOD Then Consume; { . }
  { Lire les clauses jusqu'a la prochaine section ou fin de division }
  While (current_symbol <> SYM_INPUT_OUTPUT) and
        (current_symbol <> SYM_FILE_CONTROL) and
        (current_symbol <> SYM_DATA)         and
        (current_symbol <> SYM_PROCEDURE)    and
        (current_symbol <> TOK_EOF) do
  Begin
   { Clause DECIMAL-POINT IS COMMA : noter mais non implemente ici }
   If current_symbol = SYM_DECIMAL_POINT Then
   Begin
    Consume; { DECIMAL-POINT }
    If current_symbol = SYM_IS Then Consume; { IS }
    If TokenIs('COMMA') Then
    Begin
     Consume;
     Warning('DECIMAL-POINT IS COMMA non supporte - ignore');
    End;
    If current_symbol = TOK_PERIOD Then Consume;
   End
   Else
   Begin
    { Toute autre clause SPECIAL-NAMES : ignorer jusqu'au '.' }
    SkipToPeriod;
   End;
  End;
 End;
End;

{ ---- FILE-CONTROL : SELECT ... ASSIGN ... ---- }

Procedure ParseFileControl;
Var
 fname : String;
 fidx  : Integer;
 org   : Integer; { 0=sequential,1=random,2=relative }
 acc   : Integer; { 0=sequential,1=random,2=dynamic }
 fstat : String;
Begin
 { On arrive apres 'FILE-CONTROL .' }

 { Boucle sur les clauses SELECT (une par fichier) }
 While (current_symbol <> SYM_DATA)      and
       (current_symbol <> SYM_PROCEDURE) and
       (current_symbol <> TOK_EOF)       and
       not ((current_symbol = SYM_INPUT_OUTPUT) or
            TokenIs('SORT-MERGE')) do
 Begin

  If current_symbol <> SYM_SELECT Then
  Begin
   { Token inattendu dans FILE-CONTROL }
   Warning('Attendu SELECT dans FILE-CONTROL, trouve ''' + current_token + '''');
   SkipToPeriod;
   Continue;
  End;
  Consume; { SELECT }

  { OPTIONAL optionnel }
  If TokenIs('OPTIONAL') Then Consume;

  { Nom logique du fichier }
  fname := ParseWordOrReserved;
  If fname = '' Then Begin SkipToPeriod; Continue; End;

  org  := 0;  { defaut SEQUENTIAL }
  acc  := 0;
  fstat := '';

  { Ajouter a la table des fichiers }
  fidx := FindFileEntry(fname);
  If fidx = 0 Then
   fidx := AddFileEntry(fname);

  { Clauses SELECT jusqu'au point terminateur }
  While (current_symbol <> TOK_PERIOD) and (current_symbol <> TOK_EOF) do
  Begin

   { ASSIGN TO ... }
   If current_symbol = SYM_ASSIGN Then
   Begin
    Consume; { ASSIGN }
    If current_symbol = SYM_TO Then Consume; { TO optionnel }
    { Nom physique : identifiant ou chaine litterale }
    If current_symbol = TOK_STRING Then
    Begin
     file_table[fidx]^.assign_to := current_token;
     Consume;
    End
    Else If (current_symbol = TOK_WORD) or (current_symbol >= 100) Then
    Begin
     file_table[fidx]^.assign_to := current_token;
     Consume;
     { Peut etre suivi d'un tiret : ex 'DISK' tout comme un mot }
    End
    Else
    Begin
     Error('Attendu nom ou chaine apres ASSIGN TO');
     SkipToPeriod;
     Continue;
    End;
   End

   { ORGANIZATION IS ... }
   Else If current_symbol = SYM_ORGANIZATION Then
   Begin
    Consume; { ORGANIZATION }
    If current_symbol = SYM_IS Then Consume; { IS }
    If current_symbol = SYM_SEQUENTIAL Then Begin org := 0; Consume; End
    Else If current_symbol = SYM_RANDOM    Then Begin org := 1; Consume; End
    Else If current_symbol = SYM_RELATIVE  Then Begin org := 2; Consume; End
    Else Begin Warning('Organisation inconnue : ' + current_token); Consume; End;
    file_table[fidx]^.organization := org;
   End

   { ACCESS MODE IS ... }
   Else If current_symbol = SYM_ACCESS Then
   Begin
    Consume; { ACCESS }
    If current_symbol = SYM_MODE Then Consume; { MODE }
    If current_symbol = SYM_IS   Then Consume; { IS }
    If current_symbol = SYM_SEQUENTIAL Then Begin acc := 0; Consume; End
    Else If current_symbol = SYM_RANDOM   Then Begin acc := 1; Consume; End
    Else If current_symbol = SYM_DYNAMIC  Then Begin acc := 2; Consume; End
    Else Begin Warning('Mode acces inconnu : ' + current_token); Consume; End;
    file_table[fidx]^.access_mode := acc;
   End

   { FILE STATUS IS data-name }
   Else If current_symbol = SYM_FILE_STATUS Then
   Begin
    Consume; { FILE-STATUS }
    If current_symbol = SYM_IS Then Consume; { IS }
    fstat := ParseWordOrReserved;
    file_table[fidx]^.file_status := fstat;
   End

   { RELATIVE KEY IS data-name : noter, ignorer pour l'instant }
   Else If TokenIs('RELATIVE') Then
   Begin
    Consume; { RELATIVE }
    If current_symbol = SYM_KEY Then Consume; { KEY }
    If current_symbol = SYM_IS  Then Consume; { IS }
    ParseWordOrReserved; { data-name, valeur ignoree ici }
   End

   { RECORD DELIMITER, PADDING CHARACTER, etc. : ignorer }
   Else
    Consume;

  End; { While pas de '.' }

  If current_symbol = TOK_PERIOD Then Consume; { . fin de SELECT }
  file_table[fidx]^.defined := True;

 End; { While SELECT }
End;

{ ---- INPUT-OUTPUT SECTION ---- }

Procedure ParseInputOutputSection;
Begin
 { On arrive apres 'INPUT-OUTPUT SECTION .' }

 { FILE-CONTROL optionnel }
 If current_symbol = SYM_FILE_CONTROL Then
 Begin
  Consume; { FILE-CONTROL }
  If current_symbol = TOK_PERIOD Then Consume; { . }
  ParseFileControl;
 End;

 { SORT-MERGE FILE CONTROL (non supporte, sauter) }
 If TokenIs('I-O-CONTROL') Then
 Begin
  Warning('I-O-CONTROL non supporte - ignore');
  SkipToWord('SECTION');
  SkipToPeriod;
 End;
End;

{ ---- Parseur principal ENVIRONMENT DIVISION ---- }

Procedure ParseEnvironmentDivision;
Var
 nb_files: Integer;
 i       : Integer;
Begin
 { On arrive ici avec current_token = 'ENVIRONMENT' }
 Consume; { ENVIRONMENT }

 If current_symbol <> SYM_DIVISION Then
  Error('Attendu DIVISION apres ENVIRONMENT, trouve ''' + current_token + '''')
 Else
  Consume; { DIVISION }

 If current_symbol <> TOK_PERIOD Then
  Error('Attendu ''.'' apres ENVIRONMENT DIVISION')
 Else
  Consume; { . }

 { --- CONFIGURATION SECTION (optionnelle) --- }
 If current_symbol = SYM_CONFIGURATION Then
 Begin
  Consume; { CONFIGURATION }
  If current_symbol = SYM_SECTION Then Consume; { SECTION }
  If current_symbol = TOK_PERIOD  Then Consume; { . }
  ParseConfigurationSection;
 End;

 { --- INPUT-OUTPUT SECTION (optionnelle) --- }
 If current_symbol = SYM_INPUT_OUTPUT Then
 Begin
  Consume; { INPUT-OUTPUT }
  If current_symbol = SYM_SECTION Then Consume; { SECTION }
  If current_symbol = TOK_PERIOD  Then Consume; { . }
  ParseInputOutputSection;
 End;

 { Compter les fichiers declares et afficher le bilan }
 nb_files := file_count;
 WriteLn('INFO: ENVIRONMENT DIVISION parsed. Fichiers declares: ', nb_files);
 For i := 1 to nb_files do
  WriteLn('INFO:   FILE ', i, ' = ', file_table[i]^.name,
          ' ASSIGN TO ', file_table[i]^.assign_to);
End;

{ =====================================================================
  PARSER - DATA DIVISION
  ===================================================================== }

{ Lit et reconstruit la chaine PIC a partir des tokens suivants.
  S'arrete sur un mot-cle de clause ou un point terminal. }
Function ReadPicString: String;
Var
 pic  : String;
 done : Boolean;
Begin
 pic  := '';
 done := False;
 Repeat
  Case current_symbol Of
   TOK_WORD:
    Begin
     { Arret sur mots-cles qui debutent une nouvelle clause }
     If (current_symbol = SYM_VALUE)    Or (current_symbol = SYM_VALUES)   Or
        (current_symbol = SYM_USAGE)    Or (current_symbol = SYM_OCCURS)   Or
        (current_symbol = SYM_REDEFINES) Or (current_symbol = SYM_BLANK)   Or
        (current_symbol = SYM_IS)       Or (current_symbol = SYM_ARE)      Or
        (current_symbol = SYM_GLOBAL)   Or (current_symbol = SYM_EXTERNAL) Or
        TokenIs('JUSTIFIED') Or TokenIs('JUST')  Or
        TokenIs('SIGN')      Or TokenIs('SYNCHRONIZED') Or TokenIs('SYNC') Then
      done := True
     Else
     Begin
      pic := pic + current_token;
      Consume;
     End;
    End;
   TOK_LPAREN : Begin pic := pic + '('; Consume; End;
   TOK_RPAREN : Begin pic := pic + ')'; Consume; End;
   TOK_NUMBER : Begin pic := pic + current_token; Consume; End;
   TOK_PERIOD : done := True;
   TOK_EOF    : done := True;
   Else         done := True;
  End;
 Until done;
 ReadPicString := pic;
End;

{ Analyse la chaine PIC brute (item.pic_str) et remplit les champs
  data_type, pic_digits, pic_decimals, pic_size, is_signed, byte_size. }
Procedure AnalyzePicString(Var item : TDataItem);
Var
 pic   : String;
 i, n  : Integer;
 ch    : Char;
 afterV: Boolean;
 base  : Char;
Begin
 pic    := item.pic_str;
 i      := 1;
 afterV := False;
 base   := ' ';
 item.pic_digits   := 0;
 item.pic_decimals := 0;
 item.is_signed    := False;
 { S initial = numerique signe }
 If (Length(pic) >= 1) And (pic[1] = 'S') Then
 Begin item.is_signed := True; i := 2; End;
 While i <= Length(pic) Do
 Begin
  ch := pic[i];
  n  := 1;
  { Lire le repeteur (n) si '(' suit immediatement }
  If (i < Length(pic)) And (pic[i + 1] = '(') Then
  Begin
   n := 0;
   i := i + 2; { sauter 'ch' et '(' }
   While (i <= Length(pic)) And (pic[i] <> ')') Do
   Begin n := n * 10 + Ord(pic[i]) - 48; i := i + 1; End;
   { i pointe sur ')' ; l'increment en bas le sautera }
  End;
  Case ch Of
   '9', 'Z', '0', '+', '-', '*':
    Begin
     If afterV Then item.pic_decimals := item.pic_decimals + n
     Else           item.pic_digits   := item.pic_digits   + n;
     If base = ' ' Then base := '9';
    End;
   'X': Begin item.pic_digits := item.pic_digits + n; base := 'X'; End;
   'A': Begin item.pic_digits := item.pic_digits + n; base := 'A'; End;
   'V', '.': afterV := True;
   'P': ; { facteur d'echelle, ignore }
   Else  ; { B, /, CR, DB, etc. ignore }
  End;
  i := i + 1;
 End;
 item.pic_size := item.pic_digits + item.pic_decimals;
 { Determiner le type de donnee }
 If base = 'X' Then      item.data_type := TYPE_PIC_X
 Else If base = 'A' Then item.data_type := TYPE_PIC_A
 Else If item.pic_decimals > 0 Then
 Begin
  If item.is_signed Then item.data_type := TYPE_PIC_S9V9
  Else                   item.data_type := TYPE_PIC_9V9;
 End
 Else
 Begin
  If item.is_signed Then item.data_type := TYPE_PIC_S9
  Else                   item.data_type := TYPE_PIC_9;
 End;
 item.byte_size := CalcByteSize(item.data_type, item.usage,
                                item.pic_digits, item.pic_decimals);
End;

{ Retourne le niveau COBOL du token courant (01..49, 66, 77, 88)
  ou 0 si ce n'est pas un niveau valide. Ne consomme pas le token. }
Function PeekLevel: Integer;
Var
 v : Integer;
Begin
 PeekLevel := 0;
 If current_symbol <> TOK_NUMBER Then Exit;
 v := Integer(current_value);
 If ((v >= 1) And (v <= 49)) Or (v = 66) Or (v = 77) Or (v = 88) Then
  PeekLevel := v;
End;

{ Parse les clauses d'un element de donnees deja cree.
  Modifie directement les champs de item via reference.
  S'arrete sur le point terminal ou EOF. }
Procedure ParseDataItemClauses(Var item : TDataItem);
Begin
 While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do
 Begin
  { ---- PIC / PICTURE [IS] string ---- }
  If (current_symbol = SYM_PIC) Or (current_symbol = SYM_PICTURE) Then
  Begin
   Consume; { PIC ou PICTURE }
   If current_symbol = SYM_IS Then Consume;
   item.pic_str := ReadPicString;
   AnalyzePicString(item);
  End

  { ---- USAGE [IS] ... ---- }
  Else If current_symbol = SYM_USAGE Then
  Begin
   Consume;
   If current_symbol = SYM_IS Then Consume;
   If current_symbol = SYM_DISPLAY Then
    Begin item.usage := USAGE_DISPLAY; Consume; End
   Else If (current_symbol = SYM_COMP) Or (current_symbol = SYM_COMPUTATIONAL) Then
    Begin item.usage := USAGE_COMP; Consume; End
   Else If (current_symbol = SYM_COMP_3) Or (current_symbol = SYM_PACKED_DECIMAL) Then
    Begin item.usage := USAGE_COMP_3; Consume; End
   Else If current_symbol = SYM_BINARY Then
    Begin item.usage := USAGE_BINARY; Consume; End
   Else Consume;
  End

  { ---- COMP / COMP-3 / BINARY / DISPLAY directement (sans USAGE) ---- }
  Else If (current_symbol = SYM_COMP) Or (current_symbol = SYM_COMPUTATIONAL) Then
   Begin item.usage := USAGE_COMP; Consume; End
  Else If (current_symbol = SYM_COMP_3) Or (current_symbol = SYM_PACKED_DECIMAL) Then
   Begin item.usage := USAGE_COMP_3; Consume; End
  Else If current_symbol = SYM_BINARY Then
   Begin item.usage := USAGE_BINARY; Consume; End
  Else If current_symbol = SYM_DISPLAY Then
   Begin item.usage := USAGE_DISPLAY; Consume; End

  { ---- OCCURS n [TO m] [TIMES] [DEPENDING ON var] [INDEXED BY ...] ---- }
  Else If current_symbol = SYM_OCCURS Then
  Begin
   Consume;
   If current_symbol = TOK_NUMBER Then
   Begin item.occurs_count := Integer(current_value); Consume; End;
   If current_symbol = SYM_TO Then
   Begin Consume; If current_symbol = TOK_NUMBER Then Consume; End;
   If current_symbol = SYM_TIMES Then Consume;
   If current_symbol = SYM_DEPENDING Then
   Begin
    Consume;
    If current_symbol = SYM_ON Then Consume;
    If IsIdentifier Then Consume; { nom de variable (resolution differee) }
   End;
   If current_symbol = SYM_INDEXED Then
   Begin
    Consume;
    If current_symbol = SYM_BY Then Consume;
    While IsIdentifier Do Consume;
   End;
  End

  { ---- REDEFINES var-name ---- }
  Else If current_symbol = SYM_REDEFINES Then
  Begin
   Consume;
   If IsIdentifier Then
   Begin
    item.redefines_idx := FindDataItem(current_token, current_section);
    Consume;
   End;
  End

  { ---- VALUE [IS] / VALUES [ARE] ... ---- }
  Else If (current_symbol = SYM_VALUE) Or (current_symbol = SYM_VALUES) Then
  Begin
   Consume;
   If (current_symbol = SYM_IS) Or (current_symbol = SYM_ARE) Then Consume;
   item.has_value := True;
   If current_symbol = TOK_STRING Then
   Begin
    item.val_type := VALTYPE_STRING; item.val_str := current_token; Consume;
   End
   Else If current_symbol = TOK_NUMBER Then
   Begin
    item.val_type := VALTYPE_NUMBER;
    item.val_num := current_value;
    Consume;
    { VALUE x THRU y (niveau 88 surtout) }
    If (current_symbol = SYM_THRU) Or (current_symbol = SYM_THROUGH) Then
    Begin
     Consume; item.has_thru := True;
     If current_symbol = TOK_NUMBER Then
     Begin item.thru_num := current_value; Consume; End
     Else If current_symbol = TOK_STRING Then
     Begin item.thru_str := current_token; Consume; End;
    End;
   End
   Else If (current_symbol = SYM_ZERO)  Or (current_symbol = SYM_ZEROS) Or
           (current_symbol = SYM_ZEROES) Then
    Begin item.val_type := VALTYPE_ZERO; Consume; End
   Else If (current_symbol = SYM_SPACE) Or (current_symbol = SYM_SPACES) Then
    Begin item.val_type := VALTYPE_SPACE; Consume; End
   Else If TokenIs('LOW-VALUE') Or TokenIs('LOW-VALUES') Then
    Begin item.val_type := VALTYPE_LOW; Consume; End
   Else If TokenIs('HIGH-VALUE') Or TokenIs('HIGH-VALUES') Then
    Begin item.val_type := VALTYPE_HIGH; Consume; End
   Else If (current_symbol = SYM_QUOTE_KW) Or (current_symbol = SYM_QUOTES) Then
    Begin item.val_type := VALTYPE_QUOTE; Consume; End
   Else If TokenIs('ALL') Then
   Begin
    Consume; item.val_type := VALTYPE_ALL;
    If current_symbol = TOK_STRING Then
    Begin item.val_str := current_token; Consume; End;
   End
   Else If TokenIs('TRUE')  Then Begin item.val_type := VALTYPE_TRUE_V;  Consume; End
   Else If TokenIs('FALSE') Then Begin item.val_type := VALTYPE_FALSE_V; Consume; End
   Else Consume;
  End

  { ---- BLANK WHEN ZERO ---- }
  Else If current_symbol = SYM_BLANK Then
  Begin
   Consume;
   If current_symbol = SYM_WHEN Then Consume;
   If (current_symbol = SYM_ZERO) Or (current_symbol = SYM_ZEROS) Or
      (current_symbol = SYM_ZEROES) Then Consume;
  End

  { ---- JUSTIFIED / JUST [RIGHT] ---- }
  Else If TokenIs('JUSTIFIED') Or TokenIs('JUST') Then
  Begin Consume; If TokenIs('RIGHT') Then Consume; End

  { ---- SIGN [IS] LEADING/TRAILING [SEPARATE [CHARACTER]] ---- }
  Else If TokenIs('SIGN') Then
  Begin
   Consume;
   If current_symbol = SYM_IS Then Consume;
   If TokenIs('LEADING') Or TokenIs('TRAILING') Then Consume;
   If TokenIs('SEPARATE') Then
   Begin Consume; If TokenIs('CHARACTER') Then Consume; End;
  End

  { ---- SYNCHRONIZED / SYNC [LEFT/RIGHT] ---- }
  Else If TokenIs('SYNCHRONIZED') Or TokenIs('SYNC') Then
  Begin Consume; If TokenIs('LEFT') Or TokenIs('RIGHT') Then Consume; End

  { ---- GLOBAL / EXTERNAL ---- }
  Else If current_symbol = SYM_GLOBAL   Then Consume
  Else If current_symbol = SYM_EXTERNAL Then Consume

  { ---- IS / ARE (connecteurs) ---- }
  Else If (current_symbol = SYM_IS) Or (current_symbol = SYM_ARE) Then Consume

  Else Consume; { clause inconnue, skip }

 End; { While }
End;

{ Parse les elements de donnees d'une section.
  section_id   : SECT_xxx en cours.
  file_idx_in  : index dans file_table pour SECT_FILE (0 sinon). }
Procedure ParseDataItems(section_id, file_idx_in : Integer);
Const
 MAX_STACK = 50;
Var
 lev, parent_idx, new_idx : Integer;
 item_name                : String;
 item                     : PDataItem;
 g                        : Integer;
 level_stack              : Array[1..MAX_STACK] Of Integer;
 parent_stack             : Array[1..MAX_STACK] Of Integer;
 stack_top                : Integer;
Begin
 stack_top := 0;
 Repeat
  lev := PeekLevel;
  If lev = 0 Then Break;
  Consume; { numero de niveau }

  { Nom de l'article ou FILLER }
  If current_symbol = SYM_FILLER Then
   Begin item_name := 'FILLER'; Consume; End
  Else If IsIdentifier Then
   Begin item_name := current_token; Consume; End
  Else
  Begin
   Error('Nom attendu apres le niveau');
   SkipToPeriod;
   If current_symbol = TOK_PERIOD Then Consume;
   Continue;
  End;

  { Trouver le parent dans la pile de niveaux }
  parent_idx := 0;
  If stack_top > 0 Then
  Begin
   While (stack_top > 0) And (level_stack[stack_top] >= lev) Do
    stack_top := stack_top - 1;
   If stack_top > 0 Then parent_idx := parent_stack[stack_top];
  End;

  { Creer l'article (TYPE_GROUP par defaut ; modifie par clause PIC) }
  new_idx := AddDataItem(item_name, lev, TYPE_GROUP, section_id);
  If new_idx = 0 Then Exit;

  item           := data_table[new_idx];
  item^.parent   := parent_idx;
  item^.file_idx := file_idx_in;
  item^.defined  := True;
  If lev = 88 Then item^.data_type := TYPE_COND_88;

  { Parser les clauses }
  ParseDataItemClauses(item^);

  { Recalculer byte_size avec l'USAGE definitif (peut changer si USAGE suit PIC) }
  If item^.data_type <> TYPE_GROUP Then
   item^.byte_size := CalcByteSize(item^.data_type, item^.usage,
                                    item^.pic_digits, item^.pic_decimals);

  { is_group = pas de clause PIC }
  item^.is_group := (item^.data_type = TYPE_GROUP);

  { Marquer le parent comme groupe (sauf si enfant de niveau 88 = condition) }
  If (parent_idx > 0) And (lev <> 88) Then data_table[parent_idx]^.is_group := True;

  { Empiler ce niveau }
  If stack_top < MAX_STACK Then
  Begin
   stack_top := stack_top + 1;
   level_stack[stack_top]  := lev;
   parent_stack[stack_top] := new_idx;
  End;

  If current_symbol = TOK_PERIOD Then Consume;
 Until (current_symbol = TOK_EOF) Or (PeekLevel = 0);

 { Recalculer les tailles des groupes STRUCTURELS (du bas vers le haut) }
 For g := data_count DownTo 1 Do
  If (data_table[g]^.section = section_id) And data_table[g]^.is_group
     And (data_table[g]^.level <> 88) Then
   RecalcGroupSize(g);
End;

{ Parse un descripteur FD.
  Syntaxe : FD fd-name [clauses...] .  puis les records 01+. }
Procedure ParseFDEntry;
Var
 fd_name : String;
 fi      : Integer;
Begin
 If Not IsIdentifier Then
 Begin
  Error('Nom de fichier attendu apres FD');
  SkipToPeriod;
  If current_symbol = TOK_PERIOD Then Consume;
  Exit;
 End;
 fd_name := UpperStr(current_token);
 Consume;

 fi := FindFileEntry(fd_name);
 If fi = 0 Then
  Warning('FD ' + fd_name + ' non declare dans FILE-CONTROL');

 { Clauses FD : parcourir jusqu'au point }
 While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do
 Begin
  { LABEL RECORD IS STANDARD/OMITTED }
  If TokenIs('LABEL') Then
  Begin
   Consume;
   If current_symbol = SYM_RECORD Then Consume;
   If current_symbol = SYM_IS     Then Consume;
   If TokenIs('STANDARD') Or (current_symbol = SYM_STANDARD) Or
      TokenIs('OMITTED')  Then Consume;
  End
  { RECORD CONTAINS n [TO m] CHARACTERS }
  Else If current_symbol = SYM_RECORD Then
  Begin
   Consume;
   If TokenIs('CONTAINS') Then Consume;
   If current_symbol = TOK_NUMBER Then Consume;
   If current_symbol = SYM_TO Then
   Begin Consume; If current_symbol = TOK_NUMBER Then Consume; End;
   If TokenIs('CHARACTER') Or TokenIs('CHARACTERS') Then Consume;
  End
  { BLOCK CONTAINS n [TO m] RECORDS/CHARACTERS }
  Else If TokenIs('BLOCK') Then
  Begin
   Consume;
   If TokenIs('CONTAINS') Then Consume;
   If current_symbol = TOK_NUMBER Then Consume;
   If current_symbol = SYM_TO Then
   Begin Consume; If current_symbol = TOK_NUMBER Then Consume; End;
   If (current_symbol = SYM_RECORD) Or TokenIs('RECORDS') Or
      TokenIs('CHARACTER') Or TokenIs('CHARACTERS') Then Consume;
  End
  { DATA RECORD IS / DATA RECORDS ARE name... }
  Else If current_symbol = SYM_DATA Then
  Begin
   Consume;
   If (current_symbol = SYM_RECORD) Or TokenIs('RECORDS') Then Consume;
   If (current_symbol = SYM_IS) Or (current_symbol = SYM_ARE) Then Consume;
   While IsIdentifier Do Consume;
  End
  { RECORDING MODE IS F/V/U/S }
  Else If TokenIs('RECORDING') Then
  Begin
   Consume;
   If TokenIs('MODE') Then Consume;
   If current_symbol = SYM_IS Then Consume;
   Consume;
  End
  Else Consume;
 End;
 If current_symbol = TOK_PERIOD Then Consume;

 { Parser les records de ce FD (niveaux 01+) }
 ParseDataItems(SECT_FILE, fi);
End;

{ Parse la FILE SECTION.
  Appele apres avoir consomme 'FILE SECTION .' }
Procedure ParseFileSection;
Begin
 WriteLn('INFO: Parsing FILE SECTION...');
 While current_symbol = SYM_FD Do
 Begin
  Consume; { FD }
  ParseFDEntry;
 End;
 WriteLn('INFO: FILE SECTION terminee. Items total: ', data_count);
End;

{ Parse la DATA DIVISION.
  En entree : current_symbol = SYM_DATA.
  Consomme DATA DIVISION . puis dispatch sur les sections. }
Procedure ParseDataDivision;
Var
 done : Boolean;
Begin
 Consume; { DATA }
 If current_symbol = SYM_DIVISION Then Consume;
 If current_symbol = TOK_PERIOD   Then Consume;
 WriteLn('INFO: Parsing DATA DIVISION...');
 done := False;
 Repeat
  { FILE SECTION }
  If current_symbol = SYM_FILE_SEC Then
  Begin
   Consume;
   If current_symbol = SYM_SECTION Then Consume;
   If current_symbol = TOK_PERIOD  Then Consume;
   current_section := SECT_FILE;
   ParseFileSection;
  End
  { WORKING-STORAGE SECTION }
  Else If current_symbol = SYM_WORKING_STORAGE Then
  Begin
   Consume;
   If current_symbol = SYM_SECTION Then Consume;
   If current_symbol = TOK_PERIOD  Then Consume;
   current_section := SECT_WORKING_STORAGE;
   WriteLn('INFO: Parsing WORKING-STORAGE SECTION...');
   ParseDataItems(SECT_WORKING_STORAGE, 0);
   WriteLn('INFO: WORKING-STORAGE terminee. Items total: ', data_count);
  End
  { LOCAL-STORAGE SECTION }
  Else If current_symbol = SYM_LOCAL_STORAGE Then
  Begin
   Consume;
   If current_symbol = SYM_SECTION Then Consume;
   If current_symbol = TOK_PERIOD  Then Consume;
   current_section := SECT_LOCAL_STORAGE;
   WriteLn('INFO: Parsing LOCAL-STORAGE SECTION...');
   ParseDataItems(SECT_LOCAL_STORAGE, 0);
   WriteLn('INFO: LOCAL-STORAGE terminee. Items total: ', data_count);
  End
  { LINKAGE SECTION }
  Else If current_symbol = SYM_LINKAGE Then
  Begin
   Consume;
   If current_symbol = SYM_SECTION Then Consume;
   If current_symbol = TOK_PERIOD  Then Consume;
   current_section := SECT_LINKAGE;
   WriteLn('INFO: Parsing LINKAGE SECTION...');
   ParseDataItems(SECT_LINKAGE, 0);
   WriteLn('INFO: LINKAGE terminee. Items total: ', data_count);
  End
  { PROCEDURE DIVISION ou fin de fichier = on sort }
  Else If (current_symbol = SYM_PROCEDURE) Or (current_symbol = TOK_EOF) Then
   done := True
  Else
  Begin
   Warning('Section DATA DIVISION inconnue: ' + current_token);
   Consume;
  End;
 Until done;
 WriteLn('INFO: DATA DIVISION terminee. Elements declares: ', data_count);
End;

{ ======================================================================
  GENERATEUR DE CODE - CONSTANTES OPERANDES
  ====================================================================== }
Const
 OP_NONE    = 0;
 OP_LITNUM  = 1;  { Litteral numerique }
 OP_LITSTR  = 2;  { Litteral chaine    }
 OP_VAR     = 3;  { Variable COBOL     }
 OP_ZERO    = 4;  { ZERO/ZEROS/ZEROES  }
 OP_SPACE   = 5;  { SPACE/SPACES       }
 OP_HIGH    = 6;  { HIGH-VALUE(S)      }
 OP_LOW     = 7;  { LOW-VALUE(S)       }
 OP_QUOTE_V = 8;  { QUOTE/QUOTES       }
 MAX_NEST   = 32; { Profondeur max imbrication }

{ ======================================================================
  GENERATEUR DE CODE - VARIABLES GLOBALES
  ====================================================================== }
Var
 label_counter : Integer;   { Compteur labels uniques }
 gen_enabled   : Boolean;   { Active si generation ASM demandee }
 lit_counter   : Integer;   { Compteur litteraux inline CODE }
 first_para_lbl: String;    { Label ASM du 1er paragraphe }
 cur_para_name : String;    { Nom COBOL du paragraphe courant }
 need_ret      : Boolean;   { Vrai si on doit emettre RET avant prochain label }

{ ======================================================================
  PRIMITIVES D'EMISSION ASM
  ====================================================================== }

{ Helper : LongInt -> String }
Function ItoS(n: LongInt): String;
Var s: String;
Begin Str(n, s); ItoS := s; End;

{ Helper : Integer -> String }
Function ItoSI(n: Integer): String;
Var s: String;
Begin Str(n, s); ItoSI := s; End;

{ Sanitize a string for ASM DB : double the apostrophes (MASM format) }
Function AsmStr(Const s: String): String;
Var i: Integer; r: String;
Begin
 r := '';
 For i := 1 to Length(s) do
  If s[i] = '''' Then r := r + ''''''
  Else r := r + s[i];
 AsmStr := r;
End;

Procedure Emit(Const s: String);
Begin If gen_enabled Then WriteLn(output_file, s); End;

Procedure EmitLabel(Const lbl: String);
Begin If gen_enabled Then WriteLn(output_file, lbl, ':'); End;

Procedure EmitComment(Const s: String);
Begin If gen_enabled Then WriteLn(output_file, '        ; ', s); End;

Procedure EmitBlank;
Begin If gen_enabled Then WriteLn(output_file); End;

Function NewLabel: String;
Var s: String;
Begin
 Inc(label_counter);
 s := ItoSI(label_counter);
 While Length(s) < 4 do s := '0' + s;
 NewLabel := '_CBL' + s;
End;

{ ======================================================================
  PARSEUR D'OPERANDES
  ====================================================================== }
{ Remplit op_kind / op_str (text) / op_num (valeur si litnum) / op_idx (index data_table).
  Consomme les tokens de l'operande. }
Procedure ParseOperand(Var op_kind: Integer; Var op_str: String;
                        Var op_num: LongInt; Var op_idx: Integer);
Begin
 op_kind := OP_NONE; op_str := ''; op_num := 0; op_idx := 0;
 If current_symbol = TOK_STRING Then
  Begin op_kind := OP_LITSTR; op_str := current_token; Consume; End
 Else If current_symbol = TOK_NUMBER Then
  Begin
   op_kind := OP_LITNUM; op_num := current_value;
   op_str  := ItoS(current_value); Consume;
  End
 Else If (current_symbol = SYM_ZERO) Or (current_symbol = SYM_ZEROS) Or
         (current_symbol = SYM_ZEROES) Then
  Begin op_kind := OP_ZERO; op_str := '0'; Consume; End
 Else If (current_symbol = SYM_SPACE) Or (current_symbol = SYM_SPACES) Then
  Begin op_kind := OP_SPACE; op_str := ' '; Consume; End
 Else If (current_symbol = SYM_HIGH_VALUE) Or (current_symbol = SYM_HIGH_VALUES) Then
  Begin op_kind := OP_HIGH; Consume; End
 Else If (current_symbol = SYM_LOW_VALUE) Or (current_symbol = SYM_LOW_VALUES) Then
  Begin op_kind := OP_LOW; Consume; End
 Else If (current_symbol = SYM_QUOTE_KW) Or (current_symbol = SYM_QUOTES) Then
  Begin op_kind := OP_QUOTE_V; op_str := '"'; Consume; End
 Else If IsIdentifier Or (current_symbol = SYM_FILLER) Then
 Begin
  op_kind := OP_VAR; op_str := current_token;
  op_idx  := FindDataItem(current_token, SECT_NONE);
  Consume;
  { Qualificateur OF / IN }
  If TokenIs('OF') Or TokenIs('IN') Then Begin Consume; If IsIdentifier Then Consume; End;
  { Indice tableau (var(idx)) }
  If current_symbol = TOK_LPAREN Then
  Begin
   Consume;
   While (current_symbol <> TOK_RPAREN) And (current_symbol <> TOK_EOF) Do Consume;
   If current_symbol = TOK_RPAREN Then Consume;
  End;
 End;
End;

{ Retourner etiquette ASM d'une variable (ou ?? si non trouvee) }
Function VarAsmRef(idx: Integer): String;
Begin
 If (idx < 1) Or (idx > data_count) Then VarAsmRef := '_UNDEF_'
 Else VarAsmRef := data_table[idx]^.asm_label;
End;

{ Taille en octets d'une variable (min 1) }
Function VarSz(idx: Integer): Integer;
Begin
 If (idx < 1) Or (idx > data_count) Then VarSz := 1
 Else If data_table[idx]^.byte_size <= 0 Then VarSz := 1
 Else VarSz := data_table[idx]^.byte_size;
End;

{ Vrai si token est un verbe COBOL (debut de nouvelle instruction) }
Function IsVerb: Boolean;
Begin
 IsVerb :=
  (current_symbol = SYM_MOVE)      Or (current_symbol = SYM_ADD)         Or
  (current_symbol = SYM_SUBTRACT)  Or (current_symbol = SYM_MULTIPLY_V)  Or
  (current_symbol = SYM_DIVIDE_V)  Or (current_symbol = SYM_COMPUTE)     Or
  (current_symbol = SYM_IF)        Or (current_symbol = SYM_EVALUATE)    Or
  (current_symbol = SYM_PERFORM)   Or (current_symbol = SYM_DISPLAY)     Or
  (current_symbol = SYM_ACCEPT)    Or (current_symbol = SYM_OPEN)        Or
  (current_symbol = SYM_CLOSE)     Or (current_symbol = SYM_READ)        Or
  (current_symbol = SYM_WRITE)     Or (current_symbol = SYM_REWRITE)     Or
  (current_symbol = SYM_DELETE_KW) Or (current_symbol = SYM_STOP)        Or
  (current_symbol = SYM_GO)        Or (current_symbol = SYM_CALL)        Or
  (current_symbol = SYM_EXIT)      Or (current_symbol = SYM_CONTINUE_KW) Or
  (current_symbol = SYM_INITIALIZE)Or (current_symbol = SYM_INSPECT)     Or
  (current_symbol = SYM_STRING_KW) Or (current_symbol = SYM_UNSTRING)    Or
  (current_symbol = SYM_CANCEL);
End;

{ ======================================================================
  GENERATION SEGMENT DE DONNEES
  ====================================================================== }
Procedure GenDataSegment;
Var
 i: Integer; p: PDataItem;
 fill_byte, init_val, szs: String; sz: Integer;
Begin
 Emit('.DATA');
 EmitBlank;
 Emit('; === WORKING-STORAGE SECTION ===');
 For i := 1 to data_count do
 Begin
  p := data_table[i];
  If (p^.section <> SECT_WORKING_STORAGE) And (p^.section <> SECT_LINKAGE) And
     (p^.section <> SECT_LOCAL_STORAGE) Then Continue;
  If p^.level = 88 Then Continue;
  sz := p^.byte_size; If sz <= 0 Then sz := 1;
  { Valeur initiale }
  init_val := '';
  If p^.has_value Then
  Begin
   Case p^.val_type Of
    VALTYPE_ZERO:
     If (p^.data_type = TYPE_PIC_X) Or (p^.data_type = TYPE_PIC_A) Then
      init_val := 'DUP(20h)' Else init_val := 'DUP(30h)';
    VALTYPE_SPACE:  init_val := 'DUP(20h)';
    VALTYPE_HIGH:   init_val := 'DUP(0FFh)';
    VALTYPE_LOW:    init_val := 'DUP(0)';
    VALTYPE_NUMBER:
    Begin
     Str(p^.val_num, szs);
     { Generer la valeur comme DB sequence }
     init_val := 'DUP(30h)'; { defaut, valeur precise en DATA init  }
    End;
   Else init_val := '';
   End;
  End;
  If init_val = '' Then
  Begin
   If (p^.data_type = TYPE_PIC_9) Or (p^.data_type = TYPE_PIC_S9) Or
      (p^.data_type = TYPE_PIC_9V9) Or (p^.data_type = TYPE_PIC_S9V9) Then
    init_val := 'DUP(30h)' Else init_val := 'DUP(20h)';
  End;
  Str(sz, szs);
  Emit('    ' + PadR(p^.asm_label, 24) + 'DB  ' + szs + ' ' + init_val +
       '  ; ' + p^.name + ' PIC ' + p^.pic_str);
 End;
 EmitBlank;
 { FILE SECTION - buffers de records niveau 01 }
 If file_count > 0 Then
 Begin
  Emit('; === FILE SECTION ===');
  For i := 1 to data_count do
  Begin
   p := data_table[i];
   If (p^.section <> SECT_FILE) Or (p^.level <> 1) Then Continue;
   sz := p^.byte_size; If sz <= 0 Then sz := 80;
   Str(sz, szs);
   Emit('    ' + PadR(p^.asm_label, 24) + 'DB  ' + szs + ' DUP(20h)  ; ' + p^.name);
  End;
  EmitBlank;
  Emit('; === FILE HANDLES ===');
  For i := 1 to file_count do
  Begin
   Str(i, szs);
   Emit('    ' + PadR('_FH_' + ItoSI(i), 24) + 'DW  0FFFFh  ; HANDLE ' + file_table[i]^.name);
   Emit('    ' + PadR('_FN_' + ItoSI(i), 24) + 'DB  ''' + file_table[i]^.assign_to + ''', 0  ; ' + file_table[i]^.assign_to);
  End;
  EmitBlank;
 End;
 Emit('; === INTERNAL BUFFERS ===');
 Emit('    ' + PadR('_CRLF',24)     + 'DB  13, 10, ''$''');
 Emit('    ' + PadR('_INPUTBUF',24) + 'DB  82, 0, 80 DUP(0)');
 Emit('    ' + PadR('_NUMBUF',24)   + 'DB  20 DUP(30h), ''$''');
 EmitBlank;
End;

{ ======================================================================
  GENERATION EN-TETE + FOOTER
  ====================================================================== }
Procedure GenHeader;
Begin
 Emit('; ----------------------------------------------------------------');
 Emit('; Generated by COBOL86 V1.0');
 Emit('; Source  : ' + source_filename);
 Emit('; Program : ' + program_name);
 Emit('; ----------------------------------------------------------------');
 EmitBlank;
 Emit('        .MODEL SMALL');
 Emit('        .STACK 256');
 EmitBlank;
 GenDataSegment;
 EmitBlank;
 Emit('.CODE');
 EmitBlank;
End;

Procedure GenFooter;
Begin
 EmitBlank;
 Emit('END START');
End;

{ ======================================================================
  GENERATION RUNTIME HELPERS
  ====================================================================== }
Procedure GenRuntimeHelpers;
Begin
 EmitBlank;
 Emit('; ----------------------------------------------------------------');
 Emit('; RUNTIME HELPERS');
 Emit('; ----------------------------------------------------------------');
 EmitBlank;
 Emit('_DISP_STR:');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        RET');
 EmitBlank;
 Emit('_DISP_CRLF:');
 Emit('        LEA     DX, _CRLF');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        RET');
 EmitBlank;
 Emit('        ; _DISP_VAR: SI=src, CX=nb_bytes -> affiche sur stdout');
 Emit('_DISP_VAR:');
 Emit('        JCXZ    _DVR_DONE');
 Emit('_DVR_LP:MOV     DL, [SI]');
 Emit('        MOV     AH, 02h');
 Emit('        INT     21h');
 Emit('        INC     SI');
 Emit('        LOOP    _DVR_LP');
 Emit('_DVR_DONE: RET');
 EmitBlank;
 Emit('        ; _ACCEPT_VAR: DI=dest, CX=max_size -> saisie clavier');
 Emit('_ACCEPT_VAR:');
 Emit('        PUSH    CX');
 Emit('        MOV     _INPUTBUF, CL');
 Emit('        LEA     DX, _INPUTBUF');
 Emit('        MOV     AH, 0Ah');
 Emit('        INT     21h');
 Emit('        CALL    _DISP_CRLF');
 Emit('        MOV     CL, _INPUTBUF+1');
 Emit('        XOR     CH, CH');
 Emit('        LEA     SI, _INPUTBUF+2');
 Emit('        POP     BX');
 Emit('        CMP     CX, BX');
 Emit('        JBE     _ACC_CP');
 Emit('        MOV     CX, BX');
 Emit('_ACC_CP: PUSH   CX');
 Emit('        REP     MOVSB');
 Emit('        POP     CX');
 Emit('        SUB     BX, CX');
 Emit('        MOV     AL, 20h');
 Emit('        MOV     CX, BX');
 Emit('        REP     STOSB');
 Emit('        RET');
 EmitBlank;
 Emit('        ; _MOVE_STR_LJ: SI=src, CX=src_len, DI=dest, BX=dest_len -> left-justify + space-fill');
 Emit('_MOVE_STR_LJ:');
 Emit('        CMP     CX, BX');
 Emit('        JBE     _MSL_SZ');
 Emit('        MOV     CX, BX');
 Emit('_MSL_SZ: PUSH   CX');
 Emit('        PUSH    BX');
 Emit('        REP     MOVSB');
 Emit('        POP     BX');
 Emit('        POP     CX');
 Emit('        SUB     BX, CX');
 Emit('        MOV     AL, 20h');
 Emit('        MOV     CX, BX');
 Emit('        REP     STOSB');
 Emit('        RET');
 EmitBlank;
 Emit('        ; _MOVE_NUM_RJ: SI=src, CX=src_len, DI=dest, BX=dest_len -> right-justify + zero-fill');
 Emit('_MOVE_NUM_RJ:');
 Emit('        CMP     CX, BX');
 Emit('        JBE     _MNR_PAD');
 Emit('        ADD     SI, CX');
 Emit('        SUB     SI, BX');
 Emit('        MOV     CX, BX');
 Emit('        REP     MOVSB');
 Emit('        RET');
 Emit('_MNR_PAD:');
 Emit('        SUB     BX, CX');
 Emit('        MOV     AL, 30h');
 Emit('        PUSH    CX');
 Emit('        MOV     CX, BX');
 Emit('        REP     STOSB');
 Emit('        POP     CX');
 Emit('        REP     MOVSB');
 Emit('        RET');
 EmitBlank;
 Emit('_EXIT:');
 Emit('        MOV     AX, 4C00h');
 Emit('        INT     21h');
 EmitBlank;
End;

{ ======================================================================
  GENERATION DISPLAY
  ====================================================================== }
Procedure GenDisplayOp(op_kind: Integer; Const op_str: String; op_idx: Integer);
Var cnts, szs: String;
Begin
 Case op_kind Of
  OP_LITSTR:
  Begin
   Inc(lit_counter); cnts := ItoSI(lit_counter);
   EmitComment('DISPLAY ''' + op_str + '''');
   Emit('        JMP     _DL' + cnts + 'E');
   EmitLabel('_DL' + cnts);
   Emit('        DB      ''' + AsmStr(op_str) + ''', ''$''');
   EmitLabel('_DL' + cnts + 'E');
   Emit('        LEA     DX, _DL' + cnts);
   Emit('        CALL    _DISP_STR');
  End;
  OP_LITNUM:
  Begin
   Inc(lit_counter); cnts := ItoSI(lit_counter);
   EmitComment('DISPLAY ' + op_str);
   Emit('        JMP     _DL' + cnts + 'E');
   EmitLabel('_DL' + cnts);
   Emit('        DB      ''' + op_str + ''', ''$''');
   EmitLabel('_DL' + cnts + 'E');
   Emit('        LEA     DX, _DL' + cnts);
   Emit('        CALL    _DISP_STR');
  End;
  OP_VAR:
  Begin
   If op_idx > 0 Then
   Begin
    szs := ItoSI(VarSz(op_idx));
    EmitComment('DISPLAY ' + data_table[op_idx]^.name + ' (' + szs + ' bytes)');
    Emit('        LEA     SI, ' + VarAsmRef(op_idx));
    Emit('        MOV     CX, ' + szs);
    Emit('        CALL    _DISP_VAR');
   End Else
    EmitComment('DISPLAY ???' + op_str + ' (variable non declaree)');
  End;
  OP_ZERO:  Begin Emit('        MOV     DL, 30h'); Emit('        MOV     AH, 02h'); Emit('        INT     21h'); End;
  OP_SPACE: Begin Emit('        MOV     DL, 20h'); Emit('        MOV     AH, 02h'); Emit('        INT     21h'); End;
  OP_HIGH:  Begin Emit('        MOV     DL, 0FFh'); Emit('        MOV     AH, 02h'); Emit('        INT     21h'); End;
  OP_LOW:   Begin Emit('        MOV     DL, 00h'); Emit('        MOV     AH, 02h'); Emit('        INT     21h'); End;
  Else EmitComment('DISPLAY <operande non supporte>');
 End;
End;

Procedure ParseDisplay;
Var ok: Integer; os: String; on2: LongInt; oi: Integer; no_adv: Boolean;
Begin
 Consume; { DISPLAY }
 no_adv := False;
 EmitComment('---- DISPLAY ----');
 Repeat
  { WITH NO ADVANCING }
  If (current_symbol = SYM_WITH) Or TokenIs('NO') Then
  Begin
   If current_symbol = SYM_WITH Then Consume;
   If TokenIs('NO') Then
   Begin Consume; If TokenIs('ADVANCING') Then Begin Consume; no_adv := True; End; End;
   Break;
  End;
  If (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF) Then Break;
  If IsVerb Then Break;
  ParseOperand(ok, os, on2, oi);
  If ok <> OP_NONE Then GenDisplayOp(ok, os, oi)
  Else Break;
 Until False;
 If Not no_adv Then Emit('        CALL    _DISP_CRLF');
End;

{ ======================================================================
  GENERATION ACCEPT
  ====================================================================== }
Procedure ParseAccept;
Var idx: Integer; szs: String;
Begin
 Consume; { ACCEPT }
 EmitComment('---- ACCEPT ----');
 If IsIdentifier Then
 Begin
  idx := FindDataItem(current_token, SECT_NONE); Consume;
  If current_symbol = SYM_FROM Then
  Begin
   Consume;
   If TokenIs('DATE') Or TokenIs('TIME') Or TokenIs('DAY') Or
      TokenIs('DATE-AND-TIME') Or TokenIs('DATE-OF-TODAY') Then
   Begin
    EmitComment('ACCEPT FROM DATE/TIME/DAY (stub)'); Consume;
   End Else Consume;
  End Else
  Begin
   If idx > 0 Then
   Begin
    szs := ItoSI(VarSz(idx));
    EmitComment('ACCEPT ' + data_table[idx]^.name + ' (' + szs + ' bytes)');
    Emit('        LEA     DI, ' + VarAsmRef(idx));
    Emit('        MOV     CX, ' + szs);
    Emit('        CALL    _ACCEPT_VAR');
   End Else
    EmitComment('ACCEPT (variable inconnue)');
  End;
 End Else EmitComment('ACCEPT (non reconnu)');
 While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) And
       Not IsVerb Do Consume;
End;

{ ======================================================================
  GENERATION MOVE
  ====================================================================== }
Procedure GenMoveToVar(op_kind: Integer; Const op_str: String;
                        op_num: LongInt; op_idx: Integer; dest_idx: Integer);
Var
 sz, src_sz: Integer; szs, srcs, os2, cs: String;
 dest_p, src_p: PDataItem; is_alpha: Boolean;
Begin
 If dest_idx <= 0 Then Begin EmitComment('MOVE -> dest inconnue'); Exit; End;
 dest_p   := data_table[dest_idx];
 sz       := VarSz(dest_idx); szs := ItoSI(sz);
 is_alpha := (dest_p^.data_type = TYPE_PIC_X) Or (dest_p^.data_type = TYPE_PIC_A) Or dest_p^.is_group;
 Case op_kind Of
  OP_ZERO:
  Begin
   EmitComment('MOVE ZERO TO ' + dest_p^.name);
   If is_alpha Then os2 := '20h' Else os2 := '30h';
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   Emit('        MOV     AL, ' + os2);
   Emit('        MOV     CX, ' + szs);
   Emit('        REP     STOSB');
  End;
  OP_SPACE:
  Begin
   EmitComment('MOVE SPACES TO ' + dest_p^.name);
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   Emit('        MOV     AL, 20h');
   Emit('        MOV     CX, ' + szs);
   Emit('        REP     STOSB');
  End;
  OP_HIGH:
  Begin
   EmitComment('MOVE HIGH-VALUES TO ' + dest_p^.name);
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   Emit('        MOV     AL, 0FFh');
   Emit('        MOV     CX, ' + szs);
   Emit('        REP     STOSB');
  End;
  OP_LOW:
  Begin
   EmitComment('MOVE LOW-VALUES TO ' + dest_p^.name);
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   Emit('        MOV     AL, 00h');
   Emit('        MOV     CX, ' + szs);
   Emit('        REP     STOSB');
  End;
  OP_QUOTE_V:
  Begin
   EmitComment('MOVE QUOTE TO ' + dest_p^.name);
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   Emit('        MOV     AL, 22h');
   Emit('        MOV     CX, ' + szs);
   Emit('        REP     STOSB');
  End;
  OP_LITNUM:
  Begin
   EmitComment('MOVE ' + op_str + ' TO ' + dest_p^.name);
   { Zero-fill d'abord }
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   Emit('        MOV     AL, 30h');
   Emit('        MOV     CX, ' + szs);
   Emit('        REP     STOSB');
   { Puis ecrire les chiffres a droite }
   src_sz := Length(op_str);
   srcs   := ItoSI(src_sz);
   If src_sz <= sz Then
   Begin
    Inc(lit_counter); cs := ItoSI(lit_counter);
    Emit('        JMP     _NL' + cs + 'E');
    EmitLabel('_NL' + cs);
    Emit('        DB      ''' + op_str + '''');
    EmitLabel('_NL' + cs + 'E');
    Emit('        LEA     SI, _NL' + cs);
    Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
    { Right-justify : pointer a sz-src_sz }
    If sz > src_sz Then Emit('        ADD     DI, ' + ItoSI(sz - src_sz));
    Emit('        MOV     CX, ' + srcs);
    Emit('        REP     MOVSB');
   End;
  End;
  OP_LITSTR:
  Begin
   EmitComment('MOVE ''' + op_str + ''' TO ' + dest_p^.name);
   src_sz := Length(op_str); srcs := ItoSI(src_sz);
   Inc(lit_counter); cs := ItoSI(lit_counter);
   Emit('        JMP     _SL' + cs + 'E');
   EmitLabel('_SL' + cs);
   Emit('        DB      ''' + AsmStr(op_str) + '''');
   EmitLabel('_SL' + cs + 'E');
   Emit('        LEA     SI, _SL' + cs);
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   Emit('        MOV     CX, ' + srcs);
   Emit('        MOV     BX, ' + szs);
   Emit('        CALL    _MOVE_STR_LJ');
  End;
  OP_VAR:
  Begin
   src_p := Nil;
   If op_idx > 0 Then src_p := data_table[op_idx];
   If src_p = Nil Then Begin EmitComment('MOVE ???' + op_str + ' TO ' + dest_p^.name); Exit; End;
   src_sz := VarSz(op_idx); srcs := ItoSI(src_sz);
   EmitComment('MOVE ' + src_p^.name + ' TO ' + dest_p^.name);
   Emit('        LEA     SI, ' + VarAsmRef(op_idx));
   Emit('        LEA     DI, ' + VarAsmRef(dest_idx));
   If is_alpha Then
   Begin
    Emit('        MOV     CX, ' + srcs);
    Emit('        MOV     BX, ' + szs);
    Emit('        CALL    _MOVE_STR_LJ');
   End Else
   Begin
    Emit('        MOV     CX, ' + srcs);
    Emit('        MOV     BX, ' + szs);
    Emit('        CALL    _MOVE_NUM_RJ');
   End;
  End;
  Else EmitComment('MOVE <operande non implemente> TO ' + dest_p^.name);
 End;
End;

Procedure ParseMove;
Var ok: Integer; os: String; on2: LongInt; oi: Integer;
    ok2: Integer; os2: String; on3: LongInt; oi2: Integer;
Begin
 Consume; { MOVE }
 EmitComment('---- MOVE ----');
 ParseOperand(ok, os, on2, oi);
 { MOVE CORRESPONDING }
 If (current_symbol = SYM_CORRESPONDING) Or (current_symbol = SYM_CORR) Then
 Begin
  While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
  EmitComment('MOVE CORRESPONDING - stub'); Exit;
 End;
 If current_symbol = SYM_TO Then Consume;
 Repeat
  ParseOperand(ok2, os2, on3, oi2);
  If (ok2 <> OP_VAR) And (ok2 <> OP_NONE) Then Break;
  If (ok2 = OP_VAR) And (oi2 > 0) Then
   GenMoveToVar(ok, os, on2, oi, oi2)
  Else Break;
  If (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF) Or IsVerb Then Break;
 Until False;
End;

{ ======================================================================
  GENERATION ARITHMETIQUE
  ====================================================================== }
{ Helper : emettre la lecture d'un operande numerique vers AX pour ADD/SUB }
Procedure EmitLoadNum(op_kind: Integer; Const op_str: String;
                      op_num: LongInt; op_idx: Integer);
Var szs: String;
Begin
 Case op_kind Of
  OP_LITNUM: Emit('        MOV     AX, ' + op_str);
  OP_ZERO:   Emit('        XOR     AX, AX');
  OP_VAR:
   If (op_idx > 0) And (VarSz(op_idx) <= 2) Then
   Begin
    szs := ItoSI(VarSz(op_idx));
    If VarSz(op_idx) = 1 Then
    Begin
     Emit('        XOR     AH, AH');
     Emit('        MOV     AL, ' + VarAsmRef(op_idx));
     Emit('        SUB     AL, 30h');  { zoned decimal -> binary }
    End Else
    Begin
     Emit('        MOV     AX, WORD PTR ' + VarAsmRef(op_idx));
    End;
   End Else
    Emit('        MOV     AX, 0  ; load ' + op_str);
  Else Emit('        MOV     AX, 0');
 End;
End;

Procedure ParseAdd;
Var ok: Integer; os: String; on2: LongInt; oi: Integer;
    dest_idx: Integer; szs: String; first_src: Boolean;
Begin
 Consume; { ADD }
 EmitComment('---- ADD ----');
 If (current_symbol = SYM_CORRESPONDING) Or (current_symbol = SYM_CORR) Then
 Begin
  While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
  EmitComment('ADD CORRESPONDING - stub'); Exit;
 End;
 { Lire les operandes source jusqu'a TO ou GIVING - accumuler dans AX }
 first_src := True;
 Repeat
  ParseOperand(ok, os, on2, oi);
  If ok = OP_NONE Then Break;
  If first_src Then
  Begin
   EmitLoadNum(ok, os, on2, oi);
   first_src := False;
  End Else
  Begin
   Emit('        PUSH    AX');
   EmitLoadNum(ok, os, on2, oi);
   Emit('        POP     BX');
   Emit('        ADD     AX, BX');
  End;
  If (current_symbol = SYM_TO) Or (current_symbol = SYM_GIVING) Then Break;
 Until False;
 If first_src Then Emit('        XOR     AX, AX  ; aucune source');
 If (current_symbol = SYM_TO) Or (current_symbol = SYM_GIVING) Then Consume;
 Repeat
  ParseOperand(ok, os, on2, oi);
  dest_idx := oi;
  If (ok <> OP_VAR) Or (dest_idx <= 0) Then Break;
  szs := ItoSI(VarSz(dest_idx));
  EmitComment('ADD ... TO ' + data_table[dest_idx]^.name);
  If VarSz(dest_idx) = 1 Then
  Begin
   Emit('        SUB     AX, 30h');  { enlever le '0' ASCII pour converger }
   Emit('        ADD     BYTE PTR ' + VarAsmRef(dest_idx) + ', AL');
   Emit('        ADD     BYTE PTR ' + VarAsmRef(dest_idx) + ', 30h');
  End Else
  Begin
   Emit('        ADD     WORD PTR ' + VarAsmRef(dest_idx) + ', AX');
  End;
  If TokenIs('ROUNDED') Then Consume;
  If (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF) Or IsVerb Then Break;
 Until False;
 { ON SIZE ERROR }
 If TokenIs('ON') Then Consume;
 If TokenIs('SIZE') Then Begin Consume; If TokenIs('ERROR') Then Consume; End;
 If (current_symbol = SYM_END_ADD) Then Consume;
End;

Procedure ParseSubtract;
Var ok: Integer; os: String; on2: LongInt; oi: Integer; dest_idx: Integer;
    first_src: Boolean;
Begin
 Consume; { SUBTRACT }
 EmitComment('---- SUBTRACT ----');
 If (current_symbol = SYM_CORRESPONDING) Or (current_symbol = SYM_CORR) Then
 Begin
  While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
  EmitComment('SUBTRACT CORRESPONDING - stub'); Exit;
 End;
 first_src := True;
 Repeat
  ParseOperand(ok, os, on2, oi);
  If ok = OP_NONE Then Break;
  If first_src Then
  Begin
   EmitLoadNum(ok, os, on2, oi);
   first_src := False;
  End Else
  Begin
   Emit('        PUSH    AX');
   EmitLoadNum(ok, os, on2, oi);
   Emit('        POP     BX');
   Emit('        ADD     AX, BX');
  End;
  If TokenIs('FROM') Or (current_symbol = SYM_FROM) Or (current_symbol = SYM_GIVING) Then Break;
 Until False;
 If first_src Then Emit('        XOR     AX, AX  ; aucune source');
 If TokenIs('FROM') Or (current_symbol = SYM_FROM) Then Consume;
 If (current_symbol = SYM_GIVING) Then Consume;
 Repeat
  ParseOperand(ok, os, on2, oi);
  dest_idx := oi;
  If (ok <> OP_VAR) Or (dest_idx <= 0) Then Break;
  EmitComment('SUBTRACT ... FROM ' + data_table[dest_idx]^.name);
  If VarSz(dest_idx) = 1 Then
  Begin
   Emit('        SUB     BYTE PTR ' + VarAsmRef(dest_idx) + ', AL');
   Emit('        CMP     BYTE PTR ' + VarAsmRef(dest_idx) + ', 30h');
   Emit('        JAE     _SUB_OK' + ItoSI(label_counter));
   Emit('        ADD     BYTE PTR ' + VarAsmRef(dest_idx) + ', 30h');
   EmitLabel('_SUB_OK' + ItoSI(label_counter));
  End Else
   Emit('        SUB     WORD PTR ' + VarAsmRef(dest_idx) + ', AX');
  If TokenIs('ROUNDED') Then Consume;
  If (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF) Or IsVerb Then Break;
 Until False;
 If TokenIs('ON') Then Consume;
 If TokenIs('SIZE') Then Begin Consume; If TokenIs('ERROR') Then Consume; End;
 If (current_symbol = SYM_END_SUBTRACT) Then Consume;
End;

Procedure ParseMultiply;
Begin
 Consume; { MULTIPLY }
 EmitComment('---- MULTIPLY (stub) ----');
 While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) And
       Not (current_symbol = SYM_END_SUBTRACT) Do Consume;
 If TokenIs('END-MULTIPLY') Then Consume;
End;

Procedure ParseDivide;
Begin
 Consume; { DIVIDE }
 EmitComment('---- DIVIDE (stub) ----');
 While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
 If TokenIs('END-DIVIDE') Then Consume;
End;

Procedure ParseCompute;
Var ok: Integer; os: String; on2: LongInt; oi: Integer; dest_idx: Integer;
Begin
 Consume; { COMPUTE }
 EmitComment('---- COMPUTE ----');
 ParseOperand(ok, os, on2, oi); dest_idx := oi;
 If TokenIs('ROUNDED') Then Consume;
 While (current_symbol <> TOK_EQUAL) And (current_symbol <> TOK_PERIOD) And
       (current_symbol <> TOK_EOF) Do Consume;
 If current_symbol = TOK_EQUAL Then Consume;
 ParseOperand(ok, os, on2, oi);
 If (dest_idx > 0) And (ok <> OP_NONE) Then
 Begin
  EmitComment('COMPUTE ' + data_table[dest_idx]^.name + ' = ...');
  GenMoveToVar(ok, os, on2, oi, dest_idx);
 End;
 { Ignorer reste expression (op complexe) }
 While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) And
       (current_symbol <> SYM_END_COMPUTE) And Not IsVerb Do Consume;
 If current_symbol = SYM_END_COMPUTE Then Consume;
End;

{ ======================================================================
  GENERATION CONDITIONS (pour IF/EVALUATE/PERFORM)
  ====================================================================== }
{ Emet le code CMP + saut conditionnel.
  lbl_false : ou sauter si la condition est FAUSSE. }
Procedure GenSimpleCondition(Const lbl_false: String);
Var
 ok1, ok2: Integer; os1, os2: String; on1, on2: LongInt; oi1, oi2: Integer;
 neg: Boolean; rel_op: Integer;  { 0== 1<> 2< 3> 4<= 5>= }
 lbl_neg: Integer;
Begin
 neg := False;
 If current_symbol = SYM_NOT Then Begin neg := True; Consume; End;
 ParseOperand(ok1, os1, on1, oi1);
 { Operateur relationnel }
 rel_op := 0; { = par defaut }
 If current_symbol = SYM_IS Then Consume;
 If current_symbol = SYM_NOT Then Begin neg := Not neg; Consume; End;
 Case current_symbol Of
  TOK_EQUAL:    Begin rel_op := 0; Consume; End;
  TOK_LESS:     Begin rel_op := 2; Consume; End;
  TOK_GREATER:  Begin rel_op := 3; Consume; End;
  TOK_LESSEQ:   Begin rel_op := 4; Consume; End;
  TOK_GREATEREQ:Begin rel_op := 5; Consume; End;
  TOK_NOTEQUAL: Begin rel_op := 1; Consume; End;
  SYM_EQUAL_KW:
   Begin rel_op := 0; Consume; If current_symbol = SYM_TO Then Consume; End;
  SYM_GREATER_KW:
   Begin
    Consume; rel_op := 3;
    If (current_symbol = SYM_OR) Or TokenIs('OR') Then
    Begin Consume; If TokenIs('EQUAL') Then Begin Consume; If current_symbol = SYM_TO Then Consume; End; rel_op := 5; End
    Else If current_symbol = SYM_TO Then Consume;
   End;
  SYM_LESS_KW:
   Begin
    Consume; rel_op := 2;
    If (current_symbol = SYM_OR) Or TokenIs('OR') Then
    Begin Consume; If TokenIs('EQUAL') Then Begin Consume; If current_symbol = SYM_TO Then Consume; End; rel_op := 4; End
    Else If current_symbol = SYM_TO Then Consume;
   End;
 End;
 ParseOperand(ok2, os2, on2, oi2);
 { === Generer la comparaison === }
 If (ok1 = OP_VAR) And (oi1 > 0) Then
 Begin
  If (ok2 = OP_LITSTR) And (Length(os2) = 1) Then
  Begin
   Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
   Emit('        CMP     AL, ''' + AsmStr(os2) + '''');
  End Else If (ok2 = OP_LITNUM) Then
  Begin
   If VarSz(oi1) = 1 Then
   Begin
    Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
    Inc(label_counter);
    Emit('        CMP     AL, 0' + os2 + '+30h');
   End Else
   Begin
    Emit('        MOV     AX, WORD PTR ' + VarAsmRef(oi1));
    Emit('        CMP     AX, ' + os2);
   End;
  End Else If (ok2 = OP_ZERO) Then
  Begin
   Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
   Emit('        CMP     AL, 30h');
  End Else If (ok2 = OP_SPACE) Then
  Begin
   Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
   Emit('        CMP     AL, 20h');
  End Else If (ok2 = OP_HIGH) Then
  Begin
   Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
   Emit('        CMP     AL, 0FFh');
  End Else If (ok2 = OP_LOW) Then
  Begin
   Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
   Emit('        CMP     AL, 00h');
  End Else If (ok2 = OP_VAR) And (oi2 > 0) Then
  Begin
   Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
   Emit('        CMP     AL, BYTE PTR ' + VarAsmRef(oi2));
  End Else If (ok2 = OP_LITSTR) And (Length(os2) > 1) Then
  Begin
   { Multi-char : comparer premier octet seulement (simplification) }
   Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi1));
   If Length(os2) >= 1 Then Emit('        CMP     AL, ''' + AsmStr(Copy(os2,1,1)) + '''');
  End Else
   EmitComment('condition non supportee (stub ok1=VAR ok2=' + ItoSI(ok2) + ')');
 End Else If (ok1 = OP_LITNUM) And (ok2 = OP_VAR) And (oi2 > 0) Then
 Begin
  Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(oi2));
  Emit('        CMP     AL, 0' + os1 + '+30h');
  { Inverser l'operateur car on a echange operandes }
  Case rel_op Of
   2: rel_op := 3;  3: rel_op := 2;
   4: rel_op := 5;  5: rel_op := 4;
  End;
 End Else
  EmitComment('condition non supportee (stub)');
 { Appliquer la negation }
 If neg Then
  Case rel_op Of
   0: rel_op := 1;  1: rel_op := 0;
   2: rel_op := 5;  5: rel_op := 2;
   3: rel_op := 4;  4: rel_op := 3;
  End;
 { Emettre le saut conditionnel (saute vers lbl_false si condition FAUSSE) }
 Case rel_op Of
  0: Emit('        JNE     ' + lbl_false);
  1: Emit('        JE      ' + lbl_false);
  2: Emit('        JAE     ' + lbl_false);
  3: Emit('        JBE     ' + lbl_false);
  4: Emit('        JA      ' + lbl_false);
  5: Emit('        JB      ' + lbl_false);
 Else Emit('        JNE     ' + lbl_false);
 End;
End;

{ ======================================================================
  GENERATION IF / ELSE / END-IF + ParseStatement (Forward)
  ====================================================================== }
Procedure ParseStatement; Forward;

Procedure ParseIf;
Var lbl_else, lbl_end: String; has_else: Boolean;
Begin
 Consume; { IF }
 EmitComment('---- IF ----');
 lbl_else := NewLabel + 'E';
 lbl_end  := NewLabel + 'F';
 has_else := False;
 GenSimpleCondition(lbl_else);
 If current_symbol = SYM_THEN Then Consume;
 While (current_symbol <> SYM_ELSE)     And
       (current_symbol <> SYM_END_IF)   And
       (current_symbol <> TOK_PERIOD)   And
       (current_symbol <> TOK_EOF) Do
  ParseStatement;
 If current_symbol = SYM_ELSE Then
 Begin
  has_else := True;
  Emit('        JMP     ' + lbl_end);
  EmitLabel(lbl_else);
  Consume; { ELSE }
  While (current_symbol <> SYM_END_IF) And
        (current_symbol <> TOK_PERIOD)  And
        (current_symbol <> TOK_EOF) Do
   ParseStatement;
 End;
 If current_symbol = SYM_END_IF Then Consume;
 If Not has_else Then EmitLabel(lbl_else);
 EmitLabel(lbl_end);
End;

{ ======================================================================
  GENERATION EVALUATE
  ====================================================================== }
Procedure ParseEvaluate;
Var
 lbl_end, lbl_next: String;
 ok: Integer; os: String; on2: LongInt; oi: Integer;
 eval_idx: Integer;
Begin
 Consume; { EVALUATE }
 EmitComment('---- EVALUATE ----');
 lbl_end := NewLabel + 'EV';
 ParseOperand(ok, os, on2, oi); eval_idx := oi;
 While current_symbol = SYM_WHEN Do
 Begin
  Consume; { WHEN }
  lbl_next := NewLabel + 'WN';
  If TokenIs('OTHER') Then
  Begin Consume; EmitComment('WHEN OTHER'); End
  Else
  Begin
   EmitComment('WHEN ...');
   If (eval_idx > 0) And (ok = OP_VAR) Then
   Begin
    Emit('        MOV     AL, BYTE PTR ' + VarAsmRef(eval_idx));
   End;
   ParseOperand(ok, os, on2, oi);
   case ok of
    OP_LITSTR: If Length(os) >= 1 Then Emit('        CMP     AL, ''' + AsmStr(Copy(os,1,1)) + '''');
    OP_LITNUM: Emit('        CMP     AL, 0' + os + '+30h');
    OP_ZERO:   Emit('        CMP     AL, 30h');
    OP_SPACE:  Emit('        CMP     AL, 20h');
    OP_VAR:    If oi > 0 Then Emit('        CMP     AL, BYTE PTR ' + VarAsmRef(oi));
    Else EmitComment('WHEN <operande non supporte>');
   End;
   Emit('        JNE     ' + lbl_next);
  End;
  While (current_symbol <> SYM_WHEN) And
        (current_symbol <> SYM_END_EVALUATE) And
        (current_symbol <> TOK_PERIOD) And
        (current_symbol <> TOK_EOF) Do
   ParseStatement;
  Emit('        JMP     ' + lbl_end);
  EmitLabel(lbl_next);
 End;
 If current_symbol = SYM_END_EVALUATE Then Consume;
 EmitLabel(lbl_end);
End;

{ ======================================================================
  GENERATION PERFORM
  ====================================================================== }
Procedure ParsePerform;
Var
 para_name, thru_name: String;
 para_idx: Integer;
 lbl_loop, lbl_done: String;
 ok: Integer; os: String; on2: LongInt; oi: Integer;
 times_count: LongInt; times_s: String;
Begin
 Consume; { PERFORM }
 EmitComment('---- PERFORM ----');
 { PERFORM VARYING }
 If current_symbol = SYM_VARYING Then
 Begin
  EmitComment('PERFORM VARYING (stub)');
  While (current_symbol <> SYM_END_PERFORM) And
        (current_symbol <> TOK_PERIOD) And
        (current_symbol <> TOK_EOF) Do
   ParseStatement;
  If current_symbol = SYM_END_PERFORM Then Consume;
  Exit;
 End;
 { PERFORM UNTIL inline }
 If current_symbol = SYM_UNTIL Then
 Begin
  lbl_loop := NewLabel + 'PL';
  lbl_done := NewLabel + 'PD';
  Consume;
  EmitLabel(lbl_loop);
  GenSimpleCondition(lbl_done);
  While (current_symbol <> SYM_END_PERFORM) And
        (current_symbol <> TOK_PERIOD) And
        (current_symbol <> TOK_EOF) Do
   ParseStatement;
  Emit('        JMP     ' + lbl_loop);
  EmitLabel(lbl_done);
  If current_symbol = SYM_END_PERFORM Then Consume;
  Exit;
 End;
 { PERFORM para-name }
 If IsIdentifier Then
 Begin
  para_name := current_token; Consume;
  thru_name := '';
  If (current_symbol = SYM_THRU) Or (current_symbol = SYM_THROUGH) Then
  Begin Consume; If IsIdentifier Then Begin thru_name := current_token; Consume; End; End;
  { n TIMES }
  If current_symbol = TOK_NUMBER Then
  Begin
   times_count := current_value; times_s := ItoS(times_count); Consume;
   If current_symbol = SYM_TIMES Then Consume;
   para_idx := FindParagraph(para_name);
   lbl_loop := NewLabel + 'PT';
   EmitComment('PERFORM ' + para_name + ' ' + times_s + ' TIMES');
   Emit('        MOV     CX, ' + times_s);
   EmitLabel(lbl_loop);
   Emit('        PUSH    CX');
   If para_idx > 0 Then Emit('        CALL    ' + ParaAsmLabel(para_idx))
   Else Emit('        ; CALL ' + para_name + ' (para non encore defini)');
   Emit('        POP     CX');
   Emit('        LOOP    ' + lbl_loop);
   Exit;
  End;
  If (current_symbol = SYM_TIMES) Then { PERFORM para TIMES - rarest form }
  Begin Consume; para_idx := FindParagraph(para_name);
   EmitComment('PERFORM ' + para_name);
   If para_idx > 0 Then Emit('        CALL    ' + ParaAsmLabel(para_idx));
   Exit;
  End;
  { PERFORM para UNTIL }
  If current_symbol = SYM_UNTIL Then
  Begin
   lbl_loop := NewLabel + 'PL'; lbl_done := NewLabel + 'PD';
   Consume;
   EmitLabel(lbl_loop);
   GenSimpleCondition(lbl_done);
   para_idx := FindParagraph(para_name);
   If para_idx > 0 Then Emit('        CALL    ' + ParaAsmLabel(para_idx))
   Else Emit('        ; CALL ' + para_name);
   Emit('        JMP     ' + lbl_loop);
   EmitLabel(lbl_done);
   Exit;
  End;
  { PERFORM para inline avec TEST BEFORE/AFTER VARYING }
  If (current_symbol = SYM_WITH) Or (TokenIs('WITH')) Then
  Begin
   While (current_symbol <> SYM_END_PERFORM) And (current_symbol <> TOK_PERIOD) And
         (current_symbol <> TOK_EOF) Do Consume;
   If current_symbol = SYM_END_PERFORM Then Consume;
   EmitComment('PERFORM WITH VARYING (stub)');
   Exit;
  End;
  { PERFORM para simple }
  para_idx := FindParagraph(para_name);
  If thru_name <> '' Then EmitComment('PERFORM ' + para_name + ' THRU ' + thru_name)
  Else EmitComment('PERFORM ' + para_name);
  If para_idx > 0 Then Emit('        CALL    ' + ParaAsmLabel(para_idx))
  Else Emit('        ; CALL ' + para_name + ' (non encore defini, a resoudre)');
 End Else
 Begin
  { PERFORM inline sans nom : PERFORM ... END-PERFORM }
  While (current_symbol <> SYM_END_PERFORM) And
        (current_symbol <> TOK_PERIOD) And
        (current_symbol <> TOK_EOF) Do
   ParseStatement;
  If current_symbol = SYM_END_PERFORM Then Consume;
 End;
End;

{ ======================================================================
  GENERATION FILE I/O
  ====================================================================== }
Procedure ParseOpen;
Var mode_s, fname, fh: String; mode, fi: Integer; lbl: String;
Begin
 Consume; { OPEN }
 EmitComment('---- OPEN ----');
 Repeat
  mode_s := 'INPUT'; mode := 0;
  If TokenIs('INPUT')  Then Begin mode := 0; mode_s := 'INPUT';  Consume; End
  Else If TokenIs('OUTPUT') Then Begin mode := 1; mode_s := 'OUTPUT'; Consume; End
  Else If TokenIs('I-O')    Then Begin mode := 2; mode_s := 'I-O';    Consume; End
  Else If (current_symbol = SYM_EXTEND) Or TokenIs('EXTEND') Then
   Begin mode := 3; mode_s := 'EXTEND'; Consume; End
  Else Break;
  Repeat
   If Not IsIdentifier Then Break;
   fname := current_token; Consume;
   fi := FindFileEntry(fname);
   EmitComment('OPEN ' + mode_s + ' ' + fname);
   If fi > 0 Then
   Begin
    fh  := '_FH_' + ItoSI(fi);
    lbl := 'LOPN' + ItoSI(fi) + '_' + ItoSI(label_counter);
    Inc(label_counter);
    If mode = 0 Then { INPUT }
    Begin
     Emit('        LEA     DX, _FN_' + ItoSI(fi));
     Emit('        MOV     AX, 3D00h');
     Emit('        INT     21h');
     Emit('        JC      ' + lbl + 'E');
     Emit('        MOV     ' + fh + ', AX');
     Emit('        JMP     ' + lbl + 'K');
    End Else { OUTPUT / I-O / EXTEND }
    Begin
     Emit('        LEA     DX, _FN_' + ItoSI(fi));
     Emit('        XOR     CX, CX');
     Emit('        MOV     AH, 3Ch');
     Emit('        INT     21h');
     Emit('        JC      ' + lbl + 'E');
     Emit('        MOV     ' + fh + ', AX');
     Emit('        JMP     ' + lbl + 'K');
    End;
    EmitLabel(lbl + 'E');
    Emit('        MOV     ' + fh + ', 0FFFFh');
    EmitLabel(lbl + 'K');
   End Else EmitComment('OPEN: ' + fname + ' non declare');
   If TokenIs('WITH') Then Consume;
   If TokenIs('NO') Then Begin Consume; If TokenIs('REWIND') Then Consume; End;
  Until (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF) Or
        TokenIs('INPUT') Or TokenIs('OUTPUT') Or TokenIs('I-O') Or
        (current_symbol = SYM_EXTEND);
 Until (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF);
End;

Procedure ParseClose;
Var fname, fh: String; fi: Integer; lbl: String;
Begin
 Consume; { CLOSE }
 EmitComment('---- CLOSE ----');
 Repeat
  If Not IsIdentifier Then Break;
  fname := current_token; Consume;
  fi := FindFileEntry(fname);
  EmitComment('CLOSE ' + fname);
  If fi > 0 Then
  Begin
   fh  := '_FH_' + ItoSI(fi);
   lbl := 'LCLZ' + ItoSI(fi) + '_' + ItoSI(label_counter); Inc(label_counter);
   Emit('        MOV     BX, ' + fh);
   Emit('        CMP     BX, 0FFFFh');
   Emit('        JE      ' + lbl);
   Emit('        MOV     AH, 3Eh');
   Emit('        INT     21h');
   Emit('        MOV     ' + fh + ', 0FFFFh');
   EmitLabel(lbl);
  End Else EmitComment('CLOSE: ' + fname + ' non declare');
  If TokenIs('WITH') Then Consume;
  If TokenIs('LOCK') Or TokenIs('NO') Or TokenIs('REWIND') Then Consume;
  If (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF) Or IsVerb Then Break;
 Until False;
End;

Procedure ParseRead;
Var fname, fh, rb: String; fi, sz, i2: Integer;
    lbl_ae, lbl_ne, lbl_done: String;
Begin
 Consume; { READ }
 EmitComment('---- READ ----');
 If Not IsIdentifier Then
 Begin
  While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume; Exit;
 End;
 fname := current_token; Consume;
 fi := FindFileEntry(fname);
 lbl_ae   := NewLabel + 'AE';
 lbl_ne   := NewLabel + 'NE';
 lbl_done := NewLabel + 'RD';
 If current_symbol = SYM_INTO Then Begin Consume; If IsIdentifier Then Consume; End;
 If TokenIs('NEXT') Or TokenIs('PREVIOUS') Then Consume;
 If TokenIs('RECORD') Then Consume;
 EmitComment('READ ' + fname);
 If fi > 0 Then
 Begin
  { Trouver buffer du FD }
  rb  := '_UNDEF_'; sz := 80;
  fh  := '_FH_' + ItoSI(fi);
  { Chercher le record 01 de ce fichier }
  For i2 := 1 to data_count do
   If (data_table[i2]^.section = SECT_FILE) And
      (data_table[i2]^.level = 1) And
      (data_table[i2]^.file_idx = fi) Then
   Begin
    rb := VarAsmRef(i2); sz := VarSz(i2); Break;
   End;
  Emit('        MOV     BX, ' + fh);
  Emit('        LEA     DX, ' + rb);
  Emit('        MOV     CX, ' + ItoSI(sz));
  Emit('        MOV     AH, 3Fh');
  Emit('        INT     21h');
  Emit('        JC      ' + lbl_ae);
  Emit('        CMP     AX, 0');
  Emit('        JE      ' + lbl_ae);
  Emit('        JMP     ' + lbl_ne);
 End Else EmitComment('READ: ' + fname + ' non declare');
 EmitLabel(lbl_ae);
 If (current_symbol = SYM_AT) Or TokenIs('AT') Then Consume;
 If TokenIs('END') Then
 Begin
  Consume;
  While Not (current_symbol = SYM_NOT) And Not TokenIs('NOT') And
        Not IsVerb And
        (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) And
        Not TokenIs('END-READ') And (current_symbol <> SYM_END_READ) Do
   ParseStatement;
 End;
 Emit('        JMP     ' + lbl_done);
 EmitLabel(lbl_ne);
 If (current_symbol = SYM_NOT) Or TokenIs('NOT') Then Consume;
 If (current_symbol = SYM_AT) Or TokenIs('AT') Then Consume;
 If TokenIs('END') Then
 Begin
  Consume;
  While Not TokenIs('END-READ') And (current_symbol <> SYM_END_READ) And
        Not IsVerb And
        (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do
   ParseStatement;
 End;
 EmitLabel(lbl_done);
 If (current_symbol = SYM_END_READ) Then Consume;
End;

Procedure ParseWrite;
Var
 rec_name, fh: String; fi, sz, oi2: Integer;
 ok: Integer; os: String; on2: LongInt; oi: Integer;
Begin
 Consume; { WRITE }
 EmitComment('---- WRITE ----');
 If Not IsIdentifier Then
 Begin
  While (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume; Exit;
 End;
 rec_name := current_token; Consume;
 { FROM var }
 If current_symbol = SYM_FROM Then
 Begin
  Consume;
  ParseOperand(ok, os, on2, oi);
  { Copier operande vers buffer FD }
  oi2 := FindDataItem(rec_name, SECT_FILE);
  If (oi2 > 0) And (ok = OP_VAR) And (oi > 0) Then
  Begin
   Emit('        LEA     SI, ' + VarAsmRef(oi));
   Emit('        LEA     DI, ' + VarAsmRef(oi2));
   Emit('        MOV     CX, ' + ItoSI(VarSz(oi)));
   Emit('        MOV     BX, ' + ItoSI(VarSz(oi2)));
   Emit('        CALL    _MOVE_STR_LJ');
  End;
 End;
 { AFTER/BEFORE ADVANCING }
 If (current_symbol = SYM_AFTER) Or (current_symbol = SYM_BEFORE) Then
 Begin
  Consume;
  If TokenIs('ADVANCING') Or TokenIs('WRITING') Then Consume;
  While Not IsVerb And (current_symbol <> TOK_PERIOD) And
        (current_symbol <> TOK_EOF) And
        Not TokenIs('END-WRITE') And (current_symbol <> SYM_END_WRITE) Do Consume;
 End;
 { Chercher le fichier owning le record }
 EmitComment('WRITE ' + rec_name);
 oi2 := FindDataItem(rec_name, SECT_FILE);
 If oi2 > 0 Then
 Begin
  fi := data_table[oi2]^.file_idx;
  sz := VarSz(oi2);
  If fi > 0 Then
  Begin
   fh := '_FH_' + ItoSI(fi);
   Emit('        MOV     BX, ' + fh);
   Emit('        LEA     DX, ' + VarAsmRef(oi2));
   Emit('        MOV     CX, ' + ItoSI(sz));
   Emit('        MOV     AH, 40h');
   Emit('        INT     21h');
  End Else EmitComment('WRITE: pas de fichier associe a ' + rec_name);
 End Else EmitComment('WRITE: record ' + rec_name + ' non trouve');
 If current_symbol = SYM_END_WRITE Then Consume;
End;

Procedure ParseRewrite;
Begin
 Consume; { REWRITE }
 EmitComment('---- REWRITE (stub) ----');
 While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
End;

Procedure ParseDeleteKW;
Begin
 Consume; { DELETE }
 EmitComment('---- DELETE (stub) ----');
 While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
End;

{ ======================================================================
  GENERATION STOP/GO/CALL/EXIT/DIVERS
  ====================================================================== }
Procedure ParseStop;
Begin
 Consume; { STOP }
 If TokenIs('RUN') Then Consume;
 EmitComment('STOP RUN');
 Emit('        MOV     AX, 4C00h');
 Emit('        INT     21h');
End;

Procedure ParseGoTo;
Var para_name: String; para_idx: Integer;
Begin
 Consume; { GO }
 If current_symbol = SYM_TO Then Consume;
 EmitComment('---- GO TO ----');
 If IsIdentifier Then
 Begin
  para_name := current_token; Consume;
  para_idx  := FindParagraph(para_name);
  EmitComment('GO TO ' + para_name);
  If para_idx > 0 Then Emit('        JMP     ' + ParaAsmLabel(para_idx))
  Else
  Begin
   { Para pas encore dans la table - generer un JMP avec label provisoire }
   Inc(label_counter);
   Emit('        ; JMP ' + para_name + ' (para pas encore defini)');
   Emit('        JMP     PARA_' + para_name);  { sera resolu si para existe }
  End;
  If current_symbol = SYM_DEPENDING Then
  Begin
   EmitComment('DEPENDING ON (stub)');
   While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
  End;
 End;
End;

Procedure ParseCall;
Var prog_name: String;
Begin
 Consume; { CALL }
 prog_name := '';
 If current_symbol = TOK_STRING Then Begin prog_name := current_token; Consume; End
 Else If IsIdentifier Then Begin prog_name := current_token; Consume; End;
 EmitComment('---- CALL ''' + prog_name + ''' ----');
 If current_symbol = SYM_USING Then
 Begin
  Consume;
  While IsIdentifier Or (current_symbol = SYM_BY) Or
        (current_symbol = SYM_REFERENCE) Or (current_symbol = SYM_CONTENT) Do
  Begin
   If IsIdentifier Then
   Begin
    EmitComment('  USING ' + current_token);
    Emit('        LEA     AX, ' + VarAsmRef(FindDataItem(current_token, SECT_NONE)));
    Emit('        PUSH    AX  ; USING ' + current_token);
   End;
   Consume;
  End;
 End;
 Emit('        ; CALL ' + prog_name + ' (external - stub)');
 { ON EXCEPTION }
 If TokenIs('ON') Then Consume;
 If TokenIs('EXCEPTION') Or TokenIs('OVERFLOW') Then
 Begin Consume; While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume; End;
 If TokenIs('NOT') Then Begin Consume; If TokenIs('ON') Then Consume; If TokenIs('EXCEPTION') Then Consume; End;
 If TokenIs('END-CALL') Then Consume;
End;

Procedure ParseExitStmt;
Begin
 Consume; { EXIT }
 If TokenIs('PROGRAM') Then
 Begin Consume; EmitComment('EXIT PROGRAM'); Emit('        RET     ; EXIT PROGRAM'); End
 Else
  EmitComment('EXIT (para terminus)');
End;

Procedure ParseContinue;
Begin
 Consume; { CONTINUE }
 EmitComment('CONTINUE (nop)');
 Emit('        NOP');
End;

Procedure ParseInitialize;
Var ok: Integer; os: String; on2: LongInt; oi: Integer; szs: String;
Begin
 Consume; { INITIALIZE }
 EmitComment('---- INITIALIZE ----');
 Repeat
  ParseOperand(ok, os, on2, oi);
  If ok = OP_NONE Then Break;
  If (ok = OP_VAR) And (oi > 0) Then
  Begin
   szs := ItoSI(VarSz(oi));
   EmitComment('INITIALIZE ' + data_table[oi]^.name);
   Emit('        LEA     DI, ' + VarAsmRef(oi));
   If (data_table[oi]^.data_type = TYPE_PIC_X) Or
      (data_table[oi]^.data_type = TYPE_PIC_A) Or
      data_table[oi]^.is_group Then
    Emit('        MOV     AL, 20h') Else Emit('        MOV     AL, 30h');
   Emit('        MOV     CX, ' + szs);
   Emit('        REP     STOSB');
  End;
  If (current_symbol = TOK_PERIOD) Or (current_symbol = TOK_EOF) Or IsVerb Then Break;
 Until False;
 If TokenIs('REPLACING') Then
  While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
End;

Procedure ParseStringKW;
Begin
 Consume; { STRING }
 EmitComment('---- STRING (stub) ----');
 While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) And
       Not TokenIs('END-STRING') Do Consume;
 If TokenIs('END-STRING') Then Consume;
End;

Procedure ParseUnstring;
Begin
 Consume; { UNSTRING }
 EmitComment('---- UNSTRING (stub) ----');
 While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) And
       Not TokenIs('END-UNSTRING') Do Consume;
 If TokenIs('END-UNSTRING') Then Consume;
End;

Procedure ParseInspect;
Begin
 Consume; { INSPECT }
 EmitComment('---- INSPECT (stub) ----');
 While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
End;

Procedure ParseCancel;
Begin
 Consume; { CANCEL }
 EmitComment('---- CANCEL (stub) ----');
 While Not IsVerb And (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
End;

{ ======================================================================
  DISPATCHER D'INSTRUCTIONS
  ====================================================================== }
Procedure ParseStatement;
Begin
 { Passer les points-virgules et virgules entre enonces }
 While (current_symbol = TOK_SEMICOLON) Or (current_symbol = TOK_COMMA) Do Consume;
 Case current_symbol Of
  SYM_MOVE:       ParseMove;
  SYM_ADD:        ParseAdd;
  SYM_SUBTRACT:   ParseSubtract;
  SYM_MULTIPLY_V: ParseMultiply;
  SYM_DIVIDE_V:   ParseDivide;
  SYM_COMPUTE:    ParseCompute;
  SYM_IF:         ParseIf;
  SYM_EVALUATE:   ParseEvaluate;
  SYM_PERFORM:    ParsePerform;
  SYM_DISPLAY:    ParseDisplay;
  SYM_ACCEPT:     ParseAccept;
  SYM_OPEN:       ParseOpen;
  SYM_CLOSE:      ParseClose;
  SYM_READ:       ParseRead;
  SYM_WRITE:      ParseWrite;
  SYM_REWRITE:    ParseRewrite;
  SYM_DELETE_KW:  ParseDeleteKW;
  SYM_STOP:       ParseStop;
  SYM_GO:         ParseGoTo;
  SYM_CALL:       ParseCall;
  SYM_EXIT:       ParseExitStmt;
  SYM_CONTINUE_KW:ParseContinue;
  SYM_INITIALIZE: ParseInitialize;
  SYM_INSPECT:    ParseInspect;
  SYM_STRING_KW:  ParseStringKW;
  SYM_UNSTRING:   ParseUnstring;
  SYM_CANCEL:     ParseCancel;
 Else
  { Consommer le token courant (instruction inconnue - eviter boucle infinie) }
  If (current_symbol <> TOK_PERIOD) And (current_symbol <> TOK_EOF) Then
  Begin
   If current_symbol >= 100 Then
    EmitComment('instruction inconnue: ' + current_token);
   Consume;
  End;
 End;
 { Consommer le point terminateur si present }
 If current_symbol = TOK_PERIOD Then Consume;
End;

{ ======================================================================
  PROCEDURE DIVISION PARSER
  ====================================================================== }
{ Teste si le token courant est DEBUT d'un nouveau paragraphe.
  Un paragraphe commence par un identifiant en colonne A (col 8) suivi de '.'
  Heuristique : si token_column <= 4 (colonne relative < 4 dans source_zone)
  et que c'est un identifiant non suivi d'un niveau, c'est un para. }
Function IsParaBegin: Boolean;
Begin
 IsParaBegin :=
  (IsIdentifier Or (current_symbol = TOK_WORD)) And
  ( (current_symbol <> SYM_SECTION) ) And
  Not IsVerb;
End;

Procedure ParseProcedureDivision;
Var
 para_name : String;
 para_idx  : Integer;
 first_para: Boolean;
 nxt_tok   : Integer;
Begin
 Consume; { PROCEDURE }
 If current_symbol = SYM_DIVISION Then Consume;
 { USING clause (programmes appeles) }
 If current_symbol = SYM_USING Then
 Begin
  EmitComment('PROCEDURE DIVISION USING (stub)');
  While Not (current_symbol = TOK_PERIOD) And (current_symbol <> TOK_EOF) Do Consume;
 End;
 If current_symbol = TOK_PERIOD Then Consume;
 WriteLn('INFO: Parsing PROCEDURE DIVISION...');
 { Generer le point d entree du programme }
 Emit('START:');
 Emit('        MOV     AX, @DATA');
 Emit('        MOV     DS, AX');
 Emit('        MOV     ES, AX');
 EmitBlank;
 { Appeler le premier paragraphe ; il se terminera par STOP RUN ou RET }
 first_para_lbl := '';
 first_para     := True;
 need_ret       := False;
 { Boucle principale : parser les paragraphes }
 While (current_symbol <> TOK_EOF) Do
 Begin
  { Gerer les declarations de section (saut) }
  nxt_tok := current_symbol;
  { Detecter un nouveau nom de paragraphe :
    Identifiant en colonne <= 12 dans la zone source, suivi de '.' (next tok) }
  If IsIdentifier And Not IsVerb Then
  Begin
   para_name := current_token;
   Consume;
   { Si suivi de 'SECTION .' : c'est une section COBOL }
   If current_symbol = SYM_SECTION Then
   Begin
    Consume;
    If current_symbol = TOK_PERIOD Then Consume;
    EmitComment('=== SECTION : ' + para_name + ' ===');
    Continue;
   End;
   { Sinon c'est un paragraphe }
   If current_symbol = TOK_PERIOD Then Consume;
   { Emettre RET a la fin du paragraphe precedent (sauf tout debut) }
   If Not first_para And need_ret Then
   Begin
    Emit('        RET     ; fin de ' + cur_para_name);
    EmitBlank;
   End;
   { Enregistrer le paragraphe }
   para_idx := FindParagraph(para_name);
   If para_idx = 0 Then para_idx := AddParagraph(para_name, '');
   { Emettre le label ASM }
   EmitComment('=== ' + para_name + ' ===');
   EmitLabel(ParaAsmLabel(para_idx));
   { Aussi emettre le label avec le nom COBOL pour les GO TO forwards }
   Emit('PARA_' + para_name + ':');
   { Si premier paragraphe, emettre le JMP depuis START }
   If first_para Then
   Begin
    { On doit maintenant emettre le CALL au premier para depuis START.
      Mais on est deja dans le CODE. On va emetre un JMP entre START et le para. }
    { Ruse : on a deja emis 'START:' + MOV AX,@DATA etc. Maintenant on genere
      CALL premier_para juste avant le label du para, puis apres on met le label.
      Probleme : ordre. Solution : emettre le CALL+EXIT avant le label. }
    { Pragmatique : on accepte que START tombe directement sur le premier para }
    first_para_lbl := ParaAsmLabel(para_idx);
    first_para     := False;
   End;
   cur_para_name := para_name;
   need_ret      := True;
   Continue;
  End;
  { Parser les instructions du paragraphe courant }
  If (current_symbol = TOK_EOF) Then Break;
  ParseStatement;
 End;
 { Emettre le RET final du dernier paragraphe }
 If need_ret Then
 Begin
  Emit('        RET     ; fin de ' + cur_para_name);
  EmitBlank;
 End;
 { Si le programme n a pas de STOP RUN, ajouter un EXIT propre }
 Emit('        ; Fin du programme (fallthrough)');
 Emit('        MOV     AX, 4C00h');
 Emit('        INT     21h');
 WriteLn('INFO: PROCEDURE DIVISION terminee. Paragraphes: ', para_count);
 GenRuntimeHelpers;
 GenFooter;
End;

{ ======================================================================
  INITIALISATION DU GENERATEUR
  ====================================================================== }
Procedure InitCodegen;
Begin
 label_counter  := 0;
 lit_counter    := 0;
 gen_enabled    := False; { Active par le main si fichier de sortie est ouvert }
 first_para_lbl := '';
 cur_para_name  := '';
 need_ret       := False;
End;

Var
 i            : Integer;
 opt_dump_tok : Boolean;
 opt_dump_sym : Boolean;
 arg          : String;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('COBOL86 - Cette commande permet de lancer le compilateur COBOL pour 8086/8088.');
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
  Halt(0);
 End;
 opt_dump_tok    := False;
 opt_dump_sym    := False;
 source_filename := '';
 output_filename := '';

 For i := 1 to ParamCount do
 Begin
  arg := ParamStr(i);
  If (UpperStr(arg) = '/T') or (UpperStr(arg) = '-T') Then
   opt_dump_tok := True
  Else If (UpperStr(arg) = '/S') or (UpperStr(arg) = '-S') Then
   opt_dump_sym := True
  Else If source_filename = '' Then
   source_filename := arg
  Else If output_filename = '' Then
   output_filename := arg;
 End;

 If source_filename = '' Then Begin
  WriteLn('Nom du fichier source attendue !');
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
 InitCodegen;
 InitTokenizer;

 If opt_dump_tok Then
 Begin
  DumpTokens;
  Close(input_file);
  WriteLn('Termine. Erreurs: ', error_count);
  Halt(0);
 End;

 { Dispatcher selon la division courante }
 If current_symbol = SYM_IDENTIFICATION Then
  ParseIdentificationDivision
 Else
  Warning('Fichier COBOL ne commencant pas par IDENTIFICATION DIVISION');

 { ENVIRONMENT DIVISION (optionnelle) }
 If current_symbol = SYM_ENVIRONMENT Then
  ParseEnvironmentDivision;

 { DATA DIVISION }
 If current_symbol = SYM_DATA Then
  ParseDataDivision;

 If opt_dump_sym Then DumpSymbolTable;

 { PROCEDURE DIVISION : ouvrir la sortie ASM puis generer }
 If Not opt_dump_tok And Not opt_dump_sym Then
 Begin
  Assign(output_file, output_filename);
  Rewrite(output_file);
  If IOResult <> 0 Then
  Begin
   WriteLn('ERREUR: Impossible de creer le fichier ASM: ', output_filename);
   Halt(1);
  End;
  gen_enabled := True;
  GenHeader;
  { PROCEDURE DIVISION }
  If current_symbol = SYM_PROCEDURE Then
   ParseProcedureDivision
  Else
  Begin
   { Pas de PROCEDURE DIVISION : generer au minimum un main vide }
   Emit('START:');
   Emit('        MOV     AX, @DATA');
   Emit('        MOV     DS, AX');
   Emit('        MOV     ES, AX');
   Emit('        MOV     AX, 4C00h');
   Emit('        INT     21h');
   GenRuntimeHelpers;
   GenFooter;
  End;
  Close(output_file);
  WriteLn('ASM genere: ', output_filename);
 End;

 Close(input_file);
 WriteLn('Termine. Erreurs: ', error_count);
 If error_count > 0 Then Halt(1);
END.
