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
//  RMCoreControllerPID.h
//  RMCore
//
//  Created by Romotive on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
/** @file RMCoreControllerPID.h
 @brief Public header for accessing a PID Controller object.

 This module provides an easy way to setup a PID (Proportional-Integral-
 Derivative) Controller.  To learn more about PID controllers head to wikipedia!

 When creating a PID Controller you can choose the frequency it runs at and set
 the P, I, and D gain values.  Before enabling the controller you should
 provide the target setpoint and you must provide an input source handler
 (provides controller with new data) and and output handler (does something
 with the output of the controller).  Optionally, a handler may be provided to
 perform non-standard subtraction, which is used when the controller calculates
 the error term.  An example of when this handler is needed is when controlling
 to a heading.  Because heading values "wrap around" at 0/360 degrees it's
 necessary to maintain the range with a special substraction operation, which
 the user must provide.
 
 Note, the frequency of the controller can be adjusted at any time after
 initialization.  The setpoint can also be adjusted at any time.  The gains may
 also be adjusted, although this is less common. The controller itself can be 
 disabled and re-enabled at will via the enable/disableController methods.
*/
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Data Types

/**
 @brief Structure containing information about the internal state of a PID  
 controller.
 
 This information may be useful in the output handler, for instance.
 */
typedef struct
{
    /**
     current error measurement
     */
    float error;
    /**
     previous sample's error measurement
     */
    float errorPrevious;    
    /**
     sum of error since the controller was reset 
     */
    float errorIntegral;   
    /**
     derivative of the error right now
     */
    float errorDerivative;  
    /**
     controller's output value
     */
    float output;           
} RMControllerPIDState;

/**
 This block handler provides feedback data to the controller
 */
typedef float (^RMControllerPIDInputSourceHandler)(void);

/** 
 This block handler expresses the controller output on the system
 */
typedef void (^RMControllerPIDOutputSinkHandler)(float PIDControllerOutput,
                                        RMControllerPIDState *contollerState );
/** 
 Optional block handler used to set customized math use in calculation of the
 error term
 */
typedef float (^RMControllerPIDSubtractionHandler)(float a, float b);

#pragma mark - Public Interface

/**
 @brief RMCoreControllerPID is the public interface for creating a PID 
 (Proportional-Integral-Derivative) Controller.
 */
@interface RMCoreControllerPID : NSObject

#pragma mark - Properties

/**
 Tracks if controller is enabled or not
 */
@property (nonatomic, getter=isEnabled) BOOL enabled;

/**
 Proportional controller gain
 */
@property (nonatomic) float P;

/**
 Integral controller gain
 */
@property (nonatomic) float I;

/**
 Differential controller gain
 */
@property (nonatomic) float D;

/**
Frequency at which the controller updates (Hz)
 A frequency less than or equal to zero indicates that the controller is
 externally triggered
 */
@property (nonatomic) float controlFrequency;

/**
 Controller's target value
 */
@property (nonatomic) float setpoint;

/**
 User-provided block handler that provides a source for feedback data
 */
@property (nonatomic, copy) RMControllerPIDInputSourceHandler inputSourceHandler;

/**
 User-provided block handler that receives the output of the controller
 */
@property (nonatomic, copy) RMControllerPIDOutputSinkHandler outputSinkHandler;

/**
 Optional user-provided block handler that replaces straight subtraction with
 some other differencing technique (e.g. subtraction while enforcing a range
 limit)
 */
@property (nonatomic, copy) RMControllerPIDSubtractionHandler subtractionHandler;

#pragma mark - Init Methods

/**
 Use this method to initialize a controller with all the necessary parameters 
 populated
 */
- (id)initWithFrequency:(float)controlFrequency
           proportional:(float)P
               integral:(float)I
             derivative:(float)D
               setpoint:(float)setpoint
            inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
             outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler;

/**
 Use this method to initialize a controller with all the necessary parameters, 
 plus the optional subtractionHandler, populated
 */
- (id)initWithFrequency:(float)controlFrequency
           proportional:(float)P
               integral:(float)I
             derivative:(float)D
               setpoint:(float)setpoint
            inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
             outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler
     subtractionHandler:(RMControllerPIDSubtractionHandler)subtractionHandler;

/**
 Use this method to initialize an externally triggered controller with all the necessary parameters
 populated
 */
-(id)initWithProportional:(float)P
                 integral:(float)I
               derivative:(float)D
                 setpoint:(float)setpoint
              inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
               outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler;

/**
 Use this method to initialize an externally triggered controller with all the necessary parameters,
 plus the optional subtractionHandler, populated
 */
-(id)initWithProportional:(float)P
                 integral:(float)I
               derivative:(float)D
                 setpoint:(float)setpoint
              inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
               outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler
       subtractionHandler:(RMControllerPIDSubtractionHandler)subtractionHandler;

#pragma mark - Controller Guts

/**
 This method clears the integral error and previous error values, which 
 effectively eliminates the controller's history
 */
- (void)resetController;

/**
 This method allows you to manual trigger an externally triggered control
 loop
 */
- (void)triggerController;

#pragma mark - PID Tuning Helpers

/**
 Ziegler-Nichols based tuning method for P-type controller.
 
 @param ultimateGain P-based gain (I = D = 0) at which the system begins to
 oscillate.
 */
- (void)tunePControllerWithZieglerNicholsWithUltimateGain:(float)ultimateGain;

/**
 Ziegler-Nichols based tuning method for PI-type controller.
 
 @param ultimateGain P-based gain (I = D = 0) at which the system begins to
 oscillate.
 
 @param oscillationPeriod The period of the oscillation at the ultimate gain 
 (seconds).
 */
- (void)tunePIControllerWithZeiglerNicholsWithUltimateGain:(float)ultimateGain
                                          oscillationPeriod:(float)oscillationPeriod;

/**
 Ziegler-Nichols based tuning method for PID-type controller.
 
 @param ultimateGain P-based gain (I = D = 0) at which the system begins to
 oscillate.
 
 @param oscillationPeriod The period of the oscillation at the ultimate gain
 (seconds).
 */
- (void)tunePIDControllerWithZeiglerNicholsWithUltimateGain:(float)ultimateGain
                                          oscillationPeriod:(float)oscillationPeriod;
@end

#pragma mark - PID Tuning Helper UI

/**
 @brief A set of helpful UI functionalities for tuning a RMCoreControllerPID.
 */
@interface RMCoreControllerPIDTuningUI : UIWindow

/**
 This flag is intended to be used to indicate when the controller should be
 turned on or off.  The user is responsible for reading it and changing the 
 controller's state
 */
@property (nonatomic, readonly, getter=isPIDEnabled) BOOL PIDEnabled;

/**
 This string provides a place for the user to display debug information
 */
@property (nonatomic, strong) NSString *debugMessage;

#pragma mark - Tuning UI Methods

/**
 Use this factory method to create a tuning UI window

 @param PIDController A RMCoreControllerPID instance whose data will be linked
 to this tuning UI.
 
 @param isVisible Flag that when set causes the tuning UI to be displayed after
 it is created.
 */
+ (id)createTuningUIForController:(RMCoreControllerPID *)PIDController
                          andShow:(BOOL)isVisible;
/**
 Use this method to show the tuning UI
 */
- (void)present;

/**
 Use this method to hide the tuning UI
 */
 - (void)dismiss;

@end
