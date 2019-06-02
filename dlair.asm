;----------------------------------------------
;-- Acorn Atom Dragon's Lair
;----------------------------------------------
        .DEFINE asm_code $3000
        .DEFINE header   1              ; Header Atomulator
        .DEFINE filenaam "DLAIR"

.org asm_code-22*header

.IF header
;********************************************************************
; ATM Header for Atomulator

name_start:
        .byte filenaam                  ; Filename
name_end:
        .repeat 16-name_end+name_start  ; Fill with 0
          .byte $0
        .endrep

        .word start_asm                 ; 2 bytes startaddress
        .word start_asm                 ; 2 bytes linkaddress
        .word end_asm-start_asm         ; 2 bytes filelength

;********************************************************************
.ENDIF

           .include "atmmc2def.asm"

;=================================================================
;== VARIABLE DECLARATION
;=================================================================

; Constants

MODE0           = $00
MODE1Colour     = $10
MODE1           = $30
MODE2Colour     = $50
MODE2           = $70
MODE3Colour     = $90
MODE3           = $b0
MODE4Colour     = $d0
MODE4           = $f0

buffer          = $4000
movieframes     = 6570

; vars

displaymode     = MODE

.if displaymode = 0
        clearmode       = MODE0
        scrwindow       = $8000
        screenwidth     = 32
        moviewidth      = 32
        blockloads      = 2
.endif

.if displaymode = 2
        clearmode       = MODE2
        scrwindow       = $8000
        screenwidth     = 16
        moviewidth      = 16
        blockloads      = 6
.endif

.if displaymode = 4
        clearmode       = MODE4
        scrwindow       = $8a08
        screenwidth     = 32
        moviewidth      = 16
        blockloads      = 6
.endif

bufaddress      = $80
scraddress      = $82

OSFIND          = $FFCE
OSSHUT          = $FFCB

;=================================================================
;== Macros
;=================================================================

.macro SETRWPTR addr
        lda #<addr
        sta RWPTR
        lda #>addr
        sta RWPTR+1
.endmacro

;=================================================================
;== Game Start
;=================================================================

exec:
start_asm:

        jsr atommc3_detect              ; Detect PIC vs AVR AtoMMC
; Init

        lda #<movieframes               ; Set framecounter
        sta framecounter
        lda #>movieframes
        sta framecounter+1

; Copy filename to namebuffer

loop:
        ldx #13-1
lp1:
        lda myfilename,x
        sta NAME,x
        dex
        bpl lp1

; Open file

        jsr open_file_read

; Start loading 1 frame in buffer

next_frame:
        SETRWPTR $4000                  ; Set databuffer pointer
        ldx #blockloads                 ; Load 6 blocks
lp2:
        txa
        pha

        jsr read_block_256

        inc RWPTR+1                     ; Point to next block

        pla
        tax

        dex
        bne lp2                         ; Repeat for all blocks

; Display 1 frame on screen

        ldy #(moviewidth-1)             ; Byte counter
scrloop2:

.repeat 96,cnt                          ; Display column
        lda buffer+cnt*moviewidth,y
        sta scrwindow+cnt*screenwidth,y
.endrep

        dey
        bmi next_scr
        jmp scrloop2

next_scr:
        sec
        lda framecounter
        sbc #1
        sta framecounter
        lda framecounter+1
        sbc #0
        sta framecounter+1
        bcc end_file
        jmp next_frame                  ; Repeat for all frames

end_file:
        jsr closefile                   ; Close file

        rts
;=================================================================
handle:
       .byte 0

;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Send filename and open file for reading/writing
;
; $140 = name
; a = read/write $01 = read, $11 = write
;

open_file_read:
       lda #<NAME                       ; Set namebuffer to $0140
       sta LFNPTR
       lda #>NAME
       sta LFNPTR+1
       ldx #LFNPTR
       jsr OSFIND
       sta handle
       rts

;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Close a file
;

closefile:
       ldy handle
       jmp OSSHUT

;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Read data to memory
;
; a = number of bytes to read (0 = 256)
; (RWPTR) points to target
;
read_block_256:
     ; tax				                   ; Save byte counter
       lda #0
       jsr write_latch_reg              ; ask PIC for (A) bytes of data (0=256)
       lda handle
       and #3
       asl a
       asl a
       clc
       adc #CMD_READ_BYTES
       jsr slow_cmd 	                   ; Set command
       cmp #STATUS_COMPLETE+1           ; Check if command successfull
       bcs reportDiskFailure            ; If not, report error
       jsr prepare_read_data	          ; Tell pic to release the data we just read

       ; Read data block
       ldy  #0

       bit atommc3_type
       bmi read_block_pic

read_block_avr:

       lda #MMC_MCU_WROTE               ; Read status reg
       bit ASTATUS_REG                  ; Been written yet ?
       beq read_block_avr               ; nope keep waiting

       LDA AREAD_DATA_REG               ; Then read byte
       sta (RWPTR),y    	             ; Store byte in memory
       iny				                   ; Increment memory pointer
     ; dex				                   ; Decrement byte counter
       bne read_block_avr               ; Repeat
       rts

read_block_pic:

       ;; delay is needed at 2MHz (and less than 6 NOPs crashes)
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       LDA AREAD_DATA_REG
       sta (RWPTR),y    	             ; Store byte in memory
       iny				                   ; Increment memory pointer
     ; dex				                   ; Decrement byte counter
       bne read_block_pic               ; Repeat
       rts


reportDiskFailure:
;just mess screen for now.
       pha
       lda #0
       sta $b000
       pla
       jsr $f802
       jmp $c2b2

;=================================================================

myfilename:     .byte "MOVIE"

.if displaymode=0
        .byte "0"
.endif

.if displaymode=2
        .byte "2"
.endif

.if displaymode=4
        .byte "2"
.endif

        .byte 13
framecounter:   .byte 0,0
noisecounter:   .byte 0

        .include "util.asm"
end_asm:
