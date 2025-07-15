.include "m328Pdef.inc"

; ===== Constants =====
.equ RS = 0
.equ E  = 1
.equ EEPROM_STRING_LIMIT = 16             ; Max string length to store in EEPROM

; ===== Data Section =====
.dseg
Buffer: .byte EEPROM_STRING_LIMIT         ; Buffer for storing current rain string
LastRainCategory: .byte 1                 ; Holds last rain classification

; ===== Code Section =====
.cseg
.org 0x0000
    rjmp Start                            ; Reset vector

; ===== String Constants =====
.org 0x0200
LightRain:   .db "Light Rain     ", 0
ModRain:     .db "Moderate Rain  ", 0
HeavyRain:   .db "Heavy Rain     ", 0
NoRain:      .db "No Rain        ", 0

; ===== Start Routine =====
Start:
    ; --- PWM Init on PB3 (OC2A) for LED intensity ---
    sbi DDRB, PB3                         ; PB3 as output
    ldi r16, (1<<COM2A1)|(1<<WGM21)|(1<<WGM20)
    sts TCCR2A, r16
    ldi r16, (1<<CS21)                    ; Prescaler = 8
    sts TCCR2B, r16

    ; --- ADC Init: PC0 as input ---
    ldi r16, 0x00
    out DDRC, r16                         ; All PCx as input
    out PORTC, r16                        ; Disable pull-ups

    ; --- LCD Init ---
    ldi r16, 0xFF
    out DDRD, r16                         ; LCD data pins (D0–D7) as output
    in r16, DDRB
    ori r16, (1<<RS)|(1<<E)
    out DDRB, r16                         ; RS and E as output
    ldi r16, 0
    out PORTB, r16                        ; Clear control lines

    rcall LongDelay
    rcall LongDelay

    ldi r16, 0x38                         ; 8-bit mode, 2 lines
    rcall LCD_Command
    ldi r16, 0x0C                         ; Display ON, cursor OFF
    rcall LCD_Command
    ldi r16, 0x01                         ; Clear display
    rcall LCD_Command
    rcall LongDelay
    ldi r16, 0x06                         ; Entry mode set
    rcall LCD_Command

    ; --- I2C Init for EEPROM ---
    rcall TWI_Init

    ; --- ADC Setup ---
    ldi r16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    sts ADCSRA, r16
    ldi r16, 0                            ; ADC0 channel
    sts ADMUX, r16

    ; --- Initial Read, Classify, Store & Display ---
    rcall ADC_Read
    rcall ClassifyRain
    rcall EEPROM_WriteFull
    rcall LCD_Clear
    rcall Print_EEPROM

; ===== Main Loop =====
Loop:
    rcall ADC_Read
    rcall ClassifyRain                   ; Updates r17 with new category

    lds r18, LastRainCategory
    cp r17, r18
    breq SkipUpdate                      ; No change detected

    sts LastRainCategory, r17           ; Update stored category
    rcall EEPROM_WriteFull
    rcall LCD_Clear
    rcall Print_EEPROM

SkipUpdate:
    rcall LongDelay
    rjmp Loop

; ===== Classify Rain Based on ADC Reading =====
; Sets r17 to category ID and stores string in Buffer
ClassifyRain:
    ; Check thresholds and assign message + PWM
    ldi r20, low(255)
    ldi r21, high(255)
    cp r24, r20
    cpc r25, r21
    brlo LabelNoRain

    ldi r20, low(512)
    ldi r21, high(512)
    cp r24, r20
    cpc r25, r21
    brlo LabelLight

    ldi r20, low(700)
    ldi r21, high(700)
    cp r24, r20
    cpc r25, r21
    brlo LabelModerate

    ; --- Heavy Rain ---
    ldi r17, 3
    ldi ZH, high(HeavyRain << 1)
    ldi ZL, low(HeavyRain << 1)
    ldi r16, 255
    sts OCR2A, r16
    rjmp CopyMsg

LabelModerate:
    ldi r17, 2
    ldi ZH, high(ModRain << 1)
    ldi ZL, low(ModRain << 1)
    ldi r16, 170
    sts OCR2A, r16
    rjmp CopyMsg

LabelLight:
    ldi r17, 1
    ldi ZH, high(LightRain << 1)
    ldi ZL, low(LightRain << 1)
    ldi r16, 85
    sts OCR2A, r16
    rjmp CopyMsg

LabelNoRain:
    ldi r17, 0
    ldi ZH, high(NoRain << 1)
    ldi ZL, low(NoRain << 1)
    ldi r16, 0
    sts OCR2A, r16

CopyMsg:
    ; Copy string to buffer
    ldi YH, high(Buffer)
    ldi YL, low(Buffer)
    ldi r18, EEPROM_STRING_LIMIT
CopyMsgLoop:
    lpm r16, Z+
    st Y+, r16
    dec r18
    cpi r16, 0
    breq CopyMsgDone
    brne CopyMsgLoop
CopyMsgDone:
    ret

; ===== ADC Read into r24:r25 =====
ADC_Read:
    ldi r16, (1<<REFS0)
    sts ADMUX, r16
    ldi r16, (1<<ADEN)|(1<<ADSC)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    sts ADCSRA, r16
Wait_ADC:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp Wait_ADC
    lds r24, ADCL
    lds r25, ADCH
    ret

; ===== EEPROM Write: Write full buffer over I2C =====
EEPROM_WriteFull:
    rcall TWI_Start
    ldi r24, 0xA0                         ; Device write addr
    rcall TWI_Write
    ldi r24, 0                            ; Word addr high
    rcall TWI_Write
    ldi r24, 0                            ; Word addr low
    rcall TWI_Write

    ldi YH, high(Buffer)
    ldi YL, low(Buffer)
    ldi r18, EEPROM_STRING_LIMIT
WriteLoop:
    ld r24, Y+
    rcall TWI_Write
    dec r18
    brne WriteLoop

    rcall TWI_Stop
    rcall EEPROM_Wait
    ret

; ===== Wait for EEPROM Write Completion =====
EEPROM_Wait:
    rcall TWI_Start
    ldi r24, 0xA0
    rcall TWI_Write
    brne EEPROM_Wait
    rcall TWI_Stop
    ret

; ===== Print EEPROM String to LCD =====
Print_EEPROM:
    rcall TWI_Start
    ldi r24, 0xA0
    rcall TWI_Write
    ldi r24, 0
    rcall TWI_Write
    ldi r24, 0
    rcall TWI_Write

    rcall TWI_Start
    ldi r24, 0xA1                         ; EEPROM read
    rcall TWI_Write

    ldi r19, 0
PrintLoop:
    cpi r19, EEPROM_STRING_LIMIT - 1
    breq LastByte
    rcall TWI_Read_ACK
    rjmp ShowByte
LastByte:
    rcall TWI_Read_NACK

ShowByte:
    mov r16, r24
    cpi r16, 0
    breq PrintEnd
    rcall LCD_Data
    inc r19
    cpi r19, EEPROM_STRING_LIMIT
    brne PrintLoop

PrintEnd:
    rcall TWI_Stop
    ret

; ===== TWI (I2C) Subroutines =====
TWI_Init:
    ldi r16, 0
    sts TWSR, r16
    ldi r16, 0x20                         ; TWBR = 32 for ~100kHz at 8MHz
    sts TWBR, r16
    ret

TWI_Start:
    ldi r16, (1<<TWSTA)|(1<<TWEN)|(1<<TWINT)
    sts TWCR, r16
WaitStart:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp WaitStart
    ret

TWI_Stop:
    ldi r16, (1<<TWSTO)|(1<<TWEN)|(1<<TWINT)
    sts TWCR, r16
    ret

TWI_Write:
    sts TWDR, r24
    ldi r16, (1<<TWEN)|(1<<TWINT)
    sts TWCR, r16
WaitWrite:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp WaitWrite
    ret

TWI_Read_ACK:
    ldi r16, (1<<TWEN)|(1<<TWINT)|(1<<TWEA)
    sts TWCR, r16
WaitReadACK:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp WaitReadACK
    lds r24, TWDR
    ret

TWI_Read_NACK:
    ldi r16, (1<<TWEN)|(1<<TWINT)
    sts TWCR, r16
WaitReadNACK:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp WaitReadNACK
    lds r24, TWDR
    ret

; ===== LCD Subroutines =====
LCD_Command:
    cbi PORTB, RS
    rjmp LCD_Write

LCD_Data:
    sbi PORTB, RS
    rjmp LCD_Write

LCD_Write:
    out PORTD, r16
    sbi PORTB, E
    rcall ShortDelay
    cbi PORTB, E
    rcall ShortDelay
    ret

LCD_Clear:
    ldi r16, 0x01                         ; Clear command
    rcall LCD_Command
    rcall LongDelay
    ret

; ===== Delay Subroutines =====
ShortDelay:
    ldi r20, 200
LoopS:
    dec r20
    brne LoopS
    ret

LongDelay:
    ldi r21, 20
LoopL:
    rcall ShortDelay
    dec r21
    brne LoopL
    ret
