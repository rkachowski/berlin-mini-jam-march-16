; game.s
INCLUDE "lib/gbhw.inc" ; gameboy hardware definitions
INCLUDE "lib/ibmpc1.inc" ; ibm ascii font macros
INCLUDE "lib/sprite.inc" ; sprite goodies

; consts 
TICK		EQU	$0fff
GROUND		EQU	100
CHAR_WIDTH	EQU	20
CHAR_STEP	EQU	2
LEFT_WALL 	EQU	10
RIGHT_WALL 	EQU	SCRN_X-CHAR_WIDTH

LIGHT_LEFT	EQU	50
LIGHT_WIDTH	EQU	25
LIGHT_THRESH	EQU	80

; variables
	SpriteAttr	CharSprite
	LoByteVar	LightAcc

; interrupts
SECTION "Vblank",HOME[$0040]
	jp	DMACODELOC ; *hs* update sprites every time the Vblank interrupt is called (~60Hz)
SECTION "LCDC",HOME[$0048]
	reti
SECTION "Timer_Overflow",HOME[$0050]
	reti
SECTION "Serial",HOME[$0058]
	reti
SECTION "p1thru4",HOME[$0060]
	reti

; jump to start of user code at `begin`
SECTION "start",HOME[$0100]
nop
jp begin

; rom header - no memory bank controller, 32k rom, 0; ram
	ROM_HEADER ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE
INCLUDE "lib/memory.inc"; memory copying macros

TileData:
	chr_IBMPC1 1,8 ; LOAD ENTIRE CHARACTER SET

; initialization
begin:
	nop
	di
	ld sp, $ffff  ; set the stack pointer to highest mem location + 1

; NEXT FOUR LINES FOR SETTING UP SPRITES *hs*
	call	initdma			; move routine to HRAM
	ld	a, IEF_VBLANK
	ld	[rIE],a			; ENABLE ONLY VBLANK INTERRUPT
	ei				; LET THE INTS FLY

init:
	ld a, %11100100  ; Window palette colors, from darkest to lightest
	ld	[rBGP], a		; set background and window pallette
	ldh	[rOBP0],a		; set sprite pallette 0 (choose palette 0 or 1 when describing the sprite)
	ldh	[rOBP1],a		; set sprite pallette 1

	ld a,0   ; SET SCREEN TO TO UPPER RIGHT HAND CORNER
	ld [rSCX], a
	ld [rSCY], a
	call StopLCD  ; YOU CAN NOT LOAD $8000 WITH LCD ON
	ld hl, TileData 
	ld de, _VRAM  ; $8000
	ld bc, 8*256   ; the ASCII character set: 256 characters, each with 8 bytes of display data
	call mem_CopyMono ; load tile data

; *hs* erase sprite table
	ld	a,0
	ld	hl,OAMDATALOC
	ld	bc,OAMDATALENGTH
	call	mem_Set

	ld	a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON ; *hs* see gbspec.txt lines 1525-1565 and gbhw.inc lines 70-86
	ld [rLCDC], a
	ld a, 32  ; ASCII FOR BLANK SPACE
	ld hl, _SCRN0
	ld bc, SCRN_VX_B * SCRN_VY_B
	call mem_SetVRAM

setuptitle:
	ld hl,Title
	ld de, _SCRN0+1+(SCRN_VY_B*1) ;
	ld bc, TitleEnd-Title
	call mem_CopyVRAM

setupchar:
	PutSpriteYAddr	CharSprite,GROUND
	PutSpriteXAddr	CharSprite,LEFT_WALL
 	ld	a,$01
 	ld 	[CharSpriteTileNum], a
 	ld	a,%00000000       
 	ld	[CharSpriteFlags],a 

setuplight:
	ld	a,0
	ld	[LightAcc],a

mainloop:
handlekeys:
	ld	bc,TICK
	call	simpleDelay
	call	GetKeys
	and	PADF_RIGHT
	call	nz,keypress_move
	call	z,bumpchar
updatelight:
	ld	a,[LightAcc]
	inc	a
	ld	[LightAcc],a
	cp	LIGHT_THRESH
	call	nc, drawLightOn
	call	c, drawLightOff
mainloop_end:
	jr mainloop

keypress_move:
	GetSpriteXAddr CharSprite
	cp RIGHT_WALL
	ret nc
	add a,CHAR_STEP
	PutSpriteXAddr CharSprite,a
	ret

bumpchar:
	GetSpriteXAddr CharSprite
	cp LEFT_WALL
	ret c
	sub a,CHAR_STEP
	PutSpriteXAddr CharSprite,a
	ret

drawLightOff:
 	ld	a,$01
 	ld 	[CharSpriteTileNum], a
	ret

drawLightOn:
 	ld	a,$02
 	ld 	[CharSpriteTileNum], a
	ret
	
Title:
	DB  "wow much vintage"
TitleEnd:

StopLCD:
	ld a,[rLCDC]
	rlca
	ret nc

.wait:
	ld a,[rLY]
	cp 145
	jr nz,.wait

	ld a,[rLCDC]
	res 7,a
	ld [rLCDC],a

	ret

simpleDelay:
	dec	bc
	ld	a,b
	or	c
	jr	nz,simpleDelay
	ret

; GetKeys: adapted from APOCNOW.ASM and gbspec.txt
GetKeys:
	ld 	a,P1F_5			; set bit 5
	ld 	[rP1],a			; select P14 by setting it low. See gbspec.txt lines 1019-1095
	ld 	a,[rP1]
 	ld 	a,[rP1]			; wait a few cycles
	cpl				; complement A. "You are a very very nice Accumulator..."
	and 	$0f			; look at only the first 4 bits
	swap 	a			; move bits 3-0 into 7-4
	ld 	b,a			; and store in b

 	ld	a,P1F_4			; select P15
 	ld 	[rP1],a
	ld	a,[rP1]
	ld	a,[rP1]
	ld	a,[rP1]
	ld	a,[rP1]
	ld	a,[rP1]
	ld	a,[rP1]			; wait for the bouncing to stop
	cpl				; as before, complement...
 	and $0f				; and look only for the last 4 bits
 	or b				; combine with the previous result
 	ret				; do we need to reset joypad? (gbspec line 1082)


; *hs* START
initdma:
	ld	de, DMACODELOC
	ld	hl, dmacode
	ld	bc, dmaend-dmacode
	call	mem_CopyVRAM			; copy when VRAM is available
	ret
dmacode:
	push	af
	ld	a, OAMDATALOCBANK		; bank where OAM DATA is stored
	ldh	[rDMA], a			; Start DMA
	ld	a, $28				; 160ns
dma_wait:
	dec	a
	jr	nz, dma_wait
	pop	af
	reti
dmaend:
; *hs* END
