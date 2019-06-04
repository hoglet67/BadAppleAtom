;=================================================================
; Profiling using Atom2K18's high resolution timer
;=================================================================

ProfileCtrl     = $BFE0
ProfileDivider  = $BFE4
ProfileCounter  = $BFE8

;=================================================================
; profiling_init
;=================================================================

profiling_init:
        lda #<(32 * 1000)               ; Set the counter to run at 1ms resolution
        sta ProfileDivider              ; (i.e. divide by 32,000)
        lda #>(32 * 1000)
        sta ProfileDivider + 1
        lda #0
        sta ProfileDivider + 2
        sta ProfileDivider + 3
        tax                             ; Clear the profile bucker table
profile_init_loop:
        sta profile_table_l, x
        sta profile_table_h, x
        dex
        bne profile_init_loop
        rts

;=================================================================
; profiling_clear
;=================================================================

profiling_clear:
        lda #1
        sta ProfileCtrl                 ; Stop the counter
        lda #0
        sta ProfileCounter
        sta ProfileCounter + 1
        sta ProfileCounter + 2
        sta ProfileCounter + 3
        sta ProfileCtrl                 ; Start the counter
        rts

;=================================================================
; profiling_pause
;=================================================================

profiling_pause:
        lda #2
        sta ProfileCtrl                 ; Pause the counter
        rts

;=================================================================
; profiling_resume
;=================================================================

profiling_resume:
        lda #0
        sta ProfileCtrl                 ; Pause the counter
        rts

;=================================================================
; profiling_sample
;=================================================================

profiling_sample:
        ldx ProfileCounter              ; Count is in ms units
        inc profile_table_l, X
        bne profiling_sample_exit
        inc profile_table_h, X
profiling_sample_exit:
        rts

;=================================================================
; profiling_dump
;=================================================================

profiling_dump:
        ldx #0
        ldy #0
profiling_dump_loop:
        lda profile_table_h, X          ; Skip empty entries
        ora profile_table_l, X
        beq profiling_dump_next
        txa
        jsr HEXOUT
        lda #':'
        jsr OSWRCH
        lda profile_table_h, X
        jsr HEXOUT
        lda profile_table_l, X
        jsr HEXOUT
        jsr OSCRLF
        iny
        tya
        and #7
        bne profiling_dump_next
        JSR OSRDCH
profiling_dump_next:
        inx
        bne profiling_dump_loop
        JSR OSRDCH
        jsr OSCRLF
        rts

profile_table_l:
        .repeat 256
          .byte $0
        .endrep

profile_table_h:
        .repeat 256
          .byte $0
        .endrep
