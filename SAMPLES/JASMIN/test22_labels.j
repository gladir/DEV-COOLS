; test22_labels.j - Test des labels, resolution des sauts et calcul des offsets (TODO 19)
; Teste la definition de labels, la resolution des references avant et arriere,
; les branchements 16 bits et 32 bits, les labels dans tableswitch/lookupswitch,
; et la detection des labels dupliques.

.class public test22_labels
.super java/lang/Object

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test forward reference : goto vers un label defini plus loin ---
.method public static testForwardRef()I
  .limit stack 2
  .limit locals 1
  goto SkipInit
  bipush 99
  ireturn
SkipInit:
  bipush 42
  ireturn
.end method

; --- Test backward reference : boucle avec goto vers un label defini avant ---
.method public static testBackwardRef()I
  .limit stack 2
  .limit locals 2
  iconst_0
  istore_0
  iconst_0
  istore_1
LoopStart:
  iload_0
  bipush 5
  if_icmpge LoopEnd
  iload_1
  iload_0
  iadd
  istore_1
  iinc 0 1
  goto LoopStart
LoopEnd:
  iload_1
  ireturn
.end method

; --- Test labels multiples au meme PC ---
.method public static testMultiLabel()I
  .limit stack 1
  .limit locals 1
  bipush 10
  ifeq LabelA
  bipush 1
  goto LabelC
LabelA:
LabelB:
  bipush 0
LabelC:
  ireturn
.end method

; --- Test branchements conditionnels if_icmpXX ---
.method public static testIfBranches(II)I
  .limit stack 2
  .limit locals 3
  iload_0
  iload_1
  if_icmpeq AreEqual
  iload_0
  iload_1
  if_icmplt IsLess
  bipush 1
  ireturn
IsLess:
  bipush -1
  ireturn
AreEqual:
  iconst_0
  ireturn
.end method

; --- Test goto_w (branchement 32 bits) ---
.method public static testGotoW()I
  .limit stack 1
  .limit locals 1
  goto_w FarLabel
  bipush 99
  ireturn
FarLabel:
  bipush 77
  ireturn
.end method

; --- Test ifnull et ifnonnull ---
.method public static testNullBranch(Ljava/lang/Object;)I
  .limit stack 1
  .limit locals 2
  aload_0
  ifnull IsNullLabel
  bipush 1
  ireturn
IsNullLabel:
  iconst_0
  ireturn
.end method

; --- Test tableswitch avec resolution de labels ---
.method public static testTableSwitch(I)I
  .limit stack 1
  .limit locals 2
  iload_0
  tableswitch 0 2
    TSCase0
    TSCase1
    TSCase2
    default : TSDefault

TSCase0:
  bipush 10
  ireturn
TSCase1:
  bipush 20
  ireturn
TSCase2:
  bipush 30
  ireturn
TSDefault:
  iconst_m1
  ireturn
.end method

; --- Test lookupswitch avec resolution de labels ---
.method public static testLookupSwitch(I)I
  .limit stack 1
  .limit locals 2
  iload_0
  lookupswitch
    100 : LSCase100
    200 : LSCase200
    300 : LSCase300
    default : LSDefault

LSCase100:
  bipush 1
  ireturn
LSCase200:
  bipush 2
  ireturn
LSCase300:
  bipush 3
  ireturn
LSDefault:
  iconst_0
  ireturn
.end method

; --- Test boucle while avec labels ---
.method public static testWhileLoop()I
  .limit stack 2
  .limit locals 2
  iconst_1
  istore_0
  iconst_0
  istore_1
WhileTest:
  iload_1
  bipush 10
  if_icmpge WhileDone
  iload_0
  iconst_2
  imul
  istore_0
  iinc 1 1
  goto WhileTest
WhileDone:
  iload_0
  ireturn
.end method

; --- Test branchement ifeq/ifne ---
.method public static testIfEqNe(I)I
  .limit stack 1
  .limit locals 2
  iload_0
  ifeq ReturnZero
  bipush 1
  goto Done
ReturnZero:
  iconst_0
Done:
  ireturn
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 4
  .limit locals 1
  ; Test forward ref
  invokestatic test22_labels/testForwardRef()I
  pop
  ; Test backward ref (boucle)
  invokestatic test22_labels/testBackwardRef()I
  pop
  ; Test labels multiples
  invokestatic test22_labels/testMultiLabel()I
  pop
  ; Test branchements conditionnels
  iconst_3
  iconst_5
  invokestatic test22_labels/testIfBranches(II)I
  pop
  ; Test goto_w
  invokestatic test22_labels/testGotoW()I
  pop
  ; Test null branch
  aconst_null
  invokestatic test22_labels/testNullBranch(Ljava/lang/Object;)I
  pop
  ; Test tableswitch
  iconst_1
  invokestatic test22_labels/testTableSwitch(I)I
  pop
  ; Test lookupswitch
  sipush 200
  invokestatic test22_labels/testLookupSwitch(I)I
  pop
  ; Test boucle while
  invokestatic test22_labels/testWhileLoop()I
  pop
  ; Test ifeq/ifne
  iconst_0
  invokestatic test22_labels/testIfEqNe(I)I
  pop
  return
.end method
