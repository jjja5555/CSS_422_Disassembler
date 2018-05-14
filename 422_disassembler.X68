*-----------------------------------------------------------
* Title      : 422 Disassembler 
* Written by : 
* Date       : 05/10/2018
* Description: Read string input and put that into Hexadecimal value as starting and ending address to 
*              decode.
*           
*       Update: - 05/12/2018  Martin Huang
*                   + Add user input stored start address in A5 and ending address in A6
*       Update: - 05/13/2018  Martin Huang
*                   + Decode: NOP, RTS   
*                   + Decode: EA   1) EA mode store in D4 and EA register stored in D5
*                   + EA mode:  0) Dn 
*                               1) An 
*                               2) (An)
*                               3) (An)+
*                               4) -(An)
*                               7) absolute_word, absolute_long, immediate data(haven't finished)
*                   + Decode: JSR
*       Update: - 05/14/2018  Martin Huang
*                   + Decode: NEG
*                   + Size handle: size must be stored in D6 for further use    
*                   + Decode: ASR, ASL, LSR, LSL, ROR, ROL (memory shift one bit) 
*                   + Decode: ASR, ASL, LSR, LSL, ROR, ROL (register shift)          
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program
    NEG.l   D1
    LSL     $400
    LSL     (A4)+
    LSL     -(A4)
    ROR     (A5)
    ASL     $00020000
    ASL.B   #$4,D5
    LSR.L   D5, D5
    CLR.L   D0
* Put program code here
* TEST CODE 

* -------------------------------------
* Display welcome message and check the first input address
UserStartAddress
    
    LEA     startInput, A1      * Prompt input for start address
    MOVE.B  #14, D0
    TRAP    #15

    *MOVEA.L #$00000000, A1      * Clear A1 to for user input with trap task #2
    MOVE.B  #2, D0
    TRAP    #15
    
    CLR.L   D2                  * D2 to store hexadecimal address
    CLR.B   D6                  * Use D6 as flag for error in input
    
    JSR     LOWER_CASE_CHECK    * branch to check input

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserStartAddress

    JSR     RANGE_CHECK         * branch to check range($00001000 to $00FFFFFF)

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserStartAddress

    *MOVEA.L #$00000000, A1      * Clear A1 
    MOVE.L  D2, A5              * Load accepted STARTING address into A5
 
* -------------------------------------
* Ccheck the second input address   
UserEndAddress
    LEA     endInput, A1      * Prompt input for end address
    MOVE.B  #14, D0
    TRAP    #15

    *MOVEA.L #$00000000, A1      * Clear A1 to for user input with trap task #2
    MOVE.B  #2, D0
    TRAP    #15
    
    CLR.L   D2                  * D2 to store hexadecimal address
    CLR.B   D6                  * Use D6 as flag for error in input (out of range OR non-Hex char): 1 == error, 0 == okay
    
    JSR     LOWER_CASE_CHECK    * branch to check input

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserEndAddress

    JSR     RANGE_CHECK         * branch to check range($00001000 to $00FFFFFF)

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserEndAddress
    
    JSR     DIFFERENCE_CHECK
    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserEndAddress

    *MOVEA.L #$00000000, A1      * Clear A1 
    MOVE.L  D2, A6              * Load accepted Ending address into A6

    MOVE.B  #0, $410             * Use $00000412 to store line count
* ------------------------------------------
* Check if address pointer reaches the end
* Move word size data into D3
* Move long size adderss into D2
* Use D4 to mask if necessary 
ReadMemory    
    
    
    CMPA.L  A5, A6              * check if reach the end
    BLE     END
    
    MOVE.L  A5, D2              * move address to D2  to display
    MOVE.W (A5)+, D3            * store data to D3 for further use
    MOVE.B  #8, $400            * use ($400) to store roatate count
    JSR Display_Address_L
    
    CLR.L   D2         
    MOVE.W  D3,D2               * move data to D2 to display
    MOVE.B  #4, $400            * reset ($400)
    
    LEA     space, A1      * space between address and data
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR DECODE
    
    *JSR SCREENSTOP
    
    LEA     nl, A1      * new line
    MOVE.B  #14, D0
    TRAP    #15
    
    JMP ReadMemory      * loop

* ---------------------------------------
* handle EA mode, moed must be stored in D4, and register must be stored in D5
EA_HANDLE
    CMPI.W  #0, D4
    BEQ     EA_Dn
    
    CMPI.W  #1, D4
    BEQ     EA_An
    
    CMPI.W  #2, D4
    BEQ     EA_AnIndirect

    CMPI.W  #3, D4
    BEQ     EA_Anplus
    
    CMPI.W  #4, D4
    BEQ     EA_minusAn
    
    CMPI.W  #7, D4
    BEQ     EA_AB_IM

    RTS

* ---------------------------------------
* EA data register, D5 stores register number
EA_Dn
    LEA     DDn, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D1
    MOVE.B  D5, D1
    JSR     DisplayNum
    MOVE.B  #6, D0
    TRAP    #15
    RTS

* ---------------------------------------
* EA address register, D5 stores register number
EA_An
    LEA     DAn, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D1
    MOVE.B  D5, D1
    JSR     DisplayNum
    MOVE.B  #6, D0
    TRAP    #15  
    RTS 
  
* ---------------------------------------
* EA address indirect with post incrementing, D5 stores register number
EA_Anindirect
    LEA     DAnplus, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D1
    MOVE.B  D5, D1
    JSR     DisplayNum
    MOVE.B  #6, D0
    TRAP    #15
    
    LEA     DAnplusN, A1     
    MOVE.B  #14, D0
    TRAP    #15 
    RTS
    
* ---------------------------------------
* EA address indirect with pre decrementing, D5 stores register number  
EA_Anplus
    LEA     DAnplus, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D1
    MOVE.B  D5, D1
    JSR     DisplayNum
    MOVE.B  #6, D0
    TRAP    #15
    
    LEA     DAnplusP, A1     
    MOVE.B  #14, D0
    TRAP    #15 
    RTS
* ---------------------------------------
* EA data register, D5 stores register number  
EA_minusAn
    LEA     DminusAn, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D1
    MOVE.B  D5, D1
    JSR     DisplayNum
    MOVE.B  #6, D0
    TRAP    #15
    
    LEA     DAnplusN, A1     
    MOVE.B  #14, D0
    TRAP    #15 
    RTS
    
* ---------------------------------------
* EA Absolute addressing and immediate data, D5 stores register number   
EA_AB_IM
    CMPI.B  #0, D5
    BEQ     EA_AB_WORD
    CMPI.B  #1, D5
    BEQ     EA_AB_LONG
    CMPI.B  #4, D5
    BEQ     EA_IM
    RTS
    
* ---------------------------------------
* EA Absolute addressing WORD, clear D2 to DISPLAY next word data     
EA_AB_WORD
    LEA     DAddress, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D2
    MOVE.W  (A5)+,D2
    JSR     Display_FFFF
    MOVE.B  #4, $400
    JSR Display_Address
    RTS
    
    
* ---------------------------------------
* EA Absolute addressing LONG, clear D5 to store next long data      
EA_AB_LONG
    LEA     DAddress, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D2
    MOVE.L  (A5)+,D2
    MOVE.B  #8, $400
    JSR Display_Address_L
    RTS

* ---------------------------------------
* EA Absolute addressing WORD, D5 stores register number     
EA_IM
    RTS
   
* ---------------------------------------
* handle size, size must be stored in D6
SIZE_HANDLE
    CMPI.B  #0, D6
    BEQ     BYTE_DISPLAY
    CMPI.B  #1, D6
    BEQ     WORD_DISPLAY    
    CMPI.B  #2, D6
    BEQ     LONG_DISPLAY
    RTS
* --------------------------------------
* Display byte .B after instruction    
BYTE_DISPLAY
    LEA     DByte, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS

* --------------------------------------
* Display byte .W after instruction 
WORD_DISPLAY
    LEA     DWord, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS
   
* --------------------------------------
* Display byte .L after instruction 
LONG_DISPLAY
    LEA     DLong, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS

* -------------------------------------
* Start of decoding      Use D4 to mask
DECODE
    MOVE.W  D3, D4
    
    CMPI.L  #$4E75, D3          * decode RTS
    BEQ     DISPLAY_RTS
    
    CMPI.L  #$4E71, D3          * decode NOP
    BEQ     DISPLAY_NOP

    ANDI.W  #$FFC0, D4          * decode JSR
    CMPI.W  #$4E80, D4
    BEQ     DISPLAY_JSR
    
    MOVE.W  D3, D4
    ANDI.W  #$FF00, D4          * decode NEG
    CMPI.W  #$4400, D4
    BEQ     DISPLAY_NEG    
    
    MOVE.W  D3, D4
    ANDI.W  #$FF00, D4          * decode CLR
    CMPI.W  #$4200, D4
    BEQ     DISPLAY_CLR    
  
    MOVE.W  D3, D4
    ANDI.W  #$F0C0, D4
    CMPI.W  #$E0C0, D4
    BEQ     DISPLAY_ROTATION_M    * decode ASL, ASR, LSL, LSR, ROL, ROR memory shift one bit, use D6 to store rotation type
    
    MOVE.W  D3, D4
    ANDI.W  #$F000, D4
    CMPI.W  #$E000, D4
    BEQ     DISPLAY_ROTATION_R    * decode ASL, ASR, LSL, LSR, ROL, ROR register shift, use D6 to store size type, D7 to store rotation type
   
    JSR Display_Address         * display data
    RTS



* -------------------------------------
* Display RTS
DISPLAY_RTS
    LEA     DRTS, A1      
    MOVE.B  #14, D0
    TRAP    #15
    RTS

* -------------------------------------
* Display NOP
DISPLAY_NOP
    LEA     DNOP, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
* ------------------------------------
* Display JSR and its EA mode 2) (An) 7) .W  7) .L 
DISPLAY_JSR
    LEA     DJSR, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register
    
    LSR.W   #3, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    ANDI.W  #$0007, D5          * mask last 3 bits
    
    JSR     EA_HANDLE    
    RTS
    
* -------------------------------------
* Display NEG and its size and its EA mode 1) Dn 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L
DISPLAY_NEG
    LEA     DNEG, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #6, D6              * no need to mask it is already a size
    
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register
    
    LSR.W   #3, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    ANDI.W  #$0007, D5          * mask last 3 bits
    
    JSR     EA_HANDLE
    RTS
    
* ---------------------------------------
* Display rotation  (memory shift) mode base on its condition
DISPLAY_ROTATION_M

    CLR.L   D6              * rotation check
    MOVE.W  D3, D6
    LSR.W   #8, D6
    ANDI.B  #$0F, D6  
    JSR     ROTATION_CHECK
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register
    
    LSR.W   #3, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    ANDI.W  #$0007, D5          * mask last 3 bits
    
    JSR     EA_HANDLE
    RTS
    
* ---------------------------------------
* Display rotation  (register shift) mode base on its condition
DISPLAY_ROTATION_R
    CLR.L   D6              * rotation check
    MOVE.W  D3, D6
    MOVE.W  D6, D7
    ROR.W   #8, D7
    ANDI.W  #$0001, D7

    ROR.W   #2, D6
    ANDI.W  #$0006, D6
    ADD.B   D7, D6
    JSR     ROTATION_CHECK
    
    CLR.L   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #6, D6              * no need to mask it is already a size
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     IORR
    
    
    CLR.L   D5                  * Clear register
    CLR.L   D4                  * mode set to 000, register shift only works for register

    MOVE.W  D3, D5              * D5 to store EA register
    
    ANDI.W  #$0007, D5          * mask last 3 bits
    
    JSR     EA_HANDLE
    RTS
* -------------------------------------
* Display CLR and its size and its EA mode 1) Dn 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L   
DISPLAY_CLR
    LEA     DCLR, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #6, D6              * no need to mask it is already a size
    
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register
    
    LSR.W   #3, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    ANDI.W  #$0007, D5          * mask last 3 bits
    
    JSR     EA_HANDLE
    RTS

* -----------------------------------
* Check if the address store in D2 is in range 1000 - FFFFFF
RANGE_CHECK
    CMP.L   #$FFFFFF, D2        * check upper bound
    BGT     RANGE_ERROR
    CMP.L   #$1000, D2          * check lower bound
    BLT     RANGE_ERROR
    MOVE.L  D2, D5              * check odd
    AND.L   #$01, D5
    BHI     ODD_ERROR   
    MOVE.B  #0, D6              * Set error flag as okay
    RTS
    
* --------------------------------------------------
* Check if end > start
DIFFERENCE_CHECK
    CMP.L   A5, D2
    BLE     DIFFERENCE_ERROR
    MOVE.B  #0, D6              * Set error flag as okay
    RTS
    
* --------------------------------------------------
* Display error message for end < start
DIFFERENCE_ERROR
    LEA     DifferentError, A1
    MOVE.B  #14, D0
    TRAP    #15
    MOVE.B  #1, D6      * use D2 as a flag to check input
    RTS
* ---------------------------------------------
* Display range error message
RANGE_ERROR
    LEA     RangeError, A1
    MOVE.B  #14, D0
    TRAP    #15
    MOVE.B  #1, D6      * set error flag as fault
    RTS

* --------------------------------------------------
* Display odd error message
ODD_ERROR
    LEA     OddError, A1
    MOVE.B  #14, D0
    TRAP    #15
    MOVE.B  #1, D6      * use D6 as a flag to check input
    RTS

* -------------------------------------------
* Check lower case character
LOWER_CASE_CHECK
    
    CMP.B   #102, (A1)      * check lower case f = 102. If the character is greater than 102 it is not hex
    BGT     INPUT_ERROR
    CMP.B   #97, (A1)      *  check lower case a = 97. If the character is less than 97, it might be upper case character. Need further check.
    BLT     UPPER_CASE_CHECK
    
    SUB.B   #87, (A1)      * Subtract 87 to convert lower case char to hex number

    JSR     ADDRESS_CONFIGURE   * Jump to subroutine for properly configure the address

    SUB.B   #1, D1          * minus 1 , if D1 = 0, end converting char to number
    ADDQ.L  #1, A1          * Increment address pointer
    CMP.B   #0, D1          * Check if D1 == 0, if not continue read char.
    BGT     LOWER_CASE_CHECK
    RTS
    
* -------------------------------------------
* Check upper case character
UPPER_CASE_CHECK
    CMP.B   #70, (A1)      * check upper case f = 70. If the character is greater than 70 it is not hex
    BGT     INPUT_ERROR
    CMP.B   #65, (A1)      * check lower case a = 65. If the character is less than 65 it is not hex
    BLT     NUMBER_CHECK
    SUB.B   #55, (A1)      * Subtract 55 to convert upper case char to hex number

    JSR     ADDRESS_CONFIGURE   

    SUB.B   #1, D1          * minus 1
    ADDQ.L  #1, A1          * Increment address pointer
    CMP.B   #0, D1          * Check if D1 == 0
    BGT     LOWER_CASE_CHECK
    RTS

* -------------------------------------------
* Check number
NUMBER_CHECK
    CMP.B   #57, (A1)      * check number 9. If the character is greater than 57 it is not number
    BGT     INPUT_ERROR
    CMP.B   #48, (A1)      * check number 0. If the character is less than 48 it is not number
    BLT     INPUT_ERROR
    SUB.B   #48, (A1)      * Subtract 48 to convert number to equivalent Hex value

    JSR     ADDRESS_CONFIGURE     * Jump to subroutine for properly configure the address

    SUB.B   #1, D1          * Similar to 1st input check
    ADDQ.L  #1, A1
    CMP.B   #0, D1
    BGT     LOWER_CASE_CHECK
    RTS

* --------------------------------------------------
* Properly configure address
ADDRESS_CONFIGURE
    MULS    #$10, D2        * shift left
    ADD.B   (A1), D2
    RTS

* --------------------------------------------------
* Display error message for wrong input Hex and set error flag
INPUT_ERROR
    LEA     typeInputError, A1
    MOVE.B  #14, D0
    TRAP    #15
    MOVE.B  #1, D6      * use D2 as a flag to check input
    RTS
    
* --------------------------------------------------
* Display hex. hex must be stored in D2 and number of rotation in memory $400
Display_Address
    ROL.W   #4,D2       * Rotate the first hex number to the back so we can read    
    MOVE.B  D2, D1      * D1 to store the byte data
    ANDI.B  #$0F,D1     * AND the byte data so we can only see the first one    
    CMPI.B  #$A,D1      * check if it is greater than A
    JSR     DisplayChar * If yes jmp to display (A - F)
    CMPI.B  #$A,D1      * check if it is less than A
    BLT     DisplayNum  * If yes jmp to display (0 - 9)
    MOVE.B  #6,D0       * TRAP 6 display character
    TRAP    #15         
    SUB.B   #1, $400
    CMPI.B  #0, $400   *check if roatation done
    BNE Display_Address
    RTS
    
* --------------------------------------------------
* Display hex. hex must be stored in D2 and number of rotation in memory $400
Display_Address_L
    ROL.L   #4,D2       * Rotate the first hex number to the back so we can read    
    MOVE.B  D2, D1      * D1 to store the byte data
    ANDI.B  #$0F,D1     * AND the byte data so we can only see the first one    
    CMPI.B  #$A,D1      * check if it is greater than A
    JSR     DisplayChar * If yes jmp to display (A - F)
    MOVE.B  #6,D0       * TRAP 6 display character
    TRAP    #15         
    SUB.B   #1, $400
    CMPI.B   #0, $400   *check if roatation done
    BNE Display_Address_L
    RTS

* ----------------------------------------
* determine what rotation it is  information must be store in D6
* 0 = ASR, 1 = ASL, 2 = LSR, 3 = LSL, 6 = ROR, 7 = ROL
ROTATION_CHECK   
    CMPI.B  #0, D6
    BEQ     Display_ASR
    CMPI.B  #1, D6
    BEQ     Display_ASL
    CMPI.B  #2, D6
    BEQ     Display_LSR
    CMPI.B  #3, D6
    BEQ     Display_LSL
    CMPI.B  #6, D6
    BEQ     Display_ROR
    CMPI.B  #7, D6
    BEQ     Display_ROL
    RTS
    
IORR
    MOVE.W  D3, D5
    ANDI.W  #$0020, D5
    CMPI.W  #$0020, D5
    BEQ     REGISTER_SHIFT
    
    LEA     DIM, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.W  D3, D5
    ROL.W   #7, D5
    ANDI    #$0007, D5
    
    CLR.L   D1
    MOVE.B  D5, D1
    JSR     DisplayNum
    MOVE.B  #6, D0
    TRAP    #15
    
    LEA     DComma, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
REGISTER_SHIFT
    LEA     DDn, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.W  D3, D5
    ROL.W   #7, D5
    ANDI    #$0007, D5
    
    CLR.L   D1
    MOVE.B  D5, D1
    JSR     DisplayNum
    MOVE.B  #6, D0
    TRAP    #15
    
    LEA     DComma, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    RTS
    
Display_ASR  
    LEA     DASR, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
Display_ASL  
    LEA     DASL, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
Display_LSR
    LEA     DLSR, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
Display_LSL
    LEA     DLSL, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
Display_ROR
    LEA     DROR, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
Display_ROL
    LEA     DROL, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS
    
DisplayChar
    CMPI    #$A, D1
    BLT     DisplayNum
    ADD.B   #55,D1
    RTS
    
    
DisplayNum
    ADD.B   #48,D1
    RTS
    
Display_FFFF
    CMPI.W  #$8000, D2
    BLT     FFFF
    
    RTS
    
FFFF
    LEA     DFFFF, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS
 

       
END
    LEA     endDisplay, A1
    MOVE.B  #14, D0
    TRAP    #15
    
* -----------------------------------------------------------------------------------------------------------
* Variables and constants 
* -----------------------------------------------------------------------------------------------------------
CR              EQU     $0D     * CR
LF              EQU     $0A     * LF
NL              DC.B    CR,LF,0
space           DC.B    ' ',0
zero            DC.B    '0000', 0
startInput      DC.B    'Welcome to 68k disassembler! Christopher, Martin, Patric', CR, LF 
                DC.B    'Please enter starting address in Hex($1000 to $FFFFFF): ', 0
endInput        DC.B    'Please enter ending address in Hex(must greater than start address): ', 0
typeInputError  DC.B    'ERROR: Your entered address is not a hex!', CR, LF, 0
RangeError       DC.B    'ERROR: Address is out of range', CR, LF, 0
DifferentError   DC.B    'ERROR: Ending address must be greater than Starting address', CR, LF, 0
OddError         DC.B    'ERROR: Address must be even ', CR, LF, 0
endDisplay      DC.B     'You have finihsed the decoding', CR, LF,0
enterMessage    DC.B     'Please hit enter to continue', CR, LF, 0
nullString      DC.B        '', CR, LF, 0

* INSTRUCTION SET
DRTS            DC.B    'RTS',0
DNOP            DC.B    'NOP',0
DJSR            DC.B    'JSR',0
DNEG            DC.B    'NEG',0
DCLR            DC.B    'CLR',0

* Display EA mdode
DDn             DC.B    'D',0
DAn             DC.B    'A',0
DAnplus         DC.B    '(A',0
DAnplusN        DC.B    ')',0
DAnplusP        DC.B    ')+',0
DminusAn        DC.B    '-(A',0
DFFFF           DC.B    'FFFF',0
DAddress        DC.B    '$',0
DIM             DC.B    '#$',0
DComma          DC.B    ',',0

* Display size
DByte           DC.B    '.B', 0
DWord           DC.B    '.W', 0
DLong           DC.B    '.L', 0

* Display rotation type
DASR            DC.B    'ASR', 0
DASL            DC.B    'ASL', 0
DLSR            DC.B    'LSR', 0
DLSL            DC.B    'LSL', 0
DROR            DC.B    'ROR', 0
DROL            DC.B    'ROL', 0
    END    START        ; last line of source












*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
