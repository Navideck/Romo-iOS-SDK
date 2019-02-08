/*
 * EEPROMDefs.h
 *
 * Created: 3/25/2013 2:53:59 PM
 *  Author: Aaron Solochek
 */ 


#ifndef EEPROMDEFS_H_
#define EEPROMDEFS_H_


/************************************************************************/
/* EEPROM Addresses used on robot                                       */
/************************************************************************/
#define EEPROM_SERIALNUMBER_ADDRESS			    (void*)0x0000          // 20 bytes including null terminator
#define EEPROM_HW_MAJOR_VERSION_ADDRESS		    (void*)0x0014          // 1 byte
#define EEPROM_HW_MINOR_VERSION_ADDRESS		    (void*)0x0015          // 1 byte
#define EEPROM_HW_REVISION_VERSION_ADDRESS		(void*)0x0016          // 1 byte
#define EEPROM_BOOTLOADER_MAJOR_VERSION_ADDRESS (void*)0x0017          // 1 byte
#define EEPROM_BOOTLOADER_MINOR_VERSION_ADDRESS (void*)0x0018          // 1 byte
#define EEPROM_CLOCK_PRESCALER_VALUE_ADDRESS    (void*)0x0019          // 1 byte

#define EEPROM_LEFT_TRIM_PWM_ADDRESS	        (void*)0x001A          // 2 bytes
#define EEPROM_RIGHT_TRIM_PWM_ADDRESS           (void*)0x001C          // 2 bytes
#define EEPROM_LEFT_TRIM_CURRENT_ADDRESS	    (void*)0x001E          // 2 bytes
#define EEPROM_RIGHT_TRIM_CURRENT_ADDRESS       (void*)0x0020          // 2 bytes

#define EEPROM_CP_SELFTEST_ADDRESS              (void*)0x0022          // 1 byte
#define EEPROM_PROGRAM_FLASH_ON_BOOT_ADDRESS    (void*)0x0023          // 1 byte

#define EEPROM_LEFT_TRIM_NEG_PWM_ADDRESS	    (void*)0x0024          // 2 bytes
#define EEPROM_RIGHT_TRIM_NEG_PWM_ADDRESS       (void*)0x0026          // 2 bytes
#define EEPROM_LEFT_TRIM_NEG_CURRENT_ADDRESS    (void*)0x0028          // 2 bytes
#define EEPROM_RIGHT_TRIM_NEG_CURRENT_ADDRESS   (void*)0x002A          // 2 bytes

#define EEPROM_ODOMETER_ADDRESS                 (void*)0x0030          // 8 bytes

#define EEPROM_DANCE_MODE_DATA_ADDRESS          (void*)0x00C3          // 60 bytes




#endif /* EEPROMDEFS_H_ */