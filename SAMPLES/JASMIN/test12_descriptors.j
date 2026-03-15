; test12_descriptors.j - Test des descripteurs de types JVM (TODO 09)
; Verifie la validation des descripteurs de methodes et le calcul
; automatique de max_locals a partir des descripteurs.

.class public test12_descriptors
.super java/lang/Object

; Constructeur : ()V -> 1 param slot (this)
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; Methode avec params primitifs : (II)I -> 3 slots (this+2*int)
.method public add(II)I
  .limit stack 2
  .limit locals 3
  iload_1
  iload_2
  iadd
  ireturn
.end method

; Methode statique : (II)I -> 2 slots (pas de this)
.method public static addStatic(II)I
  .limit stack 2
  .limit locals 2
  iload_0
  iload_1
  iadd
  ireturn
.end method

; Methode avec long param : (J)V -> 3 slots (this + long=2)
.method public useLong(J)V
  .limit stack 2
  .limit locals 3
  return
.end method

; Methode avec double param : (D)D -> 5 slots (this + double=2 + retour)
.method public useDouble(D)D
  .limit stack 2
  .limit locals 3
  dload_1
  dreturn
.end method

; Methode avec params mixtes : (IJFDLjava/lang/String;[I)V
; -> this(1) + int(1) + long(2) + float(1) + double(2) + Lref(1) + [ref(1) = 9 slots
.method public complex(IJFDLjava/lang/String;[I)V
  .limit stack 1
  .limit locals 9
  return
.end method

; Methode avec descripteur tableau : ([Ljava/lang/String;)V -> 2 slots
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  return
.end method

; Methode sans .limit locals : auto-locals doit calculer depuis descripteur
; (IIF)V static -> 3 slots (int+int+float = 1+1+1)
.method public static autoLocalsTest(IIF)V
  .limit stack 1
  return
.end method

; Methode sans .limit stack ni locals : les deux sont calcules automatiquement
; ()V static -> 0 slots
.method public static emptyMethod()V
  return
.end method

; Methode abstraite : pas de code, pas de .limit necessaire
.method public abstract abstractMethod(Ljava/lang/Object;)I
.end method

; Methode native : pas de code
.method public native nativeMethod(BCSZ)I
.end method
