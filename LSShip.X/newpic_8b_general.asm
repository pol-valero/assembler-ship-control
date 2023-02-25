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
ContInstL	 EQU  0x07
ContInstH	 EQU  0x08 
; Comptador per comptar 1 minut (per inactivitat)
TicsMinH	 EQU  0x09
TicsMinL	 EQU  0x0A
; Flag per saber si l'alarma està activa (=1) o no (=0)
ALARM_EN	 EQU  0x0B
; Comptador per comptar mig segon (pampallugues de l'alarma)
TicsAlarmL	 EQU  0x0C
TicsAlarmH	 EQU  0x0D
; Flag per habilitar el comptatge de temps del polsador RecordMode 
; de 1 segon (=1) o deshabilitar-lo (=0)
AUTOP_EN	 EQU  0x0E
; Comptador per comptar 1 segon (pel polsador recording)
TicsSegL	 EQU  0x0F
TicsSegH	 EQU  0x10
; Flag per saber si estem en mode recording (=1) o no ho estem (=0)
RECORD_MODE	 EQU  0x11
; Comptador per comptar periodes de PWM del servo (20ms)
Tics20		 EQU  0x12
; Codi dir: 1 --> Max Left
	   ;2 --> High Left
	   ;3 --> Mid Left
	   ;4 --> Low Left
	   ;5 --> Straight
	   ;6 --> Low Right
	   ;7 --> Mid Right 
	   ;8 --> High Right
	   ;9 --> Max Right
DIR_ACTUAL	 EQU  0x13
; Flag per saber si la direccio és esquerra (=1) o dreta (=0)
IS_LEFT		 EQU  0x14
; Comptador per comptar el THigh del PWM del servo
ContTHigh	 EQU  0x15
; Comptador per comptar el numero de passos que li toca al PWM
ContPWML	 EQU  0x16
ContPWMH	 EQU  0x17
; Comptador per comptar el delay entre save i save de 1ms en 1ms i fins a 1min
TicsDelayL	 EQU  0x18
TicsDelayH	 EQU  0x19
; Comptador per comptar el numero de Saves que ha fet per una ruta (max 30)
ContSaves	 EQU  0x1A
; Flag per saber si estem en mode pilot automatic (=1) o no (=0)
AUTOP_MODE	 EQU  0x1B
; Flag per saber si estem fent una espera de delay en el mode automatic 
; (=1) o no (=0)
DELAY_ESPERA_EN	 EQU  0x1C
; Temps de delay que tenim entre un save i un altre
; El delay el treiem del que llegim a la RAM en el mode pilot automatic
TIME_DELAY_L	 EQU  0x1D
TIME_DELAY_H	 EQU  0x1E
; Temps en el que el motor DC estara configurat a HIGH 
T_HIGH_DC	 EQU  0x1F
; Temps en el que el motor DC estara configurat a LOW 
T_LOW_DC	 EQU  0x20
; Flag per indicar que el PWM del motor DC esta a HIGH
DC_IS_SET	 EQU  0x21
; Els Tics configurats de periode del motor DC
TicsDC		 EQU  0x22

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
  
; Reseteja el comptador de delay entre save i save
RESET_TICS_DELAY
  CLRF TicsDelayH
  CLRF TicsDelayL
  RETURN

; Reseteja el comptador de 1seg   
RESET_TICS_SEG
  SETF AUTOP_EN,0
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
  CALL CHECK_PWM_DC
  CALL CHECK_20ms
  BTFSC DELAY_ESPERA_EN,0
  CALL CHECK_TICS_DELAY_AUTO
  BTFSC RECORD_MODE,0
  CALL CHECK_TICS_DELAY_REC
  BTFSC AUTOP_EN,0
  CALL CHECK_TICS_SEG
  BTFSS ALARM_EN,0
  GOTO CHECK_TICS_MIN
  GOTO MINUTE_PASSED

; Espera el temps de delay que se li ha assignat
CHECK_TICS_DELAY_AUTO
  INCF TicsDelayL,1
  BTFSC STATUS,C,0
  INCF TicsDelayH,1
  MOVF TIME_DELAY_H,0
  SUBWF TicsDelayH,0
  BTFSS STATUS,Z,0
  RETURN
  MOVF TIME_DELAY_L,0
  SUBWF TicsDelayL,0
  BTFSS STATUS,Z,0
  RETURN
  ; Ha passat el temps de delay aixi que desactivem el enable de espera
  CLRF DELAY_ESPERA_EN
  RETURN
  
; Compta el delay de Save en Save en el mode Record i avisa si ha passat 1min
CHECK_TICS_DELAY_REC
  INCF TicsDelayL,1
  BTFSC STATUS,C,0
  INCF TicsDelayH,1
  MOVLW HIGH(.58850)
  SUBWF TicsDelayH,0
  BTFSS STATUS,Z,0
  RETURN
  MOVLW LOW(.58850)
  SUBWF TicsDelayL,0
  BTFSS STATUS,Z,0
  RETURN
  CLRF RECORD_MODE
  CALL RESET_TICS_MIN
  SETF MANUAL_MODE
  CALL RGB_GREEN
  RETURN

; Crea el PWM del motor DC
CHECK_PWM_DC
  GOTO ASSIGN_PWM_VEL
  CONTINUE_VEL
  INCF TicsDC,1
  BTFSC DC_IS_SET,0
  GOTO TEMPS_DC_HIGH
  GOTO TEMPS_DC_LOW
  GO_BACK_DC
  RETURN
 
; Assigna el periode del PWM segons la seva velocitat
ASSIGN_PWM_VEL
  MOVLW .1
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO PWM_VEL_H
  MOVLW .2
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO PWM_VEL_M
  MOVLW .3
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO PWM_VEL_L
  MOVLW .4
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO PWM_VEL_0
  MOVLW .5
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO PWM_VEL_L
  MOVLW .6
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO PWM_VEL_M
  MOVLW .7
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO PWM_VEL_H

; Assigna el periode de PWM de velocitat low en el motor DC
PWM_VEL_L
  MOVLW .1
  MOVWF T_HIGH_DC
  MOVLW .4
  MOVWF T_LOW_DC
  GOTO CONTINUE_VEL
  
; Assigna el periode de PWM de velocitat mid en el motor DC
PWM_VEL_M
  MOVLW .2
  MOVWF T_HIGH_DC
  MOVLW .3
  MOVWF T_LOW_DC
  GOTO CONTINUE_VEL
  
; Assigna el periode de PWM de velocitat high en el motor DC
PWM_VEL_H
  CALL ACTIVA_PORT_DC
  GOTO GO_BACK_DC
 
; Assigna el periode de PWM de velocitat 0 en el motor DC
PWM_VEL_0
  BCF LATB,6,0
  BCF LATB,7,0
  GOTO GO_BACK_DC

; Activa el pin del PWM del motor DC segons si la velocitat es negativa o no
ACTIVA_PORT_DC
  BTFSS IS_NEGATIVE,0
  CALL ACTIVA_RB6
  BTFSC IS_NEGATIVE,0
  CALL ACTIVA_RB7
  RETURN
 
; Activa el pin RB6 (pel PWM del motor DC)
ACTIVA_RB6
  BSF LATB,6,0
  BCF LATB,7,0
  RETURN
  
; Activa el pin RB7 (pel PWM del motor DC)
ACTIVA_RB7
  BCF LATB,6,0
  BSF LATB,7,0
  RETURN
  
; Desactiva el pin del PWM del motor DC segons si la velocitat es negativa o no
DESACTIVA_PORT_DC
  BTFSS IS_NEGATIVE,0
  BCF LATB,6,0
  BTFSC IS_NEGATIVE,0
  BCF LATB,7,0
  RETURN
 
; Periode de temps que el motor DC estara apagat
TEMPS_DC_LOW  
  MOVF T_LOW_DC,0
  SUBWF TicsDC,0
  BTFSS STATUS,Z,0
  GOTO GO_BACK_DC
  CALL ACTIVA_PORT_DC
  CLRF TicsDC
  SETF DC_IS_SET,0
  GOTO GO_BACK_DC
 
; Periode de temps que el motor DC estara ences  
TEMPS_DC_HIGH
  MOVF T_HIGH_DC,0
  SUBWF TicsDC,0
  BTFSS STATUS,Z,0
  GOTO GO_BACK_DC
  CLRF TicsDC
  CALL DESACTIVA_PORT_DC
  CLRF DC_IS_SET,0
  GOTO GO_BACK_DC
  
; Comprova si ha passat 20ms (1 periode de PWM del servo)
CHECK_20ms
  INCF Tics20,1
  MOVLW .20
  SUBWF Tics20,0
  BTFSC STATUS,Z,0
  CALL NEW_SERVO_PWM
  RETURN
  
; Posa el temps a 1 que marca la direccio actual 
NEW_SERVO_PWM
  MOVFF DIR_ACTUAL,ContTHigh
  BSF LATA,2,0
  CALL POS_INICIAL_SERVO
  MOVLW .1
  SUBWF ContTHigh,0
  BTFSC STATUS,Z,0
  GOTO END_PASSOS
  DECF ContTHigh,1
  T_PASSOS
    CALL COUNT_PAS_SERVO
    DECF ContTHigh,1
    BTFSS STATUS,Z,0
    GOTO T_PASSOS
  END_PASSOS
  BCF LATA,2,0
  CLRF Tics20
  RETURN
  
; Comprova si ha passat 1 minut d'inactivitat (60000ms = 1min)
CHECK_TICS_MIN
  BTFSC AUTOP_MODE,0
  RETFIE FAST
  INCF TicsMinL,1
  BTFSC STATUS,C,0
  INCF TicsMinH,1
  MOVLW HIGH(.58850)
  SUBWF TicsMinH,0
  BTFSS STATUS,Z,0
  RETFIE FAST
  MOVLW LOW(.58850)
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
  ; Si estem canviant de mode a recording a manual, ignorem la pulsacio
  BTFSC RECORD_MODE,0
  RETURN
  ; Si no hem guardat res, no canviem al mode pilot automatic
  MOVLW .0
  SUBWF ContSaves,0
  BTFSC STATUS,Z,0
  RETURN
  SETF AUTOP_MODE,0
  CALL RGB_WHITE
  CALL INITIAL_POSITION_RAM
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
  CALL RGB_GREEN
  GOTO ESPERA_FI_P0

; Canvia el mode a creuer
CHANGE_TO_CRUISE
  CLRF MANUAL_MODE
  CALL RGB_BLUE
  GOTO ESPERA_FI_P0  

; Canvia el mode del polsador manual pel corresponent (filtrant rebots)
CHANGE_MANUAL_MODE
  CALL COUNT_20ms
  BTFSC RECORD_MODE,0
  GOTO ESPERA_FI_P0
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
  CALL NETEJA_RAM
  CALL INITIAL_POSITION_RAM
  CALL RESET_TICS_DELAY
  CLRF ContSaves
  CALL RGB_RED
  GOTO FINAL_P1

; Canvia el mode a no gravacio
CHANGE_TO_NO_RECORD
  CLRF RECORD_MODE
  CALL RGB_GREEN
  SETF MANUAL_MODE,0
  MOVLW .0
  SUBWF ContSaves,0
  BTFSS STATUS,Z,0
  CALL TIME_SAVE
  GOTO FINAL_P1
  
; Activa i desactiva el mode de gravacio i pilot automatic (filtrant rebots)
; Es canvia de mode quan deixem anar el polsador
CHANGE_RECORDING_MODE
  CALL COUNT_20ms
  BTFSS MANUAL_MODE,0
  RETURN
  CALL RESET_TICS_MIN
  CALL RESET_TICS_SEG
  CALL UPDATE_SPEED
  ESPERA_FI_P1
    BTFSS PORTB,1,0
    GOTO ESPERA_FI_P1
  CALL COUNT_20ms
  CLRF AUTOP_EN
  ; Si s'ha activat el mode pilot automatic, no canviem de mode de gravacio
  BTFSC AUTOP_MODE,0
  RETURN
  BTFSS RECORD_MODE,0
  GOTO CHANGE_TO_RECORD
  GOTO CHANGE_TO_NO_RECORD
  FINAL_P1
  RETURN

; Guarda la velocitat, direccio i delay si estem en el mode record
SAVE_PARAMS
  CALL COUNT_20ms
  BTFSS RECORD_MODE,0
  GOTO ESPERA_FI_P2
  INCF ContSaves,1
  MOVLW .1
  SUBWF ContSaves,0
  BTFSS STATUS,Z,0
  CALL TIME_SAVE
  ; Guardar velocitat
  MOVFF VEL_ACTUAL,POSTINC0
  ; Guardar direccio
  MOVFF DIR_ACTUAL,POSTINC0

  ; Reiniciar delay
  CALL RESET_TICS_DELAY
  CALL RESET_TICS_MIN
  MOVLW .30
  SUBWF ContSaves,0
  BTFSC STATUS,Z,0
  GOTO SAVES_30
  ESPERA_FI_P2
    BTFSS PORTB,2,0
    GOTO ESPERA_FI_P2
  CALL COUNT_20ms
  RETURN

TIME_SAVE
  ; Guardar delay (primer Low i despres High)
  MOVFF TicsDelayL,POSTINC0
  MOVFF TicsDelayH,POSTINC0
  RETURN
  
; Tornem al mode manual perque s'han fet 30 saves (el maxim)
SAVES_30
  CLRF RECORD_MODE
  CALL RGB_GREEN
  SETF MANUAL_MODE,0
  GOTO ESPERA_FI_P2
;--------------------------------------
; FUNCIONS DE CONFIGURACIONS DE LA RAM
;--------------------------------------
; Inicialitza la RAM a la posicio inicial on guardarem els valors 
; dels parametres. Comença a la posicio 0 del Bank 1
INITIAL_POSITION_RAM
  ; Situem a l'adreça 0
  CLRF FSR0L,0
  ; Situem al Bank 1
  MOVLW .1
  MOVWF FSR0H,0
  RETURN
  

; Neteja (posa a 0) les 128 primeres adreces del Bank 1
; Ja que com a maxim omplirem 4@ * 30saves = 120@
NETEJA_RAM
  CALL INITIAL_POSITION_RAM
  CLRF ContInstL
  NETEJA
    INCF ContInstL,1
    CLRF POSTINC0,0
    BTFSS STATUS,OV,0
    GOTO NETEJA
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
  BSF TRISA,0,0
  BSF TRISA,1,0
  BCF TRISA,2,0 
  BCF TRISA,3,0
  BSF TRISB,0,0
  BSF TRISB,1,0
  BSF TRISB,2,0
  BCF TRISB,3,0
  BCF TRISB,4,0
  BCF TRISB,6,0
  BCF TRISB,7,0
  CLRF TRISC,0
  CLRF TRISD,0
  BCF TRISE,0,0
  BCF TRISE,1,0
  BCF TRISE,2,0
  BCF INTCON2,RBPU,0
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
  MOVFF CONST_7SEG_0,LATD
  CALL RGB_GREEN
  CALL RESET_TICS_MIN
  MOVLW .4
  MOVWF VEL_ACTUAL
  MOVLW .5
  MOVWF DIR_ACTUAL
  CLRF ALARM_EN
  CLRF IS_NEGATIVE
  CLRF AUTOP_EN
  CLRF RECORD_MODE
  CLRF Tics20
  CALL RESET_TICS_DELAY
  CLRF ContSaves
  CLRF TicsDC,0
  SETF DC_IS_SET,0
  ; Inicialitzem els PWM
  BCF LATA,2,0
  BSF LATB,6,0		    
  BCF LATB,7,0
  ; Posem els 2 leds del mig de la barra encesos
  CALL CLEAN_LED_BAR
  BSF LATC,4,0
  BSF LATC,5,0
  RETURN

; Inicialitza ADC pel joystick (AN0 i AN1)
INIT_ADC
  ;Analog OUT (AN0 & AN1) i deshabilita Vref
  MOVLW b'00001101'
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
; Reprodueix ruta si estem en mode pilot automatic
BTFSC AUTOP_MODE,0
GOTO REPRODUIR_RUTA
; Consulta Polsador Manual
BTFSS PORTB,0,0 
CALL CHANGE_MANUAL_MODE
; Consulta Polsador Recording
BTFSS PORTB,1,0
CALL CHANGE_RECORDING_MODE
; Consulta Polsador Save
BTFSS PORTB,2,0
CALL SAVE_PARAMS
; Check direccio
CALL TAKE_DIRECTION 
; Check Mode i velocitat si Manual
BTFSS MANUAL_MODE,0
GOTO LOOP

; Selecciona CH0   
BCF ADCON0,CHS0,0
CALL COUNT_CHANGE_CHANNEL
CALL WAIT_GO_ADC

;Agafa el output (en ADRESH)
;Per utilitzar 7 passos OUTPUT --> ADRESH rang (numero de valors) 
			;H (N) --> [0,38]      (39)
			;M (N) --> [39,77]     (39)
			;L (N) --> [78, 116]   (39)
			;0 --> [117,138]       (22)
			;L (P) --> [139, 177]  (39)
			;M (P) --> [178,216]   (39)
			;H (P) --> [217,255]   (39)
; Divideix en 2 parts per utilitzar el bit Negative de STATUS 
; Sense sobrepassar el limit CA2
MOVLW .139
SUBWF ADRESH,0,0
BTFSC STATUS,N,0
GOTO CHECK_LOW_VEL
GOTO CHECK_HIGH_VEL

; Assigna les velocitats negatives i el 0
CHECK_LOW_VEL
  MOVLW .39
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_N_HIGH
  MOVLW .78
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_N_MID
  MOVLW .117
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_N_LOW
  GOTO VEL_0

; Assigna les velocitats positives
CHECK_HIGH_VEL
  MOVLW .178
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_P_LOW
  MOVLW .217
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_P_MID
  MOVLW .255
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO VEL_P_HIGH

; Les següents funcions assignen la velocitat, i la posen als 7seg i encenen
; o apaguen el led de velocitat negatiu mentre no estigui l'alarma activada
; Assigna la velocitat (N) H
VEL_N_HIGH
  BTFSS IS_NEGATIVE,0
  GOTO VEL_P_HIGH
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
VEL_N_MID
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
VEL_N_LOW
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
VEL_0
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
VEL_P_LOW
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
VEL_P_MID
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
VEL_P_HIGH
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

; Assigna la direccio actual
TAKE_DIRECTION
  ; Selecciona CH1
  BSF ADCON0,CHS0,0	
  CALL COUNT_CHANGE_CHANNEL
  CALL WAIT_GO_ADC
  ;Agafa el output (en ADRESH)
  ;Per utilitzar 9 passos OUTPUT --> ADRESH rang (numero de valors) 
			;MAX (L) --> [0,10]     (11)
			;H (L) --> [11,46]      (36)
			;M (L) --> [47, 82]     (36)
			;L (L) --> [83,118]     (36)
			;S --> [119, 136]       (18)
			;L (R) --> [137,172]    (36)
			;M (R) --> [173,208]    (36)
			;H (R) --> [209,244]    (36)
			;MAX (R) --> [245,255]  (11)
  
  ; Divideix in 2 parts per utilitzar el bit Negative de STATUS 
  ; Sense sobrepassar el limit CA2
  MOVLW .137
  SUBWF ADRESH,0,0
  BTFSC STATUS,N,0
  GOTO CHECK_LOW_DIR
  GOTO CHECK_HIGH_DIR
  
  ; Assigna les direccions de l'esquerra i el 0
  CHECK_LOW_DIR			
    MOVLW .11
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_L_MAX
    MOVLW .47
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_L_HIGH
    MOVLW .83
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_L_MID
    MOVLW .119
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_L_LOW
    GOTO DIR_S
  
  ; Assigna les direccions de la dreta
  CHECK_HIGH_DIR
    MOVLW .173  
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_R_LOW
    MOVLW .209
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_R_MID
    MOVLW .245
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_R_HIGH
    MOVLW .255
    SUBWF ADRESH,0,0
    BTFSC STATUS,N,0
    GOTO DIR_R_MAX
    GOTO DIR_L_MAX
  
  GO_BACK
  RETURN
  
; Les següents funcions assignen la direccio, i la posen a la barra de leds,
; a mes de mesurar el PWM que haura de tenir el servo
; Assigna la direccio (L) MAX
DIR_L_MAX
  BTFSS IS_LEFT,0
  GOTO DIR_R_MAX
  MOVLW .1
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .1
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATC,0,0
  MOVLW .1
  MOVWF IS_LEFT
  GOTO GO_BACK
 
; Assigna la direccio (L) HIGH
DIR_L_HIGH
  BTFSS IS_LEFT,0
  GOTO DIR_R_MAX
  MOVLW .2
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .2
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATC,1,0
  MOVLW .1
  MOVWF IS_LEFT
  GOTO GO_BACK
  
; Assigna la direccio (L) MID
DIR_L_MID
  MOVLW .3
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .3
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATC,2,0
  MOVLW .1
  MOVWF IS_LEFT
  GOTO GO_BACK
  
; Assigna la direccio (L) LOW
DIR_L_LOW
  MOVLW .4
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .4
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATC,3,0
  MOVLW .1
  MOVWF IS_LEFT
  GOTO GO_BACK
  
; Assigna la direccio Straight (Recte)
DIR_S
  MOVLW .5
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .5
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATC,4,0
  BSF LATC,5,0
  CLRF IS_LEFT
  GOTO GO_BACK
  
; Assigna la direccio (R) LOW
DIR_R_LOW
  MOVLW .6
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .6
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATC,6,0
  CLRF IS_LEFT
  GOTO GO_BACK
  
; Assigna la direccio (R) MID
DIR_R_MID
  MOVLW .7
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .7
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATC,7,0
  CLRF IS_LEFT
  GOTO GO_BACK
  
; Assigna la direccio (R) HIGH
DIR_R_HIGH
  MOVLW .8
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .8
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATB,3,0
  CLRF IS_LEFT
  GOTO GO_BACK
  
; Assigna la direccio (R) MAX
DIR_R_MAX
  MOVLW .9
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  GOTO GO_BACK
  MOVLW .9
  MOVWF DIR_ACTUAL
  CALL RESET_TICS_MIN
  ; Encenem el valor corresponent a la barra de leds
  CALL CLEAN_LED_BAR
  BSF LATB,4,0
  CLRF IS_LEFT
  GOTO GO_BACK

  
; Treu l'output de ADC quan hagi acabat de fer la transformacio 
WAIT_GO_ADC
  ;Preparat per agafar l'output
  BSF ADCON0,GO_NOT_DONE,0
  ;Procesessa l'output
  WAIT_ADC
    BTFSC ADCON0,GO_NOT_DONE,0
    GOTO WAIT_ADC
  RETURN
  
; Reprodueix una ruta guardada
REPRODUIR_RUTA
  MOVLW .0
  SUBWF ContSaves,0
  BTFSC STATUS,Z,0
  GOTO FINAL_RUTA
  
  ; Començem a reproduir
  MOVFF POSTINC0,VEL_ACTUAL
  MOVFF POSTINC0,DIR_ACTUAL
  MOVFF POSTINC0,TIME_DELAY_L
  MOVFF POSTINC0,TIME_DELAY_H
  ; Cridem a les funcions de direccio i velocitat
  CALL ASSIGNA_VEL
  CALL ASSIGNA_DIR
  CALL RESET_TICS_DELAY
  SETF DELAY_ESPERA_EN,0
  ; Ens esperem a que el timer indiqui que ha passat el temps de delay
  ESPERA_DELAY
    BTFSC DELAY_ESPERA_EN,0
    GOTO ESPERA_DELAY
    
  DECF ContSaves,1
  GOTO REPRODUIR_RUTA
  
  FINAL_RUTA
  CLRF AUTOP_MODE
  CALL RGB_GREEN
  SETF MANUAL_MODE,0
  CALL RESET_TICS_MIN
  GOTO LOOP
  
; Assigna la velocitat que li correspon al 7Seg pel AUTOP_MODE
ASSIGNA_VEL
  MOVLW .1
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_VEL_N_H
  MOVLW .2
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_VEL_N_M
  MOVLW .3
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_VEL_N_L
  MOVLW .4
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_VEL_0 
  MOVLW .5
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_VEL_P_L
  MOVLW .6
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_VEL_P_M
  MOVLW .7
  SUBWF VEL_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_VEL_P_H
  RETURN
  
; Assigna la velocitat High Negative
POSA_VEL_N_H
  MOVFF CONST_7SEG_HIGH,LATD
  BSF LATA,3,0
  SETF IS_NEGATIVE,0
  RETURN
  
; Assigna la velocitat Mid Negative
POSA_VEL_N_M
  MOVFF CONST_7SEG_MID,LATD
  BSF LATA,3,0
  SETF IS_NEGATIVE,0
  RETURN
   
; Assigna la velocitat Low Negative
POSA_VEL_N_L
  MOVFF CONST_7SEG_LOW,LATD
  BSF LATA,3,0
  SETF IS_NEGATIVE,0
  RETURN
  
; Assigna la velocitat 0
POSA_VEL_0
  MOVFF CONST_7SEG_0,LATD
  BCF LATA,3,0
  CLRF IS_NEGATIVE,0
  RETURN
  
; Assigna la velocitat Low Positive
POSA_VEL_P_L
  MOVFF CONST_7SEG_LOW,LATD
  BCF LATA,3,0
  CLRF IS_NEGATIVE,0
  RETURN
  
; Assigna la velocitat Mid Positive
POSA_VEL_P_M
  MOVFF CONST_7SEG_MID,LATD
  BCF LATA,3,0
  CLRF IS_NEGATIVE,0
  RETURN
  
; Assigna la velocitat High Positive
POSA_VEL_P_H
  MOVFF CONST_7SEG_HIGH,LATD
  BCF LATA,3,0
  CLRF IS_NEGATIVE,0
  RETURN
  
; Assigna la direccio que li correspon a la barra de leds pel AUTOP_MODE
ASSIGNA_DIR
  ; Netejem els leds
  CALL CLEAN_LED_BAR
  MOVLW .1
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATC,0,0
  MOVLW .2
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATC,1,0
  MOVLW .3
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATC,2,0
  MOVLW .4
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATC,3,0
  MOVLW .5
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  CALL POSA_DIR_0
  MOVLW .6
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATC,6,0
  MOVLW .7
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATC,7,0
  MOVLW .8
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATB,3,0
  MOVLW .9
  SUBWF DIR_ACTUAL,0
  BTFSC STATUS,Z,0
  BSF LATB,4,0
  RETURN
  
; Assigna la direccio 0
POSA_DIR_0
  BSF LATC,4,0
  BSF LATC,5,0
  RETURN
  
; Color del led RGB vermell pel mode record
RGB_RED
  BSF LATE,0,0
  BCF LATE,1,0
  BCF LATE,2,0
  RETURN
  
; Color del led RGB verd pel mode manual
RGB_GREEN
  BCF LATE,0,0
  BSF LATE,1,0
  BCF LATE,2,0
  RETURN

; Color del led RGB blau pel mode creuer
RGB_BLUE
  BCF LATE,0,0
  BCF LATE,1,0
  BSF LATE,2,0
  RETURN
  
; Color del led RGB blanc pel mode pilot automatic
RGB_WHITE
  BSF LATE,0,0
  BSF LATE,1,0
  BSF LATE,2,0
  RETURN
  
; Neteja amb 0's la barra de leds
CLEAN_LED_BAR
  CLRF LATC,0
  BCF LATB,3,0
  BCF LATB,4,0
  RETURN
;--------------------------------------
; COMPTATGES D'INSTRUCCIONS
;--------------------------------------
; Compta 20ms corresponents al temps de rebots dels polsadors 
; TTarget = 20ms | Tinst = 250ns --> #inst = 80.000 - 4 = 79996
; 4 + (4*X + 6)*Y = 79996 --> X = 255 | Y = 78
COUNT_20ms
  MOVLW .1 ;x = 256 - 255 = 1
  MOVWF ContInstL
  MOVLW .178 ;y = 256 - 78 = 178
  MOVWF ContInstH
  T_REBOTS
    INCF ContInstL,1
    BTFSS STATUS,C,0
    GOTO T_REBOTS
    MOVLW .1
    MOVWF ContInstL
    INCF ContInstH,1
    BTFSS STATUS,C,0
    GOTO T_REBOTS
  RETURN
  
; Compta 222us corresponents a 1 pas dels 9 que hi ha per mesurar la direccio 
; TTarget = 222us | Tinst = 250ns --> #inst = 888 - 4 = 884
; 2 + 4*X = 884 --> 2 NOP's i X = 220
COUNT_PAS_SERVO
  MOVLW .36 ;x = 256 - 220 = 36
  MOVWF ContPWML
  NOP
  NOP
  T_PAS
    INCF ContPWML,1
    BTFSS STATUS,C,0
    GOTO T_PAS  
  RETURN
  
; Compta 0,5ms corresponents a l'estat inicial del servo a 0 graus
; TTarget = 500us | Tinst = 250ns --> #inst = 2000 - 4 = 1996
; 4 + (4*X + 6)*Y = 1996 --> X = 256 | Y = 2
POS_INICIAL_SERVO
  MOVLW .0 ;x = 256 - 256 = 0
  MOVWF ContPWML
  MOVLW .254 ;y = 256 - 2 = 254
  MOVWF ContPWMH
  T_INICIAL
    INCF ContPWML,1
    BTFSS STATUS,C,0
    GOTO T_INICIAL
    MOVLW .0
    MOVWF ContPWML
    INCF ContPWMH,1
    BTFSS STATUS,C,0
    GOTO T_INICIAL
  RETURN

; Compta 100us corresponents al canvi de canal analogic pel joystick
; TTarget = 50us | Tinst = 250ns --> #inst = 200 - 4 = 196
; 2 + 4*X = 196 --> 2 NOP's i X = 48
COUNT_CHANGE_CHANNEL
  MOVLW .208 ;x = 256 - 48 = 208
  MOVWF ContInstL
  NOP
  NOP
  T_CH
    INCF ContInstL,1
    BTFSS STATUS,C,0
    GOTO T_CH  
  RETURN
	
END