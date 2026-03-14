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
  return
.end method

; --- Test des variantes iload_N / istore_N ---
.method public static testIntLoadStore()V
  .limit stack 2
  .limit locals 5
  istore_0
  istore_1
  istore_2
  istore_3
  iload_0
  iload_1
  iload_2
  iload_3
  ; iload/istore avec operande explicite
  istore 4
  iload 4
  return
.end method

; --- Test des variantes lload_N / lstore_N ---
.method public static testLongLoadStore()V
  .limit stack 4
  .limit locals 6
  lstore_0
  lstore_1
  lstore_2
  lstore_3
  lload_0
  lload_1
  lload_2
  lload_3
  ; lload/lstore avec operande
  lstore 4
  lload 4
  return
.end method

; --- Test des variantes fload_N / fstore_N ---
.method public static testFloatLoadStore()V
  .limit stack 2
  .limit locals 5
  fstore_0
  fstore_1
  fstore_2
  fstore_3
  fload_0
  fload_1
  fload_2
  fload_3
  ; fload/fstore avec operande
  fstore 4
  fload 4
  return
.end method

; --- Test des variantes dload_N / dstore_N ---
.method public static testDoubleLoadStore()V
  .limit stack 4
  .limit locals 6
  dstore_0
  dstore_1
  dstore_2
  dstore_3
  dload_0
  dload_1
  dload_2
  dload_3
  ; dload/dstore avec operande
  dstore 4
  dload 4
  return
.end method

; --- Test des variantes aload_N / astore_N ---
.method public static testRefLoadStore()V
  .limit stack 2
  .limit locals 5
  astore_0
  astore_1
  astore_2
  astore_3
  aload_0
  aload_1
  aload_2
  aload_3
  ; aload/astore avec operande
  astore 4
  aload 4
  return
.end method

; --- Test des opcodes de chargement/stockage tableau ---
.method public static testArrayLoadStore()V
  .limit stack 4
  .limit locals 2
  ; Chargement depuis tableaux
  iaload
  laload
  faload
  daload
  aaload
  baload
  caload
  saload
  ; Stockage dans tableaux
  iastore
  lastore
  fastore
  dastore
  aastore
  bastore
  castore
  sastore
  return
.end method

; --- main : point d'entree ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  return
.end method
