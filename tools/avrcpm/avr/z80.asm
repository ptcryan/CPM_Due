;    Z80 emulator with CP/M support. The Z80-specific instructions themselves actually aren't
;    implemented yet, making this more of an i8080 emulator.
;    
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


;FUSE_H=0xDF
;FUSE_L=0xF7
.include "m88def.inc"
;device ATmega88

.equ MMC_DEBUG	=	0
.equ INS_DEBUG	=	0
.equ MEMTEST	=	0
.equ BOOTWAIT	=	0
.equ PORT_DEBUG =	0
.equ DISK_DEBUG =	0
.equ MEMFILL_CB =	1
.equ STACK_DBG	=	0
.equ PRINT_PC	=	0

;Port declarations

; Port D
.equ rxd	=	0
.equ txd	=	1
.equ ram_oe	=	2
.equ ram_a8	=	3
.equ mmc_cs	=	4
.equ ram_a5	=	5
.equ ram_a6	=	6
.equ ram_a7	=	7

;Port B
.equ ram_a4	=	0
.equ ram_a3	=	1
.equ ram_a2	=	2
.equ ram_a1	=	3
.equ mmc_mosi=	3
.equ ram_a0	=	4
.equ mmc_miso=	4
.equ ram_ras=	5
.equ mmc_sck=	5

;Port C
.equ ram_d1	=	0
.equ ram_w	=	1
.equ ram_d2	=	2
.equ ram_d4 =	3
.equ ram_d3	=	4
.equ ram_cas=	5


;Flag bits in z_flags
.equ ZFL_S	=	7
.equ ZFL_Z	=	6
.equ ZFL_H	=	4
.equ ZFL_P	=	2
.equ ZFL_N	=	1
.equ ZFL_C	=	0

;Register definitions
.def z_a	=	r2
.def z_b	=	r3
.def z_c	=	r4
.def z_d	=	r5
.def z_e	=	r6
.def z_l	=	r7
.def z_h	=	r8
.def z_spl	=	r9
.def z_sph	=	r10

.def dsk_trk=	r11
.def dsk_sec=	r12
.def dsk_dmah=	r13
.def dsk_dmal=	r14

.def parityb=	r15

.def temp	=	R16 	;The temp register
.def temp2	=	R17 	;Second temp register
.def trace	=	r18
.def opl	=	r19
.def oph	=	r20
.def adrl	=	r21
.def adrh	=	r22
.def insdecl=	r23
.def z_pcl	=	r24
.def z_pch	=	r25
.def insdech=	r26
.def z_flags=	r27


;SRAM
;Sector buffer for 512 byte reads/writes from/to SD-card
.equ sectbuff = 0x200

.org 0
	rjmp start		; reset vector
	nop				; ext int 0
	nop				; ext int 1
	nop				; pcint0
	nop				; pcint1
	nop				; pcint2
	nop				; wdt
	rjmp refrint	; tim2cmpa
	nop				; tim2cmpb
	nop				; tim2ovf

start:
	ldi temp,low(RAMEND)	; top of memory
	out SPL,temp		; init stack pointer
	ldi temp,high(RAMEND)	; top of memory
	out SPH,temp		; init stack pointer

; - Kill wdt
	wdr
	ldi temp,0
	out MCUSR,temp
	ldi temp,0x18
	sts WDTCSR,temp
	ldi temp,0x10
	sts WDTCSR,temp


; - Setup Ports
	ldi temp,$3F
	out DDRB,temp
	ldi temp,$FE
	out DDRD,temp
	ldi temp,$22
	out DDRC,temp

	sbi portc,ram_w
	sbi portc,ram_cas
	sbi portb,ram_ras
	sbi portd,ram_oe
	sbi portd,mmc_cs


; - Init serial port
	ldi temp,$18
	sts ucsr0b,temp
	ldi temp,$6
	sts ucsr0c,temp
	ldi temp,32
	sts ubrr0l,temp
	ldi temp,0
	sts ubrr0h,temp

;Init timer2. Refresh-call should happen every (8ms/512)=312 cycles.
	ldi temp,2
	sts tccr2a,temp
	ldi temp,2 ;clk/8
	sts tccr2b,temp
	ldi temp,39 ;=312 cycles
	sts ocr2a,temp
	ldi temp,2
	sts timsk2,temp
	sei

.if BOOTWAIT
	push temp
	ldi temp,0
bootwait1:
	push temp
	ldi temp,0
bootwait2:
	dec temp
	brne bootwait2
	pop temp
	dec temp
	brne bootwait1

.endif

	rcall printstr
	.db "CPM on an AVR, v1.0",13,0


	rcall printstr
	.db "Initing mmc...",13,0
	rcall mmcInit


.if MEMTEST
	rcall printstr
	.db "Testing RAM...",13,0

;Fill RAM
	ldi adrl,0
	ldi adrh,0
ramtestw:
	mov temp,adrh
	eor temp,adrl
	rcall memwritebyte
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2
	brcc ramtestw

;re-read RAM
	ldi adrl,0
	ldi adrh,0
ramtestr:
	rcall memreadbyte
	mov temp2,adrh
	eor temp2,adrl
	cp temp,temp2
	breq ramtestrok
	rcall printhex
	ldi temp,'<'
	rcall uartPutc
	mov temp,adrh
	eor temp,adrl
	rcall printhex
	ldi temp,'@'
	rcall uartPutc
	mov temp,adrh
	rcall printhex
	mov temp,adrl
	rcall printhex
	ldi temp,13
	rcall uartPutc
ramtestrok:
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2
	brcc ramtestr

.endif

.if MEMFILL_CB
	;Fill ram with cbs, which (for now) will trigger an invalid opcode error.
	ldi adrl,0
	ldi adrh,0
ramfillw:
	ldi temp,0xcb
	rcall memwritebyte
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2
	brcc ramfillw
.endif



;Load initial sector from MMC (512 bytes)
	ldi adrh,0
	ldi adrl,0
	rcall mmcReadSect

;Save to Z80 RAM (only 128 bytes because that's retro)
	ldi zl,low(sectbuff)
	ldi zh,high(sectbuff)
	ldi adrh,0x20
	ldi adrl,0x00
iplwriteloop:
	ld temp,z+
	push zh
	push zl
	rcall memWriteByte
	pop zl
	pop zh
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2
	cpi zl,low(sectbuff+128)
	brne iplwriteloop
	cpi zh,high(sectbuff+128)
	brne iplwriteloop



;Init z80
	ldi temp,0x00
	mov z_pcl,temp
	ldi temp,0x20
	mov z_pch,temp

	ldi trace,0
	rcall printstr
	.db 13,"Ok, CPU is live!",13,0

main:
	ldi trace,0
	cpi z_pch,1
	brlo notraceon
	cpi z_pch,$dc
	brsh notraceon
	ldi trace,1
notraceon:


.if PRINT_PC
	cpi z_pch,1
	brlo noprintpc
	cpi z_pch,0xdc
	brsh noprintpc

	rcall printstr
	.db "PC=",0
	mov temp,z_pch
	rcall printhex
	mov temp,z_pcl
	rcall printhex
	ldi temp,10
	rcall uartputc
noprintpc:
.endif

	; *** Stage 1: Fetch next opcode
	mov adrl,z_pcl
	mov adrh,z_pch
	rcall memReadByte
	adiw z_pcl,1


.if INS_DEBUG
	cpi trace,0
	breq notrace1
	rcall printstr
	.db "PC=",0
	push temp
	mov temp,adrh
	rcall printhex
	mov temp,adrl
	rcall printhex
	pop temp
	rcall printstr
	.db ", opcode=",0
	rcall printhex
notrace1:
.endif

	; *** Stage 2: Decode it using the ins_table.
	ldi temp2,0
	ldi zl,low(inst_table*2)
	ldi zh,high(inst_table*2)
	add zl,temp
	adc zh,temp2
	add zl,temp
	adc zh,temp2
	lpm insdecl,Z+
	lpm insdech,Z

.if INS_DEBUG
	cpi trace,0
	breq notrace2
	rcall printstr
	.db ", decoded=",0
	mov temp,insdech
	rcall printhex
	mov temp,insdecl
	rcall printhex
	rcall printstr
	.db ".",13,0
notrace2:
.endif

	; *** Stage 3: Fetch operand. Use the fetch jumptable for this.
	mov temp,insdecl
	andi temp,0x1F
	cpi temp,0
	breq nofetch
	ldi temp2,0
	lsl temp
	ldi zl,low(fetchjumps*2)
	ldi zh,high(fetchjumps*2)
	add zl,temp
	adc zh,temp2

	lpm temp,Z+
	lpm temp2,Z
	mov zl,temp
	mov zh,temp2
	icall

.if INS_DEBUG
	cpi trace,0
	breq notrace3
	rcall printstr
	.db "pre: oph:l=",0
	mov temp,oph
	rcall printhex
	mov temp,opl
	rcall printhex
	rcall printstr
	.db " -- ",0
notrace3:
.endif

nofetch:
	; *** Stage 4: Execute operation :) Use the op jumptable for this.
	mov temp,insdech
	andi temp,0xFC
	lsr temp
	cpi temp,0
	breq nooper
	ldi zl,low(opjumps*2)
	ldi zh,high(opjumps*2)
	ldi temp2,0
	add zl,temp
	adc zh,temp2
	lpm temp,Z+
	lpm temp2,Z
	mov zl,temp
	mov zh,temp2
	icall

.if INS_DEBUG
	cpi trace,0
	breq notrace4
	rcall printstr
	.db ",post:oph:l=",0
	mov temp,oph
	rcall printhex
	mov temp,opl
	rcall printhex
notrace4:
.endif

nooper:
	; *** Stage 5: Store operand. Use the store jumptable for this.
	swap insdecl
	swap insdech
	mov temp,insdecl
	andi temp,0x0E
	andi insdech,0x30
	or temp,insdech
	cpi temp,0
	breq nostore
	ldi zl,low(storejumps*2)
	ldi zh,high(storejumps*2)
	ldi temp2,0
	add zl,temp
	adc zh,temp2
	lpm temp,Z+
	lpm temp2,Z
	mov zl,temp
	mov zh,temp2
	icall

.if INS_DEBUG
	cpi trace,0
	breq notrace5
	rcall printstr
	.db ", stored.",0
notrace5:
.endif

nostore:

.if INS_DEBUG
	cpi trace,0
	breq notrace6
	rcall printstr
	.db 13,0
notrace6:
.endif

	;All done. Neeeext!
	rjmp main


; ----------------Virtual peripherial interface ------

;The hw is modelled to make writing a CPM BIOS easier.
;Ports:
;0 - Con status. Returns 0xFF if the UART has a byte, 0 otherwise.
;1 - Console input, aka UDR.
;2 - Console output
;16 - Track select
;18 - Sector select
;20 - Write addr l
;21 - Write addr h
;22 - Trigger - write 1 to read, 2 to write a sector using the above info.
;	This will automatically move track, sector and dma addr to the next sector.

;Called with port in temp2. Should return value in temp.
portRead:
	cpi temp2,0
	breq conStatus
	cpi temp2,1
	breq conInp
	ret

;Called with port in temp2 and value in temp.
portWrite:
	cpi temp2,0
	breq dbgOut
	cpi temp2,2
	breq conOut
	cpi temp2,16
	breq dskTrackSel
	cpi temp2,18
	breq dskSecSel
	cpi temp2,20
	breq dskDmaL
	cpi temp2,21
	breq dskDmaH
	cpi temp2,22
	breq dskDoIt
	ret


conStatus:
	lds temp2,UCSR0A
	ldi temp,0
	sbrc temp2,7
	 ldi temp,0xff
	ret

conInp:
	rcall uartGetc
	ret

dbgOut:
	rcall printstr
	.db "Debug: ",0
	rcall printhex
	rcall printstr
	.db 13,0
	ret

conOut:
	rcall uartputc
	ret

dskTrackSel:
	mov dsk_trk,temp
	ret

dskSecSel:
	mov dsk_sec,temp
	ret

dskDmal:
	mov dsk_dmal,temp
	ret

dskDmah:
	mov dsk_dmah,temp
	ret

dskDoIt:
.if DISK_DEBUG
	push temp
	rcall printstr
	.db "Disk read: track ",0
	mov temp,dsk_trk
	rcall printhex
	rcall printstr
	.db " sector ",0
	mov temp,dsk_sec
	rcall printhex
	rcall printstr
	.db " dma-addr ",0
	mov temp,dsk_dmah
	rcall printhex
	mov temp,dsk_dmal
	rcall printhex
	rcall printstr
	.db ".",13,0
	pop temp
.endif

	;First, convert track/sector to an LBA address (in 128byte blocks)
	push temp
	mov adrl,dsk_sec
	ldi adrh,0
	mov temp2,dsk_trk
dskXlateLoop:
	cpi temp2,0
	breq dskXlateLoopEnd
	ldi temp,26
	add adrl,temp
	ldi temp,0
	adc adrh,temp
	dec temp2
	rjmp dskXlateLoop
dskXlateLoopEnd:
	pop temp

	;Now, see what has to be done.
	cpi temp,1
	breq dskDoItRead
	cpi temp,2
	breq dskDoItWrite

dskDoItRead:
	push adrl
	;Convert from 128-byte LBA blocks to 512-byte LBA blocks
	lsr adrh
	ror adrl
	lsr adrh
	ror adrl
	;Read 512-byte sector
	rcall mmcReadSect
	pop adrl

	;Now, move the correct portion of the sector from AVR ram to Z80 ram
	ldi zl,low(sectbuff)
	ldi zh,high(sectbuff)
	ldi temp,128
	ldi temp2,0
	sbrc adrl,0
	 add zl,temp
	sbrc adrl,0
	 adc zh,temp2
	sbrc adrl,1
	 inc zh

	mov adrh,dsk_dmah
	mov adrl,dsk_dmal

	ldi temp2,128
dskDoItReadMemLoop:
	push temp2
	ld temp,z+
	push zh
	push zl
	rcall memWriteByte
	pop zl
	pop zh
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2
	pop temp2
	dec temp2
	brne dskDoItReadMemLoop
	ret

dskDoItWrite:
;The write routines is a bit naive: it'll read the 512-byte sector the 128byte CPM-sector
;resides in into memory, will overwrite the needed 128 byte with the Z80s memory buffer
;and will then write it back to disk. In theory, this would mean that every 512 bytes
;written will take 4 write cycles, while theoretically the writes could be deferred so we
;would only have to do one write cycle.

.if DISK_DEBUG
	push temp
	rcall printstr
	.db "Disk write: track ",0
	mov temp,dsk_trk
	rcall printhex
	rcall printstr
	.db " sector ",0
	mov temp,dsk_sec
	rcall printhex
	rcall printstr
	.db " dma-addr ",0
	mov temp,dsk_dmah
	rcall printhex
	mov temp,dsk_dmal
	rcall printhex
	rcall printstr
	.db ".",13,0
	pop temp
.endif


	push adrl
	push adrh
	;Convert from 128-byte LBA blocks to 512-byte LBA blocks
	lsr adrh
	ror adrl
	lsr adrh
	ror adrl
	;Read 512-byte sector
	rcall mmcReadSect
	pop adrh
	pop adrl

	push adrl
	push adrh

;Copy the data from the Z80 DMA buffer in external memory to the right place in the
;sector buffer.
	;Now, move the correct portion of the sector from AVR ram to Z80 ram
	ldi zl,low(sectbuff)
	ldi zh,high(sectbuff)
	ldi temp,128
	ldi temp2,0
	sbrc adrl,0
	 add zl,temp
	sbrc adrl,0
	 adc zh,temp2
	sbrc adrl,1
	 inc zh
	mov adrh,dsk_dmah
	mov adrl,dsk_dmal
	ldi temp2,128
dskDoItWriteMemLoop:
	push temp2

	push zh
	push zl
	rcall memReadByte
	pop zl
	pop zh
	st z+,temp
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2

	pop temp2
	dec temp2
	brne dskDoItWriteMemLoop

	pop adrh
	pop adrl

	;Convert from 128-byte LBA blocks to 512-byte LBA blocks
	lsr adrh
	ror adrl
	lsr adrh
	ror adrl
	;Write the sector back.
	rcall mmcWriteSect

	;All done :)
	ret

; ----------------- MMC/SD routines ------------------

mmcByteNoSend:
	ldi temp,0xff
mmcByte:

.if MMC_DEBUG
	push zl
	push zh
	rcall printstr
	.db "MMC: <--",0
	rcall printhex
.endif
	
	out SPDR,temp
mmcWrByteW:
	in temp,SPSR
	sbrs temp,7
	 rjmp mmcWrByteW
	in temp,SPDR

.if MMC_DEBUG
	push temp
	rcall printstr
	.db ", -->",0
	rcall printhex
	rcall printstr
	.db ".",13,0
	pop temp
	pop zh
	pop zl
.endif
	ret


;Wait till the mmc answers with the response in temp2, or till a timeout happens.
mmcWaitResp:
	ldi zl,0
	ldi zh,0
mmcWaitResploop:
	rcall mmcByteNoSend
	cpi temp,0xff
	brne mmcWaitResploopEnd
	adiw zl,1
	cpi zh,255
	breq mmcWaitErr
	rjmp mmcWaitResploop
mmcWaitResploopEnd:
	ret


mmcWaitErr:
	mov temp,temp2
	rcall printhex
	rcall printstr
	.db ": Error: MMC resp timeout!",13,0
	rjmp resetAVR

mmcInit:
	ldi temp,0x53
	out SPCR,temp
	
	;Init start: send 80 clocks with cs disabled
	sbi portd,mmc_cs

	ldi temp2,20
mmcInitLoop:
	mov temp,temp2
	rcall mmcByte
	dec temp2
	brne mmcInitLoop

	cbi portd,mmc_cs
	rcall mmcByteNoSend
	rcall mmcByteNoSend
	rcall mmcByteNoSend
	rcall mmcByteNoSend
	rcall mmcByteNoSend
	rcall mmcByteNoSend
	sbi portd,mmc_cs
	rcall mmcByteNoSend
	rcall mmcByteNoSend
	rcall mmcByteNoSend
	rcall mmcByteNoSend

	;Send init command
	cbi portd,mmc_cs
	ldi temp,0xff	;dummy
	rcall mmcByte
	ldi temp,0xff	;dummy
	rcall mmcByte
	ldi temp,0x40	;cmd
	rcall mmcByte
	ldi temp,0	;pxh
	rcall mmcByte
	ldi temp,0	;pxl
	rcall mmcByte
	ldi temp,0	;pyh
	rcall mmcByte
	ldi temp,0	;pyl
	rcall mmcByte
	ldi temp,0x95	;crc
	rcall mmcByte
	ldi temp,0xff	;return byte
	rcall mmcByte

	ldi temp2,0
	rcall mmcWaitResp

	sbi portd,mmc_cs
	rcall mmcByteNoSend


;Read OCR till card is ready
	ldi temp2,150
mmcInitOcrLoop:	
	push temp2

	cbi portd,mmc_cs
	ldi temp,0xff	;dummy
	rcall mmcByte
	ldi temp,0x41	;cmd
	rcall mmcByte
	ldi temp,0	;pxh
	rcall mmcByte
	ldi temp,0	;pxl
	rcall mmcByte
	ldi temp,0	;pyh
	rcall mmcByte
	ldi temp,0	;pyl
	rcall mmcByte
	ldi temp,0x95	;crc
	rcall mmcByte
	rcall mmcByteNoSend

	ldi temp2,1
	rcall mmcWaitResp
	cpi temp,0
	breq mmcInitOcrLoopDone

	sbi portd,mmc_cs
	rcall mmcByteNoSend
	
	pop temp2
	dec temp2
	cpi temp2,0
	brne mmcInitOcrLoop

	ldi temp,4
	rjmp mmcWaitErr

mmcInitOcrLoopDone:
	pop temp2
	sbi portd,mmc_cs
	rcall mmcByteNoSend

	ldi temp,0
	out SPCR,temp
	ret


;Call this with adrh:adrl = sector number
;16bit lba address means a max reach of 32M.
mmcReadSect:
	ldi temp,0x50
	out SPCR,temp

	cbi portd,mmc_cs
	rcall mmcByteNoSend
	ldi temp,0x51	;cmd (read sector)
	rcall mmcByte
	ldi temp,0
	lsl adrl
	rol adrh
	rol temp
	rcall mmcByte
	mov temp,adrh ;pxl
	rcall mmcByte
	mov temp,adrl ;pyh
	rcall mmcByte
	ldi temp,0  ;pyl
	rcall mmcByte
	ldi temp,0x95	;crc
	rcall mmcByte
	ldi temp,0xff	;return byte
	rcall mmcByte

	;resp
	ldi temp2,2
	rcall mmcWaitResp

	;data token
	ldi temp2,3
	rcall mmcWaitResp

	;Read sector to AVR RAM
	ldi zl,low(sectbuff)
	ldi zh,high(sectbuff)
mmcreadloop:
	rcall mmcByteNoSend
	st z+,temp
	cpi zl,low(sectbuff+512)
	brne mmcreadloop
	cpi zh,high(sectbuff+512)
	brne mmcreadloop

	;CRC
	rcall mmcByteNoSend
	rcall mmcByteNoSend

	sbi portd,mmc_cs
	rcall mmcByteNoSend

	ldi temp,0
	out SPCR,temp
	ret


;Call this with adrh:adrl = sector number
;16bit lba address means a max reach of 32M.
mmcWriteSect:
	ldi temp,0x50
	out SPCR,temp

	cbi portd,mmc_cs
	rcall mmcByteNoSend

	ldi temp,0x58	;cmd (write sector)
	rcall mmcByte
	ldi temp,0
	lsl adrl
	rol adrh
	rol temp
	rcall mmcByte
	mov temp,adrh ;pxl
	rcall mmcByte
	mov temp,adrl ;pyh
	rcall mmcByte
	ldi temp,0  ;pyl
	rcall mmcByte
	ldi temp,0x95	;crc
	rcall mmcByte
	ldi temp,0xff	;return byte
	rcall mmcByte

	;resp
	ldi temp2,1
	rcall mmcWaitResp

	;Send data token
	ldi temp,0xfe
	rcall mmcByte

	;Write sector from AVR RAM
	ldi zl,low(sectbuff)
	ldi zh,high(sectbuff)
mmcwriteloop:
	ld temp,z+
	rcall mmcByte
	cpi zl,low(sectbuff+512)
	brne mmcwriteloop
	cpi zh,high(sectbuff+512)
	brne mmcwriteloop

	;CRC
	rcall mmcByteNoSend
	rcall mmcByteNoSend

	;Status. Ignored for now.
	rcall mmcByteNoSend

;Wait till the mmc has written everything
mmcwaitwritten:
	rcall mmcByteNoSend
	cpi temp,0xff
	brne mmcwaitwritten

	sbi portd,mmc_cs
	rcall mmcByteNoSend

	ldi temp,0
	out SPCR,temp
	ret


;Set up wdt to time out after 1 sec.
resetAVR:
	cli
	ldi temp,0x10
	sts WDTCSR,temp
	ldi temp,0x1f
	sts WDTCSR,temp
resetwait:
	rjmp resetwait

; ------------------ DRAM routines -------------

;Sends the address in zh:zl to the ram
dram_setaddr:
	push temp
	in temp,portd
	andi temp,0x17
	out portd,temp
	in temp,portb
	andi temp,0xE0
	out portb,temp
	sbrc zl,0
	 sbi portb,ram_a0
	sbrc zl,1
	 sbi portb,ram_a1
	sbrc zl,2
	 sbi portb,ram_a2
	sbrc zl,3
	 sbi portb,ram_a3
	sbrc zl,4
	 sbi portb,ram_a4
	sbrc zl,5
	 sbi portd,ram_a5
	sbrc zl,6
	 sbi portd,ram_a6
	sbrc zl,7
	 sbi portd,ram_a7
	sbrc zh,0
	 sbi portd,ram_a8
	pop temp
	ret

dram_getnibble:
	andi temp,0xf0
	sbic pinc,ram_d1
	 ori temp,0x1
	sbic pinc,ram_d2
	 ori temp,0x2
	sbic pinc,ram_d3
	 ori temp,0x4
	sbic pinc,ram_d4
	 ori temp,0x8
	ret

dram_sendnibble:
	push temp2
	in temp2,portc
	andi temp2,0xE2

	sbrc temp,0
	 ori temp2,(1<<ram_d1)
	sbrc temp,1
	 ori temp2,(1<<ram_d2)
	sbrc temp,2
	 ori temp2,(1<<ram_d3)
	sbrc temp,3
	 ori temp2,(1<<ram_d4)

	out portc,temp2
	pop temp2
	ret


;Loads the byte on address adrh:adrl into temp.
dram_read:
	cli
	mov zl,adrh
	ldi zh,0
	mov temp2,adrl
	lsl temp2
	rol zl
	rol zh
	;z=addr[15-7]
	rcall dram_setaddr
	cbi portb,ram_ras

	ldi zh,0
	mov zl,adrl
	andi zl,0x7F
	rcall dram_setaddr
	nop
	cbi portc,ram_cas
	nop
	nop
	cbi portd,ram_oe
	nop
	rcall dram_getnibble	
	sbi portd,ram_oe
	swap temp
	sbi portc,ram_cas

	ldi zh,0
	mov zl,adrl
	ori zl,0x80
	rcall dram_setaddr
	nop
	cbi portc,ram_cas
	nop
	cbi portd,ram_oe
	nop
	nop
	rcall dram_getnibble	

	sbi portd,ram_oe
	sbi portc,ram_cas
	sbi portb,ram_ras
	sei
	ret

;Writes the byte in temp to  adrh:adrl
dram_write:
	cli

	in temp2,ddrc
	ori temp2,0x1d
	out ddrc,temp2

	rcall dram_sendnibble

	mov zl,adrh
	ldi zh,0
	mov temp2,adrl
	lsl temp2
	rol zl
	rol zh
	;z=addr[15-7]
	rcall dram_setaddr
	nop
	nop
	cbi portb,ram_ras

	ldi zh,0
	mov zl,adrl
	ori zl,0x80
	rcall dram_setaddr
	nop
	nop
	cbi portc,ram_cas
	nop
	nop
	cbi portc,ram_w
	nop
	nop
	nop
	sbi portc,ram_w
	sbi portc,ram_cas


	ldi zh,0
	mov zl,adrl
	andi zl,0x7F
	rcall dram_setaddr
	swap temp
	rcall dram_sendnibble
	cbi portc,ram_cas
	nop
	nop
	cbi portc,ram_w
	nop
	nop
	sbi portc,ram_w
	nop
	nop
	sbi portc,ram_cas
	sbi portb,ram_ras

	in temp,ddrc
	andi temp,0xE2
	out ddrc,temp
	in temp,portc
	andi temp,0xE2
	out portc,temp
	sei
	ret

refrint:
	nop
	nop
	nop
	cbi portc,ram_cas
	nop
	nop
	nop
	nop
	cbi portb,ram_ras
	nop
	nop
	nop
	nop
	sbi portc,ram_cas
	nop
	nop
	nop
	nop
	sbi portb,ram_ras
	nop
	nop
	nop
	nop
	nop
	reti
	



; --------------- Debugging stuff ---------------

;Prints the lower nibble of temp in hex to the uart
printhexn:
	push temp
	andi temp,0xf
	cpi temp,0xA
	brlo printhexn_isno
	subi temp,-('A'-10)
	rcall uartputc
	pop temp
	ret
printhexn_isno:
	subi temp,-'0'
	rcall uartputc
	pop temp
	ret

;Prints temp in hex to the uart
printhex:
	swap temp
	rcall printhexn
	swap temp
	rcall printhexn
	ret

;Prints the zero-terminated string following the call statement. WARNING: Destroys temp.
printstr:
	pop zh
	pop zl
	push temp

	lsl zl
	rol zh

printstr_loop:
	lpm temp,z+
	cpi temp,0
	breq printstr_end
	rcall uartputc
	cpi temp,13
	brne printstr_loop
	ldi temp,10
	rcall uartputc
	rjmp printstr_loop

printstr_end:
	adiw zl,1
	lsr zh
	ror zl

	pop temp
	push zl
	push zh
	ret
	

; --------------- AVR HW <-> Z80 periph stuff ------------------

.equ memReadByte	=	dram_read
.equ memWriteByte	=	dram_write



;Fetches a char from the uart to temp. If none available, waits till one is.
uartgetc:
	lds temp,ucsr0a
	sbrs temp,7
	 rjmp uartgetc
	lds temp,udr0
	ret

;Sends a char from temp to the uart. 
uartputc:
	push temp
uartputc_l:
	lds temp,ucsr0a
	sbrs temp,5
	 rjmp uartputc_l
	pop temp
	sts udr0,temp
	ret

; ------------ Fetch phase stuff -----------------

.equ FETCH_NOP	= (0<<0)
.equ FETCH_A	= (1<<0)
.equ FETCH_B	= (2<<0)
.equ FETCH_C	= (3<<0)
.equ FETCH_D	= (4<<0)
.equ FETCH_E	= (5<<0)
.equ FETCH_H	= (6<<0)
.equ FETCH_L	= (7<<0)
.equ FETCH_AF	= (8<<0)
.equ FETCH_BC	= (9<<0)
.equ FETCH_DE	= (10<<0)
.equ FETCH_HL	= (11<<0)
.equ FETCH_SP	= (12<<0)
.equ FETCH_MBC	= (13<<0)
.equ FETCH_MDE	= (14<<0)
.equ FETCH_MHL	= (15<<0)
.equ FETCH_MSP	= (16<<0)
.equ FETCH_DIR8	= (17<<0)
.equ FETCH_DIR16= (18<<0)
.equ FETCH_RST	= (19<<0)


;Jump table for fetch routines. Make sure to keep this in sync with the .equs!
fetchjumps:
.dw do_fetch_nop
.dw do_fetch_a
.dw do_fetch_b
.dw do_fetch_c
.dw do_fetch_d
.dw do_fetch_e
.dw do_fetch_h
.dw do_fetch_l
.dw do_fetch_af
.dw do_fetch_bc
.dw do_fetch_de
.dw do_fetch_hl
.dw do_fetch_sp
.dw do_fetch_mbc
.dw do_fetch_mde
.dw do_fetch_mhl
.dw do_fetch_msp
.dw do_fetch_dir8
.dw do_fetch_dir16
.dw do_fetch_rst

do_fetch_nop:
	ret

do_fetch_a:
	mov opl,z_a
	ret

do_fetch_b:
	mov opl,z_b
	ret

do_fetch_c:
	mov opl,z_c
	ret

do_fetch_d:
	mov opl,z_d
	ret

do_fetch_e:
	mov opl,z_e
	ret

do_fetch_h:
	mov opl,z_h
	ret

do_fetch_l:
	mov opl,z_l
	ret

do_fetch_af:
	mov opl,z_flags
	mov oph,z_a
	rcall do_op_calcparity
	andi opl,~(1<<ZFL_P)
	sbrs temp2,0
	 ori opl,(1<<ZFL_P)
	ret

do_fetch_bc:
	mov opl,z_c
	mov oph,z_b
	ret

do_fetch_de:
	mov opl,z_e
	mov oph,z_d
	ret

do_fetch_hl:
	mov opl,z_l
	mov oph,z_h
	ret

do_fetch_sp:
	mov opl,z_spl
	mov oph,z_sph
	ret

do_fetch_mbc:
	mov adrh,z_b
	mov adrl,z_c
	rcall memReadByte
	mov opl,temp
	ret

do_fetch_mde:
	mov adrh,z_d
	mov adrl,z_e
	rcall memReadByte
	mov opl,temp
	ret

do_fetch_mhl:
	mov adrh,z_h
	mov adrl,z_l
	rcall memReadByte
	mov opl,temp
	ret

do_fetch_msp:
	mov adrh,z_sph
	mov adrl,z_spl
	rcall memReadByte
	mov opl,temp

	mov adrh,z_sph
	mov adrl,z_spl
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2
	rcall memReadByte
	mov oph,temp
	ret

do_fetch_dir8:
	mov adrl,z_pcl
	mov adrh,z_pch
	rcall memReadByte
	adiw z_pcl,1
	mov opl,temp
	ret

do_fetch_dir16:
	mov adrl,z_pcl
	mov adrh,z_pch
	rcall memReadByte
	mov opl,temp
	adiw z_pcl,1
	mov adrl,z_pcl
	mov adrh,z_pch
	rcall memReadByte
	adiw z_pcl,1
	mov oph,temp
	ret

do_fetch_rst:
	mov adrl,z_pcl
	mov adrh,z_pch
	rcall memReadByte
	andi temp,0x38
	ldi oph,0
	mov opl,temp
	ret
	


; ------------ Store phase stuff -----------------

.equ STORE_NOP	= (0<<5)
.equ STORE_A	= (1<<5)
.equ STORE_B	= (2<<5)
.equ STORE_C	= (3<<5)
.equ STORE_D	= (4<<5)
.equ STORE_E	= (5<<5)
.equ STORE_H	= (6<<5)
.equ STORE_L	= (7<<5)
.equ STORE_AF	= (8<<5)
.equ STORE_BC	= (9<<5)
.equ STORE_DE	= (10<<5)
.equ STORE_HL	= (11<<5)
.equ STORE_SP	= (12<<5)
.equ STORE_PC	= (13<<5)
.equ STORE_MBC	= (14<<5)
.equ STORE_MDE	= (15<<5)
.equ STORE_MHL	= (16<<5)
.equ STORE_MSP	= (17<<5)
.equ STORE_RET	= (18<<5)
.equ STORE_CALL	= (19<<5)
.equ STORE_AM	= (20<<5)

;Jump table for store routines. Make sure to keep this in sync with the .equs!
storejumps:
.dw do_store_nop
.dw do_store_a
.dw do_store_b
.dw do_store_c
.dw do_store_d
.dw do_store_e
.dw do_store_h
.dw do_store_l
.dw do_store_af
.dw do_store_bc
.dw do_store_de
.dw do_store_hl
.dw do_store_sp
.dw do_store_pc
.dw do_store_mbc
.dw do_store_mde
.dw do_store_mhl
.dw do_store_msp
.dw do_store_ret
.dw do_store_call
.dw do_store_am


do_store_nop:
	ret

do_store_a:
	mov z_a,opl
	ret

do_store_b:
	mov z_b,opl
	ret

do_store_c:
	mov z_c,opl
	ret

do_store_d:
	mov z_d,opl
	ret

do_store_e:
	mov z_e,opl
	ret

do_store_h:
	mov z_h,opl
	ret

do_store_l:
	mov z_l,opl
	ret

do_store_af:
	mov z_a,oph
	mov z_flags,opl
	ldi temp,0
	mov parityb,temp
	sbrs z_flags,ZFL_P
	 inc parityb
	ret

do_store_bc:
	mov z_b,oph
	mov z_c,opl
	ret

do_store_de:
	mov z_d,oph
	mov z_e,opl
	ret

do_store_hl:
	mov z_h,oph
	mov z_l,opl
	ret

do_store_mbc:
	mov adrh,z_b
	mov adrl,z_c
	mov temp,opl
	rcall memWriteByte
	ret

do_store_mde:
	mov adrh,z_d
	mov adrl,z_e
	mov temp,opl
	rcall memWriteByte
	ret

do_store_mhl:
	mov adrh,z_h
	mov adrl,z_l
	mov temp,opl
	rcall memWriteByte
	ret

do_store_msp:
	mov adrh,z_sph
	mov adrl,z_spl
	mov temp,opl
	rcall memWriteByte

	mov adrh,z_sph
	mov adrl,z_spl
	ldi temp,1
	ldi temp2,0
	add adrl,temp
	adc adrh,temp2
	mov temp,oph
	rcall memWriteByte

	ret

do_store_sp:
	mov z_sph,oph
	mov z_spl,opl
	ret

do_store_pc:
	mov z_pch,oph
	mov z_pcl,opl
	ret

do_store_ret:
	rcall do_op_pop16
	mov z_pcl,opl
	mov z_pch,oph
	ret

do_store_call:
	push opl
	push oph
	mov opl,z_pcl
	mov oph,z_pch
	rcall do_op_push16
	pop z_pch
	pop z_pcl
	ret

do_store_am:
	mov adrh,oph
	mov adrl,opl
	mov temp,z_a
	rcall memWriteByte
	ret


; ------------ Operation phase stuff -----------------


.equ OP_NOP		= (0<<10)
.equ OP_INC		= (1<<10)
.equ OP_DEC		= (2<<10)
.equ OP_INC16	= (3<<10)
.equ OP_DEC16	= (4<<10)
.equ OP_RLC 	= (5<<10)
.equ OP_RRC 	= (6<<10)
.equ OP_RR	 	= (7<<10)
.equ OP_RL		= (8<<10)
.equ OP_ADDA	= (9<<10)
.equ OP_ADCA	= (10<<10)
.equ OP_SUBFA	= (11<<10)
.equ OP_SBCFA	= (12<<10)
.equ OP_ANDA	= (13<<10)
.equ OP_ORA		= (14<<10)
.equ OP_XORA	= (15<<10)
.equ OP_ADDHL	= (16<<10)
.equ OP_STHL	= (17<<10) ;store HL in fetched address
.equ OP_RMEM16	= (18<<10) ;read mem at fetched address
.equ OP_RMEM8	= (19<<10) ;read mem at fetched address
.equ OP_DA		= (20<<10)
.equ OP_SCF		= (21<<10)
.equ OP_CPL		= (22<<10)
.equ OP_CCF		= (23<<10)
.equ OP_POP16	= (24<<10)
.equ OP_PUSH16	= (25<<10)
.equ OP_IFNZ	= (26<<10)
.equ OP_IFZ		= (27<<10)
.equ OP_IFNC	= (28<<10)
.equ OP_IFC		= (29<<10)
.equ OP_IFPO	= (30<<10)
.equ OP_IFPE	= (31<<10)
.equ OP_IFP		= (32<<10)
.equ OP_IFM		= (33<<10)
.equ OP_OUTA	= (34<<10)
.equ OP_IN		= (35<<10)
.equ OP_EXHL	= (36<<10)
.equ OP_DI		= (37<<10)
.equ OP_EI		= (38<<10)
.equ OP_INV		= (39<<10)

opjumps:
.dw do_op_nop
.dw do_op_inc
.dw do_op_dec
.dw do_op_inc16
.dw do_op_dec16
.dw do_op_rlc
.dw do_op_rrc
.dw do_op_rr
.dw do_op_rl
.dw do_op_adda
.dw do_op_adca
.dw do_op_subfa
.dw do_op_sbcfa
.dw do_op_anda
.dw do_op_ora
.dw do_op_xora
.dw do_op_addhl
.dw do_op_sthl
.dw do_op_rmem16
.dw do_op_rmem8
.dw do_op_da
.dw do_op_scf
.dw do_op_cpl
.dw do_op_ccf
.dw do_op_pop16
.dw do_op_push16
.dw do_op_ifnz
.dw do_op_ifz
.dw do_op_ifnc
.dw do_op_ifc
.dw do_op_ifpo
.dw do_op_ifpe
.dw do_op_ifp
.dw do_op_ifm
.dw do_op_outa
.dw do_op_in
.dw do_op_exhl
.dw do_op_di
.dw do_op_ei
.dw do_op_inv


;How the flags are supposed to work:
;7 ZFL_S - Sign flag (=MSBit of result)
;6 ZFL_Z - Zero flag. Is 1 when the result is 0
;4 ZFL_H - Half-carry (carry from bit 3 to 4)
;2 ZFL_P - Parity/2-complement Overflow
;1 ZFL_N - Subtract - set if last op was a subtract
;0 ZFL_C - Carry
;
;I sure hope I got the mapping between flags and instructions correct...


;ToDo: Parity at more instructions...

.equ AVR_H = 5
.equ AVR_S = 4
.equ AVR_V = 3
.equ AVR_N = 2
.equ AVR_Z = 1
.equ AVR_C = 0

do_op_nop:
	ret

do_op_inc:
	andi z_flags,1
	ldi temp,1
	add opl,temp
	in temp,sreg
	mov parityb,opl
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	sbrc opl,7
	 ori z_flags,(1<<ZFL_S)
	bst temp,AVR_H
	bld z_flags,ZFL_H
	ret

do_op_dec:
	andi z_flags,1
	ori z_flags,(1<<ZFL_N)
	ldi temp,1
	sub opl,temp
	in temp,sreg
	mov parityb,opl
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	bst temp,AVR_S
	bld z_flags,ZFL_S
	bst temp,AVR_H
	bld z_flags,ZFL_H
	ret

do_op_inc16:
	ldi temp,1
	ldi temp2,0
	add opl,temp
	adc oph,temp2
	ret

do_op_dec16:
	ldi temp,1
	ldi temp2,0
	sub opl,temp
	sbc oph,temp2
	ret

do_op_rlc:
	;Rotate Left Cyclical. All bits move 1 to the 
	;left, the msb becomes c and lsb.
	andi z_flags,0b11101100
	lsl opl
	brcc do_op_rlc_noc
	ori opl,1
	ori z_flags,(1<<ZFL_C)
do_op_rlc_noc:
	ret

do_op_rrc: 
	;Rotate Right Cyclical. All bits move 1 to the 
	;right, the lsb becomes c and msb.
	andi z_flags,0b11101100
	lsr opl
	brcc do_op_rrc_noc
	ori opl,0x80
	ori z_flags,(1<<ZFL_C)
do_op_rrc_noc:
	ret

do_op_rr: 
	;Rotate Right. All bits move 1 to the right, the lsb 
	;becomes c, c becomes msb.
	clc
	sbrc z_flags,ZFL_C
	 sec
	ror opl
	in temp,sreg
	andi z_flags,0b11101100
	bst temp,AVR_C
	bld z_flags,ZFL_C
	ret

do_op_rl:
	;Rotate Left. All bits move 1 to the left, the msb 
	;becomes c, c becomes lsb.
	clc
	sbrc z_flags,ZFL_C
	 sec
	rol opl
	in temp,sreg
	andi z_flags,0b11101100
	bst temp,AVR_C
	bld z_flags,ZFL_C
	ret

do_op_adda:
	ldi z_flags,0
	add opl,z_a
	in temp,sreg
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	bst temp,AVR_S
	cpi opl,$80
	brne adda_no_s
	ori z_flags,(1<<ZFL_S)
adda_no_s:
	bst temp,AVR_H
	bld z_flags,ZFL_H
	bst temp,AVR_V
	bld z_flags,ZFL_P
	bst temp,AVR_C
	bld z_flags,ZFL_C
	ret

do_op_adca:
	clc
	sbrc z_flags,ZFL_C
	 sec
	adc opl,z_a
	in temp,sreg
	ldi z_flags,0
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	sbrc opl,7
	 ori z_flags,(1<<ZFL_S)
	bst temp,AVR_H
	bld z_flags,ZFL_H
	bst temp,AVR_V
	bld z_flags,ZFL_P
	bst temp,AVR_C
	bld z_flags,ZFL_C
	andi z_flags,~(1<<ZFL_N)
	ret

do_op_subfa:
	mov temp,z_a
	sub temp,opl
	mov opl,temp
	in temp,sreg
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	bst temp,AVR_S
	bld z_flags,ZFL_S
	bst temp,AVR_H
	bld z_flags,ZFL_H
	bst temp,AVR_V
	bld z_flags,ZFL_P
	bst temp,AVR_C
	bld z_flags,ZFL_C
	ori z_flags,(1<<ZFL_N)
	ret

do_op_sbcfa:
	mov temp,z_a
	clc
	sbrc z_flags,ZFL_C
	 sec
	sbc temp,opl
	mov opl,temp
	in temp,sreg
	bst temp,AVR_S
	bld z_flags,ZFL_S
	bst temp,AVR_H
	bld z_flags,ZFL_H
	bst temp,AVR_V
	bld z_flags,ZFL_P
	bst temp,AVR_C
	bld z_flags,ZFL_C
	cpi opl,0	;AVR doesn't set Z?
	in temp,sreg
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	ori z_flags,(1<<ZFL_N)
	ret

do_op_anda:
	ldi z_flags,0
	and opl,z_a
	in temp,sreg
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	bst temp,AVR_S
	bld z_flags,ZFL_S
	bst temp,AVR_H
	bld z_flags,ZFL_H
	mov temp,opl
	ret

do_op_ora:
	ldi z_flags,0
	or opl,z_a
	in temp,sreg
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	bst temp,AVR_S
	bld z_flags,ZFL_S
	bst temp,AVR_H
	bld z_flags,ZFL_H
	mov temp,opl
	ret

do_op_xora:
	ldi z_flags,0
	eor opl,z_a
	in temp,sreg
	bst temp,AVR_Z
	bld z_flags,ZFL_Z
	bst temp,AVR_S
	bld z_flags,ZFL_S
	bst temp,AVR_H
	bld z_flags,ZFL_H
	mov temp,opl
	ret

do_op_addhl:
	add opl,z_l
	adc oph,z_h
	in temp,sreg
	bst temp,AVR_C
	bld z_flags,ZFL_C
	andi z_flags,~(1<<ZFL_N)
	ret

do_op_sthl: ;store hl to mem loc in opl
	;ToDo: check flags
	mov adrl,opl
	mov adrh,oph
	mov temp,z_l
	rcall memWriteByte

	ldi temp,1
	ldi temp2,0
	add opl,temp
	adc oph,temp2

	mov adrl,opl
	mov adrh,oph
	mov temp,z_h
	rcall memWriteByte

	ret

do_op_rmem16:
	mov adrl,opl
	mov adrh,oph
	rcall memReadByte
	mov opl,temp
	ldi temp,1
	add adrl,temp
	ldi temp,0
	adc adrh,temp
	rcall memReadByte
	mov oph,temp
	ret

do_op_rmem8:
	mov adrl,opl
	mov adrh,oph
	rcall memReadByte
	mov opl,temp
	ret

do_op_da:
	;DAA -> todo
	rcall do_op_inv
	mov temp,opl
	ret


do_op_scf:
	ori z_flags,(1<<ZFL_C)
	ret

do_op_ccf:
	ldi temp,(1<<ZFL_C)
	eor z_flags,temp
	ret

do_op_cpl:
	com opl
	ori z_flags,(1<<ZFL_N)|(1<<ZFL_H)
	ret

do_op_push16:
	ldi temp,1
	ldi temp2,0
	sub z_spl,temp
	sbc z_sph,temp2

	mov adrl,z_spl
	mov adrh,z_sph
	mov temp,oph
	rcall memWriteByte

	ldi temp,1
	ldi temp2,0
	sub z_spl,temp
	sbc z_sph,temp2

	mov adrl,z_spl
	mov adrh,z_sph
	mov temp,opl
	rcall memWriteByte

.if STACK_DBG
	rcall printstr
	.db "Stack push ",0
	mov temp,oph
	rcall printhex
	mov temp,opl
	rcall printhex
	rcall printstr
	.db ", SP is now ",0
	mov temp,z_sph
	rcall printhex
	mov temp,z_spl
	rcall printhex
	rcall printstr
	.db ".",13,0
.endif

	ret

do_op_pop16:
	mov adrl,z_spl
	mov adrh,z_sph
	rcall memReadByte
	mov opl,temp

	ldi temp,1
	ldi temp2,0
	add z_spl,temp
	adc z_sph,temp2

	mov adrl,z_spl
	mov adrh,z_sph
	rcall memReadByte
	mov oph,temp

	ldi temp,1
	ldi temp2,0
	add z_spl,temp
	adc z_sph,temp2

.if STACK_DBG
	rcall printstr
	.db "Stack pop: val ",0
	mov temp,oph
	rcall printhex
	mov temp,opl
	rcall printhex
	rcall printstr
	.db ", SP is now",0
	mov temp,z_sph
	rcall printhex
	mov temp,z_spl
	rcall printhex
	rcall printstr
	.db ".",13,0
.endif
	ret

do_op_exhl:
	mov temp,z_h
	mov z_h,oph
	mov oph,temp
	mov temp,z_l
	mov z_l,opl
	mov opl,temp
	ret

do_op_di:
	ret

do_op_ei:
	ret

do_op_ifnz:
	sbrs z_flags,ZFL_Z
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

do_op_ifz:
	sbrc z_flags,ZFL_Z
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

do_op_ifnc:
	sbrs z_flags,ZFL_C
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

do_op_ifc:
	sbrc z_flags,ZFL_C
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

do_op_ifpo:
	rcall do_op_calcparity
	sbrs temp2,0
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

do_op_ifpe:
	rcall do_op_calcparity	
	sbrc temp2,0
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

do_op_ifp: ;sign positive, aka s=0
	sbrs z_flags,ZFL_S
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

do_op_ifm: ;sign negative, aka s=1
	sbrc z_flags,ZFL_S
	 ret
	ldi insdech,0
	ldi insdecl,0
	ret

;Interface with peripherials goes here :)
do_op_outa: ; out (opl),a
.if PORT_DEBUG
	rcall printstr
	.db 13,"Port write: ",0
	mov temp,z_a
	rcall printhex
	rcall printstr
	.db " -> (",0
	mov temp,opl
	rcall printhex
	rcall printstr
	.db ")",13,0
.endif
	mov temp,z_a
	mov temp2,opl
	rcall portWrite
	ret

do_op_in:	; in a,(opl)
.if PORT_DEBUG
	rcall printstr
	.db 13,"Port read: (",0
	mov temp,opl
	rcall printhex
	rcall printstr
	.db ") -> ",0
.endif

	mov temp2,opl
	rcall portRead
	mov opl,temp

.if PORT_DEBUG
	rcall printhex
	rcall printstr
	.db 13,0
.endif
	ret

do_op_calcparity:
	ldi temp2,1
	sbrc parityb,0
	 inc temp2
	sbrc parityb,1
	 inc temp2
	sbrc parityb,2
	 inc temp2
	sbrc parityb,3
	 inc temp2
	sbrc parityb,4
	 inc temp2
	sbrc parityb,5
	 inc temp2
	sbrc parityb,6
	 inc temp2
	sbrc parityb,7
	 inc temp2
	andi temp2,1
	ret

do_op_inv:
	rcall printstr
	.db "Invalid opcode @ PC=",0
	mov temp,z_pch
	rcall printhex
	mov temp,z_pcl
	rcall printhex
haltinv:
	rjmp haltinv
	 

; ----------------------- Opcode decoding -------------------------

; Lookup table for Z80 opcodes. Translates the first byte of the instruction word into three
; operations: fetch, do something, store.
; The table is made of 256 words. These 16-bit words consist of 
; the fetch operation (bit 0-4), the processing operation (bit 10-16) and the store 
; operation (bit 5-9).

inst_table:
.dw (FETCH_NOP	| OP_NOP	| STORE_NOP)	 ; 00		NOP
.dw (FETCH_DIR16| OP_NOP	| STORE_BC )	 ; 01 nn nn	LD BC,nn
.dw (FETCH_A	| OP_NOP	| STORE_MBC  )	 ; 02		LD (BC),A
.dw (FETCH_BC	| OP_INC16	| STORE_BC )	 ; 03		INC BC
.dw (FETCH_B	| OP_INC	| STORE_B  )	 ; 04		INC B
.dw (FETCH_B	| OP_DEC	| STORE_B  )	 ; 05		DEC B
.dw (FETCH_DIR8	| OP_NOP	| STORE_B  )	 ; 06 nn	LD B,n
.dw (FETCH_A	| OP_RLC	| STORE_A  )	 ; 07		RLCA
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; 08		EX AF,AF'	(Z80)
.dw (FETCH_BC	| OP_ADDHL	| STORE_HL )	 ; 09		ADD HL,BC
.dw (FETCH_MBC	| OP_NOP	| STORE_A  )	 ; 0A		LD A,(BC)
.dw (FETCH_BC	| OP_DEC16	| STORE_BC )	 ; 0B		DEC BC
.dw (FETCH_C	| OP_INC	| STORE_C  )	 ; 0C		INC C
.dw (FETCH_C	| OP_DEC	| STORE_C  )	 ; 0D		DEC C
.dw (FETCH_DIR8	| OP_NOP	| STORE_C  )	 ; 0E nn	LD C,n
.dw (FETCH_A	| OP_RRC	| STORE_A  )	 ; 0F		RRCA
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; 10 oo	DJNZ o		(Z80)
.dw (FETCH_DIR16| OP_NOP	| STORE_DE )	 ; 11 nn nn	LD DE,nn
.dw (FETCH_A	| OP_NOP	| STORE_MDE)	 ; 12		LD (DE),A
.dw (FETCH_DE	| OP_INC16  | STORE_DE )	 ; 13		INC DE
.dw (FETCH_D	| OP_INC	| STORE_D  )	 ; 14		INC D
.dw (FETCH_D	| OP_DEC	| STORE_D  )	 ; 15		DEC D
.dw (FETCH_DIR8	| OP_NOP	| STORE_D  )	 ; 16 nn	LD D,n
.dw (FETCH_A	| OP_RL		| STORE_A  )	 ; 17		RLA
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; 18 oo	JR o		(Z80)
.dw (FETCH_DE	| OP_ADDHL	| STORE_HL )	 ; 19		ADD HL,DE
.dw (FETCH_MDE	| OP_NOP	| STORE_A  )	 ; 1A		LD A,(DE)
.dw (FETCH_DE	| OP_DEC16	| STORE_DE )	 ; 1B		DEC DE
.dw (FETCH_E	| OP_INC	| STORE_E  )	 ; 1C		INC E
.dw (FETCH_E	| OP_DEC	| STORE_E  )	 ; 1D		DEC E
.dw (FETCH_DIR8	| OP_NOP	| STORE_E  )	 ; 1E nn	LD E,n
.dw (FETCH_A	| OP_RR		| STORE_A  )	 ; 1F		RRA
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; 20 oo	JR NZ,o		(Z80)
.dw (FETCH_DIR16| OP_NOP	| STORE_HL )	 ; 21 nn nn	LD HL,nn
.dw (FETCH_DIR16| OP_STHL	| STORE_NOP)	 ; 22 nn nn	LD (nn),HL
.dw (FETCH_HL	| OP_INC16	| STORE_HL )	 ; 23		INC HL
.dw (FETCH_H	| OP_INC	| STORE_H  )	 ; 24		INC H
.dw (FETCH_H	| OP_DEC	| STORE_H  )	 ; 25		DEC H
.dw (FETCH_DIR8	| OP_NOP	| STORE_H  )	 ; 26 nn	LD H,n
.dw (FETCH_A	| OP_DA		| STORE_A  )	 ; 27		DAA
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; 28 oo	JR Z,o		(Z80)
.dw (FETCH_HL	| OP_ADDHL	| STORE_HL )	 ; 29		ADD HL,HL
.dw (FETCH_DIR16| OP_RMEM16	| STORE_HL )	 ; 2A nn nn	LD HL,(nn)
.dw (FETCH_HL	| OP_DEC16	| STORE_HL )	 ; 2B		DEC HL
.dw (FETCH_L	| OP_INC	| STORE_L  )	 ; 2C		INC L
.dw (FETCH_L	| OP_DEC	| STORE_L  )	 ; 2D		DEC L
.dw (FETCH_DIR8	| OP_NOP	| STORE_L  )	 ; 2E nn	LD L,n
.dw (FETCH_A	| OP_CPL	| STORE_A  )	 ; 2F		CPL
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; 30 oo	JR NC,o		(Z80)
.dw (FETCH_DIR16| OP_NOP	| STORE_SP )	 ; 31 nn nn	LD SP,nn
.dw (FETCH_DIR16| OP_NOP	| STORE_AM )	 ; 32 nn nn	LD (nn),A
.dw (FETCH_SP	| OP_INC16	| STORE_SP )	 ; 33		INC SP
.dw (FETCH_MHL	| OP_INC	| STORE_MHL)	 ; 34		INC (HL)
.dw (FETCH_MHL	| OP_DEC	| STORE_MHL)	 ; 35		DEC (HL)
.dw (FETCH_DIR8	| OP_NOP	| STORE_MHL)	 ; 36 nn	LD (HL),n
.dw (FETCH_NOP	| OP_SCF	| STORE_NOP)	 ; 37		SCF
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; 38 oo	JR C,o		(Z80)
.dw (FETCH_SP	| OP_ADDHL	| STORE_HL )	 ; 39		ADD HL,SP
.dw (FETCH_DIR16| OP_RMEM8	| STORE_A  )	 ; 3A nn nn	LD A,(nn)
.dw (FETCH_SP	| OP_DEC16	| STORE_SP )	 ; 3B		DEC SP
.dw (FETCH_A	| OP_INC	| STORE_A  )	 ; 3C		INC A
.dw (FETCH_A	| OP_DEC	| STORE_A  )	 ; 3D		DEC A
.dw (FETCH_DIR8	| OP_NOP	| STORE_A  )	 ; 3E nn	LD A,n
.dw (FETCH_NOP	| OP_CCF	| STORE_NOP)	 ; 3F		CCF (Complement Carry Flag, gvd)
.dw (FETCH_B	| OP_NOP	| STORE_B  )	 ; 40		LD B,r
.dw (FETCH_C	| OP_NOP	| STORE_B  )	 ; 41		LD B,r
.dw (FETCH_D	| OP_NOP	| STORE_B  )	 ; 42		LD B,r
.dw (FETCH_E	| OP_NOP	| STORE_B  )	 ; 43		LD B,r
.dw (FETCH_H	| OP_NOP	| STORE_B  )	 ; 44		LD B,r
.dw (FETCH_L	| OP_NOP	| STORE_B  )	 ; 45		LD B,r
.dw (FETCH_MHL	| OP_NOP	| STORE_B  )	 ; 46		LD B,r
.dw (FETCH_A	| OP_NOP	| STORE_B  )	 ; 47		LD B,r
.dw (FETCH_B	| OP_NOP	| STORE_C  )	 ; 48		LD C,r
.dw (FETCH_C	| OP_NOP	| STORE_C  )	 ; 49		LD C,r
.dw (FETCH_D	| OP_NOP	| STORE_C  )	 ; 4A		LD C,r
.dw (FETCH_E	| OP_NOP	| STORE_C  )	 ; 4B		LD C,r
.dw (FETCH_H	| OP_NOP	| STORE_C  )	 ; 4C		LD C,r
.dw (FETCH_L	| OP_NOP	| STORE_C  )	 ; 4D		LD C,r
.dw (FETCH_MHL	| OP_NOP	| STORE_C  )	 ; 4E		LD C,r
.dw (FETCH_A	| OP_NOP	| STORE_C  )	 ; 4F		LD C,r
.dw (FETCH_B	| OP_NOP	| STORE_D  )	 ; 50		LD D,r
.dw (FETCH_C	| OP_NOP	| STORE_D  )	 ; 51		LD D,r
.dw (FETCH_D	| OP_NOP	| STORE_D  )	 ; 52		LD D,r
.dw (FETCH_E	| OP_NOP	| STORE_D  )	 ; 53		LD D,r
.dw (FETCH_H	| OP_NOP	| STORE_D  )	 ; 54		LD D,r
.dw (FETCH_L	| OP_NOP	| STORE_D  )	 ; 55		LD D,r
.dw (FETCH_MHL	| OP_NOP	| STORE_D  )	 ; 56		LD D,r
.dw (FETCH_A	| OP_NOP	| STORE_D  )	 ; 57		LD D,r
.dw (FETCH_B	| OP_NOP	| STORE_E  )	 ; 58		LD E,r
.dw (FETCH_C	| OP_NOP	| STORE_E  )	 ; 59		LD E,r
.dw (FETCH_D	| OP_NOP	| STORE_E  )	 ; 5A		LD E,r
.dw (FETCH_E	| OP_NOP	| STORE_E  )	 ; 5B		LD E,r
.dw (FETCH_H	| OP_NOP	| STORE_E  )	 ; 5C		LD E,r
.dw (FETCH_L	| OP_NOP	| STORE_E  )	 ; 5D		LD E,r
.dw (FETCH_MHL	| OP_NOP	| STORE_E  )	 ; 5E		LD E,r
.dw (FETCH_A	| OP_NOP	| STORE_E  )	 ; 5F		LD E,r
.dw (FETCH_B	| OP_NOP	| STORE_H  )	 ; 60		LD H,r
.dw (FETCH_C	| OP_NOP	| STORE_H  )	 ; 61		LD H,r
.dw (FETCH_D	| OP_NOP	| STORE_H  )	 ; 62		LD H,r
.dw (FETCH_E	| OP_NOP	| STORE_H  )	 ; 63		LD H,r
.dw (FETCH_H	| OP_NOP	| STORE_H  )	 ; 64		LD H,r
.dw (FETCH_L	| OP_NOP	| STORE_H  )	 ; 65		LD H,r
.dw (FETCH_MHL	| OP_NOP	| STORE_H  )	 ; 66		LD H,r
.dw (FETCH_A	| OP_NOP	| STORE_H  )	 ; 67		LD H,r
.dw (FETCH_B	| OP_NOP	| STORE_L  )	 ; 68		LD L,r
.dw (FETCH_C	| OP_NOP	| STORE_L  )	 ; 69		LD L,r
.dw (FETCH_D	| OP_NOP	| STORE_L  )	 ; 6A		LD L,r
.dw (FETCH_E	| OP_NOP	| STORE_L  )	 ; 6B		LD L,r
.dw (FETCH_H	| OP_NOP	| STORE_L  )	 ; 6C		LD L,r
.dw (FETCH_L	| OP_NOP	| STORE_L  )	 ; 6D		LD L,r
.dw (FETCH_MHL	| OP_NOP	| STORE_L  )	 ; 6E		LD L,r
.dw (FETCH_A	| OP_NOP	| STORE_L  )	 ; 6F		LD L,r
.dw (FETCH_B	| OP_NOP	| STORE_MHL)	 ; 70		LD (HL),r
.dw (FETCH_C	| OP_NOP	| STORE_MHL)	 ; 71		LD (HL),r
.dw (FETCH_D	| OP_NOP	| STORE_MHL)	 ; 72		LD (HL),r
.dw (FETCH_E	| OP_NOP	| STORE_MHL)	 ; 73		LD (HL),r
.dw (FETCH_H	| OP_NOP	| STORE_MHL)	 ; 74		LD (HL),r
.dw (FETCH_L	| OP_NOP	| STORE_MHL)	 ; 75		LD (HL),r
.dw (FETCH_NOP	| OP_NOP	| STORE_NOP)	 ; 76		HALT
.dw (FETCH_A	| OP_NOP	| STORE_MHL)	 ; 77		LD (HL),r
.dw (FETCH_B	| OP_NOP	| STORE_A  )	 ; 78		LD A,r
.dw (FETCH_C	| OP_NOP	| STORE_A  )	 ; 79		LD A,r
.dw (FETCH_D	| OP_NOP	| STORE_A  )	 ; 7A		LD A,r
.dw (FETCH_E	| OP_NOP	| STORE_A  )	 ; 7B		LD A,r
.dw (FETCH_H	| OP_NOP	| STORE_A  )	 ; 7C		LD A,r
.dw (FETCH_L	| OP_NOP	| STORE_A  )	 ; 7D		LD A,r
.dw (FETCH_MHL	| OP_NOP	| STORE_A  )	 ; 7E		LD A,r
.dw (FETCH_A	| OP_NOP	| STORE_A  )	 ; 7F		LD A,r
.dw (FETCH_B	| OP_ADDA	| STORE_A  )	 ; 80		ADD A,r
.dw (FETCH_C	| OP_ADDA	| STORE_A  )	 ; 81		ADD A,r
.dw (FETCH_D	| OP_ADDA	| STORE_A  )	 ; 82		ADD A,r
.dw (FETCH_E	| OP_ADDA	| STORE_A  )	 ; 83		ADD A,r
.dw (FETCH_H	| OP_ADDA	| STORE_A  )	 ; 84		ADD A,r
.dw (FETCH_L	| OP_ADDA	| STORE_A  )	 ; 85		ADD A,r
.dw (FETCH_MHL	| OP_ADDA	| STORE_A  )	 ; 86		ADD A,r
.dw (FETCH_A	| OP_ADDA	| STORE_A  )	 ; 87		ADD A,r
.dw (FETCH_B	| OP_ADCA	| STORE_A  )	 ; 88		ADC A,r
.dw (FETCH_C	| OP_ADCA	| STORE_A  )	 ; 89		ADC A,r
.dw (FETCH_D	| OP_ADCA	| STORE_A  )	 ; 8A		ADC A,r
.dw (FETCH_E	| OP_ADCA	| STORE_A  )	 ; 8B		ADC A,r
.dw (FETCH_H	| OP_ADCA	| STORE_A  )	 ; 8C		ADC A,r
.dw (FETCH_L	| OP_ADCA	| STORE_A  )	 ; 8D		ADC A,r
.dw (FETCH_MHL	| OP_ADCA	| STORE_A  )	 ; 8E		ADC A,r
.dw (FETCH_A	| OP_ADCA	| STORE_A  )	 ; 8F		ADC A,r
.dw (FETCH_B	| OP_SUBFA	| STORE_A  )	 ; 90		SUB A,r
.dw (FETCH_C	| OP_SUBFA	| STORE_A  )	 ; 91		SUB A,r
.dw (FETCH_D	| OP_SUBFA	| STORE_A  )	 ; 92		SUB A,r
.dw (FETCH_E	| OP_SUBFA	| STORE_A  )	 ; 93		SUB A,r
.dw (FETCH_H	| OP_SUBFA	| STORE_A  )	 ; 94		SUB A,r
.dw (FETCH_L	| OP_SUBFA	| STORE_A  )	 ; 95		SUB A,r
.dw (FETCH_MHL	| OP_SUBFA	| STORE_A  )	 ; 96		SUB A,r
.dw (FETCH_A	| OP_SUBFA	| STORE_A  )	 ; 97		SUB A,r
.dw (FETCH_B	| OP_SBCFA	| STORE_A  )	 ; 98		SBC A,r
.dw (FETCH_C	| OP_SBCFA	| STORE_A  )	 ; 99		SBC A,r
.dw (FETCH_D	| OP_SBCFA	| STORE_A  )	 ; 9A		SBC A,r
.dw (FETCH_E	| OP_SBCFA	| STORE_A  )	 ; 9B		SBC A,r
.dw (FETCH_H	| OP_SBCFA	| STORE_A  )	 ; 9C		SBC A,r
.dw (FETCH_L	| OP_SBCFA	| STORE_A  )	 ; 9D		SBC A,r
.dw (FETCH_MHL	| OP_SBCFA	| STORE_A  )	 ; 9E		SBC A,r
.dw (FETCH_A	| OP_SBCFA	| STORE_A  )	 ; 9F		SBC A,r
.dw (FETCH_B	| OP_ANDA	| STORE_A  )	 ; A0		AND A,r
.dw (FETCH_C	| OP_ANDA	| STORE_A  )	 ; A1		AND A,r
.dw (FETCH_D	| OP_ANDA	| STORE_A  )	 ; A2		AND A,r
.dw (FETCH_E	| OP_ANDA	| STORE_A  )	 ; A3		AND A,r
.dw (FETCH_H	| OP_ANDA	| STORE_A  )	 ; A4		AND A,r
.dw (FETCH_L	| OP_ANDA	| STORE_A  )	 ; A5		AND A,r
.dw (FETCH_MHL	| OP_ANDA	| STORE_A  )	 ; A6		AND A,r
.dw (FETCH_A	| OP_ANDA	| STORE_A  )	 ; A7		AND A,r
.dw (FETCH_B	| OP_XORA	| STORE_A  )	 ; A8		XOR A,r
.dw (FETCH_C	| OP_XORA	| STORE_A  )	 ; A9		XOR A,r
.dw (FETCH_D	| OP_XORA	| STORE_A  )	 ; AA		XOR A,r
.dw (FETCH_E	| OP_XORA	| STORE_A  )	 ; AB		XOR A,r
.dw (FETCH_H	| OP_XORA	| STORE_A  )	 ; AC		XOR A,r
.dw (FETCH_L	| OP_XORA	| STORE_A  )	 ; AD		XOR A,r
.dw (FETCH_MHL	| OP_XORA	| STORE_A  )	 ; AE		XOR A,r
.dw (FETCH_A	| OP_XORA	| STORE_A  )	 ; AF		XOR A,r
.dw (FETCH_B	| OP_ORA	| STORE_A  )	 ; B0		OR A,r
.dw (FETCH_C	| OP_ORA	| STORE_A  )	 ; B1		OR A,r
.dw (FETCH_D	| OP_ORA	| STORE_A  )	 ; B2		OR A,r
.dw (FETCH_E	| OP_ORA	| STORE_A  )	 ; B3		OR A,r
.dw (FETCH_H	| OP_ORA	| STORE_A  )	 ; B4		OR A,r
.dw (FETCH_L	| OP_ORA	| STORE_A  )	 ; B5		OR A,r
.dw (FETCH_MHL	| OP_ORA	| STORE_A  )	 ; B6		OR A,r
.dw (FETCH_A	| OP_ORA	| STORE_A  )	 ; B7		OR A,r
.dw (FETCH_B	| OP_SUBFA	| STORE_NOP)	 ; B8		CP A,r
.dw (FETCH_C	| OP_SUBFA	| STORE_NOP)	 ; B9		CP A,r
.dw (FETCH_D	| OP_SUBFA	| STORE_NOP)	 ; BA		CP A,r
.dw (FETCH_E	| OP_SUBFA	| STORE_NOP)	 ; BB		CP A,r
.dw (FETCH_H	| OP_SUBFA	| STORE_NOP)	 ; BC		CP A,r
.dw (FETCH_L	| OP_SUBFA	| STORE_NOP)	 ; BD		CP A,r
.dw (FETCH_MHL	| OP_SUBFA	| STORE_NOP)	 ; BE		CP A,r
.dw (FETCH_A	| OP_SUBFA	| STORE_NOP)	 ; BF	 	CP A,r
.dw (FETCH_NOP  | OP_IFNZ	| STORE_RET)	 ; C0		RET NZ
.dw (FETCH_NOP  | OP_POP16	| STORE_BC )	 ; C1		POP BC
.dw (FETCH_DIR16| OP_IFNZ	| STORE_PC )	 ; C2 nn nn	JP NZ,nn
.dw (FETCH_DIR16| OP_NOP	| STORE_PC )	 ; C3 nn nn	JP nn
.dw (FETCH_DIR16| OP_IFNZ	| STORE_CALL)	 ; C4 nn nn	CALL NZ,nn
.dw (FETCH_BC	| OP_PUSH16	| STORE_NOP)	 ; C5		PUSH BC
.dw (FETCH_DIR8	| OP_ADDA	| STORE_A  )	 ; C6 nn	ADD A,n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; C7		RST 0
.dw (FETCH_NOP	| OP_IFZ	| STORE_RET)	 ; C8		RET Z
.dw (FETCH_NOP	| OP_NOP	| STORE_RET)	 ; C9		RET
.dw (FETCH_DIR16| OP_IFZ	| STORE_PC )	 ; CA nn nn	JP Z,nn
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; CB 		(Z80 specific)
.dw (FETCH_DIR16| OP_IFZ	| STORE_CALL)	 ; CC nn nn	CALL Z,nn
.dw (FETCH_DIR16| OP_NOP	| STORE_CALL)	 ; CD nn nn	CALL nn
.dw (FETCH_DIR8	| OP_ADCA	| STORE_A  )	 ; CE nn	ADC A,n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; CF		RST 8H
.dw (FETCH_NOP	| OP_IFNC	| STORE_RET)	 ; D0		RET NC
.dw (FETCH_NOP  | OP_POP16	| STORE_DE )	 ; D1		POP DE
.dw (FETCH_DIR16| OP_IFNC	| STORE_PC )	 ; D2 nn nn	JP NC,nn
.dw (FETCH_DIR8	| OP_OUTA	| STORE_NOP)	 ; D3 nn	OUT (n),A
.dw (FETCH_DIR16| OP_IFNC	| STORE_CALL)	 ; D4 nn nn	CALL NC,nn
.dw (FETCH_DE	| OP_PUSH16	| STORE_NOP)	 ; D5		PUSH DE
.dw (FETCH_DIR8	| OP_SUBFA	| STORE_A  )	 ; D6 nn	SUB n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; D7		RST 10H
.dw (FETCH_NOP	| OP_IFC	| STORE_RET)	 ; D8		RET C
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; D9		EXX			(Z80)
.dw (FETCH_DIR16| OP_IFC	| STORE_PC )	 ; DA nn nn	JP C,nn
.dw (FETCH_DIR8	| OP_IN 	| STORE_A  )	 ; DB nn	IN A,(n)
.dw (FETCH_DIR16| OP_IFC	| STORE_CALL)	 ; DC nn nn	CALL C,nn
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; DD 		(Z80)
.dw (FETCH_DIR8	| OP_SBCFA	| STORE_A  )	 ; DE nn	SBC A,n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; DF		RST 18H
.dw (FETCH_NOP	| OP_IFPO	| STORE_RET)	 ; E0		RET PO
.dw (FETCH_NOP	| OP_POP16	| STORE_HL )	 ; E1		POP HL
.dw (FETCH_DIR16| OP_IFPO	| STORE_PC )	 ; E2 nn nn	JP PO,nn
.dw (FETCH_MSP	| OP_EXHL	| STORE_MSP)	 ; E3		EX (SP),HL
.dw (FETCH_DIR16| OP_IFPO	| STORE_CALL)	 ; E4 nn nn	CALL PO,nn
.dw (FETCH_HL	| OP_PUSH16	| STORE_NOP)	 ; E5		PUSH HL
.dw (FETCH_DIR8	| OP_ANDA	| STORE_A  )	 ; E6 nn	AND n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; E7		RST 20H
.dw (FETCH_NOP	| OP_IFPE	| STORE_RET)	 ; E8		RET PE
.dw (FETCH_HL	| OP_NOP	| STORE_PC )	 ; E9		JP (HL)
.dw (FETCH_DIR16| OP_IFPE	| STORE_PC )	 ; EA nn nn	JP PE,nn
.dw (FETCH_DE	| OP_EXHL	| STORE_DE )	 ; EB		EX DE,HL
.dw (FETCH_DIR16| OP_IFPE	| STORE_CALL)	 ; EC nn nn	CALL PE,nn
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; ED		(Z80 specific)
.dw (FETCH_DIR8	| OP_XORA	| STORE_A  )	 ; EE nn	XOR n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; EF		RST 28H
.dw (FETCH_NOP	| OP_IFP	| STORE_RET)	 ; F0		RET P
.dw (FETCH_NOP	| OP_POP16	| STORE_AF )	 ; F1		POP AF
.dw (FETCH_DIR16| OP_IFP	| STORE_PC )	 ; F2 nn nn	JP P,nn
.dw (FETCH_NOP	| OP_DI		| STORE_NOP)	 ; F3		DI
.dw (FETCH_DIR16| OP_IFP	| STORE_CALL)	 ; F4 nn nn	CALL P,nn
.dw (FETCH_AF	| OP_PUSH16	| STORE_NOP)	 ; F5		PUSH AF
.dw (FETCH_DIR8	| OP_ORA	| STORE_A  )	 ; F6 nn	OR n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; F7		RST 30H
.dw (FETCH_NOP	| OP_IFM	| STORE_RET)	 ; F8		RET M
.dw (FETCH_HL	| OP_NOP	| STORE_SP )	 ; F9		LD SP,HL
.dw (FETCH_DIR16| OP_IFM	| STORE_PC )	 ; FA nn nn	JP M,nn
.dw (FETCH_NOP	| OP_EI 	| STORE_NOP)	 ; FB		EI
.dw (FETCH_DIR16| OP_IFM	| STORE_CALL)	 ; FC nn nn	CALL M,nn
.dw (FETCH_NOP	| OP_INV	| STORE_NOP)	 ; FD 		(Z80 specific)
.dw (FETCH_DIR8	| OP_SUBFA	| STORE_NOP)	 ; FE nn	CP n
.dw (FETCH_RST	| OP_NOP	| STORE_CALL)	 ; FF		RST 38H
