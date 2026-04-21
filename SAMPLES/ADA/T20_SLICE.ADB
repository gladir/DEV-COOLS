-----------------------------------------------------------------
-- T20_SLICE.ADB : test des tranches (slices) sur chaines        --
-- Couvre :                                                      --
--   - Slice avec bornes constantes : S(1..5)                    --
--   - Slice couvrant la chaine complete : S(1..N)               --
--   - Slice d un seul caractere : S(1..1)                       --
--   - Slice avec bornes dynamiques (variable de boucle)         --
--   - Plusieurs slices dans la meme instruction (tampon rotatif)--
--   - Put (sans saut de ligne) et Put_Line sur slices           --
-----------------------------------------------------------------
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T20_Slice IS
   Msg : String := "ABCDEFGHIJKL";
BEGIN
   -- Slices de base
   Put_Line(Msg(1..4));        -- "ABCD"
   Put_Line(Msg(5..8));        -- "EFGH"
   Put_Line(Msg(9..12));       -- "IJKL"

   -- Cas limites
   Put_Line(Msg(1..12));       -- chaine complete
   Put_Line(Msg(1..1));        -- un seul caractere

   -- Bornes dynamiques (variable de boucle)
   FOR K IN 1 .. 3 LOOP
      Put_Line(Msg(K..K+2));   -- "ABC", "BCD", "CDE"
   END LOOP;

   -- Plusieurs slices dans la meme expression
   -- (tampon rotatif a 4 slots dans le runtime)
   Put(Msg(1..3));
   Put(Msg(4..5));
   Put(Msg(6..7));
   Put_Line(Msg(8..12));       -- "ABCDEFGHIJKL"
END T20_Slice;
