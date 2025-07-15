
# Rain Detection and Classification System

This project presents a rain detection and classification system implemented using the ATmega328P microcontroller. It utilizes an HW-83 analog rain sensor, an LCD for real-time display, a PWM-controlled LED for visual intensity feedback, and an external EEPROM for data persistence all controlled using AVR assembly language.

## Features

- Analog rain intensity detection
- Classification: No Rain, Light Rain, Moderate Rain, Heavy Rain
- Real-time display via 16x2 LCD
- Visual feedback using PWM-controlled LED
- Data logging using 24LC512 EEPROM
- Entire system programmed in AVR Assembly language
- Simulated in Proteus
- Code in Assembly using Atmel Studio 7.0

## Components Used

- ATmega328P Microcontroller
- HW-83 Rain Sensor
- LM016L 16x2 LCD
- PWM-controlled LED
- 24C512 EEPROM

## Folder Structure

```
.
├── Rain_Detector_Documentation.docx   # Full technical documentation
├── README.md                          # GitHub readme file
└── asm_code/                          # AVR Assembly source files
```

## How It Works

1. The analog rain sensor provides varying voltage depending on moisture.
2. ATmega328P reads this via ADC and classifies rain level.
3. Classification is shown on LCD and brightness of LED is adjusted.
4. Latest classification is stored in EEPROM for persistence.

## Simulation

The system is tested using Proteus with a potentiometer to simulate analog rain input.

## Applications

- Smart agriculture
- Weather stations
- Environmental monitoring

---

Developed as part of **CS-430: Microprocessor Programming and Interfacing**
