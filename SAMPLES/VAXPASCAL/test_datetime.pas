{ test_datetime.pas - DATE, TIME, CLOCK, WALLCLOCK }
program test_datetime;
var
  d   : varying [12] of char;
  t   : varying [12] of char;
  clk : integer;
  wc  : integer;
begin
  date(d);
  writeln('Date   = ', d);

  time(t);
  writeln('Time   = ', t);

  clk := clock;
  writeln('Clock  = ', clk);

  wc := wallclock;
  writeln('Wallclock = ', wc);

  writeln('Test date/time termine.');
end.
