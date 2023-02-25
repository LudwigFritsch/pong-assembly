    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Include required files with VCS register memory mapping and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare the variables starting from memory address $80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg.u Variables
    org $80

P0XPos          byte        ; player 0 x-position
P0YPos          byte        ; player 0 y-position
P1XPos          byte        ; player 1 x-position
P1YPos          byte        ; player 1 y-position
ScoreP0         byte        ; 2-digit score of P0 stored as BCD
ScoreP1         byte        ; 2-digit score of P1 stored as BCD
Temp            byte        ; auxiliary variable to store temp values
OnesDigitOffset word        ; lookup table offset for the score Ones digit
TensDigitOffset word        ; lookup table offset for the score Tens digit
P0SpritePtr     word        ; pointer to player0 sprite lookup table
P0ColorPtr      word        ; pointer to player0 color lookup table
P1SpritePtr     word        ; pointer to player1 sprite lookup table
P1ColorPtr      word        ; pointer to player1 color lookup table
ScoreP0Sprite   byte        ; store the sprite bit pattern for the scoreP0
ScoreP1Sprite   byte        ; store the sprite bit pattern for the scoreP1
BGColor         byte        ; store the color of the background
DigitsColor     byte        ; store the color of the score

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Define constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
P0_HEIGHT = 15               ; player0 sprite height (# rows in lookup table)
P1_HEIGHT = 15               ; player1 sprite height (# rows in lookup table)
DIGITS_HEIGHT = 5           ; scoreboard digit height (#rows in lookup table)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start our ROM code at memory address $F000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg Code
    org $F000

Reset:
    CLEAN_START             ; call macro to reset memory and registers

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #10
    sta P0XPos              
    lda #100
    sta P0YPos             
    lda #120
    sta P1XPos              
    lda #100
    sta P1YPos              
    lda #0                 
    sta ScoreP0
    sta ScoreP1
    lda #$00
    sta DigitsColor         ; initialize digits color to dark grey
    lda #$0F
    sta BGColor             ; initialize background color to dark grey

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize the pointers to the correct lookup table adresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #<P0Sprite
    sta P0SpritePtr         ; lo-byte pointer for p0 sprite lookup table
    lda #>P0Sprite
    sta P0SpritePtr+1       ; hi-byte pointer for p0 sprite lookup table

    lda #<P0Color
    sta P0ColorPtr          ; lo-byte pointer for p0 color lookup table
    lda #>P0Color
    sta P0ColorPtr+1        ; hi-byte pointer for p0 color lookup table

    lda #<P1Sprite
    sta P1SpritePtr         ; lo-byte pointer for p1 sprite lookup table
    lda #>P1Sprite
    sta P1SpritePtr+1       ; hi-byte pointer for p1 sprite lookup table

    lda #<P1Color
    sta P1ColorPtr          ; lo-byte pointer for p1 color lookup table
    lda #>P1Color
    sta P1ColorPtr+1        ; hi-byte pointer for p1 color lookup table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start the main display loop and frame rendering
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartFrame:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display VSYNC and VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK              ; turn on VBLANK
    sta VSYNC               ; turn on VSYNC
    REPEAT 3
        sta WSYNC           ; display 3 recommended lines of VSYNC
    REPEND
    lda #0
    sta VSYNC               ; turn off VSYNC
    REPEAT 34               ; 37 VBLANK scanlines minus the amount of scanlines that get used by calulations down below
        sta WSYNC           ; display the recommended lines of VBLANK
    REPEND
    lda #0
    sta VBLANK              ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calculations and tasks performed in VBlank
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda P0XPos
    ldy #0
    jsr SetObjectXPos       ; set player0 horizontal position

    lda P1XPos
    ldy #1
    jsr SetObjectXPos       ; set player1 horizontal position

    sta WSYNC

    jsr CalcDigitOffset     ; calculate scoreboard digits lookup table offset

    sta HMOVE               ; apply the horizontal offsets previously set

    lda #0
    sta VBLANK              ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display the scoreboard lines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda BGColor            ; reset TIA registers before displaying the score
    sta COLUBK
    lda DigitsColor
    sta COLUPF              ; set the scoreboard playfield the digits-color
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta CTRLPF
    sta WSYNC

    ldx #DIGITS_HEIGHT      ; start X counter with 5 (height of digits)

.ScoreDigitLoop:
    ldy TensDigitOffset     ; get the tens digit offset for the Score
    lda Digits,Y            ; load the bit pattern from lookup table
    and #$F0                ; mask/remove the graphics for the ones digit
    sta ScoreP0Sprite       ; save the scoreP0 tens digit pattern in a variable

    ldy OnesDigitOffset     ; get the ones digit offset for the Score
    lda Digits,Y            ; load the digit bit pattern from lookup table
    and #$0F                ; mask/remove the graphics for the tens digit
    ora ScoreP0Sprite       ; merge it with the saved tens digit sprite
    sta ScoreP0Sprite       ; and save it
    sta WSYNC               ; wait for the end of scanline
    sta PF1                 ; update the playfield to display the Score sprite

    ldy TensDigitOffset+1   ; get the left digit offset for the Timer
    lda Digits,Y            ; load the digit pattern from lookup table
    and #$F0                ; mask/remove the graphics for the ones digit
    sta ScoreP1Sprite       ; save the scoreP1 tens digit pattern in a variable

    ldy OnesDigitOffset+1   ; get the ones digit offset for the Timer
    lda Digits,Y            ; load digit pattern from the lookup table
    and #$0F                ; mask/remove the graphics for the tens digit
    ora ScoreP1Sprite       ; merge with the saved tens digit graphics
    sta ScoreP1Sprite       ; and save it

    jsr Sleep12Cycles       ;  wastes some cycles

    sta PF1                 ; update the playfield for Timer display

    ldy ScoreP0Sprite       ; preload for the next scanline
    sta WSYNC               ; wait for next scanline

    sty PF1                 ; update playfield for the score display
    inc TensDigitOffset
    inc TensDigitOffset+1
    inc OnesDigitOffset
    inc OnesDigitOffset+1   ; increment all digits for the next line of data

    jsr Sleep12Cycles       ; waste some cycles

    dex                     ; X--
    sta PF1                 ; update the playfield for the Timer display
    bne .ScoreDigitLoop     ; if dex != 0, then branch to ScoreDigitLoop

    sta WSYNC

    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta WSYNC
    sta WSYNC
    sta WSYNC

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Draw the remaining visible scanlines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameVisibleLine:
    ldx #175                  ; X counts the number of remaining scanlines
.GameLineLoop:
.InsideSpriteP0:
    txa                      ; transfer X to A
    sec                      ; make sure carry flag is set before subtraction
    sbc P0YPos              ; subtract sprite Y-coordinate
    cmp #P0_HEIGHT           ; are we inside the sprite height bounds?
    bcc .DrawSpriteP0        ; if result < SpriteHeight, call the draw routine
    lda #0                   ; else, set lookup index to zero
.DrawSpriteP0:
    tay                      ; load Y so we can work with the pointer
    lda (P0SpritePtr),Y     ; load player0 bitmap data from lookup table
    sta GRP0                 ; set graphics for player0
    lda (P0ColorPtr),Y      ; load player color from lookup table
    sta COLUP0               ; set color of player 0

.InsideSpriteP1:
    txa                      ; transfer X to A
    sec                      ; make sure carry flag is set before subtraction
    sbc P1YPos           ; subtract sprite Y-coordinate
    cmp #P1_HEIGHT        ; are we inside the sprite height bounds?
    bcc .DrawSpriteP1        ; if result < SpriteHeight, call the draw routine
    lda #0                   ; else, set lookup index to zero
.DrawSpriteP1:
    tay                      ; load Y so we can work with the pointer
    lda (P1SpritePtr),Y  ; load player1 bitmap data from lookup table
    sta GRP1                 ; set graphics for player1
    lda (P1ColorPtr),Y   ; load player color from lookup table
    sta COLUP1               ; set color of player 1

    sta WSYNC
    dex                      ; X--
    bne .GameLineLoop      ; repeat next main game scanline until finished
    sta WSYNC                ; wait for a scanline

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display Overscan
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK             ; turn on VBLANK again
    REPEAT 30
        sta WSYNC          ; display recommended lines of VBlank Overscan
    REPEND
    lda #0
    sta VBLANK             ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Loop to next frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to handle object horizontal position with fine offset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A is the target x-coordinate position in pixels of our object
;; Y is the object type (0:player0, 1:player1, 2:missile0, 3:missile1, 4:ball)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetObjectXPos subroutine
    sta WSYNC                ; start a fresh new scanline
    sec                      ; make sure carry-flag is set before subtracion
.Div15Loop
    sbc #15                  ; subtract 15 from accumulator
    bcs .Div15Loop           ; loop until carry-flag is clear
    eor #7                   ; handle offset range from -8 to 7
    asl
    asl
    asl
    asl                      ; four shift lefts to get only the top 4 bits
    sta HMP0,Y               ; store the fine offset to the correct HMxx
    sta RESP0,Y              ; fix object position in 15-step increment
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to handle scoreboard digits to be displayed on the screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The scoreboard is stored using BCD, so the display shows hex numbers.
;; This converts the high and low nibbles of the variable Score and Timer
;; into the offsets of digits lookup table so the values can be displayed.
;; Each digit has a height of 5 bytes in the lookup table.
;;
;; For the low nibble we need to multiply by 5
;;   - we can use left shifts to perform multiplication by 2
;;   - for any number N, the value of N*5 = (N*2*2)+N
;;
;; For the upper nibble, since its already times 16, we need to divide it
;; and then multiply by 5:
;;   - we can use right shifts to perform division by 2
;;   - for any number N, the value of (N/16)*5 is equal to (N/4)+(N/16)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CalcDigitOffset subroutine
    ldx #1                   ; X register is the loop counter
.PrepareScoreLoop            ; this will loop twice, first X=1, and then X=0
    lda ScoreP0,X            ; load A with ScoreP1 (X=1) or ScoreP0 (X=0)
    and #$0F                 ; remove the tens digit by masking 4 bits 00001111
    sta Temp                 ; save the value of A into Temp
    asl                      ; shift left (it is now N*2)
    asl                      ; shift left (it is now N*4)
    adc Temp                 ; add the value saved in Temp (+N)
    sta OnesDigitOffset,X    ; save A in OnesDigitOffset+1 or OnesDigitOffset

    lda ScoreP0,X            ; load A with ScoreP1 (X=1) or ScoreP0 (X=0)
    and #$F0                 ; remove the ones digit by masking 4 bits 11110000
    lsr                      ; shift right (it is now N/2)
    lsr                      ; shift right (it is now N/4)
    sta Temp                 ; save the value of A into Temp
    lsr                      ; shift right (it is now N/8)
    lsr                      ; shift right (it is now N/16)
    adc Temp                 ; add the value saved in Temp (N/16+N/4)
    sta TensDigitOffset,X    ; store A in TensDigitOffset+1 or TensDigitOffset

    dex                      ; X--
    bpl .PrepareScoreLoop    ; while X >= 0, loop to pass a second time
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine that takes 12 cycles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; jsr takes 6 cycles
;; rts takes 6 cycles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Sleep12Cycles subroutine
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare ROM lookup tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
P0Sprite:
    .byte #%00000000         ;
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #

P1Sprite:
    .byte #%00000000         ;
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #

P0Color:
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00

P1Color:
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00
    .byte #$00

Digits:
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00110011          ;  ##  ##
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %00100010          ;  #   #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01100110          ; ##  ##
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Close off cartridge
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC
    .word Reset             ; Set reset-address
    .word Reset             ; Set interrupt-address


