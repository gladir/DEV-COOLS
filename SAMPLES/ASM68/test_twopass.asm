; test_twopass.asm - Test TODO 18 : architecture deux passes de l'assembleur
; Verifie que les references en avant (forward references) sont resolues
; correctement par l'assemblage en deux passes.

        SECTION CODE

; --- Test 1 : reference en avant avec BRA ---
start:
        BRA     target1         ; reference en avant -> resolue en passe 2
        NOP
        NOP
target1:
        NOP

; --- Test 2 : reference en avant avec BEQ ---
        MOVE.W  #0,D0
        BEQ     target2         ; branchement conditionnel en avant
        NOP
target2:
        NOP

; --- Test 3 : branchement court explicite (.S) en arriere ---
loop1:
        NOP
        DBRA    D0,loop1        ; reference en arriere (toujours OK)

; --- Test 4 : reference en avant dans BSR ---
        BSR     subroutine      ; appel a sous-routine definie plus loin
        NOP
        BRA     after_sub

subroutine:
        MOVE.L  #1,D0
        RTS

after_sub:

; --- Test 5 : EQU avec valeur connue ---
BUFSIZE EQU     256
        MOVE.W  #BUFSIZE,D0     ; utilise EQU defini ci-dessus

; --- Test 6 : EQU avec reference en avant ---
; Note : en passe 1, FWDVAL vaut 0 ; en passe 2, il vaut la bonne valeur
        MOVE.W  #FWDVAL,D1
FWDVAL  EQU     42

; --- Test 7 : DC.W avec etiquette en avant ---
        LEA     data_table,A0   ; reference en avant vers donnees
        BRA     skip_data
data_table:
        DC.W    $1234,$5678,$9ABC
skip_data:
        MOVE.W  (A0),D2

; --- Test 8 : plusieurs branchements en avant ---
        CMP.W   #1,D0
        BEQ     case1
        CMP.W   #2,D0
        BEQ     case2
        BRA     default_case

case1:
        MOVE.W  #10,D3
        BRA     end_switch
case2:
        MOVE.W  #20,D3
        BRA     end_switch
default_case:
        MOVE.W  #0,D3
end_switch:
        NOP

; --- Test 9 : branchement .S explicite en arriere ---
loop2:
        NOP
        NOP
        BRA.S   loop2           ; branchement court explicite

; --- Test 10 : SET redefinissable ---
COUNTER SET     0
        MOVE.W  #COUNTER,D4
COUNTER SET     1
        MOVE.W  #COUNTER,D5

; --- Test 11 : DS reserve de l'espace ---
        DS.W    4               ; 8 octets reserves

; --- Test 12 : etiquettes locales avec references en avant ---
global1:
.local1:
        NOP
        BRA     .local2         ; reference en avant vers etiquette locale
.local2:
        NOP

; --- Test 13 : ORG avec references en avant ---
        BRA     org_target

        ORG     $1000
org_target:
        NOP

        END     start
