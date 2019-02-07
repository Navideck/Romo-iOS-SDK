# Romotive SDK
---
## README

The Romotive SDK gives you the power to write your own programs for Romotive robots. After downloading the SDK, this guide will help you get rolling so you can start developing apps for Romo.

The SDK is broken up into multiple frameworks, so you can pick and choose what you'd like to use in your app. The list of current frameworks is:

#### RMCore
Control Romo's hardware using your own apps! Using **RMCore**, you can drive all three motors, flash LEDs, and access state information about your Romo base.

#### RMCharacter
**RMCharacter** allows you to add Romo's adorable personality to your app. Want Romo to get excited when someone tweets your username? Now he can!

## Setting up a project
There are two ways to include the Romotive SDK in your app:

- If you're starting a new app from scratch, you can modify one of the sample projects available in the "examples" folder of the SDK.

- You can integrate the Romotive SDK into your existing app with the following steps:

#### Pull in the frameworks

If you're only using **RMCore**:

- Drag `frameworks/RMCore.framework` into your app's frameworks folder.
- In additon, go to the "Build Phases" tab for your app's target, and add the following external frameworks:

         CoreMotion.framework
         ExternalAccessory.framework

If you're only using **RMCharacter**:

- Drag `frameworks/RMCharacter.framework` and `frameworks/RMCharacter.bundle` into your app's frameworks folder.
- In additon, go to the "Build Phases" tab for your app's target, and add the following external frameworks:

         AVFoundation.framework
         QuartzCore.framework

If you're using **both** frameworks:

- Just follow both steps above!

#### Enable the Accessory

*Note: Only if you're using RMCore to interface with the robot.*

1. Navigate to your app's <code>Info.plist</code> file in XCode, which should be in the Supporting Files folder by default.

2. Click on the top row ("Information Property List") and add a new entry by clicking the plus button.

3. XCode will now ask you to input the key for this new entry. Use `Supported external accessory protocols`. Expand the newly created element, and change the value for "Item 0" to be `com.romotive.romo`.

4. That's it! Save the file and you're all set to have your app talk to the hardware accessory.

## Getting started
Now that we have a project that uses the Romotive SDK, it's time to start writing some code!

#### If you're using RMCore, you'll want to do the following...

1. Import the frameworks

        #import <RMCore/RMCore.h>

2. Implement the RMCoreDelegate interface

        @interface YourVC : UIViewController <RMCoreDelegate>

3. Add a property for the robot, with the protocols you'd like to use (here we're specifying that our robot can tilt its head, drive, and use an LED)
        
        @property (nonatomic, strong) RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol> *robot;

4. Initialize your delegacy to the robot (often in viewDidLoad).
    
        [RMCore setDelegate:self];
    
5. Implement a connection delegate (triggered when a robot is connected).

        - (void)didConnectToRobot:(RMCoreRobot *)robot
        {  
            // Currently the only kind of robot is Romo3, so this is just future-proofing
            if (robot.isDrivable && robot.isHeadTiltable && robot.isLEDEquipped) {
                self.robot = (RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol> *) robot;
            }
        }
    
6. Implement disconnection delegate (triggered when a robot is disconnected).

        - (void)didDisconnectFromRobot:(RMCoreRobot *)robot
        {
            if (robot == self.robot) {
                self.robot = nil;
            }
        }
    
Now you're ready to send the robot commands. Here are some examples:
                            
- Tell the LED to blink every 1 second (where the LED will be on 40% of every second).

        [self.robot.LEDs blinkWithPeriod:1.0 
                               dutyCycle:.4];
    
- Tell the base to tilt the phone to a specific angle in degrees (here, it's 110).

        [self.robot tiltToAngle:110
                     completion:^(BOOL success) {
                         if (success) {
                             NSLog(@"Successfully tilted");
                         } else {
                             NSLog(@"Couldn't tilt to the desired angle");
                         }
                     }];
    
- Tell the base to move forward at approximately 1 meter/second.

        [self.robot driveWithRadius:RM_DRIVE_RADIUS_STRAIGHT
                              speed:1.0];
        
- Tell the robot to turn 90 degrees counter-clockwise.

        [self.robot turnByAngle:90.0
                     withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                     completion:^(float heading) {
                         NSLog(@"Finished! Ended up at heading: %f", heading);
                     }];
        
- Tell all motors to stop.

        [self.robot stopAllMotion];

#### For using RMCharacter, a good start would be...

1. Add a property for the character

        @property (nonatomic, strong) RMCharacter *romo;

2. Initialize your character (often in viewDidLoad).

        - (void)viewDidLoad
        {
            [super viewDidLoad];
            
            // Grab a shared instance of the Romo character
            self.romo = [RMCharacter Romo];
        }

3. Add the character to a superview (often in viewWillAppear).

        - (void)viewWillAppear:(BOOL)animated
        {
            [super viewWillAppear:animated];
            
            // Add Romo's face to self.view whenever the view will appear
            [self.romo addToSuperview:self.view];
        }
    
4. Ensure you remove the character's view when you're done with it (often in viewDidDisappear).

        - (void)viewDidDisappear:(BOOL)animated
        {
            [super viewDidDisappear:animated];
            
            // Removing Romo from the superview stops animations and sounds
            [self.romo removeFromSuperview];
        }
        
Now you're ready to send the character commands. You can do things like:

- Tell Romo to change his facial expression

        self.romo.expression = RMCharacterExpressionCurious;
                                    
- Tell Romo to change his emotion
    
        self.romo.emotion = RMCharacterEmotionScared;

- Tell Romo to look up and to the left:

        [self.romo lookAtPoint:RMPoint3DMake(-1.0, -1.0, 0.5) 
                      animated:YES];

## Sample Projects
We've included a few examples to help you get rolling with the Romotive SDK:

- **HelloRMCore** - Control your Romo's hardware through driving its motors and LEDs.
- **HelloRMCharacter** - Cycle through Romo's expressions and emotions.
- **HelloRomo** - Use both frameworks to see what Romo is really capable of!

## Documentation
The documentation can be found in the "docs" folder that comes bundeled with the SDK. Alternatively, you can visit <http://romotive.com/developers/docs/> for the latest documentation.
                    
If you have any questions, comments, or suggestions, please email us at <developers@romotive.com>.