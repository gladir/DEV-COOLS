; test16_controlflow.j - Test des opcodes de controle de flux (TODO 13)
; Teste les branchements conditionnels et inconditionnels, les comparaisons,
; tableswitch et lookupswitch.

.class public test16_controlflow
.super java/lang/Object

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test des branchements conditionnels sur int ---
.method public static testBranch(II)V
  .limit stack 2
  .limit locals 2

  ; ifeq / ifne / iflt / ifge / ifgt / ifle
  iload_0
  ifeq LabelZero
  goto LabelNotZero
LabelZero:
LabelNotZero:

  iload_0
  iflt LabelNeg
  goto LabelPosOrZero
LabelNeg:
LabelPosOrZero:

  ; if_icmpeq / if_icmpne / if_icmplt / if_icmpge / if_icmpgt / if_icmple
  iload_0
  iload_1
  if_icmpeq LabelEq
  goto LabelNeq
LabelEq:
LabelNeq:

  iload_0
  iload_1
  if_icmplt LabelLt
  goto LabelGe
LabelLt:
LabelGe:

  ; Branchement inconditionnel
  goto LabelEnd

LabelEnd:
  return
.end method

; --- Test des comparaisons de references ---
.method public static testRefBranch()V
  .limit stack 2
  .limit locals 2

  aconst_null
  astore_0
  aconst_null
  astore_1

  aload_0
  aload_1
  if_acmpeq RefEq
  goto RefNeq
RefEq:
RefNeq:

  aload_0
  ifnull IsNull
  goto IsNotNull
IsNull:
IsNotNull:
  return
.end method

; --- Test des comparaisons numeriques ---
.method public static testCompare()V
  .limit stack 4
  .limit locals 8

  ; lcmp
  lconst_1
  lstore_0
  ldc2_w 2
  lstore_2
  lload_0
  lload_2
  lcmp
  pop

  ; fcmpl / fcmpg
  fconst_1
  fstore 4
  fconst_2
  fstore 5
  fload 4
  fload 5
  fcmpl
  pop
  fload 4
  fload 5
  fcmpg
  pop

  ; dcmpl / dcmpg
  dconst_1
  dstore 6
  dload 6
  dload 6
  dcmpl
  pop
  dload 6
  dload 6
  dcmpg
  pop

  return
.end method

; --- Test goto_w ---
.method public static testWideJumps()V
  .limit stack 2
  .limit locals 2

  goto_w WideDest

WideDest:
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

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1
  iconst_5
  iconst_3
  invokestatic test16_controlflow/testBranch(II)V
  invokestatic test16_controlflow/testRefBranch()V
  invokestatic test16_controlflow/testCompare()V
  invokestatic test16_controlflow/testWideJumps()V
  iconst_2
  invokestatic test16_controlflow/testTableSwitch(I)V
  bipush 20
  invokestatic test16_controlflow/testLookupSwitch(I)V
  return
.end method
