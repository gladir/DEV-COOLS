; test11_method_decl.j - Test des directives de methodes (TODO 08)
; Test de .method, .end method, .limit, .line, .throws

.class public test11_method_decl
.super java/lang/Object

; Constructeur par defaut
.method public <init>()V
  .limit stack 1
  .limit locals 1
  .line 10
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; Methode statique simple avec .line
.method public static greet()V
  .limit stack 2
  .limit locals 0
  .line 18
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Bonjour"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  .line 21
  return
.end method

; Methode avec .throws
.method public static riskyMethod()V
  .limit stack 1
  .limit locals 0
  .throws java/io/IOException
  .throws java/lang/RuntimeException
  return
.end method

; Methode abstraite (pas de code)
; Note: une classe abstraite contiendrait ceci
; .method public abstract compute(I)I
; .end method

; Methode synchronized
.method public synchronized doSync()V
  .limit stack 0
  .limit locals 1
  return
.end method

; Methode finale et statique
.method public static final helper(II)I
  .limit stack 2
  .limit locals 2
  iload_0
  iload_1
  iadd
  ireturn
.end method

; Point d'entree principal
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  .line 60
  invokestatic test11_method_decl/greet()V
  .line 62
  return
.end method
