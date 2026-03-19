program TestMSGraphInit;
uses MSGraph;
begin
  WriteLn('Before SetVideoMode');
  _SetVideoMode(_MaxResMode);
  WriteLn('After SetVideoMode');
  _SetVideoMode(_DefaultMode);
  WriteLn('After reset');
end.
