title	"Capacitive touch using ADC"
    PROCESSOR	18F45K22
  
    #include    <xc.inc>
    #include    "pic18f45k22.inc"
    
    
    ; CONFIG1H
  CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block)
  CONFIG  PLLCFG = OFF          ; 4X PLL Enable (Oscillator used directly)
  CONFIG  PRICLKEN = ON         ; Primary clock enable bit (Primary clock is always enabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enable bit (Fail-Safe Clock Monitor disabled)
  CONFIG  IESO = OFF            ; Internal/External Oscillator Switchover bit (Oscillator Switchover mode disabled)

; CONFIG2L
  CONFIG  PWRTEN = OFF          ; Power-up Timer Enable bit (Power up timer disabled)
  CONFIG  BOREN = SBORDIS       ; Brown-out Reset Enable bits (Brown-out Reset enabled in hardware only (SBOREN is disabled))
  CONFIG  BORV = 190            ; Brown Out Reset Voltage bits (VBOR set to 1.90 V nominal)

; CONFIG2H
  CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bits (Watch dog timer is always disabled. SWDTEN has no effect.)
  CONFIG  WDTPS = 32768         ; Watchdog Timer Postscale Select bits (1:32768)

; CONFIG3H
  CONFIG  CCP2MX = PORTC1       ; CCP2 MUX bit (CCP2 input/output is multiplexed with RC1)
  CONFIG  PBADEN = ON           ; PORTB A/D Enable bit (PORTB<5:0> pins are configured as analog input channels on Reset)
  CONFIG  CCP3MX = PORTB5       ; P3A/CCP3 Mux bit (P3A/CCP3 input/output is multiplexed with RB5)
  CONFIG  HFOFST = ON           ; HFINTOSC Fast Start-up (HFINTOSC output and ready status are not delayed by the oscillator stable status)
  CONFIG  T3CMX = PORTC0        ; Timer3 Clock input mux bit (T3CKI is on RC0)
  CONFIG  P2BMX = PORTD2        ; ECCP2 B output mux bit (P2B is on RD2)
  CONFIG  MCLRE = EXTMCLR       ; MCLR Pin Enable bit (MCLR pin enabled, RE3 input pin disabled)

; CONFIG4L
  CONFIG  STVREN = ON           ; Stack Full/Underflow Reset Enable bit (Stack full/underflow will cause Reset)
  CONFIG  LVP = ON              ; Single-Supply ICSP Enable bit (Single-Supply ICSP enabled if MCLRE is also 1)
  CONFIG  XINST = OFF           ; Extended Instruction Set Enable bit (Instruction set extension and Indexed Addressing mode disabled (Legacy mode))

; CONFIG5L
  CONFIG  CP0 = OFF             ; Code Protection Block 0 (Block 0 (000800-001FFFh) not code-protected)
  CONFIG  CP1 = OFF             ; Code Protection Block 1 (Block 1 (002000-003FFFh) not code-protected)
  CONFIG  CP2 = OFF             ; Code Protection Block 2 (Block 2 (004000-005FFFh) not code-protected)
  CONFIG  CP3 = OFF             ; Code Protection Block 3 (Block 3 (006000-007FFFh) not code-protected)

; CONFIG5H
  CONFIG  CPB = OFF             ; Boot Block Code Protection bit (Boot block (000000-0007FFh) not code-protected)
  CONFIG  CPD = OFF             ; Data EEPROM Code Protection bit (Data EEPROM not code-protected)

; CONFIG6L
  CONFIG  WRT0 = OFF            ; Write Protection Block 0 (Block 0 (000800-001FFFh) not write-protected)
  CONFIG  WRT1 = OFF            ; Write Protection Block 1 (Block 1 (002000-003FFFh) not write-protected)
  CONFIG  WRT2 = OFF            ; Write Protection Block 2 (Block 2 (004000-005FFFh) not write-protected)
  CONFIG  WRT3 = OFF            ; Write Protection Block 3 (Block 3 (006000-007FFFh) not write-protected)

; CONFIG6H
  CONFIG  WRTC = OFF            ; Configuration Register Write Protection bit (Configuration registers (300000-3000FFh) not write-protected)
  CONFIG  WRTB = OFF            ; Boot Block Write Protection bit (Boot Block (000000-0007FFh) not write-protected)
  CONFIG  WRTD = OFF            ; Data EEPROM Write Protection bit (Data EEPROM not write-protected)

; CONFIG7L
  CONFIG  EBTR0 = OFF           ; Table Read Protection Block 0 (Block 0 (000800-001FFFh) not protected from table reads executed in other blocks)
  CONFIG  EBTR1 = OFF           ; Table Read Protection Block 1 (Block 1 (002000-003FFFh) not protected from table reads executed in other blocks)
  CONFIG  EBTR2 = OFF           ; Table Read Protection Block 2 (Block 2 (004000-005FFFh) not protected from table reads executed in other blocks)
  CONFIG  EBTR3 = OFF           ; Table Read Protection Block 3 (Block 3 (006000-007FFFh) not protected from table reads executed in other blocks)

; CONFIG7H
  CONFIG  EBTRB = OFF           ; Boot Block Table Read Protection bit (Boot Block (000000-0007FFh) not protected from table reads executed in other blocks)
  
  ;-- Variable definitions 
  
 
Delay_Var1   equ  0x00
Delay_Var2   equ  0x01
Delay_Var3   equ  0x02
Delay_Var4   equ  0x03
Delay_Var5   equ  0x04
ADC_RESULT_H equ  0x05
ADC_RESULT_L equ  0x06
CAP_REG      equ  0x07

      
CAP_THRESHOLD    set    250 ;Calibrate using this variable

  
    
; -------------	
; PROGRAM START	
; -------------
;
    PSECT code,abs //Start of main code.
    ORG 		0h 			; startup address = 0000h
    GOTO		INIT

INIT:
    CALL		OSC_INIT		; Initialize the oscillator
    CALL		ADC_INIT		; Initialize the ADC
    CALL		PORT_INIT		; Initialize PORTD
		
		
MAIN: 	
    CALL		MAIN_CAP_ROUTINE        ; Routine to sense a touch
    
    TSTFSZ		CAP_REG,0
    BRA			MAIN_L1
    BCF			PORTD,1,0
    GOTO		MAIN
    
MAIN_L1:
    BSF			PORTD, 1,0
    GOTO		MAIN
      
    
OSC_INIT:
    BSF	    IRCF2		 ;Set the oscillator speed to 4MHz
    BCF	    IRCF1
    BSF	    IRCF0
    
    
    
ADC_INIT:
    MOVLB	0xF
    ;CLRF    ADRESH,W,a
    BCF	    CHS4		 ;Use the AN1 pin for ADC input
    BCF	    CHS3
    BCF	    CHS2
    BCF	    CHS1
    BSF	    CHS0
    BCF	    GO		  ; Do not being ADC conversion
    BSF	    ADON		  ; Enable the ADC
    
    MOVLW 	00000000B 	  ; ADC: ref = Vdd,Vss
    MOVWF 	ADCON1,1
    
    BCF	    ADFM		   ; Left jusrify the ADC result
    BSF	    ACQT2		   ;Use 8Tad
    BCF	    ACQT1
    BCF	    ACQT0
    BSF	    ADCS2		   ;Use a clock speed of 600kHz which is norminal
    BSF	    ADCS1
    BSF	    ADCS0
    MOVLB	0x0
    
    RETURN
    
    
PORT_INIT:
    
    BCF	    ANSELD,1,1
    BCF     TRISD,1,0
    BCF    LATD,1,0
    
    
    
    ;BSF	    ANSELD,1,1
    ;BSF	    TRISD,1
    
ADC_CONVERSION:
    BSF	     GO		    ;Set the GO bit to begin conversion
    
ADCPoll:
    BTFSC  GO		    ;Check if GO bit is cleared
    BRA	    ADCPoll
    MOVFF   ADRESH, ADC_RESULT_H	;Move results into special registers
    MOVFF   ADRESH, ADC_RESULT_L

    RETURN
    
    
CAP_TOUCH_ROUTINE:
    ;CALL		_1ms_DELAY		    ;Begin with a 1ms delay
    
    
   ; MOVLB		0xF			    ;Enable pin RA1 as digital output
    BCF	    AN10	    ;Disable analog functionality of the pin
    
    BCF	    TRISB, 1,0		    ;Makes pin a digital output
    BCF	    PORTB, 1,0		    ;This discharges the ADC capacitor
    
    CALL    _1ms_DELAY		    ;Wait for 1ms
    
    BSF	    PORTB, 1,0		    ;Charge the capacitor
    
    NOP				    ;Wait for 5us
    NOP
    NOP
    NOP
    NOP
    
    BSF	    TRISB, 1,0		    ;Initialize the pin as a digital input
    
    NOP				    ;Wait for 5us
    NOP
    NOP
    NOP
    NOP
    
    BSF	    AN10	    ;Initialize the pin as an analog input
    BCF	    CHS4	    ;Select the AN15 pin to be sampled
    BSF	    CHS3
    BCF	    CHS2
    BSF	    CHS1
    BCF	    CHS0
    
    CALL    ADC_CONVERSION	    ;Perform the Conversion
    
    RETURN

    
    
MAIN_CAP_ROUTINE:
    BCF	    CHS4	    ;Use the AN10 pin for ADC input
	BSF	    CHS3
	BCF	    CHS2
	BSF	    CHS1
	BCF	    CHS0
	BCF	    GO		    ;Do not begin ADC conversion
	BSF	    ADON	    ;Enable the ADC

	CLRF    ADCON1,1		    ;Vref+ = Vdd , Vref- = Vss

	BCF	    ADFM	    ;Left justify the ADC result
	BSF	    ACQT2	    ;Use 8Tad
	BCF	    ACQT1
	BCF	    ACQT0
	BSF	    ADCS2	    ;Use a clock speed of 600Khz which is nominal
	BSF	    ADCS1	    
	BSF	    ADCS0 
	
    CALL		CAP_TOUCH_ROUTINE
    CALL		_1s_DELAY
    CALL		CAP_TOUCH_ROUTINE	    ; Sample twive to avoid false triggers
    
    MOVLW		CAP_THRESHOLD
    CPFSLT		ADC_RESULT_H,0		    ;A touch indicates a value below the CAP_THRESHOLD
    BRA			MAIN_CAP_ROUTINE_L1	    ;Branch to this label if the value is above the CAP_TRESHOLD
    SETF		CAP_REG,0			    ;Set CAP_REG if touch is detected
    BRA			EXIT_MAIN_CAP_ROUTINE
    
MAIN_CAP_ROUTINE_L1:
    CLRF    CAP_REG,0			    ; Clear CAP-REG if touch is not detected
    
    
EXIT_MAIN_CAP_ROUTINE:
    RETURN
    
_1ms_DELAY:
    MOVLW		0xA6
    MOVWF		Delay_Var5,0
    
_1ms_DELAY_L2:
    MOVLW		0x4
    MOVWF		Delay_Var4,0
    
 _1ms_DELAY_L1:
    DECFSZ		Delay_Var4,a
    BRA			_1ms_DELAY_L1
    DECFSZ		Delay_Var5,a
    BRA			_1ms_DELAY_L2
    
    RETURN
    
    
_1s_DELAY:
    MOVLW		0xCA
    MOVWF		Delay_Var3,0
    
_1s_DELAY_L3:
    MOVLW		0x1B
    MOVWF		Delay_Var2,0
    
_1s_DELAY_L2:
    MOVLW		0x28
    MOVWF		Delay_Var1,0
    
_1s_DELAY_L1:
    DECFSZ		Delay_Var1,a
    BRA			_1s_DELAY_L1
    DECFSZ		Delay_Var2,a
    BRA			_1s_DELAY_L2
    DECFSZ		Delay_Var3,a
    BRA			_1s_DELAY_L3
    
    RETURN
    
    end