; test09_except.j - Gestion d'exceptions
; Test de .catch, athrow, new (exception), invokevirtual getMessage

.class public test09_except
.super java/lang/Object

.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 3
  .limit locals 2

  .catch java/lang/Exception from TryStart to TryEnd using CatchHandler

TryStart:
  ; Lancer une exception
  new java/lang/Exception
  dup
  ldc "Erreur de test"
  invokespecial java/lang/Exception/<init>(Ljava/lang/String;)V
  athrow
TryEnd:
  goto AfterCatch

CatchHandler:
  ; L'exception est sur la pile
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Exception attrapee : "
  invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V
  getstatic java/lang/System/out Ljava/io/PrintStream;
  aload_1
  invokevirtual java/lang/Exception/getMessage()Ljava/lang/String;
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

AfterCatch:
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Fin du programme"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return
.end method
