//==============================================================================
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
//==============================================================================
//
//  RMCoreLEDs.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreLEDs.h
 @brief Public header for RMCoreLEDs (the interface to the LEDs in an
 RMCoreRobot) and helpful types for interfacing with the RMCoreLEDs.
 */
#import <Foundation/Foundation.h>

#pragma mark - Constants

/**
 LED operational modes
 */
typedef enum {
    /// The LEDs are off
    RMCoreLEDModeOff   = 0,
    /// The LEDs are on continuously
    RMCoreLEDModeSolid = 1,
    /// The LEDs alternate between on and off
    RMCoreLEDModeBlink = 2,
    /// The LEDs gradually fade in and/or out (depending on pulseDirection)
    RMCoreLEDModePulse = 3
} RMCoreLEDMode;

/**
 Options for direction of LED pulsing
 */
typedef enum {
    /// Half-pulse, fading out
    RMCoreLEDPulseDirectionDown      = -1,
    /// Full-pulse, fading in and out
    RMCoreLEDPulseDirectionUpAndDown = 0,
    /// Half-pulse, fading in
    RMCoreLEDPulseDirectionUp        = 1
} RMCoreLEDPulseDirection;

#pragma mark - RMCoreLEDs

/**
 @brief An RMCoreLEDs object provides an interface to the robot's LEDs.
 
 This interface provides access to the current state of the LEDs including:
    - The operational mode
    - Any mode parameters (e.g. brightness, pulse period, etc.)
 
 The mode can be set by calling any of the provided convenience methods and 
 supplying the necessary parameters.
 */
@interface RMCoreLEDs : NSObject

/**
 The mode currently in use. 
 To change, use one of the methods listed below with the appropriate parameters.
 */
@property (nonatomic, readonly) RMCoreLEDMode mode;

/**
 The brightness of the LEDs.
 Values are on the interval [0,1] (1=full brightness).
 Used with RMCoreLEDModeSolid and RMCoreLEDModeBlink.
 */
@property (nonatomic, readonly) float brightness;

/**
 The period in seconds for RMCoreLEDModeBlink and RMCoreLEDModePulse.
 Values for blink mode are on the interval (0,1].
 Values for pulse mode are on the interval (0,9.5].
 */
@property (nonatomic, readonly) float period;

/**
 The duty cycle (percentage of one period spent 'on') for RMCoreLEDModeBlink.
 Values are on the interval (0,1).
 Default value is 0.5 (equal on/off time).
 */
@property (nonatomic, readonly) float dutyCycle;

/**
 The pulse direction for RMCoreLEDModePulse.
 Default is RMCoreLEDPulseDirectionUpAndDown.
 Other options indicate HalfPulse mode.
 */
@property (nonatomic, readonly) RMCoreLEDPulseDirection pulseDirection;

/**
 The resolution of the LEDs' pulse-width modulation.
 */
@property (nonatomic, readonly) unsigned int pwmScalar;

#pragma mark - Setting the mode & parameters

/**
 Turns the LEDs on with the given brightness.
 @param brightness The brightness of the LEDs. Values are on the interval [0,1] 
 where 1 = full brightness.
 */
- (void)setSolidWithBrightness:(float)brightness;

/**
 Turns the LEDs off entirely.
 */
- (void)turnOff;

/**
 Blinks the LEDs using the given period and dutyCycle, at full brightness.
 @param period The blink period in seconds. Values are on the interval (0,60].  
 Note: firmware older than 1.1.1 is limited to a 1.0s maximum period.
 @param dutyCycle The percentage of one period spent 'on'.  Values are on the
 interval (0,1).
 */
- (void)blinkWithPeriod:(float)period
              dutyCycle:(float)dutyCycle;

/**
 Blinks the LEDs using the given period and dutyCycle, at the given brightness.
 @param period The blink period in seconds. Values are on the interval (0,60].  
 Note: firmware older than 1.1.1 is limited to a 1.0s maximum period.
 @param dutyCycle The percentage of one period spent 'on'.  Values are on the 
 interval (0,1).
 @param brightness The brightness of the LEDs. Values are on the interval [0,1] 
 where 1 = full brightness.
 */
- (void)blinkWithPeriod:(float)period
              dutyCycle:(float)dutyCycle
             brightness:(float)brightness;

/**
 Pulses the LEDs using the given period and direction.
 @param period The pulse period in seconds. Values are on the interval (0,9.5].
 @param direction The pulse direction, which also determines whether the pulse 
 is full- or half-wave.
 */
- (void)pulseWithPeriod:(float)period
              direction:(RMCoreLEDPulseDirection)direction;

#pragma mark - Initialization

/**
 Creates LEDs with command resolution of pwmScalar
 @param pwmScalar The resolution of the LEDs' pulse-width modulation
 */
- (RMCoreLEDs *)initWithPwmScalar:(unsigned int)pwmScalar;

@end
