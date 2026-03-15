; test01_hello.j - Affichage de chaines simples
; Test de getstatic, ldc, invokevirtual

.class public test01_hello
.super java/lang/Object

.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Bonjour depuis Jasmin!"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "JASMIN.PAS fonctionne!"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return
.end method
