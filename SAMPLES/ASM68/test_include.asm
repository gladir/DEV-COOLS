; test_include.asm - Test de la pile d'inclusion INCLUDE (TODO 21)
; Ce fichier teste la gestion des fichiers INCLUDE et pile de sources :
;   - Inclusion simple (INCLUDE "fichier")
;   - Constantes definies dans le fichier inclus
;   - Sous-routines definies dans le fichier inclus
;   - Inclusion de multiples fichiers
;   - Donnees incluses depuis un fichier externe
;   - Utilisation de symboles definis apres inclusion
;   - Pile de contexte source (PushInclude/PopInclude)
;   - Format d'erreur avec nom de fichier pour les inclusions
;   - Recherche dans le repertoire du fichier source courant

    ORG   $1000

; --- 1. Inclure les definitions (constantes et sous-routine) ---
    INCLUDE "inc_test_defs.asm"

; --- 2. Utiliser les constantes definies dans le fichier inclus ---
START:
    MOVE.W  #MAGIC_NUM,D1        ; Doit valoir $DEAD
    MOVE.W  #VERSION,D2          ; Doit valoir $0100
    MOVE.W  #BUF_SIZE,D3         ; Doit valoir 256

; --- 3. Appeler la sous-routine incluse ---
    BSR     inc_routine

; --- 4. Inclure un deuxieme fichier (donnees) ---
    INCLUDE "inc_test_data.asm"

; --- 5. Instructions apres les inclusions ---
AFTER_INC:
    MOVE.L  #data_table,A0       ; Adresse de la table incluse
    MOVE.W  (A0),D4              ; Lire premier mot
    LEA     AFTER_INC(PC),A1

; --- 6. Donnees locales (apres toutes les inclusions) ---
LOCAL_MSG:
    DC.B    'Principal OK',0
    EVEN

; --- 7. Fin avec adresse de demarrage ---
    END     START
