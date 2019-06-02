
;=================================================================

         ViaT1CounterL = $b804
         ViaT1CounterH = $b805
         ViaACR        = $b80b
         ViaIER        = $b80e

         SIDBase       = $bdc0
         SIDMusicLoad  = $1000

         ; SIDIrqTime    = 10000

         ; Slow down by 10% so SID length matches Video length
         ; Why is this necessary???
         SIDIrqTime    = 11050

TimerLo:
        .byte <(SIDIrqTime), <(SIDIrqTime * 2), <(SIDIrqTime * 4)

TimerHi:
        .byte >(SIDIrqTime), >(SIDIrqTime * 2), >(SIDIrqTime * 4)

SystemSpeed:
        .byte 0

OldVec:
        .byte 0,0


InitVIA:

        sei
        jsr ResetSID

        lda IRQVEC
        sta OldVec

        lda IRQVEC + 1
        sta OldVec + 1

        lda #<TimerISR
        sta IRQVEC
        lda #>TimerISR
        sta IRQVEC + 1

        JSR $FE66
        lda #$FF
        sta ViaT1CounterL
        sta ViaT1CounterH
        jsr $FE66
        lda ViaT1CounterH
        ; at 1MHZ it will be 255 -  16666/256 = 190
        ; at 2MHZ it will be 255 -  33333/256 = 125
        ; at 4MHz it will be 255 -  66666/256 = -5 = 251
        ldx #2
        cmp #220
        bcs VsyncTestDone
        dex
        cmp #150
        bcc VsyncTestDone
        dex
VsyncTestDone:
        stx SystemSpeed       ; 0 = 1MHz, 1 = 2MHz, 2 = 4MHz
        lda TimerLo,X         ; 10ms timer interrupts
        sta ViaT1CounterL
        lda TimerHi,X
        sta ViaT1CounterH

        lda ViaACR
        and #$7f
        ora #$40
        sta ViaACR
        lda #$c0
        sta ViaIER
        lda #$00
        tax
        jsr SIDMusicLoad
        cli
        rts

ResetVIA:
        sei
        jsr ResetSID

        lda OldVec
        sta IRQVEC
        lda OldVec + 1
        sta IRQVEC + 1
        lda #$40
        sta ViaIER

        cli
        rts

ISRFlag:
        .byte 0

TimerISR:
        lda ViaT1CounterL


        lda ISRFlag
        eor #$80
        sta ISRFlag
        bpl TimerISRExit

        txa
        pha
        tya
        pha
        jsr SIDMusicLoad + 3
        pla
        tay
        pla
        tax

TimerISRExit:
        pla
        rti

ResetSID:
        ldx #$1f
        lda #$00
ResetSIDLoop:
        sta SIDBase,x
        dex
        bpl ResetSIDLoop
        rts
