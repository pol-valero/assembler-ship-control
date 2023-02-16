LIST P=PIC18F4321 F=INHX32
#include <p18f4321.inc>
    
CONFIG OSC=INTIO2
CONFIG PBADEN=DIG
CONFIG WDT=OFF

;--------------------------------------
; DEFINIM VARIABLES
;--------------------------------------
; Constants per guardar el valor de velocitat en 7Segments
CONST_7SEG_HIGH  EQU  0x00
CONST_7SEG_MID   EQU  0x01
CONST_7SEG_LOW   EQU  0x02
CONST_7SEG_0	 EQU  0x03
; Flag per saber si la velocitat és negativa (=1) o positiva (=0)
IS_NEGATIVE	 EQU  0x04
; Flag per saber si estem a mode manual (=1) o creuer (=0)
MANUAL_MODE	 EQU  0x05
; Codi vel: 1 --> High Negative
	   ;2 --> Mid Negative
	   ;3 --> Low Negative
	   ;4 --> 0
	   ;5 --> Low Positive
	   ;6 --> Mid Positive
	   ;7 --> High Positive 
VEL_ACTUAL	 EQU  0x06
; Comptador per filtrar rebots
ContRebotsL	 EQU  0x07
ContRebotsH	 EQU  0x08 
; Comptador per comptar 1 minut (per inactivitat)
TicsMinH	 EQU  0x09
TicsMinL	 EQU  0x10
; Flag per saber si l'alarma està activa (=1) o no (=0)
ALARM_EN	 EQU  0x11
; Comptador per comptar mig segon (pampallugues de l'alarma)
TicsAlarmL	 EQU  0x12
TicsAlarmH	 EQU  0x13
; Flag per habilitar el comptatge de temps del polsador RecordMode 
; de 1 segon (=1) o deshabilitar-lo (=0)
AUTOP_EN	 EQU  0x14
; Comptador per comptar 1 segon (pel polsador recording)
TicsSegL	 EQU  0x15
TicsSegH	 EQU  0x16
; Flag per saber si estem en mode recording (=1) o no ho estem (=0)
RECORD_MODE	 EQU  0x17

ORG 0x0000
GOTO MAIN
ORG 0x0008
GOTO HIGH_RSI
ORG 0x0018
RETFIE FAST

;--------------------------------------
; FUNCIONS PEL TIMER
;--------------------------------------
; Recarrega el valor del timer per una interrupció cada 1ms
LOAD_TMR
  MOVLW HIGH(.61536)
  MOVWF TMR0H,0
  MOVLW LOW(.61536)
  MOVWF TMR0L,0  
  RETURN

; Reseteja el comptador de 1min   
RESET_TICS_MIN
  CLRF ALARM_EN
  CLRF TicsMinH
  CLRF TicsMinL
  RETURN

; Reseteja el comptador de 1seg   
RESET_TICS_SEG
  INCF AUTOP_EN,1
  CLRF TicsSegH
  CLRF TicsSegL
  RETURN
  
; Reseteja el comptador de 0,5seg   
RESET_TICS_ALARM
  CLRF TicsAlarmH
  CLRF TicsAlarmL
  RETURN

; Gestiona totes les interrupcions (nomes tenim de timer)
HIGH_RSI
  BTFSS INTCON,TMR0IF,0
  RETFIE FAST
  BCF INTCON,TMR0IF,0
  CALL LOAD_TMR
  BTFSC AUTOP_EN,0
  CALL CHECK_TICS_SEG
  BTFSS ALARM_EN,0
  GOTO CHECK_TICS_MIN
  GOTO MINUTE_PASSED

; Comprova si ha passat 1 minut d'inactivitat (60000ms = 1min)
CHECK_TICS_MIN
  INCF TicsMinL,1
  BTFSC STATUS,C,0
  INCF TicsMinH,1
  MOVLW HIGH(.60000)
  SUBWF TicsMinH,0
  BTFSS STATUS,Z,0
  RETFIE FAST
  MOVLW LOW(.60000)
  SUBWF TicsMinL,0
  BTFSS STATUS,Z,0
  RETFIE FAST
; Aqui ha passat 1min
MOVLW .1
MOVWF ALARM_EN
BSF LATA,3,0
CALL RESET_TICS_ALARM

; Activa l'alarma fent pampallugues canviant cada 0,5seg el led (500ms = 0,5seg)
MINUTE_PASSED
  INCF TicsAlarmL,1
  BTFSC STATUS,C,0
  INCF TicsAlarmH,1
  MOVLW HIGH(.500)
  SUBWF TicsAlarmH,0
  BTFSS STATUS,Z,0
  RETFIE FAST
  MOVLW LOW(.500)
  SUBWF TicsAlarmL,0
  BTFSS STATUS,Z,0
  RETFIE FAST
  BTG LATA,3,0
  CALL RESET_TICS_ALARM
  RETFIE FAST

; Comprova si el polsador Record ha passat 1 segon polsat
CHECK_TICS_SEG
  INCF TicsSegL,1
  BTFSC STATUS,C,0
  INCF TicsSegH,1
  MOVLW HIGH(.1000)
  SUBWF TicsSegH,0
  BTFSS STATUS,Z,0
  RETURN
  MOVLW LOW(.1000)
  SUBWF TicsSegL,0
  BTFSS STATUS,Z,0
  RETURN
  ; Ha passat 1 segon per tant canviem al mode pilot automatic
  BTFSS MANUAL_MODE,0
  RETURN
  CLRF RECORD_MODE
  BTG LATA,4,0 ;TODO: DEBUGGING
  RETURN
    
;--------------------------------------
; FUNCIONS PELS POLSADORS (per polling)
;--------------------------------------
; Actualitza el led de velocitat negativa
UPDATE_SPEED
  MOVLW .4
  SUBWF VEL_ACTUAL,0
  BTFSS STATUS,N,0
  BCF LATA,3,0
  BTFSC STATUS,N,0
  BSF LATA,3,0
  RETURN

; Canvia el mode a manual
CHANGE_TO_MANUAL
  SETF MANUAL_MODE
  GOTO ESPERA_FI_P0

; Canvia el mode a creuer
CHANGE_TO_CRUISE
  CLRF MANUAL_MODE
  GOTO ESPERA_FI_P0  

; Canvia el mode del polsador manual pel corresponent (filtrant rebots)
CHANGE_MANUAL_MODE
  CALL COUNT_20ms
  CALL RESET_TICS_MIN
  BTFSS MANUAL_MODE,0
  GOTO CHANGE_TO_MANUAL
  GOTO CHANGE_TO_CRUISE
  ESPERA_FI_P0
    BTFSS PORTB,0,0
    GOTO ESPERA_FI_P0
  CALL COUNT_20ms
  CALL UPDATE_SPEED
  RETURN

; Canvia el mode a gravacio
CHANGE_TO_RECORD
  SETF RECORD_MODE
  GOTO ESPERA_FI_P1

; Canvia el mode a no gravacio
CHANGE_TO_NO_RECORD
  CLRF RECORD_MODE
  GOTO ESPERA_FI_P1
  
; Activa i desactiva el mode de gravacio i pilot automatic (filtrant rebots)
CHANGE_RECORDING_MODE
  CALL COUNT_20ms
  CALL RESET_TICS_MIN
  CALL RESET_TICS_SEG
  BTFSS RECORD_MODE,0
  GOTO CHANGE_TO_RECORD
  GOTO CHANGE_TO_NO_RECORD
  ESPERA_FI_P1
    BTFSS PORTB,1,0
    GOTO ESPERA_FI_P1
  CALL COUNT_20ms
  CLRF AUTOP_EN
  CALL UPDATE_SPEED
  RETURN
 
;--------------------------------------
; FUNCIONS DE CONFIGURACIONS INICIALS
;--------------------------------------
; Config OSC per tenir F=16MHz
INIT_OSC
  MOVLW b'01100000'
  MOVWF OSCCON,0
  BSF OSCTUNE,PLLEN,0
  RETURN

; Inicialitza ports a utilitzar
INIT_PORTS
  CLRF TRISD,0
  BSF TRISA,0,0
  BSF TRISB,0,0
  BSF TRISB,1,0
  BCF TRISA,3,0
  BCF INTCON2,RBPU,0
  BCF TRISA,4,0 ;TODO: DEBUGGING
  RETURN

; Inicialitza variables a utilitzar
INIT_VARS
  MOVLW b'00110111'
  MOVWF CONST_7SEG_HIGH
  MOVLW b'01110101'
  MOVWF CONST_7SEG_MID
  MOVLW b'00001101'
  MOVWF CONST_7SEG_LOW
  MOVLW b'01111101'
  MOVWF CONST_7SEG_0
  SETF MANUAL_MODE
  BCF LATA,3,0
  CALL RESET_TICS_MIN
  MOVLW .4
  MOVWF VEL_ACTUAL
  CLRF ALARM_EN
  CLRF IS_NEGATIVE
  BCF LATA,4,0 ;TODO: DEBUGGING
  CLRF AUTOP_EN
  CLRF RECORD_MODE
  RETURN

; Inicialitza ADC pel joystick (AN0 i AN1)
INIT_ADC
  ;Analog OUT (AN0) i deshabilita Vref
  MOVLW b'00001110'
  MOVWF ADCON1,0
  ;Clear ADCON2
  CLRF ADCON2,0
  ;Enable ADC i selecciona Channel 0
  MOVLW b'00000001'
  MOVWF ADCON0,0
  RETURN

; Inicialitza les interrupcions a utilitzar (nomes la del timer)
INIT_IRQS
  BCF RCON,IPEN,0
  MOVLW b'11000000'
  MOVWF INTCON,0
  RETURN

; Inicialitza el timer a utilitzar (TIMER0)
INIT_TMR
  MOVLW b'10001111'
  MOVWF T0CON,0
  BSF INTCON,TMR0IE,0
  RETURN

;--------------------------------------
; MAIN I LOOP DEL PROGRAMA
;--------------------------------------
MAIN
  CALL INIT_OSC
  CALL INIT_PORTS
  CALL INIT_VARS
  CALL INIT_ADC
  CALL INIT_IRQS
  CALL INIT_TMR
  
LOOP
; Consulta Polsador Manual
BTFSS PORTB,0,0 
CALL CHANGE_MANUAL_MODE
; Consulta Polsador Recording
BTFSS PORTB,1,0
CALL CHANGE_RECORDING_MODE
; Check Mode
BTFSS MANUAL_MODE,0
GOTO LOOP

;Preparat per agafar l'output
BSF ADCON0,GO_NOT_DONE,0

;Procesessa l'output
WAIT_ADC
  BTFSC ADCON0,GO_NOT_DONE,0
  GOTO WAIT_ADC


;Agafa el output (en ADRESH)
;Per utilitzar 7 passos OUTPUT --> ADRESH rang (numero de valors) 
			;H (N) --> [0,38]      (39)
			;M (N) --> [39,77]     (39)
			;L (N) --> [78, 116]   (39)
			;0 --> [117,138]       (22)
			;L (P) --> [139, 177]  (39)
			;M (P) --> [178,216]   (39)
			;H (P) --> [217,255]   (39)
; Divideix in 2 parts per utilitzar el bit Negative de STATUS 
; Sense sobrepassar el limit CA2
MOVLW .139
SUBWF ADRESH,0,0
BTFSC STATUS,N,0
GOTO CHECK_LOW
GOTO CHECK_HIGH 

; Assigna les velocitats negatives
CHECK_LOW
  MOVLW .39
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_N_HIGH_7Seg
  MOVLW .78
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_N_MID_7Seg
  MOVLW .117
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_N_LOW_7Seg
  GOTO VEL_0_7Seg

; Assigna les velocitats positives
CHECK_HIGH
  MOVLW .178
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_P_LOW_7Seg 
  MOVLW .217
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_P_MID_7Seg 
  MOVLW .255
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_P_HIGH_7Seg

; Les següents funcions assignen la velocitat corresponent al 7seg i encenen
; o apaguen el led de velocitat negatiu mentre no estigui l'alarma activada
; Assigna la velocitat (N) H
VEL_N_HIGH_7Seg
  BTFSS IS_NEGATIVE,0
  GOTO VEL_P_HIGH_7Seg
  MOVLW .1
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO LOOP
  MOVLW .1
  MOVWF VEL_ACTUAL
  CALL RESET_TICS_MIN
  MOVFF CONST_7SEG_HIGH,LATD
  BTFSS ALARM_EN,0
  BSF LATA,3,0
  MOVLW .1
  MOVWF IS_NEGATIVE
  GOTO LOOP

; Assigna la velocitat (N) M 
VEL_N_MID_7Seg
  MOVLW .2
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO LOOP
  MOVLW .2
  MOVWF VEL_ACTUAL
  CALL RESET_TICS_MIN
  MOVFF CONST_7SEG_MID,LATD
  BTFSS ALARM_EN,0
  BSF LATA,3,0
  MOVLW .1
  MOVWF IS_NEGATIVE
  GOTO LOOP

; Assigna la velocitat (N) L
VEL_N_LOW_7Seg
  MOVLW .3
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO LOOP
  MOVLW .3
  MOVWF VEL_ACTUAL
  CALL RESET_TICS_MIN
  MOVFF CONST_7SEG_LOW,LATD
  BTFSS ALARM_EN,0
  BSF LATA,3,0
  MOVLW .1
  MOVWF IS_NEGATIVE
  GOTO LOOP

; Assigna la velocitat 0
VEL_0_7Seg
  MOVLW .4
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO LOOP
  MOVLW .4
  MOVWF VEL_ACTUAL
  CALL RESET_TICS_MIN
  MOVFF CONST_7SEG_0,LATD
  BTFSS ALARM_EN,0
  BCF LATA,3,0
  CLRF IS_NEGATIVE
  GOTO LOOP

; Assigna la velocitat (P) L 
VEL_P_LOW_7Seg
  MOVLW .5
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO LOOP
  MOVLW .5
  MOVWF VEL_ACTUAL
  CALL RESET_TICS_MIN
  MOVFF CONST_7SEG_LOW,LATD
  BTFSS ALARM_EN,0
  BCF LATA,3,0
  CLRF IS_NEGATIVE
  GOTO LOOP

; Assigna la velocitat (P) M
VEL_P_MID_7Seg
  MOVLW .6
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO LOOP
  MOVLW .6
  MOVWF VEL_ACTUAL
  CALL RESET_TICS_MIN
  MOVFF CONST_7SEG_MID,LATD
  BTFSS ALARM_EN,0
  BCF LATA,3,0
  CLRF IS_NEGATIVE
  GOTO LOOP

; Assigna la velocitat (P) H
VEL_P_HIGH_7Seg
  MOVLW .7
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO LOOP
  MOVLW .7
  MOVWF VEL_ACTUAL
  CALL RESET_TICS_MIN
  MOVFF CONST_7SEG_HIGH,LATD
  BTFSS ALARM_EN,0
  BCF LATA,3,0
  CLRF IS_NEGATIVE
  GOTO LOOP


;--------------------------------------
; COMPTATGES D'INSTRUCCIONS
;--------------------------------------

; Compta 20ms corresponents al temps de rebots dels polsadors 
; TTarget = 20ms | Tinst = 250ns --> #inst = 80.000 - 4 = 79996
; 4 + (4*X + 6)*Y = 79996 --> X = 255 | Y = 78
COUNT_20ms
  MOVLW .1 ;x = 256 - 255 = 1
  MOVWF ContRebotsL
  MOVLW .178 ;y = 256 - 78 = 178
  MOVWF ContRebotsH
  T_REBOTS
    INCF ContRebotsL,1
    BTFSS STATUS,C,0
    GOTO T_REBOTS
    MOVLW .1
    MOVWF ContRebotsL
    INCF ContRebotsH,1
    BTFSS STATUS,C,0
    GOTO T_REBOTS
  RETURN
	
END