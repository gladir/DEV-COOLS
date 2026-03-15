-- test_exceptions.ada : tests pour TODO 19 - EXCEPTIONS RAISE ET HANDLERS
-- Teste les declarations d exceptions, RAISE, et les handlers EXCEPTION
-- avec WHEN nom => et WHEN OTHERS =>

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : declaration d exception simple
procedure Test_Exc_Decl is
  My_Error : exception;
begin
  null;
end Test_Exc_Decl;

-- Test 2 : RAISE d une exception standard
procedure Test_Raise_Standard is
begin
  raise Constraint_Error;
end Test_Raise_Standard;

-- Test 3 : RAISE d une exception utilisateur
procedure Test_Raise_User is
  My_Error : exception;
begin
  raise My_Error;
end Test_Raise_User;

-- Test 4 : RAISE sans nom (re-raise)
procedure Test_Reraise is
begin
  raise;
end Test_Reraise;

-- Test 5 : handler WHEN OTHERS simple
procedure Test_When_Others is
begin
  null;
exception
  when others =>
    null;
end Test_When_Others;

-- Test 6 : handler WHEN nom specifique
procedure Test_When_Named is
  My_Error : exception;
begin
  null;
exception
  when My_Error =>
    null;
end Test_When_Named;

-- Test 7 : handler avec WHEN nom et WHEN OTHERS
procedure Test_When_Mixed is
  My_Error : exception;
begin
  null;
exception
  when My_Error =>
    null;
  when others =>
    null;
end Test_When_Mixed;

-- Test 8 : RAISE dans handler (propagation)
procedure Test_Raise_In_Handler is
  My_Error : exception;
begin
  null;
exception
  when My_Error =>
    raise;
  when others =>
    null;
end Test_Raise_In_Handler;

-- Test 9 : exception dans une fonction
function Test_Func_Exc return Integer is
  My_Error : exception;
begin
  return 42;
exception
  when others =>
    return 0;
end Test_Func_Exc;

-- Test 10 : multiple declarations d exceptions
procedure Test_Multi_Exc is
  Error_A : exception;
  Error_B : exception;
  Error_C : exception;
begin
  raise Error_B;
exception
  when Error_A =>
    null;
  when Error_B =>
    null;
  when Error_C =>
    null;
  when others =>
    null;
end Test_Multi_Exc;

-- Test 11 : exception standard PROGRAM_ERROR
procedure Test_Program_Error is
begin
  raise Program_Error;
exception
  when Program_Error =>
    null;
end Test_Program_Error;

-- Test 12 : exception avec instructions dans handler
procedure Test_Handler_Stmts is
  My_Error : exception;
  X : Integer := 0;
begin
  X := 1;
  raise My_Error;
exception
  when My_Error =>
    X := 99;
end Test_Handler_Stmts;

-- Test 13 : exception avec alternatives (|)
procedure Test_Alternatives is
  Error_A : exception;
  Error_B : exception;
begin
  null;
exception
  when Error_A | Error_B =>
    null;
  when others =>
    null;
end Test_Alternatives;

-- Test 14 : exception dans procedure imbriquee
procedure Test_Nested is
  procedure Inner is
    My_Error : exception;
  begin
    raise My_Error;
  exception
    when My_Error =>
      null;
  end Inner;
begin
  Inner;
end Test_Nested;
