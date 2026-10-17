#!/usr/bin/env python3
# w32_ptyrun.py TIMEOUT OUTPREFIX cmd args... : execute la commande dans un pseudo-terminal 80x25,
# conserve le flux brut (OUTPREFIX.RAW), le texte sans sequences d echappement (OUTPREFIX.TXT)
# et l ecran final rendu par pyte (OUTPREFIX_SCREEN.TXT). Code de sortie : celui du programme, 124 si delai.
import os, sys, pty, select, time, signal, re, struct, fcntl, termios
timeout=float(sys.argv[1]); prefix=sys.argv[2]; cmd=sys.argv[3:]
pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM']='xterm'
    os.execvp(cmd[0], cmd)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 25, 80, 0, 0))
# pas d'entree clavier : fermer stdin du cote esclave n est pas possible, on n envoie rien
data=b''; t0=time.time(); rc=None
while True:
    r,_,_=select.select([fd],[],[],0.2)
    if r:
        try:
            chunk=os.read(fd, 65536)
            if not chunk: break
            data+=chunk
        except OSError: break
    wpid, status = os.waitpid(pid, os.WNOHANG)
    if wpid == pid:
        rc = os.WEXITSTATUS(status) if os.WIFEXITED(status) else 128+os.WTERMSIG(status)
        # vider ce qui reste
        for _ in range(20):
            r,_,_=select.select([fd],[],[],0.05)
            if not r: break
            try:
                chunk=os.read(fd,65536)
                if not chunk: break
                data+=chunk
            except OSError: break
        break
    if time.time()-t0 > timeout:
        os.kill(pid, signal.SIGKILL); os.waitpid(pid,0); rc=124; break
open(prefix+'.RAW','wb').write(data)
# rendu par un emulateur de terminal (80x25 avec historique) : texte complet = historique + ecran
import pyte
screen=pyte.HistoryScreen(80, 25, history=20000, ratio=0.01); stream=pyte.ByteStream(screen)
stream.feed(data)
lines=[''.join(ch.data for ch in sorted(line.items())) if False else None for line in []]
hist=[]
for line in screen.history.top:
    hist.append(''.join(line[x].data if x in line else ' ' for x in range(80)).rstrip())
disp=[l.rstrip() for l in screen.display]
while disp and disp[-1]=='': disp.pop()
open(prefix+'.TXT','w',encoding='utf-8').write('\n'.join(hist+disp)+('\n' if (hist+disp) else ''))
sys.exit(rc if rc is not None else 1)
