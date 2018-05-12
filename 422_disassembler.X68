*-----------------------------------------------------------
* Title      : 422 Disassembler 
* Written by : 
* Date       : 05/10/2018
* Description: Read string input and put that into Hexadecimal value as starting and ending address to 
*              decode.
*           
*      Update: - 05/12/2018  Martin Huang
*                   + Add user input stored start address in A5 and ending address in A6
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here

* -------------------------------------
* Display welcome message and check the first input address
UserStartAddress
    
    LEA     startInput, A1      * Prompt input for start address
    MOVE.B  #14, D0
    TRAP    #15

    MOVEA.L #$00000000, A1      * Clear A1 to for user input with trap task #2
    MOVE.B  #2, D0
    TRAP    #15
    
    CLR.L   D2                  * D2 to store hexadecimal address
    CLR.B   D6                  * Use D6 as flag for error in input (out of range OR non-Hex char): 1 == error, 0 == okay
    
    JSR     LOWER_CASE_CHECK   * branch to check input

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserStartAddress

    JSR     RANGE_CHECK * branch to check range($00001000 to $00FFFFFF)

    CMP.B   #1, D6              * check if D6 is set, if yes return to start input
    BEQ     UserStartAddress

    MOVEA.L #$00000000, A1      * Clear A1 
    MOVE.L  D2, A5              * Load accepted STARTING address into A5
 
* -------------------------------------
* Ccheck the second input address   
UserEndAddress
    LEA     endInput, A1      * Prompt input for end address
    MOVE.B  #14, D0
    TRAP    #15

    MOVEA.L #$00000000, A1      * Clear A1 to for user input with trap task #2
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

    MOVEA.L #$00000000, A1      * Clear A1 
    MOVE.L  D2, A6              * Load accepted Ending address into A6
   
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

    SUB.B   #1, D1          * Use D1 as a counter to check next char in user input
    ADDQ.L  #1, A1          * Increment address pointer
    CMP.B   #0, D1          * Check if all chars were checked, if not continue to check
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

    JSR     ADDRESS_CONFIGURE   * Jump to subroutine for properly configure the address

    SUB.B   #1, D1          * Similar to 1st input check
    ADDQ.L  #1, A1
    CMP.B   #0, D1
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
    MULS    #$10, D2
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

 
* -----------------------------------------------------------------------------------------------------------
* Variables and constants 
* -----------------------------------------------------------------------------------------------------------
CR              EQU     $0D     * CR
LF              EQU     $0A     * LF
startInput      DC.B    'Welcome to 68k disassembler!', CR, LF 
                DC.B    'Please enter starting address in Hex($1000 to $FFFFFF): ', 0
endInput        DC.B    'Please enter ending address in Hex(must greater than start address): ', 0
typeInputError  DC.B    'ERROR: Your entered address is not a hex!', CR, LF, 0
RangeError       DC.B    'ERROR: Address is out of range', CR, LF, 0
DifferentError   DC.B    'ERROR: Ending address must be greater than Starting address', CR, LF, 0
OddError         DC.B    'ERROR: Address must be even ', CR, LF, 0

    END    START        ; last line of source




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
