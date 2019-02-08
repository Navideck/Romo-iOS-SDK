//
//  RMCoreControllerPID.m
//  Romo3
//
//  Created on 1/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMCoreControllerPID.h"
#import <RMShared/RMDispatchTimer.h>

#pragma mark - Macros/Constants

// percent off that the PID Controller frequency can be (assuming GCD holds to
// this request...)
#define RM_LEEWAY_PERCENTAGE       0.05

#define RM_DEFAULT_CONTROL_FREQUENCY   20

// controlFrequency less than or equal to zero is used to set the controller to externally
// triggered
#define RM_DEFAULT_FREQUENCY_OFF       -1

#define RM_DEFAULT_P                   1
#define RM_DEFAULT_I                   0
#define RM_DEFAULT_D                   0


#pragma mark - PID Controller

/* --Private Interface-- */
@interface RMCoreControllerPID()
{
    // this structure contains key variables used in controller update calcs
    RMControllerPIDState controllerState;
}

#pragma mark - "private" properties
/* --Private Properties-- */

// queue used to execute controller update, and timer used to trigger those
// updates
@property (nonatomic) RMDispatchTimer *controlLoopTimer;

// Timestamp of the previous controller update
@property (atomic, strong) NSDate *previousTime;

#pragma mark - "private" methods
/* --Private Mehtods-- */

// the actual control calculations happen here
- (void) applyController;

@end


/* --Class Implementation-- */
@implementation RMCoreControllerPID

#pragma mark - factory methods

- (id) init
{
    return [self initWithFrequency:RM_DEFAULT_CONTROL_FREQUENCY
                      proportional:RM_DEFAULT_P
                          integral:RM_DEFAULT_I
                        derivative:RM_DEFAULT_D
                          setpoint:0
                       inputSource:nil
                        outputSink:nil
                subtractionHandler:nil];
}

// this is the initializer method where business happens.  It is called
// internally by the two initWith methods that are intended to be used by the
// class user (the reason is to allow different types of feedback types while
// keeping the external interface relatively clean)
- (id) initWithFrequency:(float)controlFrequency // update-rate of controller
            proportional:(float)P                // proportional gain
                integral:(float)I                // integral gain
              derivative:(float)D                // derivative gain
                setpoint:(float)setpoint
             inputSource:(RMControllerPIDInputSourceHandler) inputSourceHandler
              outputSink:(RMControllerPIDOutputSinkHandler) outputSinkHandler
      subtractionHandler:(RMControllerPIDSubtractionHandler) subtractionHandler
{
    self = [super init];
    
    if (self) {
        _enabled = NO;
        
        _P = P;
        _I = I;
        _D = D;
        _controlFrequency = controlFrequency;
        _subtractionHandler = subtractionHandler;
        _inputSourceHandler = inputSourceHandler;
        _outputSinkHandler = outputSinkHandler;
        _setpoint = setpoint;
    }
    
    return self;
}

- (id) initWithFrequency:(float)controlFrequency // update-rate of controller
            proportional:(float)P                 // proportional gain
                integral:(float)I                 // integral gain
              derivative:(float)D                 // derivative gain
                setpoint:(float)setpoint          // target setpoint
             inputSource:(RMControllerPIDInputSourceHandler) inputSourceHandler
              outputSink:(RMControllerPIDOutputSinkHandler) outputSinkHandler
{
    return [self initWithFrequency:controlFrequency
                      proportional:P
                          integral:I
                        derivative:D
                          setpoint:setpoint
                       inputSource:inputSourceHandler
                        outputSink:outputSinkHandler
                subtractionHandler:nil];
}

-(id)initWithProportional:(float)P
                 integral:(float)I
               derivative:(float)D
                 setpoint:(float)setpoint
              inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
               outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler
{
    return [self initWithFrequency:RM_DEFAULT_FREQUENCY_OFF
                      proportional:P
                          integral:I
                        derivative:D
                          setpoint:setpoint
                       inputSource:inputSourceHandler
                        outputSink:outputSinkHandler
                subtractionHandler:nil];
}

-(id)initWithProportional:(float)P
                 integral:(float)I
               derivative:(float)D
                 setpoint:(float)setpoint
              inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
               outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler
       subtractionHandler:(RMControllerPIDSubtractionHandler)subtractionHandler
{
    return [self initWithFrequency:RM_DEFAULT_FREQUENCY_OFF
                      proportional:P
                          integral:I
                        derivative:D
                          setpoint:setpoint
                       inputSource:inputSourceHandler
                        outputSink:outputSinkHandler
                subtractionHandler:subtractionHandler];
}

- (void)dealloc
{
    if (_controlLoopTimer) {
        [self.controlLoopTimer stopRunning];
    }
}

#pragma mark - data accessors

// the set controller's setpoint
- (void) setSetpoint:(float)setpoint
{
    _setpoint = setpoint;
    [self resetController];
}

// allows "user" to set a new controller frequency
- (void)setControlFrequency:(float)controlFrequency
{
    // set frequency and update the dispatch timer
    _controlFrequency = controlFrequency;
    
    if (controlFrequency > 0.0) {
        self.controlLoopTimer.frequency = controlFrequency;
    } else if (_controlLoopTimer) {
        // Stop the timer if it exists to go into manually-triggered mode
        [self.controlLoopTimer stopRunning];
    }
}

#pragma mark - public methods

// This is a public method that triggers the controller.
// It is not problem to call this method even when the controller is
// internally triggered by a fixed frequency

- (void)triggerController
{
    if (self.isEnabled) {
        if (self.inputSourceHandler && self.outputSinkHandler)  {
            [self.controlLoopTimer trigger];
        } else {
            [NSException raise:@"Unititialized PID Controller"
                        format:@"PID Controller _must_ have input source and output sink set before triggering"];
        }
    }
}

#pragma mark - controller guts

// this is the business method of the controller, fresh data is taken in and a
// new output value is caluclated and then applied via the block handler
- (void)applyController
{
    float           output;                 // controller's calculated value
    float           error = 0;              // difference between new data and
                                            // setpoint
    float           errorDerivative = 0;    // derivative of error
    float           *pErrorIntegral = &(controllerState.errorIntegral);
                                            // integral of error
    float           *pErrorPrevious = &(controllerState.errorPrevious);
                                            // previous step's error value
    
    // calculate new error value
    float input = self.inputSourceHandler();
    
    if (self.subtractionHandler)
    {
        error = self.subtractionHandler(input, self.setpoint);
    }
    else
    {
        error = input - self.setpoint;
    }
    
    // calculate time step since last update
    NSDate *now = [NSDate date];
    NSTimeInterval deltaTime;
    
    if (self.previousTime)
    {
        deltaTime = [now timeIntervalSinceDate:self.previousTime];
        
        // perform intermediate calculations
        *pErrorIntegral += error * deltaTime;
        errorDerivative = (error - *pErrorPrevious) / deltaTime;
    }
    
    // Update variables for next time applyController is called
    self.previousTime = now;
    *pErrorPrevious = error;
    
    // calculate controller output
    output = (self.P * error) +
    (self.I * (*pErrorIntegral)) +
    (self.D * errorDerivative);
    
    // store values into structure in case output block handler wants to use
    // them
    controllerState.error = error;
    controllerState.errorDerivative = errorDerivative;
    controllerState.output = output;
    
    // apply controller output to system
    self.outputSinkHandler(output, &controllerState);
}

// make controller active
- (void)setEnabled:(BOOL)enabled
{
    if (enabled != _enabled) {
        _enabled = enabled;
        
        [self resetController];
        
        if (enabled) {
            if (self.controlFrequency > 0.0) {
                // Only start the timer if we aren't in manual-trigger mode (frequency of 0.0)
                if (self.inputSourceHandler && self.outputSinkHandler) {
                    [self.controlLoopTimer startRunning];
                } else {
                    [NSException raise:@"Unititialized PID Controller"
                                format:@"PID Controller _must_ have input source and output sink set before enabling"];
                }
            }
        } else if (_controlLoopTimer) {
            // Stop the timer if it existed
            [self.controlLoopTimer stopRunning];
        }
    }
}

// zero out controller's historical data
- (void)resetController
{
    self.previousTime = nil;
    
    controllerState.errorPrevious = 0;
    controllerState.errorIntegral = 0;
}

- (RMDispatchTimer *)controlLoopTimer
{
    if (!_controlLoopTimer) {
        _controlLoopTimer = [[RMDispatchTimer alloc] initWithName:@"com.Romotive.RMCoreControllerPID" frequency:self.controlFrequency];
        __weak RMCoreControllerPID *weakSelf = self;
        _controlLoopTimer.eventHandler = ^{
            [weakSelf applyController];
        };
    }
    return _controlLoopTimer;
}

#pragma mark - PID tuning helpers

// apply Ziegler-Nichols tuning of P-Controller
- (void) tunePControllerWithZieglerNicholsWithUltimateGain:
(float)ultimateGain
{
    // Ziegler-Nichols equations
    self.P = 0.50 * ultimateGain;
    self.I = 0.;
    self.D = 0.;
    
    [self resetController];
}

// apply Ziegler-Nichols tuning of PI-Controller
- (void) tunePIControllerWithZeiglerNicholsWithUltimateGain:
(float)ultimateGain
                                          oscillationPeriod:(float)oscillationPeriod
{
    // Ziegler-Nichols equations
    self.P = 0.45 * ultimateGain;
    self.I = 1.2 * self.P/oscillationPeriod;
    self.D = 0.;
    
    [self resetController];
}

// apply Ziegler-Nichols tuning of PID-Controller
- (void) tunePIDControllerWithZeiglerNicholsWithUltimateGain:
(float)ultimateGain
                                           oscillationPeriod:(float)oscillationPeriod
{
    // Ziegler-Nichols equations
    self.P = 0.60 * ultimateGain;
    self.I = 2 * self.P/oscillationPeriod;
    self.D = self.P * oscillationPeriod/8;
    
    [self resetController];
}
@end

#pragma mark
#pragma mark - PID Tuning Helper UI

#define VC_OFFSET_FROM_TOP      25      // place VC this many pixels down from
// the top of the screen (so that you
// can still pull down the settings page

@interface RMCoreControllerPIDTuningUI() <UITextFieldDelegate>

#pragma mark - Properties

@property (nonatomic, strong) UISwitch *controllerEnableSwitch;
@property (nonatomic, strong) UILabel *labelDebug;
@property (nonatomic, strong) UILabel *labelP;
@property (nonatomic, strong) UILabel *labelI;
@property (nonatomic, strong) UILabel *labelD;
@property (nonatomic, strong) UITextField *textP;
@property (nonatomic, strong) UITextField *textI;
@property (nonatomic, strong) UITextField *textD;
@property (nonatomic, strong) RMCoreControllerPID *PIDController;

@end

@implementation RMCoreControllerPIDTuningUI

#pragma mark - Initializers

// factory method for creating the UI Window
+ (id)createTuningUIForController:(RMCoreControllerPID *)PIDController
                          andShow:(BOOL)isVisible
{
    RMCoreControllerPIDTuningUI *theInstance;
    
    // create window
    theInstance = [[RMCoreControllerPIDTuningUI alloc]
                   initWithFrame:[UIScreen mainScreen].bounds ];
    
    // store controller that this UI is linked to
    theInstance.PIDController = PIDController;
    
    if (isVisible)
    {
        [theInstance present];
    }
    
    return theInstance;
}

// set up the UI
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        self.userInteractionEnabled = YES;
        
        // setup label used for display debug text
        self.labelDebug = [[UILabel alloc] init];
        CGPoint point;
        point.x = 25; point.y = self.frame.size.height - 25;
        self.labelDebug.center = point;
        self.labelDebug.textColor = [UIColor redColor];
        self.labelDebug.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        [self addSubview: self.labelDebug];
        
        // set up switch used to turn PID control on/off
        self.controllerEnableSwitch = [[UISwitch alloc] init];
        point.x = 250; point.y = 30;
        self.controllerEnableSwitch.center = point;
        [self.controllerEnableSwitch setOn: TRUE];
        [self.controllerEnableSwitch addTarget:self
                                        action:@selector(PIDEnabledChanged)
                              forControlEvents:UIControlEventValueChanged ];
        
        _PIDEnabled = YES;
        [self addSubview: self.controllerEnableSwitch];
        
        // setup text fields for user input of PID parameters
        self.textP = [[UITextField alloc] initWithFrame:CGRectMake(0,0,85,45)];
        self.textI = [[UITextField alloc] initWithFrame:CGRectMake(0,0,85,45)];
        self.textD = [[UITextField alloc] initWithFrame:CGRectMake(0,0,85,45)];
        
        self.textP.delegate = self;
        self.textI.delegate = self;
        self.textD.delegate = self;
        
        point.x = 65; point.y = 85; self.textP.center = point;
        point.x += 100; self.textI.center = point;
        point.x += 100; self.textD.center = point;
        
        self.textP.borderStyle = UITextBorderStyleRoundedRect;
        self.textI.borderStyle = UITextBorderStyleRoundedRect;
        self.textD.borderStyle = UITextBorderStyleRoundedRect;
        
        self.textP.contentVerticalAlignment =
        UIControlContentVerticalAlignmentCenter;
        self.textI.contentVerticalAlignment =
        UIControlContentVerticalAlignmentCenter;
        self.textD.contentVerticalAlignment =
        UIControlContentVerticalAlignmentCenter;
        
        self.textP.keyboardType = UIKeyboardTypeDecimalPad;
        self.textI.keyboardType = UIKeyboardTypeDecimalPad;
        self.textD.keyboardType = UIKeyboardTypeDecimalPad;
        
        [self.textP setClearButtonMode:UITextFieldViewModeWhileEditing];
        [self.textI setClearButtonMode:UITextFieldViewModeWhileEditing];
        [self.textD setClearButtonMode:UITextFieldViewModeWhileEditing];
        
        [self addSubview: self.textP];
        [self addSubview: self.textI];
        [self addSubview: self.textD];
        
        // set up labels to identify PID text boxes
        self.labelP = [[UILabel alloc] init];
        self.labelI = [[UILabel alloc] init];
        self.labelD = [[UILabel alloc] init];
        
        point.x = 5; point.y = 75; self.labelP.center = point;
        point.x = 113; self.labelI.center = point;
        point.x = 209; self.labelD.center = point;
        
        [self.labelP setTextColor: [UIColor whiteColor]];
        [self.labelI setTextColor: [UIColor whiteColor]];
        [self.labelD setTextColor: [UIColor whiteColor]];
        
        [self.labelP setBackgroundColor: [UIColor clearColor]];
        [self.labelI setBackgroundColor: [UIColor clearColor]];
        [self.labelD setBackgroundColor: [UIColor clearColor]];
        
        [self addSubview: self.labelP];
        [self addSubview: self.labelI];
        [self addSubview: self.labelD];
        
        self.labelP.text = @"P"; [self.labelP sizeToFit];
        self.labelI.text = @"I"; [self.labelI sizeToFit];
        self.labelD.text = @"D"; [self.labelD sizeToFit];
    }
    
    return self;
}

#pragma mark - Window Control

// show window
- (void)present
{
    // set window to be on top
    self.windowLevel = UIWindowLevelAlert;
    [self makeKeyAndVisible];
    
    [self populatePIDTextBoxes];
}

// hide window
- (void)dismiss
{
    [super removeFromSuperview];
    self.hidden = YES;
}

// fill in values for P, I, and D based on controller's values
- (void)populatePIDTextBoxes
{
    [self.textP setText:[NSString stringWithFormat:@"%3.3f",
                         self.PIDController.P ] ];
    [self.textI setText:[NSString stringWithFormat:@"%3.3f",
                         self.PIDController.I ] ];
    [self.textD setText:[NSString stringWithFormat:@"%3.3f",
                         self.PIDController.D ] ];
}

// used to allow touches to pass through the tuning UI if they're not somewhere
// relavent to the tuning UI
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // point is inside if one of our subviews is visiable, enabled, and was
    // touched (or, if the subview is the keyboard (isFirstResponder)
    for (UIView *view in self.subviews)
    {
        if ((!view.hidden &&
             view.userInteractionEnabled &&
             [view pointInside:[self convertPoint:point toView:view]
                     withEvent:event ] ) ||
            view.isFirstResponder )
        {
            return YES;
        }
    }
    
    return NO;
}

// close keyboard when user touches screen
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self updateModelPID];
    [self endEditing:TRUE];
}

// display message on screen
- (void) setDebugMessage:(NSString *)debugMessage
{
    _debugMessage = debugMessage;
    self.labelDebug.text = _debugMessage;
    [self.labelDebug sizeToFit];
    [self.labelDebug performSelectorOnMainThread: @selector(setNeedsDisplay)
                                      withObject:nil waitUntilDone:NO ];
}

#pragma mark - Data Control

// update underlying controller model after user has finished editing gain
// values in the UI
- (void) updateModelPID
{
    self.PIDController.P = [self.textP.text floatValue];
    self.PIDController.I = [self.textI.text floatValue];
    self.PIDController.D = [self.textD.text floatValue];
    
    [self.textP setText:[NSString stringWithFormat:@"%3.3f",
                         self.PIDController.P ] ];
    [self.textI setText:[NSString stringWithFormat:@"%3.3f",
                         self.PIDController.I ] ];
    [self.textD setText:[NSString stringWithFormat:@"%3.3f",
                         self.PIDController.D ] ];
}

// toggle flag indicating if underlying controller should be enabled/disabled
- (void)PIDEnabledChanged
{
    _PIDEnabled = !_PIDEnabled;
}

// make tuning window key so that keyboard-entered text gets to the text boxes
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    [self makeKeyAndVisible];
    return YES;
}

@end
