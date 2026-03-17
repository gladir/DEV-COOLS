{ test_graph_style.pas - Test Graph fill/line/text style functions }
program test_graph_style;
uses Graph;
begin
  { Test SetFillStyle }
  SetFillStyle(SolidFill, 10);
  WriteLn('SetFillStyle(SolidFill, 10) done');

  { Test SetLineStyle }
  SetLineStyle(SolidLn, 0, NormWidth);
  WriteLn('SetLineStyle(SolidLn, 0, NormWidth) done');

  { Test SetTextStyle }
  SetTextStyle(DefaultFont, HorizDir, 1);
  WriteLn('SetTextStyle(DefaultFont, HorizDir, 1) done');

  { Test SetTextJustify }
  SetTextJustify(LeftText, TopText);
  WriteLn('SetTextJustify(LeftText, TopText) done');

  SetTextJustify(CenterText, CenterText);
  WriteLn('SetTextJustify(CenterText, CenterText) done');

  { Test SetWriteMode }
  SetWriteMode(CopyPut);
  WriteLn('SetWriteMode(CopyPut) done');

  SetWriteMode(XORPut);
  WriteLn('SetWriteMode(XORPut) done');

  { Test SetUserCharSize }
  SetUserCharSize(2, 1, 2, 1);
  WriteLn('SetUserCharSize(2,1,2,1) done');

  { Test SetFillPattern }
  SetFillPattern(SolidFill, 5);
  WriteLn('SetFillPattern done');

  { Test fill/line style constants }
  WriteLn('SolidFill=', SolidFill);
  WriteLn('EmptyFill=', EmptyFill);
  WriteLn('SolidLn=', SolidLn);
  WriteLn('DottedLn=', DottedLn);
  WriteLn('NormWidth=', NormWidth);
  WriteLn('ThickWidth=', ThickWidth);
  WriteLn('DefaultFont=', DefaultFont);
  WriteLn('HorizDir=', HorizDir);
  WriteLn('VertDir=', VertDir);

  WriteLn('OK');
end.
