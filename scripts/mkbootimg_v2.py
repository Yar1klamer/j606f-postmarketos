#!/usr/bin/env python3
"""Собирает boot.img (Android header v2) для TB-J606F на Mac, когда mkbootimg на планшете не работает (Python SIGSEGV, 07.11).
Раскладка, cmdline и адреса берутся из образца (текущий рабочий boot.img), подставляются ядро, initramfs и DTB.
Запуск: python3 -I scripts/mkbootimg_v2.py TEMPLATE.img vmlinuz initramfs DTB OUT.img"""
import sys, struct, hashlib
src, kern, rd, dtb, out = sys.argv[1:6]
h = open(src,'rb').read()
magic,ks,ka,rs,ra,ss,sa,ta,ps,hv,osv = struct.unpack_from('<8s10I',h,0)
assert magic==b'ANDROID!' and hv==2
name=h[48:64]; cmd=h[64:576]; extra=h[608:1632]
rdo_size,rdo_off,hsize,dsz,daddr = struct.unpack_from('<IQIIQ',h,1632)
K=open(kern,'rb').read(); R=open(rd,'rb').read(); D=open(dtb,'rb').read()
sha=hashlib.sha1()
for b in (K,R,b'',b'',D): sha.update(b); sha.update(struct.pack('<I',len(b)))
hdr = struct.pack('<8s10I',magic,len(K),ka,len(R),ra,0,sa,ta,ps,hv,osv)+name+cmd+sha.digest()+b'\0'*12+extra+struct.pack('<IQIIQ',0,0,hsize,len(D),daddr)
pad=lambda b: b+b'\0'*((-len(b))%ps)
open(out,'wb').write(pad(hdr)+pad(K)+pad(R)+pad(D))
print(out, len(K), len(R), len(D))
