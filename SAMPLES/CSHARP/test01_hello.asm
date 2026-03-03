; =========================================================
; Fichier genere par CSC86 v1.0
; Source : samples\CSHARP\test01_hello.cs
; =========================================================

        .8086
        DOSSEG
        .MODEL  SMALL

; ----- Macros -----
EXIT_DOS        MACRO
                MOV     AH, 4Ch
                INT     21h
                ENDM

INIT_DS         MACRO
                MOV     AX, @DATA
                MOV     DS, AX
                ENDM

; ----- Segment STACK -----
        .STACK  512

; -----------------------------------------------------------------------
; Segment de donnees
; -----------------------------------------------------------------------
        .DATA

; ----- Litteraux de chaines -----
_SL_1                   DB      'Hello, World!',0
_SLD_1                  DW      OFFSET _SL_1, 13

; ----- Variables systeme CSC86 -----
_CS86_CRLF              DB      0Dh, 0Ah
_CS86_CRLFLEN           DW      2

_CS86_INBUF             DB      128 DUP(0)
_CS86_INLEN             DW      0

_CS86_ITOA              DB      8 DUP(0)

_CS86_TRUES             DB      'True', 0
_CS86_TRUED             DW      OFFSET _CS86_TRUES, 4

_CS86_FALSES            DB      'False', 0
_CS86_FALSED            DW      OFFSET _CS86_FALSES, 5

_CS86_NULLS             DB      0
_CS86_NULLD             DW      OFFSET _CS86_NULLS, 0


; -----------------------------------------------------------------------
; Segment de code
; -----------------------------------------------------------------------
        .CODE

; Classe : Program

; -----------------------------------------------------------------------
; Methode : Main
; -----------------------------------------------------------------------
_CF_Main:
        INIT_DS                         ; initialiser le segment de donnees
        PUSH BP
        MOV     BP, SP                  ; sauver frame pointer
        MOV     AX, WORD PTR [_SLD_1]
        MOV     DX, WORD PTR [_SLD_1+2]
        MOV     CX, DX                  ; len dans CX
        CALL    _RT_WRITESTR
        CALL    _RT_WRITECRLF
_CF_Main_ret:
        MOV     SP, BP                  ; restaurer SP
        POP  BP
        RET

        EXIT_DOS                        ; fin du programme DOS

; === RUNTIME : ARITHMETIQUE ET CONVERSIONS ===

; -----------------------------------------------------------------------
; _RT_IMUL : AX * BX -> AX (signed 16x16, low 16 bits)
_RT_IMUL:
        IMUL BX
        RET
; -----------------------------------------------------------------------
; _RT_IDIV : AX / BX -> AX=quotient DX=reste (signed)
_RT_IDIV:
        CWD
        IDIV BX
        RET
; -----------------------------------------------------------------------
; _RT_IMOD : AX mod BX -> AX (signed)
_RT_IMOD:
        CWD
        IDIV BX
        MOV     AX, DX                  ; AX = reste
        RET
; -----------------------------------------------------------------------
; _RT_ABS : |AX| -> AX
_RT_ABS:
        TEST    AX, AX
        JNS     _RT_ABS_E
        NEG  AX
_RT_ABS_E:
        RET
; -----------------------------------------------------------------------
; _RT_BOUNDS_ERR : fin programme avec code erreur 2
_RT_BOUNDS_ERR:
        MOV     AH, 4Ch
        MOV     AL, 02h
        INT  21h
; -----------------------------------------------------------------------
; _RT_INT2STR : [BP+4]=int16 -> AX=ptr DX=len (decimal)
_RT_INT2STR:
        PUSH BP
        MOV     BP, SP                  ; frame
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        MOV     AX, [BP+4]              ; charger l'entier
        XOR     SI, SI                  ; SI=0 : positif
        TEST    AX, AX
        JGE     _RT_I2S_P
        MOV     SI, 1                   ; SI=1 : negatif
        NEG  AX
_RT_I2S_P:
        LEA     DI, [_CS86_ITOA+7]      ; pointer en fin de buffer
        XOR     CX, CX                  ; CX = nombre de chiffres
_RT_I2S_L:
        XOR     DX, DX                  ; etendre AX en DX:AX (unsigned)
        MOV     BX, 10                  ; diviseur
        DIV  BX
        ADD     DL, 30h                 ; DL = chiffre ASCII
        DEC  DI
        MOV     BYTE PTR [DI], DL
        INC  CX
        TEST    AX, AX
        JNZ     _RT_I2S_L
        TEST    SI, SI
        JZ      _RT_I2S_E
        DEC  DI
        MOV     BYTE PTR [DI], 2Dh      ; tiret ASCII '-'
        INC  CX
_RT_I2S_E:
        MOV     AX, DI                  ; AX = ptr vers premier char
        MOV     DX, CX                  ; DX = longueur
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        POP  BP
        RET
; -----------------------------------------------------------------------
; _RT_STR2INT : [BP+4]=ptr [BP+6]=len -> AX=int16
_RT_STR2INT:
        PUSH BP
        MOV     BP, SP                  ; frame
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        MOV     SI, [BP+4]              ; ptr vers la chaine
        MOV     CX, [BP+6]              ; longueur
        XOR     AX, AX                  ; accumulateur = 0
        XOR     DI, DI                  ; DI=0 : positif
        TEST    CX, CX
        JZ      _RT_S2I_D
        MOV     BL, [SI]                ; premier caractere
        CMP     BL, 2Dh
        JNE     _RT_S2I_L
        MOV     DI, 1                   ; marquer negatif
        INC  SI
        DEC  CX
_RT_S2I_L:
        TEST    CX, CX
        JZ      _RT_S2I_SGN
        MOV     BL, [SI]                ; lire chiffre
        SUB     BL, 30h                 ; convertir ASCII -> valeur
        XOR     BH, BH                  ; etendre BL en BX
        PUSH    CX
        MOV     CX, 10                  ; multiplicateur
        IMUL CX
        POP     CX
        ADD     AX, BX
        INC  SI
        DEC  CX
        JMP     _RT_S2I_L
_RT_S2I_SGN:
        TEST    DI, DI
        JZ      _RT_S2I_D
        NEG  AX
_RT_S2I_D:
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        POP  BP
        RET
; -----------------------------------------------------------------------
; _RT_BOOL2STR : [BP+4]=bool -> AX=ptr DX=len
_RT_BOOL2STR:
        PUSH BP
        MOV     BP, SP                  ; frame
        MOV     AX, [BP+4]              ; charger le booleen
        TEST    AX, AX
        JZ      _RT_B2S_F
        MOV     AX, OFFSET _CS86_TRUES  ; ptr 'True'
        MOV     DX, 4                   ; len=4
        JMP     _RT_B2S_E
_RT_B2S_F:
        MOV     AX, OFFSET _CS86_FALSES ; ptr 'False'
        MOV     DX, 5                   ; len=5
_RT_B2S_E:
        POP  BP
        RET

; === FIN RUNTIME ARITHMETIQUE ===


; === RUNTIME : ENTREES/SORTIES ET GESTION PROGRAMME ===

; -----------------------------------------------------------------------
; _RT_WRITESTR : DX=ptr CX=len -> stdout (INT 21h AH=40h)
_RT_WRITESTR:
        PUSH    BX
        MOV     AH, 40h                 ; fonction write handle
        MOV     BX, 1                   ; handle stdout
        INT  21h
        POP     BX
        RET
; -----------------------------------------------------------------------
; _RT_WRITECRLF : ecrire CR+LF sur stdout
_RT_WRITECRLF:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     AH, 40h                 ; fonction write handle
        MOV     BX, 1                   ; handle stdout
        MOV     CX, 2                   ; nb octets
        MOV     DX, OFFSET _CS86_CRLF   ; buffer CR LF
        INT  21h
        POP     DX
        POP     CX
        POP     BX
        RET
; -----------------------------------------------------------------------
; _RT_WRITECHR : AL=char -> stdout (INT 21h AH=02h)
_RT_WRITECHR:
        PUSH    DX
        MOV     DL, AL                  ; caractere a ecrire
        MOV     AH, 02h                 ; fonction write char
        INT  21h
        POP     DX
        RET
; -----------------------------------------------------------------------
; _RT_READLINE : saisie une ligne -> AX=ptr DX=len
_RT_READLINE:
        PUSH    BX
        PUSH    CX
        PUSH    SI
        MOV     BYTE PTR [_CS86_INBUF], 125; capacite buffer
        MOV     BYTE PTR [_CS86_INBUF+1], 0; effacer compteur
        MOV     AH, 0Ah                 ; fonction saisie tamponnee
        MOV     DX, OFFSET _CS86_INBUF  ; adresse buffer
        INT  21h
        XOR     BX, BX                  ; BX=0
        MOV     BL, [_CS86_INBUF+1]     ; BL = nb chars
        MOV     DX, BX                  ; DX = longueur
        MOV     AX, OFFSET _CS86_INBUF+2; AX = ptr vers texte
        POP     SI
        POP     CX
        POP     BX
        RET
; -----------------------------------------------------------------------
; _RT_ERREXIT : termine le programme avec code erreur 1
_RT_ERREXIT:
        MOV     AH, 4Ch                 ; fonction exit DOS
        MOV     AL, 01h                 ; code erreur 1
        INT  21h
; -----------------------------------------------------------------------
; _RT_EXIT0 : termine le programme normalement (code 0)
_RT_EXIT0:
        MOV     AH, 4Ch                 ; fonction exit DOS
        XOR     AL, AL                  ; code retour 0
        INT  21h
; -----------------------------------------------------------------------
; _RT_STRCAT : concat [BP+8]/[BP+10] + [BP+4]/[BP+6] -> AX=ptr DX=len
_RT_STRCAT:
        PUSH BP
        MOV     BP, SP                  ; frame
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        MOV     DI, OFFSET _CS86_INBUF+2; buffer de sortie
        XOR     BX, BX                  ; BX = longueur accumulee
        MOV     SI, [BP+8]              ; ptr str1
        MOV     CX, [BP+10]             ; len str1
        TEST    CX, CX
        JZ      _RT_SC_S2
_RT_SC_L1:
        MOVSB
        INC  BX
        CMP     BX, 124                 ; limite buffer
        JAE     _RT_SC_S2
        LOOP _RT_SC_L1
_RT_SC_S2:
        MOV     SI, [BP+4]              ; ptr str2
        MOV     CX, [BP+6]              ; len str2
        TEST    CX, CX
        JZ      _RT_SC_E
_RT_SC_L2:
        MOVSB
        INC  BX
        CMP     BX, 124                 ; limite buffer
        JAE     _RT_SC_E
        LOOP _RT_SC_L2
_RT_SC_E:
        MOV     AX, OFFSET _CS86_INBUF+2; ptr resultat
        MOV     DX, BX                  ; longueur totale
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        POP  BP
        RET
; -----------------------------------------------------------------------
; _RT_STRCMP : SI/CX=str1 DI/BX=str2 -> ZF/CF
_RT_STRCMP:
        PUSH    AX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        PUSH    BX
        CMP     CX, BX
        JLE     _RT_SC2_ML
        MOV     CX, BX                  ; CX = min(len1,len2)
_RT_SC2_ML:
        TEST    CX, CX
        JZ      _RT_SC2_LEN
_RT_SC2_L:
        MOV     AL, [SI]                ; char str1
        CMP     AL, [DI]                ; comparer avec str2
        JNE     _RT_SC2_E
        INC  SI
        INC  DI
        LOOP _RT_SC2_L
_RT_SC2_LEN:
        POP     BX
        CMP     CX, BX
        PUSH    BX
        POP     BX
        POP     BX
        POP     DI
        POP     SI
        POP     CX
        POP     AX
        RET
_RT_SC2_E:
        POP     BX
        POP     DI
        POP     SI
        POP     CX
        POP     AX
        RET

; === FIN RUNTIME I/O ===


; -----------------------------------------------------------------------
; Fin du module
; -----------------------------------------------------------------------
        END     _CF_Main
