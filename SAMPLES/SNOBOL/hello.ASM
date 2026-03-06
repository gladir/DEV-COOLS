; ========================================================================
; Genere par SNOBOL86 v1.0 - SNOBOL 4 -> 8086 MASM
; Source : samples\SNOBOL\hello.sbl
; ========================================================================

.MODEL SMALL
.STACK 256

.DATA

; --- Constantes systeme ---
; "" - chaine vide (descripteur initial de toute variable)
	_SB_EMPTY_DESC:
	  DW  OFFSET _SB_EMPTY_BUF  ; ptr
	  DW  0                      ; len = 0
	_SB_EMPTY_BUF:
	  DB  0                      ; buffer null

; CRLF - fin de ligne
	_SB_CRLF_DESC:
	  DW  OFFSET _SB_CRLF_BUF  ; ptr
	  DW  2                     ; len = 2
	_SB_CRLF_BUF:
	  DB  0Dh, 0Ah, 0          ; CR LF null

; &ALPHABET - les 256 caracteres ASCII
	_SB_SYS_ALPHABET_D:
	  DW  OFFSET _SB_SYS_ALPHABET_B  ; ptr
	  DW  256                         ; len
	_SB_SYS_ALPHABET_B:
	DB  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	DB  , 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
	DB  , 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47
	DB  , 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63
	DB  , 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
	DB  , 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
	DB  , 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111
	DB  , 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127
	DB  , 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143
	DB  , 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159
	DB  , 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175
	DB  , 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191
	DB  , 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207
	DB  , 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223
	DB  , 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239
	DB  , 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255

; _SB_FAIL_DESC - sentinel d'echec (len=0FFFFh)
	_SB_FAIL_DESC:
	  DW  0       ; ptr nul
	  DW  0FFFFh  ; len magique = echec

; --- Variables systeme (&xxx) ---
	_SB_SYS_ANCHOR  DW  0       ; &ANCHOR
	_SB_SYS_DUMP    DW  0       ; &DUMP
	_SB_SYS_FNCODE  DW  0       ; &FNCODE
	_SB_SYS_FULLSCAN DW 0       ; &FULLSCAN
	_SB_SYS_STCOUNT  DW 0       ; &STCOUNT
	_SB_SYS_STFAIL   DW 0       ; &STFAIL
	_SB_SYS_STLIMIT  DW 50000   ; &STLIMIT
	_SB_SYS_TRIM     DW 0       ; &TRIM

; Descripteur : _SB_SYS_INPUT_D
	_SB_SYS_INPUT_D:
	DW  OFFSET _SB_SYS_INPUT_B  ; ptr
	DW  0                       ; len courante (init = 0)
	_SB_SYS_INPUT_B:
	DB  0                    ; buffer vide (chaine "")
	DB  0                    ; garde-fou null
; Descripteur : _SB_SYS_OUTPUT_D
	_SB_SYS_OUTPUT_D:
	DW  OFFSET _SB_SYS_OUTPUT_B  ; ptr
	DW  0                       ; len courante (init = 0)
	_SB_SYS_OUTPUT_B:
	DB  0                    ; buffer vide (chaine "")
	DB  0                    ; garde-fou null
; Descripteur : _SB_SYS_SUBJECT_D
	_SB_SYS_SUBJECT_D:
	DW  OFFSET _SB_SYS_SUBJECT_B  ; ptr
	DW  0                       ; len courante (init = 0)
	_SB_SYS_SUBJECT_B:
	DB  0                    ; buffer vide (chaine "")
	DB  0                    ; garde-fou null

; --- Descripteurs de variables SNOBOL ---

; --- Pool de litteraux de chaine ---
; Litteral : 'BONJOUR MONDE'
	_SBS_0_D:
	DW  OFFSET _SBS_0_B  ; ptr
	DW  13           ; len
	_SBS_0_B:
	DB  66, 79, 78, 74, 79, 85, 82, 32, 77, 79, 78, 68, 69
	DB  0  ; garde-fou null

; ------------------------------------------------------------------------
; Heap dynamique SNOBOL runtime (8192 octets)
; ------------------------------------------------------------------------
	_HEAP_BASE  DW  0            ; offset base dans DS
	_HEAP_PTR   DW  0            ; offset prochain octet libre
	_HEAP_END   DW  0            ; offset premiere adresse invalide
	_HEAP_BUF   DB  8192 DUP(0)  ; zone de donnees

; --- Buffers runtime ---
	_SB_NUMBUF    DB  12 DUP(0)   ; conversion entier->chaine
	_SB_INPUTBUF  DB  128 DUP(0)  ; lecture ligne DOS AH=0Ah
	_SB_WORKDESC:
	  DW  OFFSET _SB_WORKBUF  ; ptr scratch
	  DW  0                   ; len scratch
	_SB_WORKBUF   DB  256 DUP(0)  ; buffer de travail

; Message depassement &STLIMIT
	_SB_STLIMIT_MSG:
	  DB  'Erreur : &STLIMIT depasse', 0Dh, 0Ah, '$'


.CODE

; ========================================================================
; Point d'entree du programme
; ========================================================================
START:
	MOV  AX, @DATA
	MOV  DS, AX
	MOV  ES, AX

; Initialisation runtime SNOBOL
	CALL _SB_INIT_HEAP
	CALL _SB_INIT_IO
	CALL _SB_INIT_SYSVARS

; Saut vers la premiere instruction du programme
	JMP  _SBL_OUTPUT

; ------------------------------------------------------------------------
; _SB_INIT_IO : initialiser stdin/stdout (DOS : deja ouvert)
; ------------------------------------------------------------------------
_SB_INIT_IO:
	MOV  AL, 127
	MOV  [_SB_INPUTBUF], AL    ; max chars pour AH=0Ah
	MOV  BYTE PTR [_SB_INPUTBUF+1], 0
	RET

; ------------------------------------------------------------------------
; _SB_INIT_SYSVARS : initialiser les variables systeme &xxx
; ------------------------------------------------------------------------
_SB_INIT_SYSVARS:
	XOR  AX, AX
	MOV  [_SB_SYS_ANCHOR],   AX
	MOV  [_SB_SYS_DUMP],     AX
	MOV  [_SB_SYS_FNCODE],   AX
	MOV  [_SB_SYS_FULLSCAN], AX
	MOV  [_SB_SYS_STCOUNT],  AX
	MOV  [_SB_SYS_STFAIL],   AX
	MOV  [_SB_SYS_TRIM],     AX
	MOV  AX, 50000
	MOV  [_SB_SYS_STLIMIT],  AX
	RET

; --- Code programme SNOBOL (passe 1) ---
_SBL_OUTPUT:
	INC  WORD PTR [_SB_SYS_STCOUNT]
	MOV  AX, [_SB_SYS_STCOUNT]
	CMP  AX, [_SB_SYS_STLIMIT]
	JBE  @@L1
	MOV  DX, OFFSET _SB_STLIMIT_MSG
	MOV  AH, 9
	INT  21h
	JMP  _SB_END_PROG
@@L1:
; Affectation :  = 'BONJOUR MONDE'
	LEA  DI, [_SBS_0_D]
	PUSH AX
	MOV  AX, [DI]
	MOV  [_D],   AX     ; stocker ptr
	MOV  AX, [DI+2]
	MOV  [_D+2], AX     ; stocker len
	POP  AX

; Fin explicite du programme (-END-)
	JMP  _SB_END_PROG


; ------------------------------------------------------------------------
; _SB_END_PROG : fin du programme SNOBOL
; ------------------------------------------------------------------------
_SB_END_PROG:
	MOV  AX, [_SB_SYS_DUMP]
	CMP  AX, 0
	JE   @@L2
	CALL _SB_DUMP_VARS
@@L2:

; Retour DOS - code 0
	MOV  AX, 4C00h
	INT  21h

; ------------------------------------------------------------------------
; _SB_DUMP_VARS : dump variables globales (stub v1)
; ------------------------------------------------------------------------
_SB_DUMP_VARS:
	RET

; ------------------------------------------------------------------------
; === Runtime : gestion du heap dynamique ===
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; _SB_INIT_HEAP : initialiser le heap dynamique
; ------------------------------------------------------------------------
_SB_INIT_HEAP:
	MOV  AX, OFFSET _HEAP_BUF
	MOV  [_HEAP_BASE], AX
	MOV  [_HEAP_PTR],  AX
	ADD  AX, 8192
	MOV  [_HEAP_END],  AX
	RET

; ------------------------------------------------------------------------
; _SB_ALLOC : allouer CX octets sur le heap -> BX = adresse
; ------------------------------------------------------------------------
_SB_ALLOC:
	MOV  BX, [_HEAP_PTR]
	MOV  AX, BX
	ADD  AX, CX
	CMP  AX, [_HEAP_END]
	JBE  @@L3
	MOV  DX, OFFSET _SB_HEAP_OOM_MSG
	MOV  AH, 9
	INT  21h
	JMP  _SB_END_PROG
@@L3:
	MOV  [_HEAP_PTR], AX
	RET

; ------------------------------------------------------------------------
; _SB_NEWSTR : allouer un descripteur pour CX chars -> DI
; ------------------------------------------------------------------------
_SB_NEWSTR:
	PUSH CX
	ADD  CX, 5
	CALL _SB_ALLOC
	POP  CX
	MOV  DI, BX
	MOV  AX, BX
	ADD  AX, 4
	MOV  [DI],   AX
	MOV  [DI+2], CX
	PUSH DI
	MOV  DI, AX
	ADD  DI, CX
	MOV  BYTE PTR [DI], 0
	POP  DI
	RET

; ------------------------------------------------------------------------
; _SB_COPYSTR : copier desc SI -> desc DI
; ------------------------------------------------------------------------
_SB_COPYSTR:
	PUSH SI
	PUSH DI
	MOV  CX, [SI+2]
	PUSH CX
	PUSH SI
	CALL _SB_NEWSTR
	MOV  DX, DI
	POP  SI
	POP  CX
	PUSH SI
	MOV  SI, [SI]
	MOV  DI, [DX]
	REP  MOVSB
	POP  SI
	POP  DI
	MOV  AX, [DX]
	MOV  [DI],   AX
	MOV  AX, [DX+2]
	MOV  [DI+2], AX
	POP  SI
	RET

; ------------------------------------------------------------------------
; _SB_CONCATSTR : DI||SI -> DX = nouveau desc
; ------------------------------------------------------------------------
_SB_CONCATSTR:
	PUSH SI
	PUSH DI
	MOV  AX, [DI+2]
	MOV  BX, [SI+2]
	MOV  CX, AX
	ADD  CX, BX
	PUSH AX
	PUSH BX
	PUSH SI
	PUSH DI
	CALL _SB_NEWSTR
	MOV  DX, DI
	POP  DI
	POP  SI
	POP  BX
	POP  AX
	PUSH SI
	MOV  SI, [DI]
	MOV  DI, [DX]
	MOV  CX, AX
	REP  MOVSB
	POP  SI
	MOV  SI, [SI]
	MOV  CX, BX
	REP  MOVSB
	MOV  BYTE PTR [DI], 0
	POP  DI
	POP  SI
	RET

; ------------------------------------------------------------------------
; === Runtime : operations sur les chaines ===
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; _RT_STRLEN : CX <- longueur du descripteur DI
; ------------------------------------------------------------------------
_RT_STRLEN:
	MOV  CX, [DI+2]
	RET

; ------------------------------------------------------------------------
; _RT_STRNCPY : copier CX octets de DS:SI vers ES:DI (brut)
; ------------------------------------------------------------------------
_RT_STRNCPY:
	JCXZ @@L4
	REP  MOVSB
@@L4:
	RET

; ------------------------------------------------------------------------
; _RT_STRCMP : comparer desc SI et desc DI -> flags CPU
;   ZF=1 si egal, CF=1 si SI < DI lexicographiquement
; ------------------------------------------------------------------------
_RT_STRCMP:
	PUSH SI
	PUSH DI
	PUSH BX
	MOV  CX, [SI+2]         ; CX = len1
	MOV  BX, [DI+2]         ; BX = len2
	MOV  AX, CX             ; AX = len1 (sauvegarde pour comparer longueurs)
	CMP  CX, BX
	JBE  @@L5         ; utiliser min(len1,len2)
	MOV  CX, BX
@@L5:
	MOV  SI, [SI]           ; SI = ptr donnees1
	MOV  DI, [DI]           ; DI = ptr donnees2
	JCXZ @@L6
	REPE CMPSB              ; comparer octet par octet
	JNE  @@L7        ; difference trouvee -> flags deja positionnes
@@L6:
	CMP  AX, BX             ; bytes egaux : comparer longueurs
@@L7:
	POP  BX
	POP  DI
	POP  SI
	RET

; ------------------------------------------------------------------------
; _RT_SUBSTR : extraire sous-chaine SI[AX..AX+CX-1] -> DI
;   AX = position 1-based, CX = longueur. Clamp si trop long.
; ------------------------------------------------------------------------
_RT_SUBSTR:
	PUSH BX
	PUSH DX
	CMP  AX, 1
	JAE  @@L8            ; pos >= 1 ok
	MOV  DX, OFFSET _RT_RANGE_ERR_MSG
	MOV  AH, 9
	INT  21h
	JMP  _SB_END_PROG
@@L8:
	MOV  BX, [SI+2]         ; BX = src_len
	CMP  AX, BX
	JBE  @@L9
	XOR  CX, CX             ; longueur = 0
	JMP  @@L10
@@L9:
	MOV  DX, AX
	DEC  DX                 ; DX = pos - 1
	MOV  BX, [SI+2]
	SUB  BX, DX             ; BX = chars disponibles depuis pos
	CMP  CX, BX
	JBE  @@L10      ; longueur ok
	MOV  CX, BX             ; clamp
@@L10:
	PUSH SI
	PUSH AX                 ; sauvegarder pos
	PUSH CX                 ; sauvegarder longueur
	CALL _SB_NEWSTR         ; DI = nouveau desc
	POP  CX                 ; longueur
	POP  AX                 ; pos
	POP  SI                 ; src_desc
	PUSH DI                 ; sauvegarder desc resultat
	MOV  DI, [DI]           ; DI = ptr buffer dest
	MOV  SI, [SI]           ; SI = ptr donnees source
	DEC  AX                 ; AX = pos - 1 (offset 0-based)
	ADD  SI, AX             ; SI = source + offset
	JCXZ @@L8_end
	REP  MOVSB
@@L8_end:
	MOV  BYTE PTR [DI], 0   ; null garde-fou
	POP  DI                 ; DI = desc resultat
	POP  DX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_DUPL : SI repete CX fois -> DI = desc concatene
; ------------------------------------------------------------------------
_RT_DUPL:
	PUSH CX                 ; [1] sauvegarder count
	MOV  AX, [SI+2]         ; AX = src_len
	MUL  CX                 ; AX = src_len * count (16 bits, ignore overflow)
	PUSH SI                 ; [2] sauvegarder src_desc
	MOV  CX, AX             ; CX = longueur totale pour _SB_NEWSTR
	CALL _SB_NEWSTR         ; DI = nouveau desc
	MOV  BX, DI             ; BX = desc resultat (sauvegarder)
	MOV  DI, [BX]           ; DI = ptr buffer dest courant
	POP  SI                 ; [2] src_desc
	MOV  DX, [SI+2]         ; DX = src_len (fixe pendant la boucle)
	MOV  SI, [SI]           ; SI = ptr donnees source (fixe)
	POP  CX                 ; [1] count
@@L11:
	JCXZ @@L13
	PUSH SI
	PUSH CX
	MOV  CX, DX             ; CX = src_len pour MOVSB
	JCXZ @@L12
	REP  MOVSB              ; copier src vers DI (DI avance)
@@L12:
	POP  CX
	POP  SI
	DEC  CX
	JMP  @@L11
@@L13:
	MOV  BYTE PTR [DI], 0   ; null garde-fou
	MOV  DI, BX             ; DI = desc resultat
	RET

; ------------------------------------------------------------------------
; _RT_REPLACE : transliterer SI via table[256] BX -> DI
; ------------------------------------------------------------------------
_RT_REPLACE:
	PUSH BX
	PUSH SI
	MOV  CX, [SI+2]         ; CX = longueur
	PUSH CX                 ; [1] sauvegarder longueur
	PUSH BX                 ; [2] sauvegarder table
	CALL _SB_NEWSTR         ; DI = nouveau desc
	MOV  DX, DI             ; DX = desc resultat
	MOV  DI, [DX]           ; DI = ptr buffer dest
	POP  BX                 ; [2] table
	POP  CX                 ; [1] longueur
	POP  SI                 ; src_desc
	MOV  SI, [SI]           ; SI = ptr donnees source
	JCXZ @@L15
@@L14:
	MOV  AL, [SI]           ; lire char source
	INC  SI
	XLAT                    ; AL <- BX[AL] (transliteration)
	MOV  [DI], AL           ; ecrire char traduit
	INC  DI
	LOOP @@L14
@@L15:
	MOV  BYTE PTR [DI], 0   ; null garde-fou
	MOV  DI, DX             ; DI = desc resultat
	POP  SI
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_TRIM : supprimer les blancs en fin de chaine SI -> DI
; ------------------------------------------------------------------------
_RT_TRIM:
	PUSH BX
	PUSH DX
	MOV  BX, [SI]           ; BX = ptr donnees
	MOV  CX, [SI+2]         ; CX = longueur initiale
	JCXZ @@L17           ; chaine vide -> rien a faire
@@L16:
	MOV  DX, BX
	ADD  DX, CX
	DEC  DX                 ; DX = adresse du dernier char
	CMP  BYTE PTR [DX], 32  ; est-ce un espace ?
	JNE  @@L17
	DEC  CX
	JCXZ @@L17
	JMP  @@L16
@@L17:
	PUSH SI
	PUSH CX                 ; [1] longueur trimee
	CALL _SB_NEWSTR         ; DI = nouveau desc
	POP  CX                 ; [1]
	POP  SI                 ; src_desc
	PUSH DI                 ; sauvegarder desc result
	MOV  DI, [DI]           ; DI = buffer dest
	MOV  SI, [SI]           ; SI = ptr donnees source
	JCXZ @@L17_copy
	REP  MOVSB
@@L17_copy:
	MOV  BYTE PTR [DI], 0   ; null
	POP  DI                 ; DI = desc resultat
	POP  DX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_LPAD : cadrer SI a gauche sur CX chars (fill=AL) -> DI
; ------------------------------------------------------------------------
_RT_LPAD:
	PUSH BX
	PUSH DX
	MOV  BX, [SI+2]         ; BX = src_len
	CMP  CX, BX
	JBE  @@L18         ; width <= len : pas de remplissage
	MOV  DX, CX
	SUB  DX, BX             ; DX = width - src_len (nb fill chars)
	PUSH SI
	PUSH AX                 ; [1] fill_char
	PUSH BX                 ; [2] src_len
	PUSH DX                 ; [3] nb fill chars
	CALL _SB_NEWSTR         ; DI = desc de longueur width
	MOV  BX, DI             ; BX = desc result
	MOV  DI, [BX]           ; DI = ptr buffer
	POP  DX                 ; [3] nb fill chars
	POP  CX                 ; [2] src_len
	POP  AX                 ; [1] fill_char (en AL)
	POP  SI                 ; src_desc
	PUSH CX                 ; sauvegarder src_len
	MOV  CX, DX
@@L20:
	JCXZ @@L19
	MOV  [DI], AL
	INC  DI
	LOOP @@L20
@@L19:
	POP  CX                 ; src_len
	MOV  SI, [SI]           ; SI = ptr donnees source
	JCXZ @@L18_end
	REP  MOVSB
@@L18_end:
	MOV  BYTE PTR [DI], 0
	MOV  DI, BX             ; DI = desc result
	POP  DX
	POP  BX
	RET
@@L18:
	CALL _SB_COPYSTR
	POP  DX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_RPAD : cadrer SI a droite sur CX chars (fill=AL) -> DI
; ------------------------------------------------------------------------
_RT_RPAD:
	PUSH BX
	PUSH DX
	MOV  BX, [SI+2]         ; BX = src_len
	CMP  CX, BX
	JBE  @@L21         ; pas de remplissage
	MOV  DX, CX
	SUB  DX, BX             ; DX = nb fill chars
	PUSH SI
	PUSH AX                 ; [1] fill_char
	PUSH BX                 ; [2] src_len
	PUSH DX                 ; [3] nb fill
	CALL _SB_NEWSTR         ; DI = desc width chars
	MOV  BX, DI             ; BX = desc result
	MOV  DI, [BX]           ; DI = ptr buffer
	POP  DX                 ; [3] nb fill
	POP  CX                 ; [2] src_len
	POP  AX                 ; [1] fill_char
	POP  SI                 ; src_desc
	PUSH DX                 ; sauvegarder nb fill
	MOV  SI, [SI]
	JCXZ @@L23
	REP  MOVSB
@@L23:
	POP  CX                 ; nb fill
@@L22:
	JCXZ @@L21_end
	MOV  [DI], AL
	INC  DI
	LOOP @@L22
@@L21_end:
	MOV  BYTE PTR [DI], 0
	MOV  DI, BX
	POP  DX
	POP  BX
	RET
@@L21:
	CALL _SB_COPYSTR
	POP  DX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_REVERSE : inverser les octets de SI -> DI
; ------------------------------------------------------------------------
_RT_REVERSE:
	PUSH BX
	PUSH DX
	MOV  CX, [SI+2]         ; CX = longueur
	PUSH SI
	PUSH CX                 ; [1]
	CALL _SB_NEWSTR         ; DI = nouveau desc
	POP  CX                 ; [1]
	POP  SI                 ; src_desc
	PUSH DI                 ; sauvegarder desc result
	MOV  BX, [DI]           ; BX = ptr buffer dest
	MOV  DX, [SI]           ; DX = ptr donnees source
	JCXZ @@L26
	ADD  DX, CX
	DEC  DX                 ; DX pointe sur le dernier char source
	MOV  DI, BX             ; DI = debut buffer dest
@@L25:
	MOV  AL, [DX]           ; lire char depuis la fin
	MOV  [DI], AL           ; ecrire au debut dest
	INC  DI
	DEC  DX
	LOOP @@L25
@@L26:
	MOV  BYTE PTR [BX+CX], 0 ; null (CX=0 ici, correct)
	POP  DI                 ; DI = desc resultat
	POP  DX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_UPPER : convertir SI en majuscules -> DI
; ------------------------------------------------------------------------
_RT_UPPER:
	PUSH BX
	PUSH DX
	MOV  CX, [SI+2]
	PUSH SI
	PUSH CX                 ; [1]
	CALL _SB_NEWSTR         ; DI = nouveau desc
	MOV  DX, DI             ; DX = desc result
	MOV  DI, [DX]           ; DI = buffer dest
	POP  CX                 ; [1]
	POP  SI                 ; src_desc
	MOV  SI, [SI]           ; SI = ptr donnees source
	JCXZ @@L29
@@L27:
	MOV  AL, [SI]
	INC  SI
	CMP  AL, 61h            ; 'a'
	JB   @@L28
	CMP  AL, 7Ah            ; 'z'
	JA   @@L28
	AND  AL, 0DFh           ; minuscule -> majuscule
@@L28:
	MOV  [DI], AL
	INC  DI
	LOOP @@L27
@@L29:
	MOV  BYTE PTR [DI], 0
	MOV  DI, DX             ; DI = desc resultat
	POP  DX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_LOWER : convertir SI en minuscules -> DI
; ------------------------------------------------------------------------
_RT_LOWER:
	PUSH BX
	PUSH DX
	MOV  CX, [SI+2]
	PUSH SI
	PUSH CX                 ; [1]
	CALL _SB_NEWSTR         ; DI = nouveau desc
	MOV  DX, DI             ; DX = desc result
	MOV  DI, [DX]           ; DI = buffer dest
	POP  CX                 ; [1]
	POP  SI                 ; src_desc
	MOV  SI, [SI]           ; SI = ptr donnees source
	JCXZ @@L32
@@L30:
	MOV  AL, [SI]
	INC  SI
	CMP  AL, 41h            ; 'A'
	JB   @@L31
	CMP  AL, 5Ah            ; 'Z'
	JA   @@L31
	OR   AL, 20h            ; majuscule -> minuscule
@@L31:
	MOV  [DI], AL
	INC  DI
	LOOP @@L30
@@L32:
	MOV  BYTE PTR [DI], 0
	MOV  DI, DX             ; DI = desc resultat
	POP  DX
	POP  BX
	RET

; ------------------------------------------------------------------------
; === Runtime : conversions et arithmetique ===
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; _RT_STR2INT : desc SI -> AX entier signe
; ------------------------------------------------------------------------
_RT_STR2INT:
	PUSH SI
	PUSH BX
	PUSH CX
	PUSH DX
	MOV  CX, [SI+2]           ; CX = longueur
	MOV  SI, [SI]             ; SI = ptr donnees
	XOR  AX, AX               ; accumulateur
	XOR  BX, BX               ; BX = signe (0=+, 1=-)
	JCXZ @@L37            ; chaine vide -> 0
@@L33:
	CMP  BYTE PTR [SI], 32
	JNE  @@L34
	INC  SI
	LOOP @@L33
	JMP  @@L37
@@L34:
	CMP  BYTE PTR [SI], 2Dh   ; '-'
	JNE  @@L35
	MOV  BX, 1
	INC  SI
	DEC  CX
	JMP  @@L36
@@L35:
	CMP  BYTE PTR [SI], 2Bh   ; '+'
	JNE  @@L36
	INC  SI
	DEC  CX
@@L36:
	JCXZ @@L37
	MOV  DL, [SI]             ; lire char
	SUB  DL, 30h              ; '0' = 30h
	JB   @@L37            ; < '0' -> stop
	CMP  DL, 9
	JA   @@L37            ; > '9' -> stop
	PUSH DX                   ; sauvegarder digit
	MOV  DX, 10
	MUL  DX                   ; DX:AX = AX * 10
	POP  DX
	ADD  AX, DX               ; AX += digit
	INC  SI
	DEC  CX
	JMP  @@L36
@@L37:
	CMP  BX, 0
	JE   @@L39
	NEG  AX                   ; appliquer le signe negatif
@@L39:
	POP  DX
	POP  CX
	POP  BX
	POP  SI
	RET

; ------------------------------------------------------------------------
; _RT_INT2STR : AX entier -> DI descripteur chaine
; ------------------------------------------------------------------------
_RT_INT2STR:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH SI
	PUSH DX
	XOR  BX, BX               ; BX = signe
	CMP  AX, 0
	JGE  @@L40
	NEG  AX
	MOV  BX, 1
@@L40:
	MOV  SI, OFFSET _SB_NUMBUF + 11 ; ptr fin de buffer
	MOV  BYTE PTR [SI], 0      ; null guard
	MOV  CX, 0                 ; compteur chars
	MOV  DX, 10
@@L41:
	XOR  DX, DX
	MOV  DX, 10
	DIV  DX                    ; AX = quotient, DX = reste (digit)
	ADD  DL, 30h               ; digit -> ASCII
	DEC  SI
	MOV  [SI], DL              ; ecrire dans buffer (droite vers gauche)
	INC  CX
	CMP  AX, 0
	JNE  @@L41
	CMP  BX, 0
	JE   @@L42
	DEC  SI
	MOV  BYTE PTR [SI], 2Dh   ; '-'
	INC  CX
@@L42:
	PUSH SI                    ; [1] ptr debut chaine dans NUMBUF
	PUSH CX                    ; [2] longueur
	CALL _SB_NEWSTR            ; DI = nouveau desc
	POP  CX                    ; [2]
	POP  SI                    ; [1] source
	PUSH DI                    ; sauvegarder desc result
	MOV  DI, [DI]             ; DI = ptr buffer dest
	JCXZ @@L43
	REP  MOVSB
@@L43:
	MOV  BYTE PTR [DI], 0
	POP  DI                    ; DI = desc resultat
	POP  DX
	POP  SI
	POP  CX
	POP  BX
	POP  AX
	RET

; ------------------------------------------------------------------------
; _RT_STR2REAL : desc SI -> DX:AX reel 16.16
; ------------------------------------------------------------------------
_RT_STR2REAL:
	PUSH SI
	PUSH BX
	PUSH CX
	MOV  CX, [SI+2]           ; CX = longueur
	MOV  SI, [SI]             ; SI = ptr donnees
	XOR  DX, DX               ; DX = partie entiere
	XOR  AX, AX               ; AX = partie fractionnaire
	XOR  BX, BX               ; BX = signe
	JCXZ @@L52
@@L44:
	CMP  BYTE PTR [SI], 32
	JNE  @@L45
	INC  SI
	LOOP @@L44
	JMP  @@L52
@@L45:
	CMP  BYTE PTR [SI], 2Dh
	JNE  @@L46
	MOV  BX, 1
	INC  SI
	DEC  CX
	JMP  @@L47
@@L46:
	CMP  BYTE PTR [SI], 2Bh
	JNE  @@L47
	INC  SI
	DEC  CX
@@L47:
	JCXZ @@L52
	CMP  BYTE PTR [SI], 2Eh   ; '.'
	JE   @@L48
	MOV  AL, [SI]
	SUB  AL, 30h
	JB   @@L52
	CMP  AL, 9
	JA   @@L52
	PUSH AX
	PUSH CX
	MOV  AX, DX
	MOV  CX, 10
	MUL  CX                   ; DX:AX = DX*10
	MOV  DX, AX               ; DX = partie entiere * 10
	POP  CX
	POP  AX
	ADD  DX, AX               ; DX += digit
	XOR  AX, AX               ; remettre AX=0 (frac)
	INC  SI
	DEC  CX
	JMP  @@L47
@@L48:
	INC  SI
	DEC  CX
	PUSH DX                   ; [1] sauvegarder partie entiere
	MOV  DX, 6553             ; DX = poids du 1er chiffre decimal (/65536)
	XOR  AX, AX               ; AX = accumulateur fraction
@@L49:
	JCXZ @@L51
	CMP  DX, 0                ; poids trop petit ?
	JE   @@L51
@@L50:
	MOV  BL, [SI]
	SUB  BL, 30h
	JB   @@L51
	CMP  BL, 9
	JA   @@L51
	PUSH AX
	PUSH CX
	MOV  AX, DX               ; AX = poids courant
	XOR  BH, BH
	MUL  BX                   ; DX:AX = poids * digit
	XCHG AX, DX               ; DX = resultat high = contribution fraction
	POP  CX
	POP  AX
	ADD  AX, DX               ; ajouter contribution
	PUSH AX
	MOV  AX, DX
	XOR  DX, DX
	MOV  BX, 10
	DIV  BX                   ; poids /= 10
	MOV  DX, AX               ; DX = nouveau poids
	POP  AX
	INC  SI
	DEC  CX
	JMP  @@L49
@@L51:
	PUSH AX                   ; [2] sauvegarder frac
	POP  AX
	POP  DX                   ; [1] restaurer partie entiere
	PUSH AX                   ; [3] frac -> stack
	CMP  BX, 0
	JE   @@L54
	NEG  DX
	JMP  @@L54
@@L52:
	CMP  BX, 0
	JE   @@L54
	NEG  DX
@@L54:
	POP  AX                   ; [3] restaurer frac dans AX
	POP  CX
	POP  BX
	POP  SI
	RET

; ------------------------------------------------------------------------
; _RT_REAL2STR : DX:AX reel 16.16 -> DI descripteur chaine
; ------------------------------------------------------------------------
_RT_REAL2STR:
	PUSH BX
	PUSH CX
	PUSH SI
	PUSH AX                   ; [1] sauvegarder partie frac
	MOV  AX, DX               ; AX = partie entiere
	CALL _RT_INT2STR          ; DI = desc chaine int
	MOV  SI, DI               ; SI = desc entier
	POP  AX                   ; [1] restaurer frac
	PUSH BP
	MOV  BP, SP
	SUB  SP, 8                 ; 6 chiffres + '.' + null
	MOV  BYTE PTR [BP-1], 2Eh ; '.'
	MOV  CX, 6                 ; 6 chiffres decimaux
	MOV  BX, BP
	SUB  BX, 2                 ; BX = ptr vers 1er chiffre decimal
@@L56:
	JCXZ @@L57
	MOV  DX, 10
	MUL  DX                    ; DX:AX = frac * 10
	PUSH DX
	ADD  DL, 30h               ; DX = digit ASCII
	MOV  [BX], DL
	DEC  BX
	POP  DX
	XCHG AX, DX               ; AX = reste fractionnaire
	XOR  DX, DX
	LOOP @@L56
@@L57:
	MOV  CX, [SI+2]           ; CX = longueur partie entiere
	ADD  CX, 7                 ; + 1 point + 6 chiffres
	PUSH SI                    ; [2] desc entier
	PUSH AX                    ; [3] (inutilise)
	CALL _SB_NEWSTR            ; DI = nouveau desc total
	POP  AX
	POP  SI                    ; [2]
	PUSH DI                    ; [4] sauvegarder desc result
	MOV  DI, [DI]             ; DI = ptr buffer dest
	MOV  CX, [SI+2]
	MOV  SI, [SI]
	JCXZ @@L59
	REP  MOVSB
@@L59:
	MOV  BYTE PTR [DI], 2Eh   ; '.'
	INC  DI
	MOV  SI, BX
	INC  SI                    ; SI = BP-7, dernier chiffre ecrit = 1er decimal
	MOV  CX, 6
@@L60:
	JCXZ @@L61
	MOV  AL, [SI]
	MOV  [DI], AL
	INC  SI
	INC  DI
	LOOP @@L60
@@L61:
	MOV  BYTE PTR [DI], 0     ; null garde-fou
	POP  DI                    ; [4] DI = desc resultat
	ADD  SP, 8                 ; liberer pile
	POP  BP
	POP  SI
	POP  CX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_IADD : AX + BX -> AX
; ------------------------------------------------------------------------
_RT_IADD:
	ADD  AX, BX
	RET

; ------------------------------------------------------------------------
; _RT_ISUB : AX - BX -> AX
; ------------------------------------------------------------------------
_RT_ISUB:
	SUB  AX, BX
	RET

; ------------------------------------------------------------------------
; _RT_IMUL : AX * BX -> AX (signe, partie basse)
; ------------------------------------------------------------------------
_RT_IMUL:
	IMUL BX                   ; DX:AX = AX * BX (signe)
	RET                       ; AX = partie basse

; ------------------------------------------------------------------------
; _RT_IDIV : AX / BX -> AX (quotient signe). Erreur sur div/0.
; ------------------------------------------------------------------------
_RT_IDIV:
	CMP  BX, 0
	JNE  @@L62
	MOV  DX, OFFSET _RT_DIVZERO_MSG
	MOV  AH, 9
	INT  21h
	JMP  _SB_END_PROG
@@L62:
	CWD                        ; signe-etendre AX -> DX:AX
	IDIV BX                    ; AX = quotient, DX = reste
	RET

; ------------------------------------------------------------------------
; _RT_RADD : (DX:AX) + (CX:BX) -> DX:AX  (reel 16.16)
; ------------------------------------------------------------------------
_RT_RADD:
	ADD  AX, BX               ; fractions
	ADC  DX, CX               ; parties entieres + retenue
	RET

; ------------------------------------------------------------------------
; _RT_RSUB : (DX:AX) - (CX:BX) -> DX:AX  (reel 16.16)
; ------------------------------------------------------------------------
_RT_RSUB:
	SUB  AX, BX
	SBB  DX, CX
	RET

; ------------------------------------------------------------------------
; _RT_RMUL_FULL : multiplication 16.16 precise
;   (DX:AX) * (CX:BX) -> DX:AX
;   Methode : a*c + [(a*d)>>16 + (c*f)>>16] avec a=DX,f=AX,c=CX,d=BX
; ------------------------------------------------------------------------
_RT_RMUL:
	PUSH SI
	PUSH DI
	PUSH DX                   ; [1] a = int(op1)
	PUSH AX                   ; [2] f = frac(op1)
	PUSH CX                   ; [3] c = int(op2)
	PUSH BX                   ; [4] d = frac(op2)
	MOV  AX, DX               ; AX = a
	IMUL CX                   ; DX:AX = a*c
	MOV  SI, AX               ; SI = partie entiere result (low 16)
	XOR  DI, DI               ; DI = accumulateur frac
	MOV  AX, [SP+6]           ; AX = a
	MUL  WORD PTR [SP]        ; DX:AX = a*d (non signe)
	ADD  DI, AX               ; frac += lo(a*d)
	ADD  SI, DX               ; int++ += hi(a*d)
	MOV  AX, [SP+4]           ; AX = f
	MUL  WORD PTR [SP+2]      ; DX:AX = c*f (non signe)
	ADD  DI, AX               ; frac += lo(c*f)
	ADD  SI, DX               ; int  += hi(c*f)
	MOV  DX, SI               ; DX = partie entiere
	MOV  AX, DI               ; AX = partie fractionnaire
	ADD  SP, 8
	POP  DI
	POP  SI
	RET

; ------------------------------------------------------------------------
; _RT_RDIV : (DX:AX) / (CX:BX) -> DX:AX  (reel 16.16)
; ------------------------------------------------------------------------
_RT_RDIV:
	PUSH BX
	PUSH CX
	PUSH SI
	PUSH DI
	MOV  SI, CX
	OR   SI, BX               ; (CX | BX) == 0 ?
	JNZ  @@L64
	MOV  DX, OFFSET _RT_DIVZERO_MSG
	MOV  AH, 9
	INT  21h
	JMP  _SB_END_PROG
@@L64:
	MOV  AX, DX               ; AX = int(numerateur)
	CWD
	IDIV CX                   ; AX = int(quotient), DX = reste
	MOV  DI, AX               ; DI = quotient entier
	XCHG AX, DX               ; AX = reste
	XOR  DX, DX
	DIV  CX                   ; AX = (reste*65536)/CX approx via high/low trick
	XOR  AX, AX               ; AX = 0 (poids bas pour shift *65536)
	DIV  CX                   ; DX:AX = reste:0 / CX -> AX=frac
	MOV  DX, DI               ; DX = partie entiere
	POP  DI
	POP  SI
	POP  CX
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_ICOMPARE : CMP AX, BX (entiers signes) -> flags
; ------------------------------------------------------------------------
_RT_ICOMPARE:
	CMP  AX, BX
	RET

; ------------------------------------------------------------------------
; _RT_RCOMPARE : comparer DX:AX vs CX:BX (reel 16.16) -> flags
; ------------------------------------------------------------------------
_RT_RCOMPARE:
	CMP  DX, CX               ; comparer parties entieres
	JNE  @@L65          ; si != les flags sont deja bons
	CMP  AX, BX               ; meme partie entiere : comparer fractions
@@L65:
	RET

; ------------------------------------------------------------------------
; === Runtime : tables associatives ===
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; _RT_TABLE_NEW : creer une table associative de CX slots -> BX
; ------------------------------------------------------------------------
_RT_TABLE_NEW:
	PUSH AX
	PUSH CX
	PUSH DI
	PUSH DX
	PUSH CX                    ; [1] sauvegarder nb slots
	MOV  AX, CX
	ADD  AX, AX                ; *2
	ADD  AX, AX                ; *4
	ADD  AX, AX                ; *8 = CX*8
	ADD  AX, 6                 ; + header
	MOV  CX, AX
	CALL _SB_ALLOC             ; BX = ptr debut
	POP  CX                    ; [1] nb slots
	MOV  [BX],   CX            ; [BX+0] = size
	MOV  WORD PTR [BX+2], 0    ; [BX+2] = count = 0
	PUSH BX
	MOV  AX, CX
	MOV  DX, 3
	MUL  DX                    ; AX = CX*3 (DX=0 si CX < 21845)
	MOV  DX, 4
	DIV  DX                    ; AX = CX*3/4
	POP  BX
	MOV  [BX+4], AX            ; [BX+4] = load
	MOV  DI, BX
	ADD  DI, 6                 ; DI = debut slots
	MOV  AX, CX
	ADD  AX, AX
	ADD  AX, AX
	ADD  AX, AX                ; AX = CX*8
	MOV  CX, AX
	XOR  AL, AL
	JCXZ @@L67
	REP  STOSB                  ; remplir a zero
@@L67:
	POP  DX
	POP  DI
	POP  CX
	POP  AX
	RET

; ------------------------------------------------------------------------
; _RT_TABLE_HASH : hacher DI dans table BX -> AX=index (interne)
; ------------------------------------------------------------------------
_RT_TABLE_HASH:
	PUSH BX
	PUSH SI
	PUSH CX
	PUSH DX
	MOV  SI, [DI]              ; ptr donnees cle
	MOV  CX, [DI+2]            ; longueur cle
	XOR  AX, AX                ; accumulateur hash
@@L68:
	JCXZ @@L69
	MOV  DL, [SI]
	XOR  DH, DH
	ADD  AX, DX                ; hash += octet
	INC  SI
	DEC  CX
	JMP  @@L68
@@L69:
	MOV  CX, [BX]              ; CX = size
	JCXZ @@L70
	XOR  DX, DX
	DIV  CX                    ; DX:AX / CX -> AX=quot, DX=reste
	MOV  AX, DX                ; AX = hash index
	JMP  @@L71
@@L70:
	XOR  AX, AX
@@L71:
	POP  DX
	POP  CX
	POP  SI
	POP  BX
	RET

; ------------------------------------------------------------------------
; _RT_TABLE_LOOKUP : chercher cle DI dans table BX -> SI=slot AX=0/1/2
; ------------------------------------------------------------------------
_RT_TABLE_LOOKUP:
	PUSH BP
	MOV  BP, SP
	PUSH DI                    ; [BP-2] = cle_desc original
	PUSH CX                    ; [BP-4] = caller CX (sauvegarde)
	PUSH DX                    ; [BP-6] = hash initial (sera rempli)
	CALL _RT_TABLE_HASH        ; AX = hash initial
	MOV  [BP-6], AX            ; sauvegarder hash initial
@@L72:
	MOV  CX, AX
	ADD  CX, CX                ; *2
	ADD  CX, CX                ; *4
	ADD  CX, CX                ; *8
	MOV  SI, BX
	ADD  SI, 6
	ADD  SI, CX                ; SI = &slot[AX]
	MOV  CX, [SI]
	OR   CX, [SI+2]
	JNZ  @@L73
@@L79:
	XOR  AX, AX                ; AX=0 : vide
	JMP  @@L81
@@L73:
	MOV  CX, [SI+2]            ; cle_len du slot
	MOV  DI, [BP-2]            ; recharger cle_desc original
	CMP  CX, [DI+2]            ; longueurs egales ?
	JNE  @@L77
	PUSH AX                    ; [1] sauvegarder hash courant
	PUSH SI                    ; [2] sauvegarder ptr slot
	MOV  SI, [SI]              ; SI = ptr donnees slot.cle
	MOV  DI, [DI]              ; DI = ptr donnees cle recherche
	JCXZ @@L75
	REPE CMPSB                  ; comparer octet par octet
@@L75:
	POP  SI                    ; [2] restaurer ptr slot
	MOV  DI, [BP-2]            ; restaurer cle_desc original
	POP  AX                    ; [1] restaurer hash courant
	JNE  @@L77          ; bytes differents -> prochain slot
@@L76:
	MOV  AX, 1                 ; AX=1 : trouve
	JMP  @@L81
@@L77:
	INC  AX
	CMP  AX, [BX]              ; >= size ?
	JB   @@L78
	XOR  AX, AX                ; repasser a 0
@@L78:
	CMP  AX, [BP-6]            ; retour au hash initial -> plein
	JNE  @@L72
@@L80:
	MOV  AX, 2                 ; AX=2 : plein
@@L81:
	POP  DX
	POP  CX
	POP  DI
	POP  BP
	RET

; ------------------------------------------------------------------------
; _RT_TABLE_GET : lire val de cle DI dans table BX -> DX=val, AX=1/0
; ------------------------------------------------------------------------
_RT_TABLE_GET:
	PUSH SI
	PUSH CX
	CALL _RT_TABLE_LOOKUP      ; SI=slot, AX=0/1/2
	CMP  AX, 1
	JE   @@L82
@@L83:
	XOR  AX, AX                ; AX=0 : absent
	XOR  DX, DX                ; DX=0
	JMP  @@L82_end
@@L82:
	MOV  DX, SI
	ADD  DX, 4                 ; DX = &slot.val = SI+4
	MOV  AX, 1                 ; AX=1 : trouve
@@L82_end:
	POP  CX
	POP  SI
	RET

; ------------------------------------------------------------------------
; _RT_TABLE_SET : inserer/modifier cle DI -> val SI dans table BX
; ------------------------------------------------------------------------
_RT_TABLE_SET:
	PUSH AX
	PUSH SI
	PUSH CX
	PUSH DX
	PUSH SI                    ; [1] sauvegarder val_desc
	CALL _RT_TABLE_LOOKUP      ; SI=slot, AX=0/1/2
	POP  DX                    ; [1] DX = val_desc
	CMP  AX, 2
	JE   @@L86
	CMP  AX, 1
	JE   @@L84
	MOV  CX, [BX+2]            ; count
	CMP  CX, [BX+4]            ; count >= load ?
	JAE  @@L86
@@L85:
	MOV  CX, [DI]
	MOV  [SI],   CX            ; slot.cle_ptr = DI.ptr
	MOV  CX, [DI+2]
	MOV  [SI+2], CX            ; slot.cle_len = DI.len
	INC  WORD PTR [BX+2]
@@L84:
	MOV  CX, [DX]
	MOV  [SI+4], CX            ; slot.val_ptr = DX.ptr
	MOV  CX, [DX+2]
	MOV  [SI+6], CX            ; slot.val_len = DX.len
	POP  DX
	POP  CX
	POP  SI
	POP  AX
	RET
@@L86:
	MOV  DX, OFFSET _RT_TABLE_OVF_MSG
	MOV  AH, 9
	INT  21h
	JMP  _SB_END_PROG

; ------------------------------------------------------------------------
; _RT_TABLE_DEL : supprimer cle DI de la table BX
; ------------------------------------------------------------------------
_RT_TABLE_DEL:
	PUSH AX
	PUSH SI
	PUSH CX
	CALL _RT_TABLE_LOOKUP      ; SI=slot, AX=0/1/2
	CMP  AX, 1
	JNE  @@L88            ; pas trouve -> rien a faire
@@L87:
	MOV  WORD PTR [SI],   0    ; cle_ptr = 0 (vider slot)
	MOV  WORD PTR [SI+2], 0    ; cle_len = 0
	MOV  WORD PTR [SI+4], 0    ; val_ptr = 0
	MOV  WORD PTR [SI+6], 0    ; val_len = 0
	DEC  WORD PTR [BX+2]       ; count--
@@L88:
	POP  CX
	POP  SI
	POP  AX
	RET

; ------------------------------------------------------------------------
; === Runtime : tableaux 1D ===
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; _RT_ARRAY_NEW : creer tableau 1D [CX..DX] -> BX
; ------------------------------------------------------------------------
_RT_ARRAY_NEW:
	PUSH AX
	PUSH CX
	PUSH DX
	PUSH DI
	PUSH SI
	MOV  AX, DX               ; AX = ub
	SUB  AX, CX               ; AX = ub - lb
	INC  AX                    ; AX = size
	PUSH AX                    ; [1] sauvegarder size
	PUSH CX                    ; [2] sauvegarder lb
	PUSH DX                    ; [3] sauvegarder ub
	MOV  SI, AX               ; SI = size
	ADD  AX, AX                ; *2
	ADD  AX, AX                ; *4 = size*4
	ADD  AX, 6                 ; + header
	MOV  CX, AX
	CALL _SB_ALLOC             ; BX = ptr debut
	POP  DX                    ; [3] ub
	POP  CX                    ; [2] lb
	POP  AX                    ; [1] size
	MOV  [BX],   CX            ; [BX+0] = lb
	MOV  [BX+2], DX            ; [BX+2] = ub
	MOV  [BX+4], AX            ; [BX+4] = size
	MOV  DI, BX
	ADD  DI, 6                 ; DI = debut des descripteurs
	MOV  CX, AX
	ADD  CX, CX
	ADD  CX, CX                ; CX = size*4
	XOR  AL, AL
	JCXZ @@L89
	REP  STOSB                  ; remplir a zero
@@L89:
	POP  SI
	POP  DI
	POP  DX
	POP  CX
	POP  AX
	RET

; ------------------------------------------------------------------------
; _RT_ARRAY_IDX : valider AX et calculer ptr desc -> DI (interne)
; ------------------------------------------------------------------------
_RT_ARRAY_IDX:
	PUSH AX
	PUSH CX
	CMP  AX, [BX]              ; AX < lb ?
	JB   @@L91
	CMP  AX, [BX+2]            ; AX > ub ?
	JA   @@L91
	SUB  AX, [BX]             ; AX = AX - lb (offset 0-based)
	ADD  AX, AX                ; *2
	ADD  AX, AX                ; *4
	MOV  DI, BX
	ADD  DI, 6                 ; sauter le header
	ADD  DI, AX                ; DI = ptr descripteur
	CLC                        ; CF=0 : valide
	POP  CX
	POP  AX
	RET
@@L91:
	STC                        ; CF=1 : hors-bornes
	POP  CX
	POP  AX
	RET

; ------------------------------------------------------------------------
; _RT_ARRAY_GET : lire element[AX] de tableau BX -> DI, AX=1/0
; ------------------------------------------------------------------------
_RT_ARRAY_GET:
	CALL _RT_ARRAY_IDX         ; DI=ptr desc, CF=hors-bornes
	JC   @@L93
	MOV  AX, 1                 ; AX=1 : valide
	RET
@@L93:
	XOR  AX, AX                ; AX=0 : hors-bornes
	XOR  DI, DI
	RET

; ------------------------------------------------------------------------
; _RT_ARRAY_SET : ecrire SI dans element[AX] du tableau BX -> AX=1/0
; ------------------------------------------------------------------------
_RT_ARRAY_SET:
	PUSH DI
	PUSH CX
	CALL _RT_ARRAY_IDX         ; DI=ptr desc, CF=hors-bornes
	JC   @@L95
	MOV  CX, [SI]
	MOV  [DI],   CX            ; ptr
	MOV  CX, [SI+2]
	MOV  [DI+2], CX            ; len
	MOV  AX, 1                 ; AX=1 : ok
	POP  CX
	POP  DI
	RET
@@L95:
	XOR  AX, AX                ; AX=0 : hors-bornes
	POP  CX
	POP  DI
	RET

; ------------------------------------------------------------------------
; _RT_ARRAY_OOB_ERR : acces hors-bornes tableau -> arret
; ------------------------------------------------------------------------
_RT_ARRAY_OOB_ERR:
	MOV  DX, OFFSET _RT_ARRAY_OOB_MSG
	MOV  AH, 9
	INT  21h
	JMP  _SB_END_PROG

; Stubs de retour de fonctions utilisateur
_SB_RETURN:
	MOV  AX, 1              ; succes : DI = desc resultat
	POP  BP
	RET

_SB_FRETURN:
	XOR  AX, AX            ; echec : AX=0
	LEA  DI, [_SB_EMPTY_DESC]
	POP  BP
	RET

_SB_NRETURN:
	MOV  AX, 1              ; retour sans valeur
	LEA  DI, [_SB_EMPTY_DESC]
	POP  BP
	RET

; ------------------------------------------------------------------------
; === Runtime : entree / sortie (stdin / stdout) ===
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; _RT_READLINE : lire une ligne stdin -> descripteur _SB_SYS_INPUT_D
; ------------------------------------------------------------------------
_RT_READLINE:
	PUSH BX
	PUSH CX
	PUSH DX
; INT 21h AH=0Ah : saisie tamponnee sur stdin
	MOV  AH, 0Ah
	LEA  DX, [_SB_INPUTBUF]
	INT  21h
; Longueur reelle = _SB_INPUTBUF+1
	XOR  CX, CX
	MOV  CL, [_SB_INPUTBUF+1]
; Longueur nulle => ligne vide; 1Ah en premier => EOF DOS
	CMP  CX, 0
	JE   _RT_READLINE_EOF
	LEA  BX, [_SB_INPUTBUF+2]
	MOV  AL, [BX]
	CMP  AL, 1Ah              ; Ctrl+Z = EOF DOS
	JE   _RT_READLINE_EOF
; Construire descripteur : ptr = &_SB_INPUTBUF+2, len = CX
	LEA  DI, [_SB_SYS_INPUT_D]
	MOV  [DI],   BX           ; ptr -> donnees
	MOV  [DI+2], CX           ; len = chars lus
	POP  DX
	POP  CX
	POP  BX
	MOV  AX, 1                ; AX=1 => succes
	RET
_RT_READLINE_EOF:
	POP  DX
	POP  CX
	POP  BX
	XOR  AX, AX               ; AX=0 => EOF/echec
	RET

; ------------------------------------------------------------------------
; _RT_WRITELINE : ecrire chaine [SI] sur stdout + CRLF
; ------------------------------------------------------------------------
_RT_WRITELINE:
	PUSH BX
	PUSH CX
	PUSH DX
; Extraire len et ptr du descripteur SI
	MOV  DX, [SI]             ; ptr donnees
	MOV  CX, [SI+2]           ; len
	CMP  CX, 0
	JE   _RT_WRITELINE_CRLF   ; chaine vide : sauter au CRLF
; INT 21h AH=40h : ecrire CX octets sur stdout (handle 1)
	MOV  AH, 40h
	MOV  BX, 1                ; handle stdout
	INT  21h
_RT_WRITELINE_CRLF:
; Ecrire CRLF
	MOV  AH, 40h
	MOV  BX, 1
	MOV  CX, 2
	LEA  DX, [_SB_CRLF_BUF]
	INT  21h
	POP  DX
	POP  CX
	POP  BX
	MOV  AX, 1
	RET


; ========================================================================
; Fin du fichier genere par SNOBOL86
; ========================================================================
END START
