; Two-digit 00-59 counter using Timer B and multiplexed seven-segment displays.
; TI MSP430 assembler syntax for Code Composer Studio.
;
; Register state:
; R10: display toggle (0 = units, 1 = tens)
; R11: units digit (0-9)
; R12: tens digit (0-5)
; R13: Timer B overflow count (0-253)
; R14: digit passed to ComputeSegments
; R15: active-low segment pattern returned by ComputeSegments
;
; Wiring follows the original coursework diagram. P1.0-P1.6 drive segments;
; P1.7 and P2.0 are the display-select lines.

            .cdecls C,LIST,"msp430.h"
            .def RESET
            .text
            .retain
            .retainrefs

TIMER_RELOAD        .equ 65407   ; 65536 - 129 ACLK ticks
TICKS_PER_SECOND    .equ 254     ; ~0.99994 s at 32768 Hz ACLK, excluding ISR overhead

RESET:
            mov.w   #__STACK_END, SP
            mov.w   #WDTPW|WDTHOLD, &WDTCTL
            clr.b   R10
            clr.b   R11
            clr.b   R12
            clr.w   R13

; Initialize segment outputs and two display-select pins.
            mov.b   #0FFh, &P1DIR
            mov.b   #0FFh, &P1OUT  ; active-low segments off; P1.7 high
            bis.b   #BIT0, &P2DIR
            bic.b   #BIT0, &P2OUT
            bic.b   #LOCKLPM5, &PM5CTL0

; ACLK = 32768 Hz assumed. Each overflow is approximately 129/32768 s.
            mov.w   #TBCLR, &TB0CTL
            mov.w   #TIMER_RELOAD, &TB0R
            bis.w   #TBSSEL__ACLK|MC__CONTINUOUS|TBIE, &TB0CTL
            bis.w   #GIE, SR

Main_Loop:
            jmp     Main_Loop

; Timer B overflow: refresh one digit and count elapsed refresh periods.
ISR_TB0:
            xor.b   #BIT0, R10
            bit.b   #BIT0, R10
            jz      ShowUnits

ShowTens:
            mov.b   R12, R14
            call    #ComputeSegments
            bic.b   #BIT0, &P2OUT ; blank both digits before changing segments
            bic.b   #BIT7, &P1OUT
            mov.b   R15, &P1OUT
            bis.b   #BIT7, &P1OUT ; select tens (as in original wiring)
            jmp     CountTick

ShowUnits:
            mov.b   R11, R14
            call    #ComputeSegments
            bic.b   #BIT0, &P2OUT ; blank both digits before changing segments
            bic.b   #BIT7, &P1OUT
            mov.b   R15, &P1OUT
            bic.b   #BIT7, &P1OUT ; deselect tens
            bis.b   #BIT0, &P2OUT ; select units

CountTick:
            inc.w   R13
            cmp.w   #TICKS_PER_SECOND, R13
            jl      ReloadTimer
            clr.w   R13
            call    #IncrementDigits

ReloadTimer:
            mov.w   #TIMER_RELOAD, &TB0R
            bic.w   #TBIFG, &TB0CTL
            reti

; Convert 0-9 to common-anode (active-low) segment patterns.
; The decimal-point bit is high (off) in each pattern.
ComputeSegments:
            cmp.b   #0, R14
            jne     Digit1
            mov.b   #0C0h, R15
            ret
Digit1:
            cmp.b   #1, R14
            jne     Digit2
            mov.b   #0F9h, R15
            ret
Digit2:
            cmp.b   #2, R14
            jne     Digit3
            mov.b   #0A4h, R15
            ret
Digit3:
            cmp.b   #3, R14
            jne     Digit4
            mov.b   #0B0h, R15
            ret
Digit4:
            cmp.b   #4, R14
            jne     Digit5
            mov.b   #099h, R15
            ret
Digit5:
            cmp.b   #5, R14
            jne     Digit6
            mov.b   #092h, R15
            ret
Digit6:
            cmp.b   #6, R14
            jne     Digit7
            mov.b   #082h, R15
            ret
Digit7:
            cmp.b   #7, R14
            jne     Digit8
            mov.b   #0F8h, R15
            ret
Digit8:
            cmp.b   #8, R14
            jne     Digit9
            mov.b   #080h, R15
            ret
Digit9:
            cmp.b   #9, R14
            jne     NotADigit
            mov.b   #098h, R15
            ret
NotADigit:
            ret

; Carry units into tens, and wrap 59 back to 00.
IncrementDigits:
            inc.b   R11
            cmp.b   #10, R11
            jne     NoCarry
            clr.b   R11
            inc.b   R12
            cmp.b   #6, R12
            jne     NoCarry
            clr.b   R12
NoCarry:
            ret

            .global __STACK_END
            .sect   .stack
            .sect   ".reset"
            .short  RESET
            .sect   ".int42"  ; original report vector; confirm against exact device
            .short  ISR_TB0