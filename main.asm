;--------------------------------------------------
; Generate to a .prg file
;--------------------------------------------------
GenerateTo "multiplex.prg"", d64, progdisk

;--------------------------------------------------
; Include constants
;--------------------------------------------------
incasm  "vic2constants.asm"
incasm  "cia.asm"

;--------------------------------------------------
; Include character set and screen definitions
;--------------------------------------------------
incasm  "charset2.asm"
incasm  "screens.asm"

;--------------------------------------------------
; Main program with Basic starter
;--------------------------------------------------
*= $0800
        byte    $00,$0c,$08,$0a,$00,$9e,$32,$30,$36,$34,$00,$00,$00,$00

*= $0810
        jsr     init    
        lda     #1      ; select screen number
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
;  Game code
;--------------------------------------------------
incasm  "game_code.asm"

;--------------------------------------------------
;  sprite data
;--------------------------------------------------
incasm  "sprite_data.asm"

;--------------------------------------------------
;  General tables and data
;--------------------------------------------------

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


