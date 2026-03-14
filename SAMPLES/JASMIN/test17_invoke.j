; test17_invoke.j - Test des opcodes d'invocation de methodes (TODO 14)
; Teste invokevirtual, invokespecial, invokestatic, invokeinterface.

.class public test17_invoke
.super java/lang/Object

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Methode statique simple ---
.method public static add(II)I
  .limit stack 2
  .limit locals 2
  iload_0
  iload_1
  iadd
  ireturn
.end method

; --- Methode d'instance ---
.method public getValue()I
  .limit stack 1
  .limit locals 1
  iconst_5
  ireturn
.end method

; --- Test invokestatic ---
.method public static testStatic()V
  .limit stack 2
  .limit locals 1
  iconst_3
  iconst_4
  invokestatic test17_invoke/add(II)I
  istore_0
  return
.end method

; --- Test invokevirtual ---
.method public static testVirtual()V
  .limit stack 2
  .limit locals 2
  new test17_invoke
  dup
  invokespecial test17_invoke/<init>()V
  astore_0
  aload_0
  invokevirtual test17_invoke/getValue()I
  istore_1
  return
.end method

; --- Test invokeinterface ---
.method public static testInterface()V
  .limit stack 2
  .limit locals 2
  ; Creer un ArrayList qui implemente List
  new java/util/ArrayList
  dup
  invokespecial java/util/ArrayList/<init>()V
  astore_0
  aload_0
  invokeinterface java/util/List/size()I 1
  istore_1
  return
.end method

; --- Test invokevirtual avec descripteurs complexes ---
.method public static testComplexDescriptors()V
  .limit stack 3
  .limit locals 2
  ; Appel avec descripteur objet
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "test"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  ; Appel avec plusieurs parametres
  ldc "hello"
  astore_0
  ldc "hello"
  astore_1
  aload_0
  aload_1
  invokevirtual java/lang/String/equals(Ljava/lang/Object;)Z
  pop
  return
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1
  ; Appel statique
  invokestatic test17_invoke/testStatic()V
  ; Appel virtuel
  invokestatic test17_invoke/testVirtual()V
  return
.end method
