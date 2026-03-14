; test19_objarray.j - Test des opcodes de creation d'objets et tableaux (TODO 16)
; Teste new, newarray, anewarray, multianewarray, arraylength,
; checkcast, instanceof.

.class public test19_objarray
.super java/lang/Object

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test new : creation d'objet ---
.method public static testNew()V
  .limit stack 2
  .limit locals 1
  ; Creer un nouvel objet Object
  new java/lang/Object
  dup
  invokespecial java/lang/Object/<init>()V
  astore_0
  ; Creer un StringBuilder
  new java/lang/StringBuilder
  dup
  invokespecial java/lang/StringBuilder/<init>()V
  pop
  return
.end method

; --- Test newarray : creation de tableaux de types primitifs ---
.method public static testNewarray()V
  .limit stack 2
  .limit locals 2
  ; Creer un tableau de 10 int
  bipush 10
  newarray int
  astore_0
  ; Creer un tableau de 5 byte
  iconst_5
  newarray byte
  astore_0
  ; Creer un tableau de 3 char
  iconst_3
  newarray char
  astore_0
  ; Creer un tableau de 4 boolean
  iconst_4
  newarray boolean
  astore_0
  ; Creer un tableau de 2 short
  iconst_2
  newarray short
  astore_0
  ; Creer un tableau de 3 long
  iconst_3
  newarray long
  astore_0
  ; Creer un tableau de 2 float
  iconst_2
  newarray float
  astore_0
  ; Creer un tableau de 1 double
  iconst_1
  newarray double
  astore_0
  return
.end method

; --- Test anewarray : creation de tableaux de references ---
.method public static testAnewarray()V
  .limit stack 2
  .limit locals 1
  ; Creer un tableau de 5 String
  iconst_5
  anewarray java/lang/String
  astore_0
  ; Creer un tableau de 3 Object
  iconst_3
  anewarray java/lang/Object
  astore_0
  return
.end method

; --- Test multianewarray : creation de tableaux multi-dimensionnels ---
.method public static testMultianewarray()V
  .limit stack 3
  .limit locals 1
  ; Creer un tableau 3x4 de int (int[][])
  iconst_3
  iconst_4
  multianewarray [[I 2
  astore_0
  return
.end method

; --- Test arraylength : longueur d'un tableau ---
.method public static testArraylength()V
  .limit stack 2
  .limit locals 2
  ; Creer un tableau de 10 int et obtenir sa longueur
  bipush 10
  newarray int
  astore_0
  aload_0
  arraylength
  istore_1
  return
.end method

; --- Test checkcast : verification de transtypage ---
.method public static testCheckcast()V
  .limit stack 2
  .limit locals 2
  ; Creer un objet et le caster
  new java/lang/Object
  dup
  invokespecial java/lang/Object/<init>()V
  astore_0
  aload_0
  checkcast java/lang/Object
  astore_1
  return
.end method

; --- Test instanceof : test de type ---
.method public static testInstanceof()V
  .limit stack 2
  .limit locals 2
  ; Creer un objet et tester son type
  new java/lang/Object
  dup
  invokespecial java/lang/Object/<init>()V
  astore_0
  aload_0
  instanceof java/lang/Object
  istore_1
  return
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  invokestatic test19_objarray/testNew()V
  invokestatic test19_objarray/testNewarray()V
  invokestatic test19_objarray/testAnewarray()V
  invokestatic test19_objarray/testMultianewarray()V
  invokestatic test19_objarray/testArraylength()V
  invokestatic test19_objarray/testCheckcast()V
  invokestatic test19_objarray/testInstanceof()V
  return
.end method
