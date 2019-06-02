; atmmmc2def.h Symbolic defines for AtoMMC2

; 2011-05-25, Phill Harvey-Smith.

; OS overrides
;
TOP         =$0d
PAGE        =$12
ARITHWK     =$23

; if ATOM_CRC_POLYNOMIAL is defined, *CRC will use it
; if not, it will use the original code which is faster, but ~30 bytes longer
ATOM_CRC_POLYNOMIAL = $2d


; these need to be in ZP
;
RWPTR       =$ac         ; W - data target vector
ZPTW        =$ae         ; [3] - general use temp vector, used by vechexs, RS, WS

LFNPTR      =$c9         ; W -pointer to filename (usually $140)
LLOAD       =$cb         ; W - load address
LEXEC       =$cd         ; W - execution address
LLENGTH     =$cf         ; W - byte length

SFNPTR      =$c9         ; W -pointer to filename (usually $140)
SLOAD       =$cb         ; W - reload address
SEXEC       =$cd         ; W - execute
SSTART      =$cf         ; W - data start
SEND        =$d1         ; W - data end + 1

CRC         =$c9         ; 3 bytes in ZP - should be ok as this addr only used for load/save??

RDCCNT      =$c9         ; B - bytes in pool - ie ready to be read from file
RDCLEN      =$ca         ; W - length of file supplying characters

HANDLER     =$d1         ; used by iterator.asm
TMPY        =$d5         ; used by iterator.asm

tmp_ptr3    =$D5
tmp_ptr5    =$D6
tmp_ptr6    =$D7

MONFLAG     =$ea         ; 0 = messages on, ff = off

NAME       =$140         ; sits astride the BASIC input buffer and string processing area.
NAME2      =$160

IRQVEC     =$204         ; we patch these (maybe more ;l)
COMVEC     =$206
RDCVEC     =$20a
LODVEC     =$20c
SAVVEC     =$20e

; DOS scratch RAM 3CA-3FC. As the AtoMMC interface effectively precludes the use of DOS..
;
FKIDX      =$3ca         ; B - fake key index
RWLEN      =$3cb         ; W - count of bytes to write
FILTER     =$3cd         ; B - dir walk filter


; FN       ADDR
;
OSWRCH     =$fff4
OSRDCH     =$ffe3
OSECHO     =$ffe6
OSCRLF     =$ffed
COSSYN     =$fa7d
COSPOST    =$fa76
RDADDR     =$fa65
CHKNAME    =$f84f
SKIPSPC    =$f876
RDOPTAD    =$f893
BADNAME    =$f86c
WSXFER2    =$f85C
COPYNAME   =$f818
HEXOUT4    =$f7ee
HEXOUT2    =$f7f1
HEXOUT     =$f802
HEXOUTS    =$f7fa
SPCOUT     =$f7fd
STROUT     =$f7d1

; I/O register base
;

.ifdef ALTADDR
AREG_BASE         = $b408
.else
AREG_BASE         = $b400
.endif

ACMD_REG       = AREG_BASE+CMD_REG
ALATCH_REG                      = AREG_BASE+LATCH_REG
AREAD_DATA_REG                  = AREG_BASE+READ_DATA_REG
AWRITE_DATA_REG                 = AREG_BASE+WRITE_DATA_REG
ASTATUS_REG       = AREG_BASE+STATUS_REG

; // Register definitions, these are offsets from 0xB400 on the Atom side.

CMD_REG                         =   $00
LATCH_REG                       =   $01
READ_DATA_REG                   =   $02
WRITE_DATA_REG                  =   $03
STATUS_REG                      =   $04

; // DIR_CMD_REG commands
CMD_DIR_OPEN                    =   $00
CMD_DIR_READ                    =   $01
CMD_DIR_CWD                     =   $02
CMD_DIR_GETCWD                  =   $03
CMD_DIR_MKDIR                   =   $04
CMD_DIR_RMDIR                   =   $05

; // RENAME commands
CMD_RENAME                      =   $08

; // CMD_REG_COMMANDS
CMD_FILE_CLOSE                  =   $10
CMD_FILE_OPEN_READ              =   $11
CMD_FILE_OPEN_IMG               =   $12
CMD_FILE_OPEN_WRITE             =   $13
CMD_FILE_DELETE                 =   $14
CMD_FILE_GETINFO                =   $15

CMD_INIT_READ                   =   $20
CMD_INIT_WRITE                  =   $21
CMD_READ_BYTES                  =   $22
CMD_WRITE_BYTES                 =   $23

; // READ_DATA_REG "commands"

; // EXEC_PACKET_REG "commands"
CMD_EXEC_PACKET                 =   $3F

; // SDOS_LBA_REG commands
CMD_LOAD_PARAM                  =   $40
CMD_GET_IMG_STATUS              =   $41
CMD_GET_IMG_NAME                =   $42
CMD_READ_IMG_SEC                =   $43
CMD_WRITE_IMG_SEC               =   $44
CMD_SER_IMG_INFO                =   $45
CMD_VALID_IMG_NAMES             =   $46
CMD_IMG_UNMOUNT                 =   $47

; // UTIL_CMD_REG commands
CMD_GET_CARD_TYPE               =   $80
CMD_GET_PORT_DDR                =   $A0
CMD_SET_PORT_DDR                =   $A1
CMD_READ_PORT                   =   $A2
CMD_WRITE_PORT                  =   $A3
CMD_GET_FW_VER                  =   $E0
CMD_GET_BL_VER                  =   $E1
CMD_GET_CFG_BYTE                =   $F0
CMD_SET_CFG_BYTE                =   $F1
CMD_READ_AUX                    =   $FD
CMD_GET_HEARTBEAT               =   $FE


; // Status codes
STATUS_OK                       =   $3F
STATUS_COMPLETE                 =   $40
STATUS_BUSY                     =   $80

ERROR_MASK                      =   $3F

; // To be or'd with STATUS_COMPLETE
ERROR_NO_DATA                   =   $08
ERROR_INVALID_DRIVE             =   $09
ERROR_READ_ONLY                 =   $0A
ERROR_ALREADY_MOUNT             =   $0A

; // STATUS_REG bit masks
; //
; // MMC_MCU_BUSY set by a write to CMD_REG by the Atom, cleared by a write by the MCU
; // MMC_MCU_READ set by a write by the Atom (to any reg), cleared by a read by the MCU
; // MCU_MMC_WROTE set by a write by the MCU cleared by a read by the Atom (any reg except status).
; //
MMC_MCU_BUSY                    =   $01
MMC_MCU_READ                    =   $02
MMC_MCU_WROTE                   =   $04

;// TUBE variables

TUBE_CTRL      =   $60          ; Tube control block address
TUBE_FLAG      =  $3CF          ; Tube enabled flag, set by atom tube host
TUBE_ENABLED   =   $5A          ; Tube enable magic value
TUBE_CLIENT_ID =   $DD          ; Client ID for AtoMMC2 used in tube protocol
