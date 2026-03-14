; test13_loadstore.j - Test des opcodes de chargement et stockage (TODO 10)
; Verifie iload/istore, lload/lstore, fload/fstore, dload/dstore,
; aload/astore (avec variantes _0 a _3 et operande),
; ainsi que les opcodes de chargement/stockage tableau.

.class public test13_loadstore
.super java/lang/Object

; Constructeur standard
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test des variantes iload_N / istore_N ---
.method public static testIntLoadStore()V
  .limit stack 2
  .limit locals 5
  iconst_1
  istore_0
  iconst_2
  istore_1
  iconst_3
  istore_2
  iconst_4
  istore_3
  iload_0
  pop
  iload_1
  pop
  iload_2
  pop
  iload_3
  pop
  ; iload/istore avec operande explicite
  iconst_5
  istore 4
  iload 4
  pop
  return
.end method

; --- Test des variantes lload_N / lstore_N ---
.method public static testLongLoadStore()V
  .limit stack 4
  .limit locals 6
  lconst_1
  lstore_0
  lconst_0
  lstore_2
  lload_0
  pop2
  lload_2
  pop2
  ; lload/lstore avec operande
  lconst_1
  lstore 4
  lload 4
  pop2
  return
.end method

; --- Test des variantes fload_N / fstore_N ---
.method public static testFloatLoadStore()V
  .limit stack 2
  .limit locals 5
  fconst_1
  fstore_0
  fconst_2
  fstore_1
  fconst_0
  fstore_2
  fconst_1
  fstore_3
  fload_0
  pop
  fload_1
  pop
  fload_2
  pop
  fload_3
  pop
  ; fload/fstore avec operande
  fconst_0
  fstore 4
  fload 4
  pop
  return
.end method

; --- Test des variantes dload_N / dstore_N ---
.method public static testDoubleLoadStore()V
  .limit stack 4
  .limit locals 6
  dconst_1
  dstore_0
  dconst_0
  dstore_2
  dload_0
  pop2
  dload_2
  pop2
  ; dload/dstore avec operande
  dconst_1
  dstore 4
  dload 4
  pop2
  return
.end method

; --- Test des variantes aload_N / astore_N ---
.method public static testRefLoadStore()V
  .limit stack 2
  .limit locals 5
  aconst_null
  astore_0
  aconst_null
  astore_1
  aconst_null
  astore_2
  aconst_null
  astore_3
  aload_0
  pop
  aload_1
  pop
  aload_2
  pop
  aload_3
  pop
  ; aload/astore avec operande
  aconst_null
  astore 4
  aload 4
  pop
  return
.end method

; --- Test des opcodes de chargement/stockage tableau ---
.method public static testArrayLoadStore()V
  .limit stack 4
  .limit locals 2
  ; Creer un tableau int, stocker et charger
  iconst_3
  newarray int
  astore_0
  aload_0
  iconst_0
  bipush 42
  iastore
  aload_0
  iconst_0
  iaload
  pop
  return
.end method

; --- main : point d'entree ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  return
.end method
