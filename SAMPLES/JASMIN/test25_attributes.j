; test25_attributes.j - Test des attributs supplementaires (TODO 22)
; Teste .source, .deprecated, .signature, .inner class, .enclosing method.

.source test25_attributes.java
.class public test25_attributes
.super java/lang/Object

; --- Signature generique de la classe ---
.signature Ljava/lang/Object;Ljava/lang/Comparable<Ljava/lang/String;>;

; --- Inner class declaration ---
.inner class public static test25_attributes$Inner test25_attributes Inner

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Methode deprecated ---
.method public static oldMethod()V
  .deprecated
  .limit stack 2
  .limit locals 1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "This method is deprecated"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return
.end method

; --- Methode avec signature generique ---
.method public static genericMethod()V
  .signature (Ljava/util/List<Ljava/lang/String;>;)V
  .limit stack 2
  .limit locals 1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Generic method"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return
.end method

; --- Methode avec .deprecated et .signature combines ---
.method public static oldGenericMethod()V
  .deprecated
  .signature (Ljava/util/Map<Ljava/lang/String;Ljava/lang/Integer;>;)V
  .limit stack 2
  .limit locals 1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Old generic method"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return
.end method

; --- Methode normale avec .line (LineNumberTable) ---
.method public static methodWithLines()V
  .limit stack 2
  .limit locals 1
  .line 100
  getstatic java/lang/System/out Ljava/io/PrintStream;
  .line 101
  ldc "Method with line numbers"
  .line 102
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  .line 103
  return
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1
  .line 200
  invokestatic test25_attributes/oldMethod()V
  .line 201
  invokestatic test25_attributes/genericMethod()V
  .line 202
  invokestatic test25_attributes/oldGenericMethod()V
  .line 203
  invokestatic test25_attributes/methodWithLines()V
  .line 204
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "All attribute tests passed"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  .line 206
  return
.end method
