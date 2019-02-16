//
//  RMCoreStasisDetector.m
//  RMCore
//

#import "RMCoreStasisDetector.h"
#import "RMCoreInertialStasis.h"

@interface RMCoreStasisDetector()


@property (nonatomic) BOOL visualStasis;         // vision-based stasis status
@property (nonatomic) BOOL inertialStasis;       // IMU-based stasis status

// this module owns the inertial stasis detector, it doesn't own the vision
// sensor because that's part of the vision system module (not sure if this
// is an okay thing or not...)
@property (nonatomic, strong) RMCoreInertialStasis *inertialStasisDetector;

@end


#pragma  mark - Setup

@implementation RMCoreStasisDetector

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init
{
    self = [super init];
    if(!self) {return nil;}
 
    // various virtual stasis detectors that are used as input
    [self addObservations];
    
    _inertialStasisDetector = [[RMCoreInertialStasis alloc] init];
    
    return self;
}

- (void)setRobot:robot
{
    _robot = robot;
    _inertialStasisDetector.robot = robot;
}

- (void)addObservations
{
    // visual stasis detector
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(visualStasisDetected)
                                                 name:@"RMVisualStasisDetected"
                                               object:nil ];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(visualStasisCleared)
                                                 name:@"RMVisualStasisCleared"
                                               object:nil ];
    // inertial stasis detector
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inertialStasisDetected)
                                                 name:@"RMInerialStasisDetected"
                                               object:nil ];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inertialStasisCleared)
                                                 name:@"RMInertialStasisCleared"
                                               object:nil ];
}

#pragma mark - Stasis Sub-Module Observers

- (void)visualStasisDetected
{
    self.visualStasis = YES;
    [self fuseStasisSensors];
}

- (void)visualStasisCleared
{
    self.visualStasis = NO;
    [self fuseStasisSensors];
}

- (void)inertialStasisDetected
{
    self.inertialStasis = YES;
    [self fuseStasisSensors];
}

- (void)inertialStasisCleared
{
    self.inertialStasis = NO;
    [self fuseStasisSensors];
}

# pragma mark - Stasis Fuser

// Provide single stasis detector output based on all the input sources
- (void)fuseStasisSensors
{
    // nice and simple for now... we can get fancier later, as need be
    if(self.inertialStasis || self.visualStasis)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RMStasisDetected" object:nil];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RMStasisCleared" object:nil];
    }
}

@end