To rebuild the disk-image, you need:
- dd
- z80asm
- cpmtools

The disk format the emulator uses is somewhat weird: it's the same as
the ibm-3740 disk format but without track skew. To be able to write it.
add this text as the first entry in your /etc/cpmtools/diskdefs:

diskdef avrcpm
  seclen 128
  tracks 77
  sectrk 26
  blocksize 1024
  maxdir 64
  skew 1
  boottrk 2
  os p2dos
end

