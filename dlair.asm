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

displaymode     = 4

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

AREG_BASE       = $b400

ACMD_REG        = AREG_BASE+CMD_REG
ALATCH_REG      = AREG_BASE+LATCH_REG
AREAD_DATA_REG  = AREG_BASE+READ_DATA_REG
AWRITE_DATA_REG = AREG_BASE+WRITE_DATA_REG
ASTATUS_REG     = AREG_BASE+STATUS_REG

;=================================================================
;== Macros
;=================================================================

.macro SLOWCMD
        jsr SLOWCMD_SUB
.endmacro

.macro writeportFAST port
        sta port
.endmacro

.macro SETRWPTR addr
        lda #<addr
        sta RWPTR
        lda #>addr
        sta RWPTR+1
.endmacro

.macro SLOWCMDI command
        lda #command
        SLOWCMD
.endmacro

.macro readportFAST port
        lda port
.endmacro

;=================================================================
;== Game Start
;=================================================================

exec:
start_asm:

; Init

        lda #$40                        ; Set namebuffer to $0140
        sta LFNPTR
        lda #$01
        sta LFNPTR+1

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

        lda #0                          ; Load 256 bytes
        jsr read_block

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
        dec framecounter
        beq chk_frame
        jmp next_frame

chk_frame:
        dec framecounter+1
        beq end_file
        jmp next_frame                  ; Repeat for all frames

end_file:
        jsr closefile                   ; Close file

        rts

;=================================================================

SLOWCMD_SUB:
        writeportFAST ACMD_REG
SlowLoop:
        lda #0
        sec
SLOWCMD_DELAY_LOOP:
        sbc #1
        bne SLOWCMD_DELAY_LOOP
        lda ACMD_REG
        bmi SlowLoop
        rts

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

        .include "atmmc2def.asm"
        .include "file.inc"
end_asm:
