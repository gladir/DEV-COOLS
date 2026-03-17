-- test_ifcase.ada : tests pour TODO 17 - IF/ELSIF/ELSE et CASE/WHEN/OTHERS
-- Fichier de test pour le compilateur ADACW32

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : IF simple
procedure Test_If_Simple is
   X : Integer := 10;
begin
   if X > 5 then
      Put_Line("X > 5");
   end if;
end Test_If_Simple;

-- Test 2 : IF / ELSE
procedure Test_If_Else is
   X : Integer := 3;
begin
   if X > 5 then
      Put_Line("grand");
   else
      Put_Line("petit");
   end if;
end Test_If_Else;

-- Test 3 : IF / ELSIF / ELSE
procedure Test_If_Elsif is
   N : Integer := 42;
begin
   if N < 0 then
      Put_Line("negatif");
   elsif N = 0 then
      Put_Line("zero");
   elsif N < 10 then
      Put_Line("petit");
   elsif N < 100 then
      Put_Line("moyen");
   else
      Put_Line("grand");
   end if;
end Test_If_Elsif;

-- Test 4 : IF imbrique
procedure Test_If_Nested is
   A : Integer := 1;
   B : Integer := 2;
begin
   if A > 0 then
      if B > 0 then
         Put_Line("A et B positifs");
      else
         Put_Line("A positif, B non");
      end if;
   else
      Put_Line("A non positif");
   end if;
end Test_If_Nested;

-- Test 5 : IF avec expressions booleennes
procedure Test_If_Bool is
   Flag : Boolean := True;
begin
   if Flag then
      Put_Line("flag vrai");
   end if;
end Test_If_Bool;

-- Test 6 : CASE simple avec entiers
procedure Test_Case_Simple is
   X : Integer := 2;
begin
   case X is
      when 1 => Put_Line("un");
      when 2 => Put_Line("deux");
      when 3 => Put_Line("trois");
      when others => Put_Line("autre");
   end case;
end Test_Case_Simple;

-- Test 7 : CASE avec alternatives |
procedure Test_Case_Alts is
   X : Integer := 5;
begin
   case X is
      when 1 | 2 | 3 => Put_Line("petit");
      when 4 | 5 | 6 => Put_Line("moyen");
      when others => Put_Line("grand");
   end case;
end Test_Case_Alts;

-- Test 8 : CASE sans OTHERS
procedure Test_Case_No_Others is
   C : Integer := 1;
begin
   case C is
      when 0 => Put_Line("zero");
      when 1 => Put_Line("un");
   end case;
end Test_Case_No_Others;

-- Test 9 : CASE avec OTHERS seul
procedure Test_Case_Others_Only is
   V : Integer := 99;
begin
   case V is
      when others => Put_Line("toujours");
   end case;
end Test_Case_Others_Only;

-- Test 10 : IF dans un CASE
procedure Test_If_In_Case is
   X : Integer := 2;
   Y : Integer := 10;
begin
   case X is
      when 1 =>
         if Y > 5 then
            Put_Line("X=1, Y>5");
         end if;
      when 2 =>
         if Y > 5 then
            Put_Line("X=2, Y>5");
         else
            Put_Line("X=2, Y<=5");
         end if;
      when others =>
         Put_Line("autre X");
   end case;
end Test_If_In_Case;

-- Test 11 : CASE dans un IF
procedure Test_Case_In_If is
   A : Integer := 1;
   B : Integer := 3;
begin
   if A > 0 then
      case B is
         when 1 => Put_Line("B=1");
         when 2 => Put_Line("B=2");
         when 3 => Put_Line("B=3");
         when others => Put_Line("B autre");
      end case;
   else
      Put_Line("A <= 0");
   end if;
end Test_Case_In_If;

-- Test 12 : CASE avec caracteres
procedure Test_Case_Char is
   C : Character := 'B';
begin
   case C is
      when 'A' => Put_Line("lettre A");
      when 'B' => Put_Line("lettre B");
      when others => Put_Line("autre lettre");
   end case;
end Test_Case_Char;

-- Test 13 : IF avec expression complexe
procedure Test_If_Complex_Expr is
   A : Integer := 5;
   B : Integer := 10;
begin
   if A + B > 12 then
      Put_Line("somme grande");
   elsif A * B > 40 then
      Put_Line("produit grand");
   else
      Put_Line("petites valeurs");
   end if;
end Test_If_Complex_Expr;

-- Test 14 : CASE avec bloc de plusieurs instructions
procedure Test_Case_Multi_Stmts is
   X : Integer := 1;
   R : Integer := 0;
begin
   case X is
      when 1 =>
         R := 10;
         R := R + 5;
      when 2 =>
         R := 20;
      when others =>
         R := 0;
   end case;
end Test_Case_Multi_Stmts;
