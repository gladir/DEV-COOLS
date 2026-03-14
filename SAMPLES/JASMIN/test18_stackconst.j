; test18_stackconst.j - Test des opcodes de manipulation de pile et
; chargement de constantes (TODO 15)
; Teste nop, pop, pop2, dup, dup_x1, dup_x2, dup2, dup2_x1, dup2_x2,
; swap, aconst_null, iconst_m1..iconst_5, lconst_0/1, fconst_0/1/2,
; dconst_0/1, bipush, sipush, ldc, ldc_w, ldc2_w.

.class public test18_stackconst
.super java/lang/Object

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test manipulation de la pile ---
.method public static testStack()V
  .limit stack 6
  .limit locals 2
  ; nop
  nop
  ; pousser et depiler
  iconst_1
  pop
  ; pousser 2 et depiler 2
  iconst_1
  iconst_2
  pop2
  ; dup : dupliquer le sommet
  iconst_3
  dup
  pop2
  ; dup_x1 : dupliquer sous le 2e
  iconst_1
  iconst_2
  dup_x1
  pop
  pop
  pop
  ; dup_x2 : dupliquer sous le 3e
  iconst_1
  iconst_2
  iconst_3
  dup_x2
  pop
  pop
  pop
  pop
  ; dup2 : dupliquer les 2 mots du sommet
  iconst_1
  iconst_2
  dup2
  pop2
  pop2
  ; dup2_x1 : dupliquer 2 mots sous le 3e
  iconst_1
  iconst_2
  iconst_3
  dup2_x1
  pop
  pop
  pop
  pop
  pop
  ; dup2_x2 : dupliquer 2 mots sous le 4e
  iconst_1
  iconst_2
  iconst_3
  iconst_4
  dup2_x2
  pop
  pop
  pop
  pop
  pop
  pop
  ; swap : echanger les 2 mots du sommet
  iconst_1
  iconst_2
  swap
  pop
  pop
  return
.end method

; --- Test constantes entiers ---
.method public static testIntConst()V
  .limit stack 4
  .limit locals 2
  ; aconst_null
  aconst_null
  astore_0
  ; iconst_m1 a iconst_5
  iconst_m1
  istore_0
  iconst_0
  istore_0
  iconst_1
  istore_0
  iconst_2
  istore_0
  iconst_3
  istore_0
  iconst_4
  istore_0
  iconst_5
  istore_0
  return
.end method

; --- Test constantes long, float, double ---
.method public static testOtherConst()V
  .limit stack 4
  .limit locals 4
  ; lconst_0, lconst_1
  lconst_0
  lstore_0
  lconst_1
  lstore_0
  ; fconst_0, fconst_1, fconst_2
  fconst_0
  fstore_2
  fconst_1
  fstore_2
  fconst_2
  fstore_2
  ; dconst_0, dconst_1
  dconst_0
  dstore_0
  dconst_1
  dstore_0
  return
.end method

; --- Test bipush et sipush ---
.method public static testPush()V
  .limit stack 2
  .limit locals 1
  ; bipush avec differentes valeurs
  bipush 0
  pop
  bipush 42
  pop
  bipush 127
  pop
  bipush -1
  pop
  bipush -128
  pop
  ; sipush avec differentes valeurs
  sipush 0
  pop
  sipush 256
  pop
  sipush 1000
  pop
  sipush -1
  pop
  sipush -1000
  pop
  return
.end method

; --- Test ldc, ldc_w, ldc2_w ---
.method public static testLdc()V
  .limit stack 4
  .limit locals 4
  ; ldc entier
  ldc 42
  istore_0
  ; ldc chaine
  ldc "Hello World"
  astore_1
  ; ldc flottant
  ldc 3.14
  fstore_2
  ; ldc_w entier
  ldc_w 12345
  istore_0
  ; ldc_w chaine
  ldc_w "Test ldc_w"
  astore_1
  ; ldc2_w long
  ldc2_w 100000
  lstore_0
  return
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  invokestatic test18_stackconst/testStack()V
  invokestatic test18_stackconst/testIntConst()V
  invokestatic test18_stackconst/testOtherConst()V
  invokestatic test18_stackconst/testPush()V
  invokestatic test18_stackconst/testLdc()V
  return
.end method
