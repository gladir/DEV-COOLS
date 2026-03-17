-- test_subprograms.ada : Test des signatures PROCEDURE et FUNCTION (TODO 12)
--
-- Ce fichier teste :
--   1. Forward declarations PROCEDURE (specs avec ';')
--   2. Forward declarations FUNCTION avec RETURN (specs avec ';')
--   3. Parametres simples (IN par defaut)
--   4. Parametres IN explicite
--   5. Parametres OUT
--   6. Parametres IN OUT
--   7. Plusieurs parametres separes par ','
--   8. Groupes de parametres separes par ';'
--   9. Procedures et fonctions sans parametres
--  10. Corps de procedure (body avec IS) - skip

WITH Ada.Text_IO;
USE Ada.Text_IO;

-- 1. Spec sans parametres
PROCEDURE Simple_Proc;

-- 2. Spec avec un parametre IN (par defaut)
PROCEDURE Print_Value (X : Integer);

-- 3. Spec avec plusieurs parametres dans un groupe
PROCEDURE Swap_Values (A : IN OUT Integer; B : IN OUT Integer);

-- 4. Spec FUNCTION sans parametres
FUNCTION Get_Zero RETURN Integer;

-- 5. Spec FUNCTION avec parametre IN
FUNCTION Double (N : Integer) RETURN Integer;

-- 6. Spec FUNCTION avec parametres multiples
FUNCTION Max_Of (A : Integer; B : Integer) RETURN Integer;

-- 7. Spec avec mode OUT
PROCEDURE Init_Value (Result : OUT Integer);

-- 8. Spec avec plusieurs groupes de parametres
PROCEDURE Multi_Params (X : Integer; Y : IN OUT Integer; Z : OUT Integer);

-- 9. Spec FUNCTION avec Boolean
FUNCTION Is_Positive (N : Integer) RETURN Boolean;

-- 10. Body de procedure (avec IS)
PROCEDURE Main_Test IS
BEGIN
   NULL;
END Main_Test;
