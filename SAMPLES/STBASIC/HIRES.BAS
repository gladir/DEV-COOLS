10 fullw 2:clearw 2
20 SQUARES: a=2:b=3:L=61:w=56
30 x=a:y=b
40 linef x,y,x+L,y
50 linef x+L,y,x+L,y+w
60 linef x+L,y+w,x,y+w
70 linef x,y+w,x,y
80 x=x+61
90 if x>600 then x=a:y=y+56
100 if y>320 then 120
110 goto 40
120 a=a+2:b=b+2:L=L-4:w=w-4
130 if w<8 then 150
140 goto 30
150 gosub DELAY
160 LINES: x=0:y=8
170 while x<614
180 linef 307,172,x,y
190 x=x+5
200 wend
210 while y<344
220 linef 307,172,x,y
230 y=y+3
240 wend
250 while x>0
260 linef 307,172,x,y
270 x=x-5
280 wend
290 while y>0
300 linef 307,172,x,y
310 y=y-3
320 wend
330 gosub DELAY
340 DESIGN: x1=1:x2=614:y1=1:y2=343
350 linef x1,y1,x2,y1
360 linef x2,y1,x2,y2
370 linef x2,y2,x1,y2
380 linef x1,y2,x1,y1
390 x1=x1+2:x2=x2-2:y1=y1+2:y2=y2-2
400 if y2>=22 then 350
410 gosub DELAY
420 end
430 DELAY: for z=1 to 5000 :next
440 clearw 2: return
