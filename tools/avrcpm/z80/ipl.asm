;    CP/M IPL for z80due
;    Copyright (C) 2014 ptcryan
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.

org $2000
	; IPL for the z80due. Loads CPM from the 'disk' from
	; track 0 sector 1 to track 1 sector 25.

	ld sp,$1000
	
;	call printipl

; Here we want to copy the CP/M system from disk to memory.
; CP/M occupies the first two tracks of the disk minus the
; first sector which contains the initial program loader (this
; program)
	ld b,51				; load 51 sectors (2 tracks * 26 sectors - this sector)
	ld de,$0001			; start with track 0 sector 1
	ld hl,$3400+$A800	; destination is start of CCP+b
loadloop:
	ld a,d 				; track
	out (16),a
	ld a,e 				; sector
	out (18),a
	ld a,l 				; dma L
	out (20),a
	ld a,h 				; dma H
	out (21),a
	ld a,1 				; Read sector to RAM
	out (22),a

	push bc
	ld bc,$80 			; increment RAM pointer to next block
	add hl,bc
	pop bc

	inc e 				; increment sector
	ld a,e
	cp 26
	jp nz,noNextTrack

	inc d 				; increment track
	ld e,0 				; reset sector counter to 0

noNextTrack:

	dec b
	jp nz,loadloop

	jp $4A00+$A800 		; jump to BIOS

printipl:
	ld a,'i'
	out (2),a
	ld a,'p'
	out (2),a
	ld a,'l'
	out (2),a
	ld a,13
	out (2),a
	ld a,10
	out (2),a
	ret

end