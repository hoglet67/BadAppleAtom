;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Variable declaration
;
LFNPTR		=$c9		; W -pointer to filename (usually $140)
LLOAD		=$cb		; W - load address
LEXEC		=$cd		; W - execution address
LLENGTH		=$cf		; W - byte length

RWPTR		=$ac		; W - data target vector
NAME		=$140		; sits astride the BASIC input buffer and string processing area.

IRQVEC		=$204		; we patch these (maybe more ;l)
COMVEC		=$206
RDCVEC		=$20a
LODVEC		=$20c
SAVVEC		=$20e


;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Open file for reading
;
;
open_file_read:
   lda #CMD_FILE_OPEN_READ	; Set command open file for reading
   jsr open_file		; Open file with filename in $140
   jmp expect64orless		; Check for error



;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Send filename and open file for reading/writing
;
; $140 = name
; a = read/write $01 = read, $11 = write
;
open_file:
   pha				; Save read/write mode
   jsr send_name		; Send filename to AtoMMC, terminated with 0
   pla				; Restore read/write mode
   SLOWCMD 			; Send command and wait until ready
   rts

send_name:
   jsr prepare_write_data	; Prepare to write filename to AtoMMC

   ldx #0			; Send filename
   beq @pumpname
@nextchar:
   writeportFAST AWRITE_DATA_REG
   inx
@pumpname:
   lda NAME,x			; Read filename from filename buffer
   cmp #$0d			; Check for end of string
   bne @nextchar

   lda #0			; Terminate the string
   writeportFAST AWRITE_DATA_REG
	jsr interwritedelay
   jmp interwritedelay



;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Close a file
;
closefile:
   SLOWCMDI CMD_FILE_CLOSE	; Close the file 
   jmp expect64orless		; Check for error



;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Read data to memory
;
; a = number of bytes to read (0 = 256)
; (RWPTR) points to target
;
read_block:
   tax				; Save byte counter

   ; ask PIC for (A) bytes of data (0=256)
   writeportFAST ALATCH_REG	; Set ammount to read
   jsr interwritedelay
   SLOWCMDI CMD_READ_BYTES	; Set command
    
   jsr expect64orless		; Check for error
   jsr prepare_read_data	; Tell pic to release the data we just read

   ; Read data block
   ldy  #0
@loop:
   readportFAST	AREAD_DATA_REG	; Then read byte
;	eor #$ff
   sta (RWPTR),y		; Store byte in memory
   iny				; Increment memory pointer
   dex				; Decrement byte counter
   bne @loop			; Repeat

   rts


;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Short delay
;
; Enough to intersperse 2 writes to the FATPIC.
;
interwritedelay:
   lda  #8			; Changed for 2Mhz operation
   sec
@loop:
   sbc #1
   bne @loop
   rts



;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Perform slow command initialisation and expect a return code <= 64
;
expect64orless:
   cmp #STATUS_COMPLETE+1	; Check if command successfull
   bcs reportDiskFailure	; If not, report error
   rts

reportDiskFailure:
;just mess screen for now.

	pha
	lda #0
	sta $b000
	pla
	jsr $f802
	jmp$c2b2


    ldy #0
    lda #$aa
@lp:
   sta $8000,y
   iny
   bne @lp

	jmp end_file


;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~;~~
;
; Prepare AtoMMC for reading or writing data
;
prepare_read_data:
   lda 	#CMD_INIT_READ		; Prepare for reading
   writeportFAST ACMD_REG				
   jsr interwritedelay
   jmp interwritedelay


prepare_write_data: 
   lda #CMD_INIT_WRITE		; Prepare for writing
   writeportFAST ACMD_REG 			
   jsr interwritedelay
   jmp interwritedelay
 
