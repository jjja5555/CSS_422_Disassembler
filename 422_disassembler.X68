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
*                   + Decode: LEA
*                   + Decode: CMP
*                   + Decode: MOVEQ, ADDQ, ADDI
*                   + Decode: ADDA
*                   + added: address control, word size (0 - 7fff) (ffff8000 - ffffffff)
*                   + Decode: MOVEA, MULS, MULU, DIVU
*                   + Decode: BCC, BGT, BLE
*                   + Decode: MOVE
*                   + Decode: MOVEM         4880 MASK FB80
*                   + Decode: AND
*                   + Decode: OR
*                   + Decode: ADD
*                   + Decode: SUB
*       Update:  - 05/15/2018 Martin Huang
*                   + Debug:  MOVEM
*                   + Debug:  ROTATION 000 represent number 8
*       Update:  - 05/16/2018 Martin Huang
*                   + Update: Now using BCS to detect registerList in MOVEM
*                   + Bug fixed: word addressing, ANDI, ORI
*        Update:  - 05/24/2018 Martin
*                   + Debug:  MOVEM
*                   +         It works under every condition 
<<<<<<< HEAD
*                   + Debug:  MOVE, Now it can identify MOVEA and MOVE
=======
*       Update:   - 5/26/2018 Chris
*                   +Modified so data outputs one page at a time
*                   +Modified so after decoding program prompts user to go again
>>>>>>> 21d8566de4a0f28e425408420bb98896636302ac
*-----------------------------------------------------------
START      ORG    $1000     *First instruction of program
                    
            SUB.W	(A4),D6
            ADD.W   (A4),D6

    		MOVE.B	D0,D1
	
    		AND.B	#$10,$4568
    		OR.W	#$10,$4568
    
    
* -------------------------------------
* Display welcome message and check the first input address
UserStartAddress
    
    LEA     startInput, A1      * Prompt input for start address
    MOVE.B  #14, D0
    TRAP    #15
    MOVEA.L #$0, A1      * Clear A1 so data at address doesn't get modified
    
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
    MOVE.L  D2, A5              * Load accepted STARTING address into A5
 
* -------------------------------------
* Ccheck the second input address   
UserEndAddress
    LEA     endInput, A1      * Prompt input for end address
    MOVE.B  #14, D0
    TRAP    #15

    MOVEA.L #$0, A1      * Clear A1 so data at address doesn't get modified
    MOVE.B  #2, D0
    TRAP    #15
    
    CLR.L   D2                  * D2 to store hexadecimal address
    CLR.B   D6                  * Use D6 as flag for error in input (out of range OR non-Hex char): 1 == error, 0 == okay
    
    * TODO 
*    CMP.B   #102, (A1)      * check lower case f = 102. If the character is greater than 102 it is not hex
*    BGT     INPUT_ERROR
*    
*    CMP.B   #97, (A1)      * check lower case f = 102. If the character is greater than 102 it is not hex
*    BGE     INPUT_ERROR
    
    JSR     LOWER_CASE_CHECK    * branch to check input

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserEndAddress

    JSR     RANGE_CHECK         * branch to check range($00001000 to $00FFFFFF)

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserEndAddress
    
    JSR     DIFFERENCE_CHECK
    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserEndAddress

    MOVE.L  D2, A6              * Load accepted Ending address into A6

    MOVE.B  #0, $410             * Use $00000412 to store line count
    
    MOVEA.W #$600,A2             *Address to hold counter for lines printed per page
    MOVE.B  #$1D,(A2)           *0x20 lines per page 
* ------------------------------------------
* Check if address pointer reaches the end
* Move word size data into D3
* Move long size adderss into D2
* Use D4 to mask if necessary 
ReadMemory    
    MOVEA.W #$600,A2             *move counter variabled to A2
    SUB.B   #1,(A2)             *decrement lines-per-page counter
    CMP.B   #0,(A2)             *Check if lines-per-page counter has reached 0
    BEQ     WAIT_FOR_PROMPT     *wait for prompt to continue output 

RETURN_FROM_PROMPT
    CMPA.L  A5, A6              * check if reach the end
    BLE     DECODING_FINISHED
    
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

*----------------------------------------------------------------------------
*Outputs prompt after the screen fills with output. Waits until user responds
WAIT_FOR_PROMPT
    LEA     enterMessage,A1
    MOVE.B  #14,D0
    Trap #15
    MOVEA.L #0,A1
    MOVE.B  #2,D0
    Trap #15 
    MOVE.B  #$1D,(A2)      
    BRA RETURN_FROM_PROMPT

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
    LEA     DIM, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     IM_SIZE
    RTS
   
IM_SIZE
    CMPI.B  #2, D6
    BEQ     IM_LONG
    
    CLR.L   D2
    MOVE.W  (A5)+,D2
    MOVE.B  #4, $400
    JSR Display_Address
    
    RTS
IM_LONG
    CLR.L   D2
    MOVE.L  (A5)+,D2
    MOVE.B  #8, $400
    JSR Display_Address_L
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
    
    CMPI.W  #$4E75, D3          * decode RTS
    BEQ     DISPLAY_RTS
    
    CMPI.W  #$4E71, D3          * decode NOP
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
    
    MOVE.W  D3, D4
    ANDI.W  #$F1C0, D4          * decode LEA
    CMPI.W  #$41C0, D4
    BEQ     DISPLAY_LEA         
    
    MOVE.W  D3, D4              * decode CMP
    ANDI.W  #$F000, D4
    CMPI.W  #$B000, D4
    BEQ     DISPLAY_CMP
    
    MOVE.W  D3, D4              * decode MOVEQ
    ANDI.W  #$F000, D4
    CMPI.W  #$7000, D4
    BEQ     DISPLAY_MOVEQ
    
    MOVE.W  D3, D4              * decode ADDQ
    ANDI.W  #$F000, D4
    CMPI.W  #$5000, D4
    BEQ     DISPLAY_ADDQ
    
    MOVE.W  D3, D4              * decode ADDI
    ANDI.W  #$FF00, D4
    CMPI.W  #$0600, D4
    BEQ     DISPLAY_ADDI
    
    MOVE.W  D3, D4              * decode SUBI
    ANDI.W  #$FF00, D4
    CMPI.W  #$0400, D4
    BEQ     DISPLAY_SUBI
    
    MOVE.W  D3, D4              * decode ANDI
    ANDI.W  #$FF00, D4
    CMPI.W  #$0200, D4
    BEQ     DISPLAY_ANDI
    
    MOVE.W  D3, D4              * decode ORI
    ANDI.W  #$FF00, D4
    CMPI.W  #$0000, D4
    BEQ     DISPLAY_ORI
    
    MOVE.W  D3, D4              * decode ADDA
    ANDI.W  #$F0C0, D4
    CMPI.W  #$D0C0, D4
    BEQ     DISPLAY_ADDA     

    MOVE.W  D3, D4              * decode MOVEA
    ANDI.W  #$F1C0, D4
    CMPI.W  #$3040, D4
    BEQ     DISPLAY_MOVEA    
    ANDI.W  #$F1C0, D4
    CMPI.W  #$2040, D4
    BEQ     DISPLAY_MOVEA    
    
    MOVE.W  D3, D4              * decode MULS/ MULU
    ANDI.W  #$F0C0, D4
    CMPI.W  #$C0C0, D4
    BEQ     DISPLAY_MUL
    
    MOVE.W  D3, D4              * decode DIVU
    ANDI.W  #$F0C0, D4
    CMPI.W  #$80C0, D4
    BEQ     DISPLAY_DIVU        
    
    MOVE.W  D3, D4              * decode BXX
    ANDI.W  #$F000, D4
    CMPI.W  #$6000, D4
    BEQ     DISPLAY_BXX  
    
    MOVE.W  D3, D4              * decode MOVE
    ANDI.W  #$F000, D4
    CMPI.W  #$1000, D4
    BEQ     DISPLAY_MOVE  
    CMPI.W  #$3000, D4
    BEQ     DISPLAY_MOVE 
    CMPI.W  #$2000, D4
    BEQ     DISPLAY_MOVE
    
    MOVE.W  D3, D4              * decode AND
    ANDI.W  #$F000, D4
    CMPI.W  #$C000, D4
    BEQ     DISPLAY_AND  
    
    MOVE.W  D3, D4              * decode OR
    ANDI.W  #$F000, D4
    CMPI.W  #$8000, D4
    BEQ     DISPLAY_OR

    MOVE.W  D3, D4              * decode ADD
    ANDI.W  #$F000, D4
    CMPI.W  #$D000, D4
    BEQ     DISPLAY_ADD
    
    MOVE.W  D3, D4              * decode SUB
    ANDI.W  #$F000, D4
    CMPI.W  #$9000, D4
    BEQ     DISPLAY_SUB
    
    
    MOVE.W  D3, D4              * decode MOVEM
    ANDI.W  #$FB80, D4
    CMPI.W  #$4880, D4
    BEQ     DISPLAY_MOVEM
          
    
   
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
    LSR.W   #6, D6              
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
* ---------------------------------------
* Display LEA and its EA mode   2) (An) 7) .W .L
DISPLAY_LEA
    LEA     DLEA, A1
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
    
    LEA     DComma, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.W  #1, D4
    MOVE.W  D3, D5              * D5 to store EA register
    ROL.W   #7, D5
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE
    RTS

* -----------------------------------
* Display CMP and its size and its EA mode 1) Dn 2) An 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L 7) immediate 
DISPLAY_CMP   
    LEA     DCMP, A1
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
    
    LEA     DComma, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.W  #0, D4
    MOVE.W  D3, D5              * D5 to store EA register
    ROL.W   #7, D5
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE   
    RTS
    
* -----------------------------------
* Display MOVEQ    
DISPLAY_MOVEQ
    LEA     DMOVEQ, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     DIM, A1        
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D2              * 8 bit number
    MOVE.B  D3, D2          * Move last 8 bits to display
    MOVE.B  #4, $400
    JSR Display_Address
    
    LEA     DComma, A1      * comma
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.W  #0, D4
    MOVE.W  D3, D5              * D5 to store EA register
    ROL.W   #7, D5
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE   
    
    RTS   
    
* -----------------------------------
* Display ADDQ and its size and its EA mode 1) Dn 2) An 3) (An) 4) (An)+ 5) -(An) 7) .L 7) .W
DISPLAY_ADDQ
    LEA     DADDQ, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     DIM, A1        
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D2              * 8 bit number
    ROL.W   #7, D2
    ANDI.W  #$0007, D2          * mask last 3 bits
    CMPI.B  #0, D2
    JSR     ZERO2EIGHT
    MOVE.B  #4, $400
    JSR Display_Address
    
    LEA     DComma, A1      * comma
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
* Display ADDI and its size and its EA mode 1) Dn 2) An 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L      7) IMMEDIATE
DISPLAY_ADDI
    LEA     DADDI, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #6, D6              * no need to mask it is already a size
    
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     DIM, A1        
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     LONG_CHECK
    
    LEA     DComma, A1      * comma
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
* Display ANDI and its size and its EA mode 1) Dn 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L   
DISPLAY_ANDI
    LEA     DAND, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #6, D6              * no need to mask it is already a size
    
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     DIM, A1        
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     LONG_CHECK
    
    LEA     DComma, A1      * comma
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
* Display ORI and its size and its EA mode 1) Dn 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L   
DISPLAY_ORI
    LEA     DOR, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #6, D6              * no need to mask it is already a size
    
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     DIM, A1        
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     LONG_CHECK
    
    LEA     DComma, A1      * comma
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
* Display SUBI and its size and its EA mode 1) Dn 2) An 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L      7) IMMEDIATE
DISPLAY_SUBI
    LEA     DSUBI, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #6, D6              * no need to mask it is already a size
    
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    LEA     DIM, A1        
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     LONG_CHECK
    
    LEA     DComma, A1      * comma
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
* Display ADDA and its size and its EA mode 1) Dn 2) An 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L    7) immediate  
DISPLAY_ADDA
    LEA     DADDA, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store size 00 B 01 W 10 L
    LSR.W   #8, D6              * no need to mask it is already a size
    ANDI.W  #1, D6
    ADDQ.B  #1, D6
    
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
    
    LEA     DComma, A1      * comma
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  #1, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register    
    ROL.W   #7, D5              * rotate for EA mode
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE
    
    RTS   

* -----------------------------------
* Display MOVEA and its size and its EA mode 1) Dn 2) An 3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L    7) immediate  
DISPLAY_MOVEA
    LEA     DMOVEA, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store size 00 B 01 W 10 L
    ROL.W   #4, D6              * no need to mask it is already a size
    ANDI.W  #3, D6   
    JSR     MOVE_SIZE
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
    
    LEA     DComma, A1      * comma
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  #1, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register    
    ROL.W   #7, D5              * rotate for EA mode
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE
    
    RTS  

* -----------------------------------
* Display MUL and modes (MULS OR MULU) and its EA mode 1) Dn  3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L    7) immediate 
DISPLAY_MUL
    LEA     DMUL, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store MODE   MULS = 7 MULU = 3
    LSR.W   #6, D6              
    ANDI.W  #7, D6
    
    JSR     S_U_HANDLE
    
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
    
    LEA     DComma, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.W  #0, D4
    MOVE.W  D3, D5              * D5 to store EA register
    ROL.W   #7, D5
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE   
    RTS
    
* -----------------------------------
* Display DIVU and its EA mode 1) Dn  3) (An) 4) (An)+ 5) -(An) 7) .W 7) .L    7) immediate 
DISPLAY_DIVU
    LEA     DDIVU, A1
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
    
    LEA     DComma, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.W  #0, D4
    MOVE.W  D3, D5              * D5 to store EA register
    ROL.W   #7, D5
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE   
    RTS
* -----------------------------------------
* Display branch condition and the displacement
DISPLAY_BXX
    MOVE.W  D3, D4
    ANDI.W  #$0F00, D4
    JSR     BXX_CONDITION
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     DISPLACEMENT_HANDLE
    
    RTS
* -------------------------------------------
* Display MOVE instruction and source and destination EA mode
DISPLAY_MOVE
    LEA     DMOVE, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store size 00 B 01 W 10 L       01 11 10
    LSR.W   #8, D6              * shift size right
    LSR.W   #4, D6              * shift again
    JSR     MOVE_SIZEE
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
    
    LEA     DComma, A1      * comma
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register    
    ROR.W   #6, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    
    ROL.W   #7, D5
    ANDI.   #$0007, D5
    JSR     EA_HANDLE
    
    RTS

MOVE_SIZEE
    CMPI.B  #1, D6
    BEQ     CBYTE
    CMPI.B  #3, D6
    BEQ     CWORD
    RTS
    
CBYTE   
    MOVE.B  #0, D6
    RTS
CWORD
    MOVE.B  #1, D6
    RTS
    
* -------------------------------------------
* Display MOVEM PUSH AND POP, WORKING EA MODE 2) (An) 3) (An)+ 4) -(An) 7) .W 7) .W
* REGISTER LOCATIONS are stored in D7
DISPLAY_MOVEM 
    LEA     DMOVEM, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D6
    MOVE.B  D3, D6              * D6 to store size 00 B 01 W 10 L       01 11 10
    LSR.W   #6, D6              * shift size right
    SUBQ    #1, D6
    JSR     SIZE_HANDLE
    
    MOVE.W  (A5)+, D7   
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    JSR     MOVEM_DIR
    RTS


MOVEM_DIR
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register
    
    LSR.W   #3, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    ANDI.W  #$0007, D5          * mask last 3 bits
    
    MOVE.W  D3, D6
    ANDI.W  #$0400, D6
    CMPI.W  #$0400, D6
    BEQ     MEM2REG
    
    CLR.L   D1
    JSR     Display_register_BCS
    LEA     DComma, A1      * comma
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

MEM2REG
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register
    
    LSR.W   #3, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE
    
    LEA     DComma, A1      * comma
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D1
    JSR     Display_register_BCS  
    RTS
 
Display_register_BCS
    CMPI.B  #4, D4
    BEQ     Display_register_D
    
    CMPI.W  #0, D7
    BEQ     END_D
    CLR.L   D5
    LSR.W   #1, D7
    BCS     PRINT_REGISTER
    ADDI.B   #1, D1
    JMP     Display_register_BCS

Display_register_D  
    CMPI.W  #0, D7
    BEQ     END_D
    CLR.L   D5
    LSL.W   #1, D7
    BCS     PRINT_REGISTER
    ADDI.B   #1, D1
    JMP     Display_register_D
    
END_D
    
    RTS   
PRINT_REGISTER
    CMPI.B  #8, D1
    BGE     PRINT_A
    LEA     DDn, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    MOVE.B  #3, D0
    TRAP    #15
    
    ADDI.B   #1, D1
    
    CMPI.W  #0, D7
    BEQ     END_D
    
    LEA     DSLASH, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    CMPI.B  #4, D4
    BEQ     ROL_W
    
    
    JMP     Display_register_BCS


PRINT_A
    LEA     DAn, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    SUBI.B  #8, D1
    MOVE.B  #3, D0
    TRAP    #15
    ADDI.B  #8, D1
    
    ADDI.B   #1, D1
    
    CMPI.W  #0, D7
    BEQ     END_D
    
    LEA     DSLASH, A1     
    MOVE.B  #14, D0
    TRAP    #15
    
    
    CMPI.B  #4, D4
    BEQ     ROL_W
    
    
    JMP     Display_register_BCS

ROL_W
    JMP     Display_register_D
* -------------------------------------------
* Display AND instruction and source and destination EA mode
DISPLAY_AND   
    LEA     DAND, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store size 00 B 01 W 10 L      
    LSR.W   #6, D6              * shift size right
    ANDI.W  #3, D6
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR     D7
    MOVE.W  D3, D7
    LSR.W   #8, D7
    ANDI.W  #1, D7
    JSR     MODE_CHECK
    
    RTS

* -------------------------------------------
* Display OR instruction and source and destination EA mode
DISPLAY_OR   
    LEA     DOR, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store size 00 B 01 W 10 L      
    LSR.W   #6, D6              * shift size right
    ANDI.W  #3, D6
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR     D7
    MOVE.W  D3, D7
    LSR.W   #8, D7
    ANDI.W  #1, D7
    JSR     MODE_CHECK
    
    RTS
    
* -------------------------------------------
* Display ADD instruction and source and destination EA mode
DISPLAY_ADD   
    LEA     DADD, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store size 00 B 01 W 10 L      
    LSR.W   #6, D6              * shift size right
    ANDI.W  #3, D6
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR     D7
    MOVE.W  D3, D7
    LSR.W   #8, D7
    ANDI.W  #1, D7
    JSR     MODE_CHECK
    
    RTS
    
* -------------------------------------------
* Display SUB instruction and source and destination EA mode
DISPLAY_SUB   
    LEA     DSUB, A1
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.B   D6
    MOVE.W  D3, D6              * D6 to store size 00 B 01 W 10 L      
    LSR.W   #6, D6              * shift size right
    ANDI.W  #3, D6
    JSR     SIZE_HANDLE
    
    LEA     space, A1      * space 
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR     D7
    MOVE.W  D3, D7
    LSR.W   #8, D7
    ANDI.W  #1, D7
    JSR     MODE_CHECK
    
    RTS


MODE_CHECK
    CMPI.B  #1, D7
    BEQ     Dn_EA
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  D3, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register
    
    LSR.W   #3, D4              * rotate for EA mode
    ANDI.W  #$0007, D4          * mask last 3 bits
    ANDI.W  #$0007, D5          * mask last 3 bits
    JSR     EA_HANDLE
    
    LEA     DComma, A1      * comma
    MOVE.B  #14, D0
    TRAP    #15
    
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  #0, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register    
    ROL.W   #7, D5
    ANDI.   #$0007, D5
    JSR     EA_HANDLE
    RTS

Dn_EA   
    CLR.L   D5                  * Clear register
    CLR.L   D4
    
    MOVE.W  #0, D4              * D4 to store EA mode
    MOVE.W  D3, D5              * D5 to store EA register    
    ROL.W   #7, D5
    ANDI.   #$0007, D5
    JSR     EA_HANDLE
    
    LEA     DComma, A1      * comma
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
        
BXX_CONDITION
    CMPI.W  #$0400, D4
    BEQ     Display_BCC
    CMPI.W  #$0E00, D4
    BEQ     Display_BGT
    CMPI.W  #$0F00, D4
    BEQ     Display_BLE
    LEA     DBXX, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS
Display_BCC
    LEA     DBCC, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS
Display_BGT
    LEA     DBGT, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS
Display_BLE   
    LEA     DBLE, A1     
    MOVE.B  #14, D0
    TRAP    #15
    RTS

DISPLACEMENT_HANDLE
    CMPI.B  #$00, D3
    BEQ     WORD_D
    CMPI.B  #$FF, D3
    BEQ     LONG_D
    
    MOVE.B  D3, D2
    MOVE.B  #$4, $400
    JSR Display_Address
    RTS   
    
WORD_D
    MOVE.W  #7, D4
    MOVE.W  #0, D5              * D5 to store EA register
    JSR     EA_HANDLE  
    RTS   
    
LONG_D
    MOVE.W  #7, D4
    MOVE.W  #1, D5              * D5 to store EA register
    JSR     EA_HANDLE  
    RTS   
ZERO2EIGHT
    CMPI.B  #0, D2
    BEQ     Z2E
    RTS  
    
Z2E
    MOVEQ   #8, D2
    RTS
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
    
    MOVE.B  D5, D2
    JSR     ZERO2EIGHT
    MOVE.B  D2, D5
    
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
    CMPI.L  #$8000, D2
    BGE     FFFF
    
    RTS
    
FFFF
    LEA     DFFFF, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS

MOVE_SIZE
    CMPI.B  #$3, D6
    BEQ     MOVE_WORD
    RTS
 
MOVE_WORD
    SUBI.B  #2, D6
    RTS      
    
LONG_CHECK
    CMPI.B  #2, D6
    BEQ     D_LONG
    CLR.L   D2              * 8 bit number
    MOVE.W  (A5)+, D2
    MOVE.B  #4, $400
    JSR Display_Address
    RTS
    
D_LONG
    CLR.L   D2              * 8 bit number
    MOVE.L  (A5)+, D2
    MOVE.B  #8, $400
    JSR Display_Address_L
    RTS
    
S_U_HANDLE
    CMPI.B  #7, D6
    BEQ     D_S_HANDLE
    LEA     Dunsigned, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS

D_S_HANDLE
    LEA     Dsigned, A1
    MOVE.B  #14, D0
    TRAP    #15
    RTS    

*-------------------------------------
*Handle end of user requested decoding.
*Prompt user to go again.    
DECODING_FINISHED
    LEA     endDisplay, A1
    MOVE.B  #14, D0
    TRAP    #15
    LEA     goAgainPrompt,A1
    Trap #15
    MOVE.B  #2,D0
    MOVE.w  #$700,A1
    Trap #15
    CMP.B   #$59,(A1)
    BEQ     GO_AGAIN_PREP
    CMP.B   #$79,(A1)
    BNE     EXIT
    
*------------------------------------
*Prep system for another round of decoding.
*Clear data registers
GO_AGAIN_PREP
    CLR.L   D0
    CLR.L   D1
    CLR.L   D2
    CLR.L   D3
    CLR.L   D4
    CLR.L   D5
    CLR.L   D6
    CLR.L   D7
    BRA     userStartAddress 
    
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
endDisplay      DC.B     'You have finihsed decoding', CR, LF, 0
enterMessage    DC.B     'Please hit enter to continue', CR, LF, 0
goAgainPrompt   DC.B    'Would you like to go again? (y/n)',CR,LF,0
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

* instruction
DLEA            DC.B    'LEA', 0
DCMP            DC.B    'CMP', 0
DMOVEQ          DC.B    'MOVEQ', 0
DADDQ           DC.B    'ADDQ', 0
DADDI           DC.B    'ADDI', 0
DSUBI           DC.B    'SUBI', 0
DADDA           DC.B    'ADDA', 0
DMOVEA          DC.B    'MOVEA', 0
DDIVU           DC.B    'DIVU',0
DBCC            DC.B    'BCC',0
DBGT            DC.B    'BGT',0
DBLE            DC.B    'BLE',0
DBXX            DC.B    'BXX',0
DMOVE           DC.B    'MOVE',0
DMOVEM          DC.B    'MOVEM',0
DAND            DC.B    'AND',0
DOR             DC.B    'OR',0
DADD            DC.B    'ADD',0
DSUB            DC.B    'SUB',0
DSLASH          DC.B    '/',0

* SIGN OR UNSIGN
DMUL            DC.B    'MUL',0
Dunsigned       DC.B    'U',0
Dsigned         DC.B    'S',0

<<<<<<< HEAD
=======
*<<<<<<< HEAD
>>>>>>> 21d8566de4a0f28e425408420bb98896636302ac
            MOVEM.L   (A1)+,D1-D7
            MOVEM.W   (A1)+,A1/D7
            MOVEM.L   (A1)+,A1/D7
            MOVEM.W   (A1),A1-A7
            
            MOVEM.W   A1-A7,$12
<<<<<<< HEAD
=======
*=======
>>>>>>> 21d8566de4a0f28e425408420bb98896636302ac
NOP
    RTS
    NOP
    RTS
    LEA     (A0),A0
    LEA     (A5),A0
    LEA     (A7),A0
    LEA     (A0),A7
    LEA     (A5),A7
    LEA     (A7),A7
    CLR.B     D0
    CLR.B     D7
    CLR.W     D0
    CLR.W     D7
    CLR.L     D0
    CLR.L     D7
    CLR.B     (A0)
    CLR.B     (A7)
    CLR.W     (A0)
    CLR.W     (A7)
    CLR.L     (A0)
    CLR.L     (A7)
    CLR.B     (A0)+
    CLR.B     (A7)+
    CLR.W     (A0)+
    CLR.W     (A7)+
    CLR.L     (A0)+
    CLR.L     (A7)+
    CLR.B     -(A0)
    CLR.B     -(A7)
    CLR.W     -(A0)
    CLR.W     -(A7)
    CLR.L     -(A0)
    CLR.L     -(A7)
    MOVE.B    D0,D1
    MOVE.B    D0,(A0)
    MOVE.B    D0,(A0)+
    MOVE.B    D0,-(A0)
    MOVE.B    (A0),D0
    MOVE.B    (A0),(A1)
    MOVE.B    (A0),(A1)+
    MOVE.B    (A0),-(A1)
    MOVE.B    (A0)+,D0
    MOVE.B    (A0)+,(A1)
    MOVE.B    (A0)+,(A1)+
    MOVE.B    (A0)+,-(A1)
    MOVE.B    -(A0),D0
    MOVE.B    -(A0),(A1)
    MOVE.B    -(A0),(A1)+
    MOVE.B    -(A0),-(A1)
    MOVE.W    D0,D1
    MOVE.W    D0,(A0)
    MOVE.W    D0,(A0)+
    MOVE.W    D0,-(A0)
    MOVE.W    A0,D0
    MOVE.W    A0,(A1)
    MOVE.W    A0,(A1)+
    MOVE.W    A0,-(A1)
    MOVE.W    (A0),D0
    MOVE.W    (A0),(A1)
    MOVE.W    (A0),(A1)+
    MOVE.W    (A0),-(A1)
    MOVE.W    (A0)+,D0
    MOVE.W    (A0)+,(A1)
    MOVE.W    (A0)+,(A1)+
    MOVE.W    (A0)+,-(A1)
    MOVE.W    -(A0),D0
    MOVE.W    -(A0),(A1)
    MOVE.W    -(A0),(A1)+
    MOVE.W    -(A0),-(A1)
    MOVE.L    D0,D1
    MOVE.L    D0,(A0)
    MOVE.L    D0,(A0)+
    MOVE.L    D0,-(A0)
    MOVE.L    A0,D0
    MOVE.L    A0,(A1)
    MOVE.L    A0,(A1)+
    MOVE.L    A0,-(A1)
    MOVE.L    (A0),D0
    MOVE.L    (A0),(A1)
    MOVE.L    (A0),(A1)+
    MOVE.L    (A0),-(A1)
    MOVE.L    (A0)+,D0
    MOVE.L    (A0)+,(A1)
    MOVE.L    (A0)+,(A1)+
    MOVE.L    (A0)+,-(A1)
    MOVE.L    -(A0),D0
    MOVE.L    -(A0),(A1)
    MOVE.L    -(A0),(A1)+
    MOVE.L    -(A0),-(A1)
    MOVEM.W   A1-A7,-(A1)
    MOVEM.L   D1-D7,-(A1)
    MOVEM.W   A1/D7,-(A1)
    MOVEM.L   A1/D7,-(A1)
    MOVEM.W   A1-A7,(A1)
    MOVEM.L   D1-D7,(A1)
    MOVEM.W   A1/D7,(A1)
    MOVEM.L   A1/D7,(A1)
    MOVEM.W   (A1)+,A1-A7
    MOVEM.L   (A1)+,D1-D7
    MOVEM.W   (A1)+,A1/D7
    MOVEM.L   (A1)+,A1/D7
    MOVEM.W   (A1),A1-A7
    MOVEM.L   (A1),D1-D7
    MOVEM.W   (A1),A1/D7
    MOVEM.L   (A1),A1/D7
    MOVEA.W    D0,A0
    MOVEA.W    A0,A0
    MOVEA.W    (A0),A0
    MOVEA.W    (A0)+,A0
    MOVEA.W    -(A0),A0
    MOVEA.L    D0,A0
    MOVEA.L    A0,A0
    MOVEA.L    (A0),A0
    MOVEA.L    (A0)+,A0
    MOVEA.L    -(A0),A0  
    ADD.B     D1,D2
    ADD.B     D1,(A1)
    ADD.B     D1,(A1)+
    ADD.B     D1,-(A1)
    ADD.B     (A1),D1
    ADD.B     (A1)+,D1
    ADD.B     -(A1),D1
    ADD.W     D1,D2
    ADD.W     D1,(A1)
    ADD.W     D1,(A1)+
    ADD.W     D1,-(A1)
    ADD.W     (A1),D1
    ADD.W     (A1)+,D1
    ADD.W     -(A1),D1
    ADD.L     D1,D2
    ADD.L     D1,(A1)
    ADD.L     D1,(A1)+
    ADD.L     D1,-(A1)
    ADD.L     (A1),D1
    ADD.L     (A1)+,D1
    ADD.L     -(A1),D1
    ADDA.W        D1,A2
    ADDA.W        (A1),A2
    ADDA.W        (A1)+,A2
    ADDA.W        -(A1),A2
    ADDA.L        D1,A2
    ADDA.L        (A1),A2
    ADDA.L        (A1)+,A2
    ADDA.L        -(A1),A2
    SUB.B     D1,D2
    SUB.B     D1,(A1)
    SUB.B     D1,(A1)+
    SUB.B     D1,-(A1)
    SUB.B     (A1),D1
    SUB.B     (A1)+,D1
    SUB.B     -(A1),D1
    SUB.W     D1,D2
    SUB.W     D1,A1
    SUB.W     D1,(A1)
    SUB.W     D1,(A1)+
    SUB.W     D1,-(A1)
    SUB.W     A1,D1
    SUB.W     (A1),D1
    SUB.W     (A1)+,D1
    SUB.W     -(A1),D1
    SUB.L     D1,D2
    SUB.L     D1,A1
    SUB.L     D1,(A1)
    SUB.L     D1,(A1)+
    SUB.L     D1,-(A1)
    SUB.L     A1,D1
    SUB.L     (A1),D1
    SUB.L     (A1)+,D1
    SUB.L     -(A1),D1    
    MULS.W    D0,D1
    MULS.W    (A0),D1
    MULS.W    -(A0),D1
    MULS.W    (A0)+,D1
    DIVU.W    D0,D1
    DIVU.W    (A0),D1
    DIVU.W    -(A0),D1
    DIVU.W    (A0)+,D1
    AND.B     D1,D2
    AND.B     D1,(A1)
    AND.B     D1,(A1)+
    AND.B     D1,-(A1)
    AND.B     (A1),D1
    AND.B     (A1)+,D1
    AND.B     -(A1),D1
    AND.W     D1,D2
    AND.W     D1,(A1)
    AND.W     D1,(A1)+
    AND.W     D1,-(A1)
    AND.W     (A1),D1
    AND.W     (A1)+,D1
    AND.W     -(A1),D1
    AND.L     D1,D2
    AND.L     D1,(A1)
    AND.L     D1,(A1)+
    AND.L     D1,-(A1)
    AND.L     (A1),D1
    AND.L     (A1)+,D1
    AND.L     -(A1),D1
    OR.B     D1,D2
    OR.B     D1,(A1)
    OR.B     D1,(A1)+
    OR.B     D1,-(A1)
    OR.B     (A1),D1
    OR.B     (A1)+,D1
    OR.B     -(A1),D1
    OR.W     D1,D2
    OR.W     D1,(A1)
    OR.W     D1,(A1)+
    OR.W     D1,-(A1)
    OR.W     (A1),D1
    OR.W     (A1)+,D1
    OR.W     -(A1),D1
    OR.L     D1,D2
    OR.L     D1,(A1)
    OR.L     D1,(A1)+
    OR.L     D1,-(A1)
    OR.L     (A1),D1
    OR.L     (A1)+,D1
    OR.L     -(A1),D1
    LSL.B     D1,D2
    LSL.W     D1,D2
    LSL.W     (A1)
    LSL.W     (A1)+
    LSL.W     -(A1)
    LSL.L     D1,D2
    LSR.B     D1,D2
    LSR.W     D1,D2
    LSR.W     (A1)
    LSR.W     (A1)+
    LSR.W     -(A1)
    LSR.L     D1,D2    
    ASR.B     D1,D2
    ASR.W     D1,D2
    ASR.W     (A1)
    ASR.W     (A1)+
    ASR.W     -(A1)
    ASR.L     D1,D2
    ASL.B     D1,D2
    ASL.W     D1,D2
    ASL.W     (A1)
    ASL.W     (A1)+
    ASL.W     -(A1)
    ASL.L     D1,D2
    ROL.B     D1,D2
    ROL.W     D1,D2
    ROL.W     (A1)
    ROL.W     (A1)+
    ROL.W     -(A1)
    ROL.L     D1,D2
    ROR.B     D1,D2
    ROR.W     D1,D2
    ROR.W     (A1)
    ROR.W     (A1)+
    ROR.W     -(A1)
    ROR.L     D1,D2    
    CMP.B    D0,D1
    CMP.B    (A0),D1
    CMP.B    -(A0),D1
    CMP.B    (A0)+,D1
    CMP.W    D0,D1
    CMP.W    A0,D1
    CMP.W    (A0),D1
    CMP.W    -(A0),D1
    CMP.W    (A0)+,D1
    CMP.L    D0,D1
    CMP.L    A0,D1
    CMP.L    (A0),D1
    CMP.L    -(A0),D1
    CMP.L    (A0)+,D1
    BCC.B     label1
    BCC.B     label2
    BGT.B     label1
    BGT.B     label2
    BLE.B     label1
    BLE.B     label2
    BCC.W     label1
    BCC.W     label2
    BCC.W     label3
    BGT.W     label1
    BGT.W     label2
    BGT.W     label3
    BLE.W     label1
    BLE.W     label2
    BLE.W     label3
    JSR       (A0)
    JSR       $1234
    JSR       $12345678
    JSR       label1
    JSR       label2
    JSR       label3
    NOP
    RTS
label1
    NOP
    RTS
    LEA       $12,A0
    LEA       $1234,A0
    LEA       $12345678,A0
    CLR.B     $12
    CLR.B     $1234
    CLR.B     $12345678
label2
    CLR.W     $12
    CLR.W     $1234
    CLR.W     $12345678
    CLR.L     $12
    CLR.L     $1234
    CLR.L     $12345678
    MOVEQ     #$0,D0
    MOVEQ     #$12,D0
    MOVEQ     #$FF,D0
    ADDI.B    #$12,D1
    ADDI.B    #$12,(A0)
    ADDI.B    #$12,(A0)+
    ADDI.B    #$12,-(A0)
    ADDI.B    #$12,$1234
label3
    ADDI.B    #$12,$12345678
    ADDI.W    #$1234,D1
    ADDI.W    #$1234,(A0)
    ADDI.W    #$1234,(A0)+
    ADDI.W    #$1234,-(A0)
    ADDI.W    #$1234,$1234
    ADDI.W    #$1234,$12345678
    ADDI.L    #$12345678,D1
    ADDI.L    #$12345678,(A0)
    ADDI.L    #$12345678,(A0)+
    ADDI.L    #$12345678,-(A0)
    ADDI.L    #$12345678,$1234
    ADDI.L    #$12345678,$12345678
    ADDQ      #$1,D0
    ADDQ      #$3,D0
    ADDQ      #$8,D0
    MOVE.B    $12,D1
    MOVE.B    $12,(A0)
    MOVE.B    $12,(A0)+
    MOVE.B    $12,-(A0)
    MOVE.B    $1234,D0
    MOVE.B    $1234,(A1)
    MOVE.B    $1234,(A1)+
    MOVE.B    $1234,-(A1)
    MOVE.B    $12345678,D0
    MOVE.B    $12345678,(A1)
    MOVE.B    $12345678,(A1)+
    MOVE.B    $12345678,-(A1)
    MOVE.B    #$12,D0
    MOVE.B    #$12,(A1)
    MOVE.B    #$12,(A1)+
    MOVE.B    #$12,-(A1)
    MOVE.W    $12,D1
    MOVE.W    $12,(A0)
    MOVE.W    $12,(A0)+
    MOVE.W    $12,-(A0)
    MOVE.W    $1234,D0
    MOVE.W    $1234,(A1)
    MOVE.W    $1234,(A1)+
    MOVE.W    $1234,-(A1)
    MOVE.W    $12345678,D0
    MOVE.W    $12345678,(A1)
    MOVE.W    $12345678,(A1)+
    MOVE.W    $12345678,-(A1)
    MOVE.W    #$1234,D0
    MOVE.W    #$1234,(A1)
    MOVE.W    #$1234,(A1)+
    MOVE.W    #$1234,-(A1)
    MOVE.L    $12,D1
    MOVE.L    $12,(A0)
    MOVE.L    $12,(A0)+
    MOVE.L    $12,-(A0)
    MOVE.L    $1234,D0
    MOVE.L    $1234,(A1)
    MOVE.L    $1234,(A1)+
    MOVE.L    $1234,-(A1)
    MOVE.L    $12345678,D0
    MOVE.L    $12345678,(A1)
    MOVE.L    $12345678,(A1)+
    MOVE.L    $12345678,-(A1)
    MOVE.L    #$12345678,D0
    MOVE.L    #$12345678,(A1)
    MOVE.L    #$12345678,(A1)+
    MOVE.L    #$12345678,-(A1)
    MOVEM.W   A1-A7,$12
<<<<<<< HEAD
=======
*>>>>>>> 02e884c1dda6a6ded823204406dbd05093c25bc7
>>>>>>> 21d8566de4a0f28e425408420bb98896636302ac
    MOVEM.L   D1-D7,$12
    MOVEM.W   A1/D7,$12
    MOVEM.L   A1/D7,$12
    MOVEM.W   A1-A7,$1234
    MOVEM.L   D1-D7,$1234
    MOVEM.W   A1/D7,$1234
    MOVEM.L   A1/D7,$1234
    MOVEM.W   A1-A7,$12345678
    MOVEM.L   D1-D7,$12345678
    MOVEM.W   A1/D7,$12345678
    MOVEM.L   A1/D7,$12345678
    MOVEM.W   $12,A1-A7
    MOVEM.L   $12,D1-D7
    MOVEM.W   $12,A1/D7
    MOVEM.L   $12,A1/D7
    MOVEM.W   $1234,A1-A7
    MOVEM.L   $1234,D1-D7
    MOVEM.W   $1234,A1/D7
    MOVEM.L   $1234,A1/D7
    MOVEM.W   $12345678,A1-A7
    MOVEM.L   $12345678,D1-D7
    MOVEM.W   $12345678,A1/D7
    MOVEM.L   $12345678,A1/D7
<<<<<<< HEAD



=======
*<<<<<<< HEAD



	
	

*=======
>>>>>>> 21d8566de4a0f28e425408420bb98896636302ac
    ADD.B     D1,$12
    ADD.B     D1,$1234
    ADD.B     D1,$12345678
    ADD.B     $12,D1
    ADD.B     $1234,D1
    ADD.B     $12345678,D1
    ADD.B     #$12,D1
    ADD.W     D1,$12
    ADD.W     D1,$1234
    ADD.W     D1,$12345678
    ADD.W     $12,D1
    ADD.W     $1234,D1
    ADD.W     $12345678,D1
    ADD.W     #$1234,D1
    ADD.L     D1,$12
    ADD.L     D1,$1234
    ADD.L     D1,$12345678
    ADD.L     $12,D1
    ADD.L     $1234,D1
    ADD.L     $12345678,D1
    ADD.L     #$12345678,D1
    ADDA.W    $12,A2
    ADDA.W    $1234,A2
    ADDA.W    $12345678,A2
    ADDA.W    #$1234,A2
    ADDA.L    $12,A2
    ADDA.L    $1234,A2
    ADDA.L    $12345678,A2
    ADDA.L    #$12345678,A2
    SUB.B     D1,$12
    SUB.B     D1,$1234
    SUB.B     D1,$12345678
    SUB.B     $12,D1
    SUB.B     $1234,D1
    SUB.B     $12345678,D1
    SUB.B     #$12,D1
    SUB.W     D1,$12
    SUB.W     D1,$1234
    SUB.W     D1,$12345678
    SUB.W     $12,D1
    SUB.W     $1234,D1
    SUB.W     $12345678,D1
    SUB.W     #$1234,D1
    SUB.L     D1,$12
    SUB.L     D1,$1234
    SUB.L     D1,$12345678
    SUB.L     $12,D1
    SUB.L     $1234,D1
    SUB.L     $12345678,D1
    SUB.L     #$12345678,D1
    MULS.W    $12,D1
    MULS.W    $1234,D1
    MULS.W    $12345678,D1
    MULS.W    #$1234,D1
    DIVU.W    $12,D1
    DIVU.W    $1234,D1
    DIVU.W    $12345678,D1
    DIVU.W    #$1234,D1
    AND.B     D1,$12
    AND.B     D1,$1234
    AND.B     D1,$12345678
    AND.B     $12,D1
    AND.B     $1234,D1
    AND.B     $12345678,D1
    AND.B     #$12,D1
    AND.W     D1,$12
    AND.W     D1,$1234
    AND.W     D1,$12345678
    AND.W     $12,D1
    AND.W     $1234,D1
    AND.W     $12345678,D1
    AND.W     #$1234,D1
    AND.L     D1,$12
    AND.L     D1,$1234
    AND.L     D1,$12345678
    AND.L     $12,D1
    AND.L     $1234,D1
    AND.L     $12345678,D1
    AND.L     #$12345678,D1
    LSL.B     #$1,D2
    LSL.W     #$2,D2
    LSL.L     #$3,D2
    LSL.W     $12
    LSL.W     $1234
    LSL.W     $12345678
    ASR.B     #$1,D2
    ASR.W     #$2,D2
    ASR.L     #$3,D2
    ASR.W     $12
    ASR.W     $1234
    ASR.W     $12345678
    ROL.B     #$1,D2
    ROL.W     #$2,D2
    ROL.L     #$3,D2
    ROL.W     $12
    ROL.W     $1234
    ROL.W     $12345678
label4    CMP.B     $12,D1
    CMP.B     $1234,D1
    CMP.B     $12345678,D1
    CMP.B     #$12,D1
    CMP.W     $12,D1
    CMP.W     $1234,D1
    CMP.W     $12345678,D1
    CMP.W     #$1234,D1
    CMP.L     $12,D1
    CMP.L     $1234,D1
    CMP.L     $12345678,D1
    CMP.L     #$12345678,D1
    BCC.B     label4
    BGT.B     label4
    BLE.B     label4
    BCC.W     label1
    BCC.W     label2
    BCC.W     label3
    BGT.W     label1
    BGT.W     label2
    BGT.W     label3
    BLE.W     label1
    BLE.W     label2
    BLE.W     label3
    JSR       label1
    JSR       label2
    JSR       label3
    MOVEA     D1,A1
    ADDA      D1,A1
    BTST      #1,D1


<<<<<<< HEAD
    END    START        ; last line of source
=======
*>>>>>>> 02e884c1dda6a6ded823204406dbd05093c25bc7

EXIT
    END    START        ; last line of source


























<<<<<<< HEAD


=======
>>>>>>> 02e884c1dda6a6ded823204406dbd05093c25bc7

>>>>>>> 21d8566de4a0f28e425408420bb98896636302ac
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
