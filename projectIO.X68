*-----------------------------------------------------------
* Title      :I/O for starting/ending address
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
start       org     $1000
RESTART
            MOVE.B  #14,D0              *for Trap #15 output
            LEA     msgPromptStart, A1  *load starting address message
            Trap #15                    *set output
            MOVEA.L #$2000,A1           *set address to store user input 
            MOVE.B  #2,D0               *for Trap#15 input
            Trap #15                    *set intput
            MOVE.B  #8,D3               *use D3 as counter for input
PARSE_INPUT
            MOVE.B  (A1)+,D1            *move first byte of address intput to D1
            BRA     VERIFY_INPUT        *check that input is valid
CONTINUE_INPUT
            CMP.B   #$39, D1            *check if digit or hex letter
            BGT     PARSE_HEX           *branch if hex letter 
            SUB.B   #$30, D1            *subtract 30 from ascii value to get hex number
            LSL.L   #4,D2               *D2 contains the address parsed so far
            OR.B    D1,D2               *Change first left 4 digits of D2 to match D1
            CLR.L   D1                  *Clear D1 for next input byte to be parsed
            SUB.B   #1,D3               *decrement D3 counter
            CMP     #0,D3               *See if D3 is zero (see if input parsing is finished)
            BNE     PARSE_INPUT         *If D3 is not zero, there is still input left to parse
            CMP.B   #0,D4               *D4 contains value when parsing ending address input
            BNE     FINISH_ADDRESS_INPUT  *If D4 is not zero, address parsing is finished    
            MOVEA.L D2,A5                   *If D4 is zero,starting address finished parsing, move to A5
            BRA     ENDING_ADDRESS          *Begin ending address input and parsing
            
PARSE_HEX
            CMP.B   #$60,D1             *Check if value is lower or upper case hex letter
            BGT     PARSE_LOWER_HEX     *If higher than $60, this is a lower case hex letter, else upper case
            SUB.B   #$37,D1             *Subtract $37 to convert ASCII to hex letter
            LSL.L   #4,D2               *Shift D2 left 4 to make room for next parsed value
            OR.B    D1,D2               *Move parsed value in D1 to cumulative value in D2
            CLR.L   D1                  *Clear value in D1 for next input value
            SUB.B   #1,D3               *Decrement D3 counter
            CMP     #0,D3               *Check if counter is zero
            BNE     PARSE_INPUT         *If counter is not zero, there are still values left to parse
            CMP.B   #0,D4               *D4 has value ending address is being parsed
            BNE     FINISH_ADDRESS_INPUT    *If D4 is not zero, address parsing is finished
            MOVEA.L D2,A5                   *If D4 is zero, starting address finished parsing, move to A5
            BRA     ENDING_ADDRESS          *Begin ending address input and parsing
            
PARSE_LOWER_HEX
            SUB.B   #$57,D1             *subtract $57 to convert ASCII to hex letter
            LSL.L   #4,D2               *Shift D2 4 bits to the left to make room for next hextet
            OR.B    D1,D2               *Move D1 parsed value to cumulative value in D2
            CLR.L   D1                  *Clear D1 for next input value
            SUB.B   #1,D3               *Decrement D3 counter
            CMP     #0,D3               *Check if counter is zero 
            BNE     PARSE_INPUT         *If D3 is not zero, parsing is not finished
            CMP.B   #0,D4               *D4 contains value if ending address being parsed
            BNE     FINISH_ADDRESS_INPUT    *If D4 is not zero, address parsing finished
            MOVEA.L D2,A5                   *If D4 is zero, starting address finished parsing, move to A5
            BRA     ENDING_ADDRESS          *Begin ending address input and parsing
            
ENDING_ADDRESS
            CLR.L   D0                  *clearing registers for new input values
            CLR.L   D1
            CLR.L   D2
            CLR.L   D3
            MOVE.B  #1,D4               *set flag to indicate input for ending address
            MOVE.B  #8,D3               *Set counter for parsing values
            LEA     msgEndAddr,A1       *Load ending address request prompt
            MOVE.B  #14,D0              *Move output value for Trap #15
            TRAP #15                    *Output message to console
            MOVE.B  #2,D0               *Move input value for Trap #15
            Trap #15                    *Input from console
            BRA     PARSE_INPUT         *Parse ending address input
            
FINISH_ADDRESS_INPUT
            MOVE.L  D2,A6               *move ending address to A6
            CLR.L   D0                  *Clear data registers
            CLR.L   D1
            CLR.L   D2
            CLR.L   D3
            CLR.L   D4
            MOVEA.L #0,A1               *Clear address register
            BRA     exit 

VERIFY_INPUT
            CMP.B   #$30,D1                 
            BLT     HANDLE_INVALID_INPUT    *value less than zero is invalid ASCII value
            CMP.B   #$66,D1 
            BGT     HANDLE_INVALID_INPUT    *value greater than 66 is invalid ASCII value
            CMP.B   #$3A,D1
            BLT     CONTINUE_INPUT          *value 30 - 39 is valid
            CMP.B   #$41,D1
            BLT     HANDLE_INVALID_INPUT    *value 3A - 40 is not valid
            CMP.B   #$47,D1
            BLT     CONTINUE_INPUT          *value 41 - 46 is valid
            CMP.B   #$61,D1
            BLT     HANDLE_INVALID_INPUT    *value 47 - 60 is not valid
            BRA     CONTINUE_INPUT

HANDLE_INVALID_INPUT       
            LEA     msgError,A1             *load error message
            MOVE.B  #14,D0                  *move output for Trap #15
            Trap #15                        *print output
            CLR.L   D0                      *clear data registers
            CLR.L   D1
            CLR.L   D2
            CLR.L   D3
            CLR.L   D4
            MOVEA.L #0,A1                   *clear address registers
            MOVEA.L #0,A5
            MOVEA.L #0,A6
            BRA     RESTART                 *restart address input sequence


*---------messages and constants-----------------------
CR                  EQU     $0D
LF                  EQU     $0A
msgPromptStart      DC.B    'Enter valid 32-bit (8 characters) starting address: ',CR,LF,0
msgEndAddr          DC.B    'Enter valid 32-bit (8 characters) ending address',CR,LF,0
msgError            DC.B    'Address invalid, try again',CR,LF,0

exit
            end     start



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
