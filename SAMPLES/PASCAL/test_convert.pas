program test_convert;

function convert_to_jasmin(s: String): String;
var
  result: String;
begin
  result := s;
  
  writeln('DEBUG: Input string: [', s, '] Length=', Length(s));
  
  if Pos('ldd  # ', result) = 1 then begin
    result := 'bipush ' + Copy(result, 7, Length(result));
    writeln('DEBUG: Matched ldd  # pattern');
  end
  else if Pos('ldd  #', result) = 1 then begin
    result := 'bipush ' + Copy(result, 6, Length(result));
    writeln('DEBUG: Matched ldd  # pattern (no space after #)');
  end
  else if Pos('std   ', result) = 1 then begin
    result := 'istore ' + Copy(result, 7, Length(result));
    writeln('DEBUG: Matched std with 3 spaces');
  end
  else if Pos('ldd   ', result) = 1 then begin
    result := 'iload ' + Copy(result, 7, Length(result));
    writeln('DEBUG: Matched ldd with 3 spaces');
  end
  else begin
    writeln('DEBUG: No pattern matched');
  end;
  
  writeln('DEBUG: Output string: [', result, ']');
  convert_to_jasmin := result;
end;

begin
  writeln(convert_to_jasmin('ldd  # 5'));
  writeln(convert_to_jasmin('std   x'));
  writeln(convert_to_jasmin('ldd   x'));
end.
