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

cbuffer         = $6000
movieframes     = 6570

; vars

displaymode     = MODE

.if displaymode = 0
        clearmode       = MODE0
        scrwindow       = $8000
        screenwidth     = 32
        moviewidth      = 32
        movieheight     = 96            ; this should be 16, but it runs way too fast!
        blockloads      = 2
        buffer          = $4000
        bufferend       = $4200
        compressed      = 0
        doublebuffer    = 0
.endif

.if displaymode = 2
        clearmode       = MODE2
        scrwindow       = $8000
        screenwidth     = 16
        moviewidth      = 16
        movieheight     = 96
        blockloads      = 6
        buffer          = $4000
        bufferend       = $4600
        compressed      = 0
        doublebuffer    = 0
.endif

.if displaymode = 4
        clearmode       = MODE4
        scrwindow       = $8a08
        screenwidth     = 32
        moviewidth      = 16
        movieheight     = 96
        blockloads      = 6
        buffer          = $4000
        bufferend       = $4600
        compressed      = 0
        doublebuffer    = 0
.endif

.if displaymode = 6
        clearmode       = MODE4
        scrwindow       = $8000
        screenwidth     = 32
        moviewidth      = 32
        movieheight     = 192
        blockloads      = 24
        buffer          = $8000
        bufferend       = $9800
        compressed      = 1
        doublebuffer    = 1
.endif

bufptr          = $80
OSFIND          = $FFCE
OSSHUT          = $FFCB
GODIL_MODE_EXT  = $BDE0

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
        jsr InitVIA                     ; setup VIA correctly for 1/2/4MHz operation
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

.if doublebuffer = 1
        lda #$20
        sta GODIL_MODE_EXT
.endif

next_frame:

.if doublebuffer = 1
        lda GODIL_MODE_EXT
        eor #$30
        sta GODIL_MODE_EXT
.endif

.if compressed = 1
        jsr read_frame_compressed
.else
        jsr read_frame_uncompressed
.endif

; Display 1 frame on screen

; VSYNC
;
; PIC (at any speed) is too slow to run at 30fps
;
;              CLEAR 0        CLEAR 2/4      CLEAR 4 GS
; AVR @ 1MHz   22.5 FPS (0)   17.0 FPS (0)
; AVR @ 2MHz   45.0 FPS (1)   32.8 FPS (1)
; AVR @ 4MHz   85.2 FPS (2)   58.1 FPS (1)

        bit atommc3_type                ; Test the AtoMMC type
        bmi vsync_0                     ; PIC? skip all vsync
        lda SystemSpeed                 ; Set by InitVIA, 0=1MHz, 1=2MHz, 2=4MHz, 3=8MHz
        beq vsync_0                     ; AVR at 1MHz is too slow to run at 30fps
.if displaymode = 0
        cmp #2
.endif
        bne vsync_1
vsync_2:
        jsr $fe66                       ; Wait for VSYNC
vsync_1:
        jsr $fe66                       ; Wait for VSYNC
vsync_0:

.if (buffer <> scrwindow)

        ldy #(moviewidth-1)             ; Byte counter
scrloop2:

.repeat movieheight,cnt                 ; Display column
        lda buffer+cnt*moviewidth,y
        sta scrwindow+cnt*screenwidth,y
.endrep
        dey
        bmi next_scr
        jmp scrloop2

.endif

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
        jsr ResetVIA                    ; Disable VIA interrupts and restore the vector

.if doublebuffer = 1
        lda #0
        sta GODIL_MODE_EXT
.endif

        lda #12
        jmp OSWRCH

;=================================================================

read_frame_uncompressed:

        SETRWPTR buffer                 ; Set databuffer pointer
        ldx #blockloads                 ; Load 6 blocks
@loop:
        txa
        pha

        jsr read_block_256

        inc RWPTR+1                     ; Point to next block

        pla
        tax

        dex
        bne @loop                       ; Repeat for all blocks

        rts

;=================================================================

read_frame_compressed:

        SETRWPTR cbuffer                ; Set databuffer pointer
        lda #<buffer
        sta bufptr
        lda #>buffer
        sta bufptr + 1

@loop1:
        jsr read_block_256

        ldx #0

@loop2:
        lda cbuffer, x                  ; <value>
        inx
        ldy cbuffer, x                  ; <run length>
        beq @done                       ; if 0, then terminate

@loop3:
        dey
        sta (bufptr), y
        bne @loop3

        lda cbuffer, x                  ; <run length>
        clc
        adc bufptr
        sta bufptr
        bcc @next
        inc bufptr + 1
        lda bufptr + 1
        cmp #>bufferend
        beq @done
@next:
        inx
        bne @loop2
        beq @loop1
@done:
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
        lda #<NAME                      ; Set namebuffer to $0140
        sta LFNPTR
        lda #>NAME
        sta LFNPTR+1
        ldx #LFNPTR
        sec                             ; Use file for input
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
      ; tax                             ; Save byte counter
        lda #0
        jsr write_latch_reg             ; ask PIC for (A) bytes of data (0=256)
        lda handle
        and #3
        asl a
        asl a
        clc
        adc #CMD_READ_BYTES
        jsr slow_cmd                    ; Set command
        cmp #STATUS_COMPLETE+1          ; Check if command successfull
        bcs reportDiskFailure           ; If not, report error
        jsr prepare_read_data           ; Tell pic to release the data we just read

        ; Read data block
        ldy  #0

        bit atommc3_type
        bmi read_block_pic

read_block_avr:

        lda #MMC_MCU_WROTE              ; Read status reg
        bit ASTATUS_REG                 ; Been written yet ?
        beq read_block_avr              ; nope keep waiting

        LDA AREAD_DATA_REG              ; Then read byte
        sta (RWPTR),y                   ; Store byte in memory
        iny                             ; Increment memory pointer
      ; dex                             ; Decrement byte counter
        bne read_block_avr              ; Repeat
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
        sta (RWPTR),y                   ; Store byte in memory
        iny                             ; Increment memory pointer
      ; dex                             ; Decrement byte counter
        bne read_block_pic              ; Repeat
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

.if displaymode=6
        .byte "4"
.endif

.if compressed=1
        .byte "C"
.endif
        .byte 13

framecounter:   .byte 0,0

        .include "util.asm"


        .include "via.asm"

end_asm:
