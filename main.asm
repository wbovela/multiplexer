GenerateTo "multiplex.prg"", d64, progdisk
incasm  "vic2constants.asm"
incasm  "cia.asm"
incasm  "charset2.asm"
incasm  "screens.asm"
*= $0800
        byte    $00,$0c,$08,$0a,$00,$9e,$32,$30,$36,$34,$00,$00,$00,$00
*= $0810
;--------------------------------------------------
; Main program
;--------------------------------------------------
        jsr     init    
        lda     #1              ; select screen number   
        jsr     draw_screen
        jsr     set_interrupt
        jmp     *       ; infinite loop
;--------------------------------------------------
; End Main program
;--------------------------------------------------

;--------------------------------------------------
; Init
; Initialise screen, charset and memory setup
;--------------------------------------------------
init
        lda     #00     
        sta     BORDER_COLOR
        sta     SCREEN_COLOR; set screen to black
        jsr     print_welcome; print welcome message and clear screen
        jsr     setup_sprite; initialise sprite 1
        ; install new character set
        lda     #%11000 ; set screen to $0400, chars set to $2000
        sta     $d018   
        ; switch off basic rom
        lda     #$2f    ; set bits 0-2 to 1 for read/write
        sta     0       
        lda     #$36    ; set bits 0-2 to %110 to switch off BASIC ROM
        sta     1       
        rts

;--------------------------------------------------
; draw_screen
; Draw screen and color data
; @param a = screen number
;--------------------------------------------------
screen  byte    0       ; stores the screen number
draw_screen
        asl     ; shift left to multiply by 2
        tax             ; x = screen number now
        stx     screen  ; store it.
        lda     tb_scrn,x; store the low byte
        sta     $31     ; in zero page
        lda     tb_scrn,x+1; store high byte
        sta     $32     ; in zero page

        ; first the color data to $d800
        ldy     #$00    
@loop   lda     scr1_col,y; $d800 - $d8ff
        sta     $d800,y 
        lda     scr1_col+$0100,y; $d900 - $d9ff
        sta     $d800+$0100,y
        lda     scr1_col+$0200,y; $da00 - $daff
        sta     $d800+$0200,y
        lda     scr1_col+$0300,y; $db00 - $dbff
        sta     $d800+$0300,y

        ; and the screen data
        ldx     screen  ; take the screen number we stored
        lda     tb_scrn,x+1; get the high byte of the screen data address
        sta     $32     ; restore high byte of destination in zero page
        ; now we can copy the screen data
        lda     ($31),y ; first $ff block from screen data source
        sta     $0400,y ; to screen memory
        inc     $32     ; and increase high byte (adds $0100 like above)
        lda     ($31),y ; second $ff block
        sta     $0400+$0100,y
        inc     $32     
        lda     ($31),y ; third $ff block
        sta     $0400+$0200,y
        inc     $32     
        lda     ($31),y ; fourth $ff block
        sta     $0400+$0300,y
        iny
        bne     @loop   
        rts

;--------------------------------------------------
;  set new interrupt handler
;--------------------------------------------------
set_interrupt
        sei
        ldy     #$7f    ; $7f = %01111111
        sty     CIA1    ; Turn off CIA 1  Timer interrupts
        sty     CIA2    ; Turn off CIA 2  Timer interrupts
        lda     CIA1    ; cancel all CIA-IRQs in queue/unprocessed
        lda     CIA2    ; cancel all CIA-IRQs in queue/unprocessed
        lda     #<int   
        sta     $0314   
        lda     #>int   
        sta     $0315   ; setup the vector for our own irq
        lda     #75     ; set rasterline to where the
        sta     RASTER_LINE; interrupt should occur
        lda     #01     ; bit 0 is raster interrupt
        sta     INTERRUPT_ENABLE; request a raster interrupt from vic2
        lda     RASTER_LINE_MSB; Bit#7 of $d011 is basically...
        and     #$7f    ; ...the 9th Bit for $d012
        sta     RASTER_LINE_MSB; we need to make sure it is set to zero
        lda     #0      
        sta     curr    ; set table pointer to 0
        cli
        rts

;--------------------------------------------------
int     lda     INTERRUPT_EVENT
        and     #$01    
        sta     INTERRUPT_EVENT; has the raster interrupt happened?
        bne     irq     
        jmp     $ea81   
;--------------------------------------------------
irq     jsr     animate ; move along the x axis
        ldx     curr    ; load table index
        lda     tb_ypos,x; get y position raster position
        sta     SPRITE_0_Y; set y position
        lda     tb_shp,x; get next sprite pointer
        sta     $07f8   ; store $0a00 = $28*#64
        lda     tb_rst,x; get next raster line
        sta     RASTER_LINE
        lda     tb_col,x; get next color
        sta     SPRITE_SOLID_ALL_2
        inc     curr    ; increase cursor
        lda     curr    
        cmp     #4      
        bne     end     
        lda     #0      
        sta     curr    
end     jmp     $ea81
;--------------------------------------------------
;   move sprite along x axis
;--------------------------------------------------
screen@ byte    0
animate nop
        inc     SPRITE_0_X
        lda     SPRITE_0_X
        bne     ex      
        lda     #50     
        sta     SPRITE_0_X
        ; switch screens
        lda     screen@
        jsr     draw_screen
        lda     screen@
        beq     one
        ldx     #0
        jmp     ex@
one     ldx     #1
ex@     stx     screen@
        rts
        
        
ex      rts
;--------------------------------------------------
;   initialise sprite 1
;--------------------------------------------------
setup_sprite
        lda     #1      ; colors
        sta     SPRITE_SOLID_ALL_1
        lda     #11     
        sta     SPRITE_SOLID_ALL_2
        lda     #15     
        sta     SPRITE_SOLID_0; set
        lda     #64     
        sta     SPRITE_0_X; X-Position
        lda     #$01    ;
        sta     SPRITE_ENABLE; Sprite 1 on
        sta     SPRITE_HIRES; Multicolor
        rts
;--------------------------------------------------
;   print welcome
;--------------------------------------------------
print_welcome
        ldx     #0      
@loop    lda     welcome,x
        cmp     #$ff    
        beq     ex_loop 
        jsr     $ffd2   
        inx
        jmp     @loop   
ex_loop rts
;--------------------------------------------------
;   2 Sprite shapes
;--------------------------------------------------
*=$0a00
        byte    $ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$f0
        byte    $00,$00,$b0,$00,$00,$A0,$00,$00,$AC,$00,$00,$F8,$00,$00,$FE,$0E
        byte    $f0,$aa,$a9,$7c,$aa,$aa,$5b,$ab,$ea,$aa,$eb,$fa,$ab,$03,$f0,$00
        byte    $03,$f0,$00,$03,$c0,$00,$03,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff
; $0a40
        byte    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        byte    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        byte    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        byte    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
welcome byte    147
        text    "The Highlander"
        byte    $FF

; tables
tb_rst  byte    121, 143, 187, 77; raster lines where interrupts happen
tb_ypos byte    78, 122, 144, 189; y position of sprite
tb_col  byte    0, 6, 3, 2; color codes for sprites
tb_shp  byte    $28, $29, $28, $29; sprite shape pointers
tb_scrn word    $a400, $a800
curr    byte    0       ; table pointers
delay   byte    0

