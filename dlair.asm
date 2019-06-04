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
;== Include Atom2K18 profiling code
;=================================================================

profiling       = 1

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
        movieheight     = 16
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
tmpy            = $82
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

.if profiling = 1
        jsr profiling_init
.endif

        lda ViaT1CounterH
        sta last_vsync_time
        lda ISRCounter
        sta last_vsync_time + 1


next_frame:

.if profiling = 1
        jsr profiling_clear
.endif

.if compressed = 1
;       jsr read_frame_compressed       ; AtoMMC => cbuffer => display
        jsr stream_frame_compressed     ; AtoMMC => display
.else
        jsr read_frame_uncompressed
.endif

.if profiling = 1
        jsr profiling_sample
.endif

        jsr adaptive_vsync              ; cap rate to 30 FPS

.if doublebuffer = 1
        lda GODIL_MODE_EXT
        eor #$30
        sta GODIL_MODE_EXT
.endif

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
        jsr OSWRCH

.if profiling = 1
        jsr profiling_dump
.endif

        ldx #0
vsync_stats_loop:
        txa
        lsr a
        clc
        adc #'0'
        jsr OSWRCH
        lda #':'
        jsr OSWRCH
        lda vsync_stats + 1, x
        jsr $f802
        lda vsync_stats, x
        jsr $f802
        jsr OSCRLF
        inx
        inx
        cpx #$10
        bne vsync_stats_loop
        rts

;=================================================================

        .include "via.asm"

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

        lda #<buffer                    ; Self modifying code
        sta @store + 1
        lda #>buffer
        sta @store + 2

@loop1:
        jsr read_block_256

        ldx #0
        clc
@loop2:
        ldy cbuffer, x                  ; <run length>
        sty tmpy
        inx
        lda cbuffer, x                  ; <value>

@loop3:
        dey
@store:
        sta buffer, y
        bne @loop3

        ;clc                            ; careful inspection shows C is always clear
        lda tmpy                        ; <run length>
        adc @store + 1
        sta @store + 1
        bcc @next
        inc @store + 2
        lda @store + 2
        cmp #>bufferend
        bcs @done
@next:
        inx
        bne @loop2
        beq @loop1
@done:
        rts

;=================================================================

stream_frame_compressed:

        lda #<buffer                    ; Self modifying code
        sta @store + 1
        lda #>buffer
        sta @store + 2

@loop1:
        jsr prepare_read_block_256

        ldx #$80
        clc
@loop2:

        ; Ignore handshake for speed; no delay actually needed
        ldy AREAD_DATA_REG              ; <run length>
        sty tmpy

        ; Ignore handshake for speed
        ; AVR needs delay of 16 cycles @ 8MHz
        ; PIC needs delay of 18 cycles @ 4MHz
        ;                    AVR  PIC
        bit atommc3_type   ; (4)  (4)
        bpl @avr           ; (3)  (2)
        sty tmpy           ;      (3)
@avr:
        sty tmpy           ; (3)  (3)
        nop                ; (2)  (2)
        nop                ; (2)  (2)
        nop                ; (2)  (2)
                           ;(16) (18)

        lda AREAD_DATA_REG              ; <value>

@loop3:
        dey
@store:
        sta buffer, y
        bne @loop3

        ;clc                            ; careful inspection shows C is always clear
        lda tmpy
        adc @store + 1
        sta @store + 1
        bcc @next
        inc @store + 2
        lda @store + 2
        cmp #>bufferend
        bcs @done
@next:
        dex
        bne @loop2
        beq @loop1
@done:
        rts

;=================================================================
; Adaptive VSYNC
;
; Attempts to pace the play back at 30 FPS.
;
; while (1) {
;   t = <now> - <last_vsync_time>
;   if (t > 30ms) {
;      break;
;   }
;   JSR $FE66
; }
; last_vsync_time = <now>
;
; The hard part is using T1 (the SID timer) plus an extension counter
; to actually work out the time, as the counter rate depends on the
; Atom clock speed.
;
; TODO - somehow read ViaT1CounterH and ISRCounter atomically

adaptive_vsync:

        lda #0
        sta vsync_count

adaptive_vsync_loop:

        lda ViaT1CounterH               ; Read the MSB of the VIA T1 Counter
        sta now_time
        lda ISRCounter                  ; And the extension counter incremented by the ISR
        sta now_time + 1

        lda #0
        sta delta_time + 1
        lda last_vsync_time
        sec
        sbc now_time
        bcs no_wrap
        dec delta_time + 1              ; -1 equates to a borrow in the next phase
no_wrap:
        sta delta_time

        ldx SystemSpeed                 ; 0=1MHz, 1=2MHz, 2=4MHz, 4=8MHz
        ldy now_time + 1
wraps_loop:
        cpy last_vsync_time + 1         ; for each increment of the ISR counter
        beq wraps_loop_done
        dey
        lda delta_time
        clc
        adc TimerHi, X                  ; add time equivalent to the period of T1
        sta delta_time
        bcc wraps_loop
        inc delta_time + 1
        jmp wraps_loop
wraps_loop_done:

; At this point delta_time is a 16-bit binary in units of 256 clock cycles
;
; Normalize it to units ot 32us by multiplying as follows:
;       1MHz (X=0) multiply by 8
;       2MHz (X=1) multiply by 4
;       4MHz (X=2) multiply by 2
;       8MHz (X=3) multiply by 1

normalize_loop:
        cpx #3
        bcs normalize_done
        asl delta_time
        rol delta_time + 1
        inx
        bne normalize_loop
normalize_done:

; At this point delta_time is a 16-bit binary in units of 32us
;
; Compare with 30ms to decide how to proceed
        sec
        lda delta_time                  ; this is a standard 16-bit unsigned compare
        sbc #<(32000/32)
        lda delta_time + 1
        sbc #>(32000/32)
        bcs vsync_exit                  ; branch if greater than 30ms

        jsr $fe66                       ; wait for another vsync
        inc vsync_count

        jmp adaptive_vsync_loop         ; loop back

vsync_exit:
        lda ViaT1CounterH               ; record <now> for next time vsync is called
        sta last_vsync_time
        lda ISRCounter
        sta last_vsync_time + 1

        lda vsync_count
        and #7
        asl a
        tax
        inc vsync_stats, x
        bne vsync_exit1
        inc vsync_stats + 1, x
vsync_exit1:
        rts

delta_time:
       .byte 0, 0

now_time:
       .byte 0, 0

last_vsync_time:
       .byte 0, 0

vsync_count:
       .byte 0

vsync_stats:
       .word 0 ; 0 VSYNC needed - took more than 2 VSYNCs to generate frame
       .word 0 ; 1 VSYNC needed
       .word 0 ; 2 VSYNC needed
       .word 0 ; 3 VSYNC needed - should never happen
       .word 0 ; etc
       .word 0
       .word 0
       .word 0

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
prepare_read_block_256:
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
        jmp prepare_read_data           ; Tell pic to release the data we just read

read_block_256:

        jsr prepare_read_block_256

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

.if profiling = 1
        .include "profiling.asm"
.endif

        .include "util.asm"

end_asm:
