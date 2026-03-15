; test07_field.j - Champs d'instance et statiques
; Test de getfield, putfield, getstatic, putstatic, new, invokespecial

.class public test07_field
.super java/lang/Object

; Champ d'instance
.field private valeur I

; Champ statique
.field public static compteur I

.method public <init>()V
  .limit stack 2
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  ; this.valeur = 0
  aload_0
  iconst_0
  putfield test07_field/valeur I
  return
.end method

; Methode setter
.method public setValeur(I)V
  .limit stack 2
  .limit locals 2
  aload_0
  iload_1
  putfield test07_field/valeur I
  return
.end method

; Methode getter
.method public getValeur()I
  .limit stack 1
  .limit locals 1
  aload_0
  getfield test07_field/valeur I
  ireturn
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 3
  .limit locals 2

  ; Initialiser le compteur statique
  bipush 99
  putstatic test07_field/compteur I

  ; Creer un objet test07_field
  new test07_field
  dup
  invokespecial test07_field/<init>()V
  astore_1

  ; obj.setValeur(42)
  aload_1
  bipush 42
  invokevirtual test07_field/setValeur(I)V

  ; Afficher obj.getValeur() = 42
  getstatic java/lang/System/out Ljava/io/PrintStream;
  aload_1
  invokevirtual test07_field/getValeur()I
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher le compteur statique = 99
  getstatic java/lang/System/out Ljava/io/PrintStream;
  getstatic test07_field/compteur I
  invokevirtual java/io/PrintStream/println(I)V

  return
.end method
