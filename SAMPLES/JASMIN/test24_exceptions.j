; test24_exceptions.j - Test des directives d'exceptions (TODO 21)
; Teste .catch et .throws pour la gestion des exceptions JVM.

.class public test24_exceptions
.super java/lang/Object

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Methode avec un seul .catch ---
.method public static singleCatch()V
  .limit stack 3
  .limit locals 2

  .catch java/lang/Exception from TryStart to TryEnd using Handler1

TryStart:
  new java/lang/Exception
  dup
  ldc "Erreur simple"
  invokespecial java/lang/Exception/<init>(Ljava/lang/String;)V
  athrow
TryEnd:
  goto Done1

Handler1:
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Caught: simple exception"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

Done1:
  return
.end method

; --- Methode avec .catch all (intercepte tout) ---
.method public static catchAll()V
  .limit stack 3
  .limit locals 2

  .catch all from TryStart2 to TryEnd2 using HandlerAll

TryStart2:
  new java/lang/RuntimeException
  dup
  ldc "Runtime error"
  invokespecial java/lang/RuntimeException/<init>(Ljava/lang/String;)V
  athrow
TryEnd2:
  goto Done2

HandlerAll:
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Caught: all exceptions"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

Done2:
  return
.end method

; --- Methode avec plusieurs .catch (chaine d'exceptions) ---
.method public static multipleCatch()V
  .limit stack 3
  .limit locals 2

  .catch java/lang/ArithmeticException from TryStart3 to TryEnd3 using ArithHandler
  .catch java/lang/NullPointerException from TryStart3 to TryEnd3 using NullHandler
  .catch java/lang/Exception from TryStart3 to TryEnd3 using GenHandler

TryStart3:
  iconst_1
  iconst_0
  idiv
  pop
TryEnd3:
  goto Done3

ArithHandler:
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Caught: ArithmeticException"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  goto Done3

NullHandler:
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Caught: NullPointerException"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  goto Done3

GenHandler:
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Caught: generic Exception"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

Done3:
  return
.end method

; --- Methode avec .throws (declaration d'exception) ---
.method public static throwsMethod()V
  .throws java/io/IOException
  .limit stack 3
  .limit locals 1
  new java/io/IOException
  dup
  ldc "IO Error"
  invokespecial java/io/IOException/<init>(Ljava/lang/String;)V
  athrow
.end method

; --- Methode avec .throws multiples ---
.method public static multiThrows()V
  .throws java/io/IOException
  .throws java/lang/InterruptedException
  .limit stack 1
  .limit locals 1
  return
.end method

; --- Methode avec .catch et .throws combines ---
.method public static catchAndThrows()V
  .throws java/lang/Exception
  .limit stack 3
  .limit locals 2

  .catch java/io/IOException from IOTry to IOEnd using IOHandler

IOTry:
  new java/io/IOException
  dup
  ldc "IO error in catchAndThrows"
  invokespecial java/io/IOException/<init>(Ljava/lang/String;)V
  athrow
IOEnd:
  goto IODone

IOHandler:
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Caught IOException in catchAndThrows"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

IODone:
  return
.end method

; --- Methode avec .catch et .line combines ---
.method public static catchWithLines()V
  .limit stack 3
  .limit locals 2

  .catch java/lang/Exception from LStart to LEnd using LHandler

  .line 10
LStart:
  new java/lang/Exception
  dup
  .line 12
  ldc "Error with line numbers"
  invokespecial java/lang/Exception/<init>(Ljava/lang/String;)V
  .line 14
  athrow
LEnd:
  .line 16
  goto LDone

LHandler:
  .line 18
  astore_1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  .line 19
  ldc "Caught with line numbers"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

LDone:
  .line 22
  return
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1
  .line 100
  invokestatic test24_exceptions/singleCatch()V
  .line 101
  invokestatic test24_exceptions/catchAll()V
  .line 102
  invokestatic test24_exceptions/multipleCatch()V
  .line 103
  invokestatic test24_exceptions/multiThrows()V
  .line 104
  invokestatic test24_exceptions/catchAndThrows()V
  .line 105
  invokestatic test24_exceptions/catchWithLines()V
  .line 106
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "All exception tests passed"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  .line 108
  return
.end method
