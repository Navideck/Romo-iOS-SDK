# Romo iOS SDK
---
## Version History

### 0.5.3 (RC)
#### Fixed in this version
- **RMVision**: Fix not locking camera before frame rate adjustment
- **RMCharacter**: Backport to iOS 7
- **POD**: Set minimum iOS version to 7.0

### 0.5.2 (RC)
#### New in this version
- **README**: Renamed app to *Romo* and SDK to *Romo iOS SDK*
- **POD**: Switched to the new repo URL after renaming

### 0.5.1 (RC)
#### New in this version
- **RMCharacter**: Migrate to using `resource_bundle` in CocoaPods
- **RMCharacter**: Set iOS 9 as minimum to be able to use `NSDataAsset`

### 0.4.1 (RC)
#### Fixed in this version
- **README**: Improved Swift instructions
- **README**: Added `.plist` instructions for background mode

### 0.4 (RC)
#### New in this version
This is a significant upgrade that improves Swift support and adds background mode support! 

- **RMCore**: Added `+ (void)allowBackground:(BOOL)isBackgroundAllowed` to allow Romo to stay connected when the app enters the background.

Additionally, this beta release introduces the following sample application:

- **HelloRMCoreSwift**: Illustrates the use of RMCore to move around your Romo using Swift.

In addition the project's README was updated with the following changes:
- Added Swift instructions for RMCore
- Added background mode instructions for RMCore
- Added syntax highlighting

#### Fixed in this version
- **RMCore**: RMCore's API now adheres more closely to Swift conventions. 
- **README**: Outdated RMCore instructions were fixed.

### 0.3.2 (Public Beta)
#### Fixed in this version
- **RMCharacter**: Fix incompatible pointers type for RMCharacterImage

### 0.3.1 (Public Beta)
#### New in this version
Minimum supported iOS version is iOS 7 now.

#### Fixed in this version
- **RMShared** and **RMVision**: Removed iOS 6 related code
- **RMCharacter**: Asset handling improvements

### 0.3 (Public Beta)
#### New in this version
- **RMShared**: Duplicated logic from **RMCharacted** was moved to RMShared
- **RMCharacter**: Duplicated logic was moved to **RMShared**
- **RMCharacter**: Assets for all scales are generated
- **RMCharacter**: All assets were moved in an Asset Catalog
- **RMCharacter**: Reduce assets size

#### Fixed in this version
- **RMCore**: Fixed a threading issue that was causing robots to spin indefinitely
- **RMCore** and **RMCharacterDelegate**: Naming conventions updated to align closer with Apple’s standards

### 0.2 (Public Beta)
#### New in this version
- **RMCore**: Robots post NSNotifications on connect and disconnect
- **RMCore**: Robot and iDevice attitude (orientation in 3-space) and inertial measurements (acceleration, rotation rates, etc.) are available and easily accessible 
- **RMCore**: New drive commands: command robot to turn by a certain angle or to a particular heading (note: absolute heading will drift over time)
- **RMCore**: PID controller class is now publicly available
- **RMCharacter**: Ability to rotate the character's face

#### Fixed in this version
- **RMCore**: Fixed a threading issue that was causing robots to spin indefinitely
- **RMCore** and **RMCharacterDelegate**: Naming conventions updated to align closer with Apple’s standards

---
### 0.1 (Private Alpha)
#### New in this version
This version marks the initial distribution of the Romotive SDK to external developers. The current frameworks included in the alpha SDK are **RMCore** and **RMCharacter**.

- **RMCore**: Interfaces with the hardware of any Romotive robot
- **RMCharacter**: Allows developers to use Romo's character and personality in their own applications

Additionally, this alpha release introduces the following sample applications:

- **HelloRMCore**: Illustrates the use of RMCore to move around your Romo.
- **HelloRMCharacter**: Shows how to interface with the Romo character through your app.
- **HelloRomo**: Example of using both RMCore and RMCharacter to make Romo come to life!
