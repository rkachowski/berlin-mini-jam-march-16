; rbgb.inc
; gameboy stdlib - memory functions
; https://github.com/rkachowski/rubygb


; rbgb_blit - copy an image to vram
; assumes map data is sequential in memory
; hl - map data base address
; de - destination base address
; a - height in tiles
; c - width in tiles
;
; e.g.
; width(c) = 7, height(a) = 6
;
;     memory(hl)           vram(de)
;    TILEMAPTILEM         TILEMAP-------
;    APTILEMAPTIL  +-->   TILEMAP-------
;    MAPTILEMAPTI         TILEMAP-------
;    LEMAP-------         TILEMAP-------
;                         TILEMAP-------
;
; this is totally awful and abuses the stack but it works for now
rbgb_blit:
    push bc
    ;set length to tile map width (bc)
    ;preserve values because mem_CopyVRAM will screw up the registers
    push af; save value of a
    push hl
    push de
	call	mem_CopyVRAM	; load tile data
    ;retrieve values
    pop de
    pop hl
    pop af
    pop bc
    push bc

    ;add width to source (hl)
    add hl, bc
    push hl; save source position

    ;load de into hl
    push de
    pop hl

    ;add 0x20 / 32 to destination (de)
    ld bc, $20
    add hl, bc

    ;load hl into de
    push hl
    pop de
    
    pop hl;retrieve source position

    pop bc

    dec a
    jp nz, rbgb_blit
    ret
