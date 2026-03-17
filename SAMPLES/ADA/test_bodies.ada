-- test_bodies.ada : Test des corps PROCEDURE et FUNCTION (TODO 13)
--
-- Ce fichier teste :
--   1. Procedure sans parametres avec corps vide (NULL)
--   2. Procedure avec parametres IN et corps simple
--   3. Procedure avec variables locales dans la partie declarative
--   4. Function sans parametres avec RETURN
--   5. Function avec parametre IN et RETURN
--   6. Function avec plusieurs parametres
--   7. Sous-programme avec partie declarative (types + variables)
--   8. Procedure avec EXCEPTION handler
--   9. Sous-programmes imbriques (nested)
--  10. Procedure comme programme principal (pattern ADB)

WITH Ada.Text_IO;
USE Ada.Text_IO;

-- 1. Procedure sans parametres - corps vide
PROCEDURE Do_Nothing IS
BEGIN
   NULL;
END Do_Nothing;

-- 2. Procedure avec parametre IN
PROCEDURE Print_Int (X : Integer) IS
BEGIN
   NULL;
END Print_Int;

-- 3. Procedure avec variables locales
PROCEDURE Local_Vars IS
   A : Integer;
   B : Integer;
   C : Boolean;
BEGIN
   NULL;
END Local_Vars;

-- 4. Function sans parametres
FUNCTION Get_Zero RETURN Integer IS
BEGIN
   NULL;
END Get_Zero;

-- 5. Function avec un parametre
FUNCTION Double (N : Integer) RETURN Integer IS
BEGIN
   NULL;
END Double;

-- 6. Function avec plusieurs parametres
FUNCTION Max_Of (A : Integer; B : Integer) RETURN Integer IS
BEGIN
   NULL;
END Max_Of;

-- 7. Sous-programme avec types locaux et variables
PROCEDURE Complex_Decls IS
   TYPE Color IS (Red, Green, Blue);
   SUBTYPE Small IS Integer RANGE 1 .. 100;
   X : Integer;
   Flag : Boolean;
BEGIN
   NULL;
END Complex_Decls;

-- 8. Procedure avec EXCEPTION
PROCEDURE With_Exception IS
   Value : Integer;
BEGIN
   NULL;
EXCEPTION
   WHEN OTHERS =>
      NULL;
END With_Exception;

-- 9. Sous-programmes imbriques
PROCEDURE Outer IS
   Inner_Val : Integer;

   PROCEDURE Inner IS
   BEGIN
      NULL;
   END Inner;

   FUNCTION Helper RETURN Integer IS
   BEGIN
      NULL;
   END Helper;

BEGIN
   NULL;
END Outer;

-- 10. Programme principal
PROCEDURE Main_Test IS
BEGIN
   NULL;
END Main_Test;
