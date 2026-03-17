{ test_graph_text.pas - Test Graph text functions }
program test_graph_text;
uses Graph;
begin
  { Test SetTextStyle }
  SetTextStyle(DefaultFont, HorizDir, 1);
  WriteLn('SetTextStyle(DefaultFont, HorizDir, 1) done');

  { Test SetTextJustify }
  SetTextJustify(LeftText, TopText);
  WriteLn('SetTextJustify done');

  { Test SetUserCharSize }
  SetUserCharSize(1, 1, 1, 1);
  WriteLn('SetUserCharSize done');

  { Test font constants }
  WriteLn('DefaultFont=', DefaultFont);
  WriteLn('TriplexFont=', TriplexFont);
  WriteLn('SmallFont=', SmallFont);
  WriteLn('SansSerifFont=', SansSerifFont);
  WriteLn('GothicFont=', GothicFont);

  { Test text justify constants }
  WriteLn('LeftText=', LeftText);
  WriteLn('CenterText=', CenterText);
  WriteLn('RightText=', RightText);
  WriteLn('BottomText=', BottomText);
  WriteLn('TopText=', TopText);

  WriteLn('OK');
end.
