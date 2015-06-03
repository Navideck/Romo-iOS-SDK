# Romotive SDK
---
## Version History

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



