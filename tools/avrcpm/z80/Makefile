#WARNING! Do not run a 'make install' unless you know what you're doing.

INSTALLDISK=/dev/disk2

diskimage: cpm.bin cpmdsk/*
	mkfs.cpm -f avrcpm -b cpm.bin -L test diskimage
	cd cpmdsk; for x in *; do sudo cpmcp -f avrcpm ../diskimage $$x 0:$$x; done; cd ..

cpm.bin: ipl.bin bios.bin CPM.SYS
	dd conv=sync bs=128  count=1 if=ipl.bin > cpm.bin
	dd conv=sync bs=128 count=44 if=CPM.SYS >> cpm.bin
	dd conv=sync bs=128  count=6 if=bios.bin >> cpm.bin

ipl.bin: ipl.asm
	z80asm ipl.asm -o ipl.bin -lipl.lst

bios.bin: bios.asm
	z80asm bios.asm -o bios.bin -lbios.lst

clean:
	rm -f bios.lst bios.bin
	rm -f ipl.lst ipl.bin
	rm -f cpm.bin diskimage

install: diskimage dummy
	sudo dd if=diskimage of=${INSTALLDISK} conv=sync
	sync
	sudo cpmls -f avrcpm ${INSTALLDISK}
	sync
	sleep 1
	sync


dummy:
