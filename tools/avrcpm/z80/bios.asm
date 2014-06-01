;    CP/M BIOS for avrcpm
;    Copyright (C) 2010 Sprite_tm
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

mem_offset:	equ	$A800				; Offset for 62K of memory
bios:		equ	$4A00+mem_offset	; base of BIOS
cpmb:		equ	$3400+mem_offset	; base of CPM (CCP)
bdos:		equ	$3c06+mem_offset	; base of BDOS
iobyte:		equ $0003				; address of the IOBYTE
cdisk:		equ	$0004				; address of last logged disk
buff:		equ	$0080				; default buffer address

cr:			equ	$0d					; carriage return
lf:			equ	$0a					; line feed



org	bios
	jp boot
wboote:
	jp wboot
	jp const
	jp conin
	jp conout
	jp list
	jp punch
	jp reader
	jp home
	jp seldsk
	jp settrk
	jp setsec
	jp setdma
	jp read
	jp write
	jp listst
	jp sectran

; Disk Parameter Header
dph:
	dw trans 						; XLT:    Address of translation table
	dw 0 							; 000:    Scratchpad
	dw 0 							; 000:    Scratchpad
	dw 0 							; 000:    Scratchpad
	dw dirbuf 						; DIRBUF: Address of a dirbuff scratchpad
	dw dpb 							; DPB:    Address of a disk parameter block
	dw chk 							; CSV:    Address of scratchpad area for changed disks
	dw all 							; ALV:    Address of an allocation info sratchpad

signon:
	db 0dh, 0ah, 0ah
	db '64'
	db 'K CP/M Vers 2.2', cr, lf
	db 'Z80Due BIOS v0.2', cr, lf, 0

boot:
	ld sp, buff+$80
	ld hl, signon
	call prmsg
	xor a
	ld (iobyte), a					; clear the IOBYTE
	ld (cdisk), a					; clear the active disk
	jp gocpm

wboot:
	ld sp, buff						; use the disk buffer space for now. Not being used now.

; reload CP/M and initialize low memory
loadcpm:
	ld b, 51						; load 51 sectors (2 tracks * 26 sectors - ipl)
	ld de, $0001					; start with track 0 sector 1
	ld hl, cpmb						; destination is start of CCP+b
loadloop:
	ld c, d			 				; set the track
	call settrk
	ld c ,e							; set sector
	call setsec
	push bc
	ld b, h							; set DMA
	ld c, l
	call setdma
;	pop bc
	call read 						; Read sector to RAM
;	push bc
	ld bc, $80 						; increment RAM pointer to next block
	add hl, bc
	pop bc
	inc e 							; increment sector
	ld a, e
	cp 26
	jp nz, noNextTrack
	inc d 							; increment track
	ld e, 0 						; reset sector counter to 0
noNextTrack:
	dec b
	jp nz, loadloop

; CP/M is reloaded. Now initialize low memory
; Initialize the DMA to 0x0080
gocpm:
	ld bc, buff
	call setdma

; Reset monitor entry points
	ld a, $c3						; load a with jump opcode
	ld (0), a						; store at 0000
	ld hl, wboote					; load hl with warm boot address
;	ld (1), hl						; store at 0001
	ld a, l
	ld (1), a
	ld a, h
	ld (2), a
	ld (5), a						; store jump at 0005
	ld hl, bdos						; load hl with bdos entry
;	ld (6), hl						; store at 0006
	ld a, l
	ld (6), a
	ld a, h
	ld (7), a

; Put the initial drive # into c and jump to CP/M
	ld a, (cdisk)
	ld c, a

	jp cpmb

const:
	in a,(0)
	ret

conin:
	in a,(0)
	cp $ff
	jp nz,conin

	in a,(1)
	ret

conout:
	push af
	ld a,c
	out (2),a
	pop af
	ret

list:
	ret

punch:
	ret

reader:
	ld a,$1F
	ret

home:
	push af
	ld a,0
	out (16),a
	pop af
	ret

seldsk:
	push af
	ld a,c
	cp 0
	jp nz,seldsk_na
	ld hl,dph
	pop af
	ret
seldsk_na:
	ld hl,0
	pop af
	ret

settrk:
	push af
	ld a,c
	out (16),a
	pop af
	ret

setsec:
	push af
	ld a,c
	out (18),a
	pop af
	ret

setdma:
	push af
	ld a,c
	out (20),a
	ld a,b
	out (21),a
	pop af
	ret

read:
	ld a,1
	out (22),a
	ld a,0
	ret

write:
	ld a,2
	out (22),a
	ld a,0
	ret

listst:
	ld a,0
	ret

sectran:
	;translate sector bc using table at de, res into hl
	;not implemented :)
	ld h,b
	ld l,c
	ret

	ld hl, signon					; print the CP/M banner

prmsg:
	ld a, (hl)
	or a
	ret z
	ld c, a
	call conout
	inc hl
	jp prmsg


; Disk Parameter Block
dpb:
	dw 26 			; SPT:    sectors per track
	db 3 			; BSH:    data allocation block shift factor
	db 7 			; BLM:    Data Allocation Mask
	db 0 			; EXM:    Extent mask
	dw 242 			; DSM:    Disk storage capacity
	dw 63 			; DRM:    no of directory entries
	db 192 			; AL0
	db 0 			; AL1
	dw 16 			; CKS:    size of dir check vector
	dw 2 			; OFF:    no of reserved tracks

; Sector translation table. Not used in this system.
trans:
	db 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
	db 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26

; Scratchpad area for BDOS directory operation.
dirbuf:
	ds 128			; DMA transfer area

; Scratchpad area to check for changed disks
chk:
	ds 16			; 

; Scratchpad area to keep disk storage allocation information
all:
	ds 31			;

end