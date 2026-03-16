{ test_graph_const.pas - Test all Graph unit constants }
program test_graph_const;
uses Graph;
begin
  { Driver constants }
  WriteLn('Detect=', Detect);
  WriteLn('CGA=', CGA);
  WriteLn('EGA=', EGA);
  WriteLn('VGA=', VGA);

  { Error constants }
  WriteLn('grOk=', grOk);
  WriteLn('grNoInitGraph=', grNoInitGraph);
  WriteLn('grNotDetected=', grNotDetected);
  WriteLn('grError=', grError);

  { Line style constants }
  WriteLn('SolidLn=', SolidLn);
  WriteLn('DottedLn=', DottedLn);
  WriteLn('CenterLn=', CenterLn);
  WriteLn('DashedLn=', DashedLn);
  WriteLn('UserBitLn=', UserBitLn);

  { Width constants }
  WriteLn('NormWidth=', NormWidth);
  WriteLn('ThickWidth=', ThickWidth);

  { Fill constants }
  WriteLn('EmptyFill=', EmptyFill);
  WriteLn('SolidFill=', SolidFill);
  WriteLn('LineFill=', LineFill);
  WriteLn('UserFill=', UserFill);

  { Font constants }
  WriteLn('DefaultFont=', DefaultFont);
  WriteLn('TriplexFont=', TriplexFont);
  WriteLn('SmallFont=', SmallFont);
  WriteLn('SansSerifFont=', SansSerifFont);
  WriteLn('GothicFont=', GothicFont);

  { Direction constants }
  WriteLn('HorizDir=', HorizDir);
  WriteLn('VertDir=', VertDir);

  { Text justify constants }
  WriteLn('LeftText=', LeftText);
  WriteLn('CenterText=', CenterText);
  WriteLn('RightText=', RightText);
  WriteLn('BottomText=', BottomText);
  WriteLn('TopText=', TopText);

  { BitBlt constants }
  WriteLn('CopyPut=', CopyPut);
  WriteLn('XORPut=', XORPut);
  WriteLn('ORPut=', ORPut);
  WriteLn('ANDPut=', ANDPut);
  WriteLn('NOTPut=', NOTPut);

  WriteLn('OK');
end.
