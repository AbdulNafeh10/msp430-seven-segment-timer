; Reconstructed from the original A2 report, pages 8-12.
; Formatting only; logic preserved.

;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
          .cdecls C,LIST,"msp430.h"                ; Include device header file

;-------------------------------------------------------------------------------
          .def RESET                         ; Export program entry-point to
                                     ; make it known to the linker.
;-------------------------------------------------------------------------------
          .text                        ; Assemble into program memory.
          .retain                       ; Override ELF conditional linking
                                     ; and retain the current section.
          .retainrefs                     ; And retain any sections that have
                                     ; references to the current section.

;-------------------------------------------------------------------------------
RESET           mov.w #__STACK_END,SP                         ; Initialize stack pointer
StopWDT mov.w #WDTPW|WDTHOLD,&WDTCTL ; Stop watchdog timer


;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------

; Initialize registers for variable storage-------------------------------------
          clr.b R10                 ; Initializes R10 as display toggle flag.
          clr.b R11                ; Sets R11 as the units digit register.
          clr.b R12                 ; Sets R12 as the tens digit register.
          clr.w R13                  ; Initializes R13 as the seconds counter.

init:
          mov.b #0FFh, &P1DIR     ; Configures all P1 pins as outputs.
          mov.b #03Fh, &P1OUT      ; Turns off all segments for common anode setup.
          bis.b #BIT0, &P2DIR   ; Configures P2.0 as an output.
          bic.b #BIT0, &P2OUT    ; Sets P2.0 to low (off).
          bic.b #LOCKLPM5, &PM5CTL0 ; Unlocks the GPIO settings after power-up.

; Timer setup for display refresh timing----------------------------------------
        bis.w #TBCLR, &TB0CTL             ; Clears timer B settings.

mov.w #65407, &TB0R      ; Sets the start value for the timer.
        bis.w #TBSSEL__ACLK, &TB0CTL ; Selects ACLK as the timer clock source.
        bis.w #MC__CONTINUOUS, &TB0CTL; Configures the timer for continuous mode.
        bis.w #TBIE, &TB0CTL    ; Enables interrupt for timer B.

        nop                      ; No operation (ensures separation of instructions).
        bis.w #GIE, SR                ; Enables global interrupts.
        nop                      ; No operation.

Main_Loop:
      jmp        Main_Loop              ; Continuously loops to maintain program running.

;-------------------------------------------------------------------------------
; Interrupt Service Routine for Timer B
;-------------------------------------------------------------------------------
ISR_TB0:
          xor.b #0x01, R10                    ; Toggles the display flag between 0 and 1.
          bit.b #BIT0, R10
          jnz UpdateDisplay1                    ; If flag is 1, update display 1.
          jz     UpdateDisplay2                ; If flag is 0, update display 2.

UpdateDisplay1:
      mov.b R12, R14        ; Loads the tens digit into R14.
      call #ComputeSegments       ; Calculates segment values based on R14.
      mov.b R15, &P1OUT         ; Outputs segment values to display 1.
      bis.b #BIT7, &P1OUT      ; Activates display 1.
      bic.b #BIT0, &P2OUT      ; Deactivates display 2.
      jmp ContinueISR       ; Continues ISR operations.

UpdateDisplay2:
      mov.b R11, R14        ; Loads the units digit into R14.
      call #ComputeSegments        ; Calculates segment values based on R14.
      mov.b R15, &P1OUT          ; Outputs segment values to display 2.
      bic.b #BIT7, &P1OUT       ; Deactivates display 1.
      bis.b #BIT0, &P2OUT       ; Activates display 2.
      jmp ContinueISR        ; Continues ISR operations.

ContinueISR:
       inc.w R13              ; Increments the second counter.
       cmp.w #254, R13              ; Checks if 254 interrupts have occurred.
       jl   NotYetASecond         ; If less than 254, continue counting.
       clr.w R13             ; Resets the counter when a second has passed.
       call #IncrementDigits       ; Increments the displayed digits.

NotYetASecond:
       mov.w #65407, &TB0R         ; Reloads the initial timer value.
       bic.w #TBIFG, &TB0CTL        ; Clears the timer interrupt flag.
       reti             ; Returns from interrupt.

;-------------------------------------------------------------------------------
; Segment computation for digits
;-------------------------------------------------------------------------------
ComputeSegments:
          cmp.b #0, R14                       ; Compares R14 with 0.
          jne Digit1                     ; Jumps to digit 1 calculation if not matched.
          mov.b #0xC0, R15                       ; Segment pattern for '0'.
          ret
Digit1:
          cmp.b #1, R14
          jne Digit2
          mov.b #0xF9, R15                      ; Segment pattern for '1'.
          ret
Digit2:
          cmp.b #2, R14
          jne Digit3
          mov.b #0xA4, R15                      ; Segment pattern for '2'.
          ret
Digit3:
          cmp.b #3, R14
          jne Digit4
          mov.b #0xB0, R15                      ; Segment pattern for '3'.
          ret
Digit4:
          cmp.b #4, R14
          jne Digit5
          mov.b #0x99, R15                      ; Segment pattern for '4'.
          ret
Digit5:
          cmp.b #5, R14
          jne Digit6
          mov.b #0x92, R15                      ; Segment pattern for '5'.
          ret
Digit6:
          cmp.b #6, R14
          jne Digit7
          mov.b #0x82, R15                      ; Segment pattern for '6'.
          ret
Digit7:

cmp.b #7, R14
          jne Digit8
          mov.b #0xF8, R15                     ; Segment pattern for '7'.
          ret
Digit8:
          cmp.b #8, R14
          jne Digit9
          mov.b #0x80, R15                     ; Segment pattern for '8'.
          ret
Digit9:
      cmp.b #9, R14
      jne NotADigit
      mov.b #0x98, R15                         ; Segment pattern for '9'.
      ret
NotADigit:
      ret

;-------------------------------------------------------------------------------
; Function to increment display digits
;-------------------------------------------------------------------------------
IncrementDigits:
          inc.b R11                       ; Increments the units digit.
          cmp.b #10, R11                       ; Checks if it's time to reset (after 9).
          jne NoCarry                       ; Continues if no carry is needed.
          clr.b R11                      ; Resets units to 0.
          inc.b R12                       ; Increments tens digit.
          cmp.b #6, R12                       ; Checks if tens digit also needs resetting.
          jne NoCarry                       ; Continues if no reset needed.
          clr.b R12                      ; Resets tens digit.

NoCarry:
      ret                            ; Returns from the function.

                             nop                          ; No operation.


;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
          .global __STACK_END
          .sect .stack

;-------------------------------------------------------------------------------
; Interrupt Vectors

;-------------------------------------------------------------------------------
          .sect ".reset"                  ; MSP430 RESET Vector
          .short RESET

          .sect ".int42"                 ; Timer B ISR vector
          .short ISR_TB0