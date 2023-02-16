;    LIST P=PIC18F4321 F=INHX32
;#include <p18f4321.inc>
;    
;CONFIG OSC=HS
;CONFIG PBADEN=DIG
;CONFIG WDT=OFF
;    
;ORG 0x0000
;GOTO MAIN
;ORG 0x0008
;RETFIE FAST
;ORG 0x0018
;RETFIE FAST
;
;; Definim variables  
;  
;   
;INIT_PORTS
;  RETURN
;
;INIT_EUSART
;  ; Set EUSART PORTs
;  BSF TRISC,6,0
;  BSF TRISC,7,0
;  ; Load TXSTA
;  MOVLW b'00100110'
;  MOVWF TXSTA,0
;  ; Load RCSTA
;  MOVLW b'10010000'
;  MOVWF RCSTA,0
;  ; Load BAUDCON
;  MOVLW b'01001000'
;  ; Load the n (Baud Rate)
;  MOVLW HIGH(.259)
;  MOVWF SPBRGH,0
;  MOVLW LOW(.259)
;  MOVWF SPBRG,0  
;  RETURN
;MAIN
;  CALL INIT_PORTS
;  CALL INIT_EUSART  
;LOOP
;  ; Wait TXReg to be empty
;  WAIT_TX_EMPTY
;    BTFSS   TXSTA,TRMT,0
;    GOTO    WAIT_TX_EMPTY
;  ; Load TXReg
;  MOVLW .9
;  MOVWF TXREG,0
;  
;  GOTO LOOP	
;
;END
    LIST P=PIC18F4321   F=INHX32

;El com es troba en el administrador de dispositivos

    #include <p18f4321.inc>

    CONFIG  OSC=HS     ; L?oscil.lador

    CONFIG  PBADEN=DIG ; Volem que el PORTB sigui DIGital

    CONFIG  WDT=OFF    ; Desactivem el WatchDog Timer

    

    LoQueTransmeto EQU 0X00

    LoQueRebo EQU 0X01

 

    ORG     0x0000

    GOTO    MAIN 

    ORG     0x0008

    RETFIE FAST

    ;GOTO ProcessaRSI

    ORG     0x0018

    RETFIE FAST

    ;ProcessaRSI

    INTSIO

BSF TRISC,6,0

BSF TRISC,7,0

MOVLW b'00100100'  ;BIT 2 HIGH SPEED OR LOW SPEED?

MOVWF TXSTA,0

MOVLW b'10010000'

MOVWF RCSTA,0

MOVLW b'00001000'

MOVWF BAUDCON,0

MOVLW high(.259)

MOVWF SPBRGH,0

movlw low(.259)

MOVWF SPBRG,0

    RETURN

   
INIT_ADC
  ;Analog OUT (AN0) and disable Vref
  MOVLW b'00001110'
  MOVWF ADCON1,0
  ;Clear ADCON2
  CLRF ADCON2,0
  ;Enable ADC and select Channel 0
  MOVLW b'00000001'
  MOVWF ADCON0,0
  RETURN
  
MAIN

    SETF ADCON1,0; Configurem el PORTA digital 

    BCF TRISA,3,0

    BCF TRISA,4,0
    CALL INIT_ADC
    CALL INTSIO

    

LOOP
    Call EsperaSIOTX
    
    ;Ready to pick output
    BSF ADCON0,GO_NOT_DONE,0

    ;Process output
    WAIT_ADC
      BTFSC ADCON0,GO_NOT_DONE,0
      GOTO WAIT_ADC
    MOVFF ADRESH, TXREG
    ;Ready to pick output
    Call EsperaSIOTX
      
    MOVFF ADRESL, TXREG
    
    GOTO EsperaByte
    
    GOTO LOOP

EsperaSIOTX

    BTFSS TXSTA,TRMT,0 ;SKIP IF EMMPTY

    GOTO EsperaSIOTX

EsperaByte

    BTFSS PIR1,RCIF,0  ;Si es fica a 1 eesque ha entrat un nou byte,i aquets byte esta en el rcreg

    GOTO EsperaByte

    MOVFF RCREG,LoQueRebo ;Moc lo que rebu a la equ
    
    MOVLW .2
    SUBWF LoQueRebo,0
    BTFSS STATUS,Z,0
    GOTO EsperaByte
    ; Hem rebut un 2
    RETURN


END