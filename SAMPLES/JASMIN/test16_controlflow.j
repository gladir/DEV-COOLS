; test16_controlflow.j - Test des opcodes de controle de flux (TODO 13)
; Teste les branchements conditionnels et inconditionnels, les comparaisons,
; tableswitch et lookupswitch.

.class public test16_controlflow
.super java/lang/Object

; --- Test des branchements conditionnels sur int ---
.method public static testBranch()V
  .limit stack 2
  .limit locals 2

  ; ifeq / ifne / iflt / ifge / ifgt / ifle
  iload_0
  ifeq LabelZero
  ifne LabelNotZero
  iflt LabelNeg
  ifge LabelPosOrZero
  ifgt LabelPos
  ifle LabelNegOrZero

LabelZero:
LabelNotZero:
LabelNeg:
LabelPosOrZero:
LabelPos:
LabelNegOrZero:

  ; if_icmpeq / if_icmpne / if_icmplt / if_icmpge / if_icmpgt / if_icmple
  iload_0
  iload_1
  if_icmpeq LabelEq
  if_icmpne LabelNeq
  if_icmplt LabelLt
  if_icmpge LabelGe
  if_icmpgt LabelGt
  if_icmple LabelLe

LabelEq:
LabelNeq:
LabelLt:
LabelGe:
LabelGt:
LabelLe:

  ; Branchement inconditionnel
  goto LabelEnd

LabelEnd:
  return
.end method

; --- Test des comparaisons de references ---
.method public static testRefBranch()V
  .limit stack 2
  .limit locals 2

  aload_0
  aload_1
  if_acmpeq RefEq
  if_acmpne RefNeq
RefEq:
RefNeq:

  aload_0
  ifnull IsNull
  ifnonnull IsNotNull
IsNull:
IsNotNull:
  return
.end method

; --- Test des comparaisons numeriques ---
.method public static testCompare()V
  .limit stack 4
  .limit locals 4

  ; lcmp
  lload_0
  lload_2
  lcmp

  ; fcmpl / fcmpg
  fload_0
  fload_1
  fcmpl
  fload_0
  fload_1
  fcmpg

  ; dcmpl / dcmpg
  dload_0
  dload_2
  dcmpl
  dload_0
  dload_2
  dcmpg

  return
.end method

; --- Test goto_w / jsr / jsr_w / ret ---
.method public static testWideJumps()V
  .limit stack 2
  .limit locals 2

  goto_w WideDest

WideDest:
  jsr SubRoutine
  goto SkipSub
SubRoutine:
  astore_1
  ret 1
SkipSub:
  return
.end method

; --- Test tableswitch ---
.method public static testTableSwitch(I)V
  .limit stack 1
  .limit locals 2

  iload_0
  tableswitch 1 3
    Case1
    Case2
    Case3
    default : DefaultCase

Case1:
Case2:
Case3:
DefaultCase:
  return
.end method

; --- Test lookupswitch ---
.method public static testLookupSwitch(I)V
  .limit stack 1
  .limit locals 2

  iload_0
  lookupswitch
    10 : Label10
    20 : Label20
    30 : Label30
    default : LabelDefault

Label10:
Label20:
Label30:
LabelDefault:
  return
.end method
