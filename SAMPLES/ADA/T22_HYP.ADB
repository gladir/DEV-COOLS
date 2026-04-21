------------------------------------------------------------
-- T22_HYP.ADB - Fonctions hyperboliques et exponentielles
--
-- Teste les fonctions Ada.Numerics.Elementary_Functions
-- implementees en FPU x87 : Exp, Log, Sinh, Cosh, Tanh,
-- ainsi que Sqrt et Arcsin qui utilisent les memes primitives
-- FPU (FSUBP/FDIVP/FSCALE).
--
-- Valeurs de reference :
--   Exp(0)    = 1.0
--   Exp(1)    = 2.718281...
--   Log(e)    ~ 1.0
--   Sinh(0)   = 0.0
--   Cosh(0)   = 1.0
--   Tanh(0)   = 0.0
--   Sinh(1)   = 1.1752011...
--   Cosh(1)   = 1.5430806...
--   Tanh(1)   = 0.7615941...
--   Arcsin(0) = 0.0
--   Arcsin(0.5) ~ 0.5235987 (= Pi/6)
------------------------------------------------------------
WITH Ada.Text_IO;
WITH Ada.Numerics.Elementary_Functions;
USE Ada.Text_IO;
USE Ada.Numerics.Elementary_Functions;

PROCEDURE T22_Hyp IS
   Y : Float;
BEGIN
   Put_Line("=== Exp / Log ===");
   Y := Exp(0.0);
   IF Y = 1.0 THEN Put_Line("  Exp(0)  = 1.0      OK");
   ELSE            Put_Line("  Exp(0)  = 1.0      FAIL"); END IF;

   Y := Exp(1.0);
   IF Y > 2.71 AND Y < 2.72 THEN Put_Line("  Exp(1)  ~ 2.718    OK");
   ELSE                          Put_Line("  Exp(1)  ~ 2.718    FAIL"); END IF;

   Y := Log(1.0);
   IF Y > -0.001 AND Y < 0.001 THEN Put_Line("  Log(1)  = 0.0      OK");
   ELSE                             Put_Line("  Log(1)  = 0.0      FAIL"); END IF;

   Put_Line("=== Sinh / Cosh / Tanh ===");
   Y := Sinh(0.0);
   IF Y = 0.0 THEN Put_Line("  Sinh(0) = 0.0      OK");
   ELSE            Put_Line("  Sinh(0) = 0.0      FAIL"); END IF;

   Y := Cosh(0.0);
   IF Y = 1.0 THEN Put_Line("  Cosh(0) = 1.0      OK");
   ELSE            Put_Line("  Cosh(0) = 1.0      FAIL"); END IF;

   Y := Tanh(0.0);
   IF Y = 0.0 THEN Put_Line("  Tanh(0) = 0.0      OK");
   ELSE            Put_Line("  Tanh(0) = 0.0      FAIL"); END IF;

   Y := Sinh(1.0);
   IF Y > 1.17 AND Y < 1.18 THEN Put_Line("  Sinh(1) ~ 1.175    OK");
   ELSE                          Put_Line("  Sinh(1) ~ 1.175    FAIL"); END IF;

   Y := Cosh(1.0);
   IF Y > 1.54 AND Y < 1.55 THEN Put_Line("  Cosh(1) ~ 1.543    OK");
   ELSE                          Put_Line("  Cosh(1) ~ 1.543    FAIL"); END IF;

   Y := Tanh(1.0);
   IF Y > 0.76 AND Y < 0.77 THEN Put_Line("  Tanh(1) ~ 0.762    OK");
   ELSE                          Put_Line("  Tanh(1) ~ 0.762    FAIL"); END IF;

   Put_Line("=== Identite cosh(x)^2 - sinh(x)^2 = 1 ===");
   Y := Cosh(2.0) * Cosh(2.0) - Sinh(2.0) * Sinh(2.0);
   IF Y > 0.99 AND Y < 1.01 THEN Put_Line("  cosh(2)^2 - sinh(2)^2 = 1  OK");
   ELSE                          Put_Line("  cosh(2)^2 - sinh(2)^2 = 1  FAIL"); END IF;

   Put_Line("=== Arcsin (utilise FSUBRP + FSQRT + FPATAN) ===");
   Y := Arcsin(0.0);
   IF Y = 0.0 THEN Put_Line("  Arcsin(0)   = 0        OK");
   ELSE            Put_Line("  Arcsin(0)   = 0        FAIL"); END IF;

   Y := Arcsin(0.5);    -- Pi/6 = 0.5235987
   IF Y > 0.52 AND Y < 0.53 THEN Put_Line("  Arcsin(0.5) ~ 0.5236   OK");
   ELSE                          Put_Line("  Arcsin(0.5) ~ 0.5236   FAIL"); END IF;
END T22_Hyp;
