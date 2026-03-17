{ test_cstring_msgraph.pas - Test CString params with MSGraph functions }
{ Compile avec : TPCW32 --quickpascal test_cstring_msgraph.pas          }
{ Verifie que les procedures et fonctions MSGraph acceptent des         }
{ variables de type CString en parametres.                              }

Program TestCStringMSGraph;

Uses MSGraph;

Var
  S : CString;
  R : Integer;

Begin
  S := 'Hello CString';

  { Procedures avec parametre CString }
  _OutText(S);
  WriteLn('_OutText(CString) done');

  _OutGText(S);
  WriteLn('_OutGText(CString) done');

  _OutMem(S, 5);
  WriteLn('_OutMem(CString, 5) done');

  { Fonctions avec parametre CString }
  R := _RegisterFonts(S);
  WriteLn('_RegisterFonts(CString) = ', R);

  R := _SetFont(S);
  WriteLn('_SetFont(CString) = ', R);

  R := _GetGTextExtent(S);
  WriteLn('_GetGTextExtent(CString) = ', R);

  { Test avec literal de chaine aussi }
  _OutText('Literal string');
  WriteLn('_OutText(literal) done');

  R := _RegisterFonts('*.fon');
  WriteLn('_RegisterFonts(literal) = ', R);

  WriteLn('OK');
End.
