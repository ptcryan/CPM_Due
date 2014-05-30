Tiny howto:

- Burn the ATMega88. Hex-file is in the avr-directory, fuse-values are given in
  the z80.asm file.
- Copy the disk-image raw to disk. No drag&drop, no filesystem, no partitions:
  you'll need to do a 
dd if=diskimage of=/dev/sdx
  under Unix. Make sure to replace sdx with the /dev/sdx with where your SD-card
  actually lives! The image is only 256k, so any old MMC/SD will do. I tried
  both a nameless 8M MMC and an 1G Kingston SD-card, and both worked fine.
- Build the schematic, start a terminal emulator and play a bit of zork!

In case you want to rebuild the disk image, see the files in the z80 directory.
