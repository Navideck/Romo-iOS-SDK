# Romo iOS SDK
<a href="https://www.patreon.com/bePatron?u=5127277" target="_blank"><img alt="become a patron" src="https://c5.patreon.com/external/logo/become_a_patron_button.png" height="35px"></a>

<p align="center">
<img src="https://raw.githubusercontent.com/Navideck/Romo-X/master/Assets.xcassets/Missions/Editor/Actions/Turn/romoTurn28.imageset/romoTurn28%401x.png"/>
</p>

<p align="center" >
<img src="https://img.shields.io/badge/platform-iOS%206,%207,%208,%209,%2010,%2011,%2012-blue.svg" alt="Platform: iOS 6, 7, 8, 9, 10, 11, 12" /></p>

Romo SDK gives you the power to write your own software for Romo robots. After downloading the SDK, this guide will help you get rolling so you can start developing apps for Romo.

This project is a continuation of the *Romo SDK*, an attempt to breathe life into the lovable but sadly discontinued, iPhone robot, **Romo**. The goal is to enable a community of makers, tutors and researchers that is actively engaged with the Romo platform and smartphone robotics.

The SDK is broken up into 3 major frameworks, so you can pick and choose what you'd like to use in your app. The list of current frameworks is:

#### RMCore
Control Romo's hardware using your own apps! Using **RMCore**, you can drive all three motors, flash LEDs, and access state information about your Romo base.

#### RMCharacter
**RMCharacter** allows you to add Romo's adorable personality to your app. Want Romo to get excited when someone tweets your username? Now he can!

#### RMVision
**RMVision** allows you to use the iPhone's camera to allow Romo to see but also understand the world using computer vision.

## Setting up a project
You have multiple options:
### Using CocoaPods
The most easy way to include the Romo SDK in your app is using CocoaPods:

    `pod 'Romo'`
    
Note that this will get you only `RMCore`. 

If you additionally need `RMCharacter` add

    `pod 'Romo/RMCharacter'`

If you additionally need `RMVision` add

    `pod 'Romo/RMVision'`

A complete `PodFile` with all frameworks would look like this:

```
# Uncomment the next line to define a global platform for your project
platform :ios, '6.0'

target 'My Cool Romo App' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  # Pods for My Cool Romo App
  pod 'Romo'
  pod 'Romo/RMCharacter'
  pod 'Romo/RMVision'
  
end
```

### Carthage
Although not tested yet, the basic folder structure for Carthage is in place so it should theoretically already be working.

### Manually
- You can drag and drop the files from the framework you want inside your own project. All source files are under `Classes` and optionally there might be an additional `Assets` folder like in the case of `RMCharacter`

#### Enable the Accessory

*Note: Only if you're using RMCore to interface with the robot.*

1. Navigate to your app's <code>Info.plist</code> file in XCode, which should be in the Supporting Files folder by default.

2. Click on the top row ("Information Property List") and add a new entry by clicking the plus button.

3. XCode will now ask you to input the key for this new entry. Use `Supported external accessory protocols`. Expand the newly created element, and change the value for "Item 0" to be `com.romotive.romo`.

4. That's it! Save the file and you're all set to have your app talk to the hardware accessory.

## Getting started
Now that we have a project that uses the Romo SDK, it's time to start writing some code!

#### If you're using RMCore, you'll want to do the following...

1. Import the frameworks

       #import <Romo/RMCore.h>

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

## Sample Projects / Examples
We've written a few sample applications to get you started using the Romotive SDK. Each framework has an `Examples` subfolder with one or more example projects. Some project you will find are:

### HelloRMCore
Control your Romo's hardware through driving its motors and LEDs.

This simple application presents three buttons on the screen when the iDevice is docked on a robot. Two of these buttons tilt the robot's head up and down when tapped. The third button tells the robot to drive in a circle and blink its LED.

### HelloRMCharacter
Cycle through Romo's expressions and emotions, and see how he can look around.

To get started interfacing with an **RMCharacter** object, we show you how to get Romo's face to appear on your iDevice. Drag your finger on Romo's face to have him look around. When your finger leaves the screen, Romo will perform a random expression (a brief action) and transition into a random emotion (a persistent state).

### HelloRomo
Use both **RMCore** and **RMCharacter** to drive Romo around and make faces.

Swipe left or right on Romo's face, and he will start driving in a circle in the direction you swiped. When you poke Romo's face, he'll stop what he's doing. Finally, swipe up to change Romo's emotional state. 

## Documentation
The documentation can be found in the "docs" folder that comes bundeled with the SDK.

## FAQ

### Is the Romo App on the App Store?
Find the *Romo X* app on the [App Store](https://itunes.apple.com/us/app/romo-x/id1436292886)

### Is the Romo App open source?
Find the *Romo X* app source code [here](https://github.com/Navideck/Romo-X)

### Is firmware source code available?
Find Romo's firmware source code [here](https://github.com/Navideck/Romo-Firmware)

### Where can I buy a Romo robot?
There seems to be plenty of stock in online stores.

### Which Romo works with the SDK?
Any Romo with either 30pin or lightning port. This includes Romo models 3A, 3B, 3L.

### Which iPhone works with Romo?
iPhone 3GS and above. iPhone SE fits like a glove. iPhone 6, 7 and 8 need some squeezing but fit just fine. iPhone X is too big.

### Which iOS versions are compatible with the SDK?
The *Romo X* app works from **iOS 6.0** up to **iOS 12**! Yes, iOS 12!

### How did this come to be?
Romotive, the company behind Romo, after shutting down were kind enough to open source their code stating:
*"We've decided to completely open-source every last bit of Romo's smarts. All of our projects live in this repo and you're free to use them however you like."*

Issues and pull requests are always welcome!

## Patrons
* Ryan Oksenhorn
* Matt Duston
* Suschman
* Bruce Ownbey
* Shreyas Gite

Support us by becoming a patron!

<a href="https://www.patreon.com/bePatron?u=5127277" target="_blank"><img alt="become a patron" src="https://c5.patreon.com/external/logo/become_a_patron_button.png" height="35px"></a>