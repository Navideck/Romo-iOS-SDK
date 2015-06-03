//
//  ViewController.m
//  HelloRMCore
//

#import "ViewController.h"

@interface ViewController ()

- (void)layoutForConnected;
- (void)layoutForUnconnected;

@end

@implementation ViewController

#pragma mark -- View Lifecycle --

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Assume the Robot is not connected
    [self layoutForUnconnected];

    // To receive messages when Robots connect & disconnect, set RMCore's delegate to self
    [RMCore setDelegate:self];
}


#pragma mark -- RMCoreDelegate Methods --

- (void)didConnectToRobot:(RMCoreRobot *)robot
{
    // Currently the only kind of robot is Romo3, so this is just future-proofing
    if ([robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.Romo3 = (RMCoreRobotRomo3 *)robot;
        
        // Change Romo's LED to be solid at 80% power
        [self.Romo3.LEDs solidWithBrightness:0.8];
        
        [self layoutForConnected];
    }
}

- (void)didDisconnectFromRobot:(RMCoreRobot *)robot
{
    if (robot == self.Romo3) {
        self.Romo3 = nil;
        
        [self layoutForUnconnected];
    }
}

#pragma mark -- IBAction Methods --

- (void)didTouchDriveInCircleButton:(UIButton *)sender
{
    // If Romo3 is driving, let's stop driving
    BOOL RomoIsDriving = (self.Romo3.leftDriveMotor.powerLevel != 0) || (self.Romo3.rightDriveMotor.powerLevel != 0);
    if (RomoIsDriving) {
        // Change Romo's LED to be solid at 80% power
        [self.Romo3.LEDs solidWithBrightness:0.8];
        
        // Tell Romo3 to stop
        [self.Romo3 stopDriving];
        
        [sender setTitle:@"Drive in circle" forState:UIControlStateNormal];
        
    } else {
        // Change Romo's LED to pulse
        [self.Romo3.LEDs pulseWithPeriod:1.0 direction:RMCoreLEDPulseDirectionUpAndDown];
        
        // Romo's top speed is around 0.75 m/s
        float speedInMetersPerSecond = 0.5;
        
        // Drive a circle about 0.25 meter in radius
        float radiusInMeters = 0.25;
        
        // Give Romo the drive command
        [self.Romo3 driveWithRadius:radiusInMeters speed:speedInMetersPerSecond];
        
        [sender setTitle:@"Stop Driving" forState:UIControlStateNormal];
    }
}

- (void)didTouchTiltDownButton:(UIButton *)sender
{
    // If Romo3 is tilting, stop tilting
    BOOL RomoIsTilting = (self.Romo3.tiltMotor.powerLevel != 0);
    if (RomoIsTilting) {
        
        // Tell Romo3 to stop tilting
        [self.Romo3 stopTilting];
        
        [sender setTitle:@"Tilt Down" forState:UIControlStateNormal];
        
    } else {
        
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
        
        // Tilt down by ten degrees
        float tiltByAngleInDegrees = 10.0;
        
        [self.Romo3 tiltByAngle:tiltByAngleInDegrees
                     completion:^(BOOL success) {
                         // Reset button title on the main queue
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [sender setTitle:@"Tilt Down" forState:UIControlStateNormal];
                         });
                     }];
    }
}

- (void)didTouchTiltUpButton:(UIButton *)sender
{
    // If Romo3 is tilting, stop tilting
    BOOL RomoIsTilting = (self.Romo3.tiltMotor.powerLevel != 0);
    if (RomoIsTilting) {
        
        // Tell Romo3 to stop tilting
        [self.Romo3 stopTilting];
        
        [sender setTitle:@"Tilt Up" forState:UIControlStateNormal];
        
    } else {
        
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
        
        // Tilt up by ten degrees
        float tiltByAngleInDegrees = -10.0;
        
        [self.Romo3 tiltByAngle:tiltByAngleInDegrees
                     completion:^(BOOL success) {
                         // Reset button title on the main queue
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [sender setTitle:@"Tilt Up" forState:UIControlStateNormal];
                         });
                     }];
    }
}

#pragma mark -- Private Methods: Build the UI --

- (void)layoutForConnected
{
    // Lets make some buttons so we can tell Romo's base to do stuff
    if (!self.connectedView) {
        self.connectedView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.connectedView.backgroundColor = [UIColor whiteColor];
        
        self.driveInCircleButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.driveInCircleButton.frame = CGRectMake(80, 50, 160, 60);
        [self.driveInCircleButton setTitle:@"Drive in circle" forState:UIControlStateNormal];
        [self.driveInCircleButton addTarget:self action:@selector(didTouchDriveInCircleButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.connectedView addSubview:self.driveInCircleButton];
        
        self.tiltDownButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.tiltDownButton.frame = CGRectMake(80, 130, 80, 60);
        [self.tiltDownButton setTitle:@"Tilt Down" forState:UIControlStateNormal];
        [self.tiltDownButton addTarget:self action:@selector(didTouchTiltDownButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.connectedView addSubview:self.tiltDownButton];
        
        self.tiltUpButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.tiltUpButton.frame = CGRectMake(180, 130, 80, 60);
        [self.tiltUpButton setTitle:@"Tilt Up" forState:UIControlStateNormal];
        [self.tiltUpButton addTarget:self action:@selector(didTouchTiltUpButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.connectedView addSubview:self.tiltUpButton];
    }
    
    [self.unconnectedView removeFromSuperview];
    [self.view addSubview:self.connectedView];
}

- (void)layoutForUnconnected
{
    // If we aren't connected to a Romo base, just show a label
    if (!self.unconnectedView) {
        self.unconnectedView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.unconnectedView.backgroundColor = [UIColor whiteColor];
        
        UILabel *notConnectedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.center.y, self.view.frame.size.width, 40)];
        notConnectedLabel.textAlignment = NSTextAlignmentCenter;
        notConnectedLabel.text = @"Romo Not Connected";
        [self.unconnectedView addSubview:notConnectedLabel];
    }

    [self.connectedView removeFromSuperview];
    [self.view addSubview:self.unconnectedView];
}

@end
