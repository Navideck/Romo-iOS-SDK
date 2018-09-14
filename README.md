# Romo iOS SDK
<a href="https://www.patreon.com/bePatron?u=5127277" target="_blank"><img alt="become a patron" src="https://c5.patreon.com/external/logo/become_a_patron_button.png" height="35px"></a>

<p align="center">
<img src="https://github.com/fotiDim/Romo/raw/master/Romo/Assets.xcassets/Missions/Editor/Actions/Turn/romoTurn28%401x.imageset/romoTurn28%401x.png"/>
</p>

<p align="center" >
<img src="https://img.shields.io/badge/platform-iOS%208,%209,%2010,%2011%2B-blue.svg" alt="Platform: iOS 8, 9, 10, 11, 12" /> <img src="https://img.shields.io/gitter/room/nwjs/nw.js.svg" alt="chat on gitter" /></p>

This project is a continuation of the *Romo* app and *Romo SDK*, an attempt to breathe life into the lovable but sadly discontinued, iPhone robot, **Romo**.

## Where do I find the app?
Find the *Romo X* app on the [App Store](https://itunes.apple.com/us/app/romo-x/id1436292886)

## How do I use the SDK in my own app?
The Romo SDK is a dynamic framework. You need to add **RMShared** and **RMCore** in project. In addition you need to add their respective dependencies. So the list comes down to:
* RMShared
* RMCore
* [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack)
* [NMSSH](https://github.com/NMSSH/NMSSH)
* [SocketRocket](https://github.com/facebook/SocketRocket)

For RMVision you need to download separately the **OpenCV 2** iOS framework and place it under **SDK/RMVision/RMVision/lib/OpenCV**

You can use ```carthage update --platform iOS``` if you need to fetch or update the dependencies using [Carthage](https://github.com/Carthage/Carthage). Don't forget to add all frameworks to the **Embedded Binaries** section under the **General** tab of your app's target.

Your app's info.plist should include the **Supported external accessory protocols** key with a value of **com.romotive.romo** to be able to connect to Romo.

Have a look in the **HelloRMCore** project as an example. Every framework is already checked out in the repo and you should be able to compile out of the box.

## FAQ

### How did this came to be?
Romotive, the company behind Romo, after shutting down were kind enough to open source their code stating:
*"We've decided to completely open-source every last bit of Romo's smarts. All of our projects live in this repo and you're free to use them however you like."*

### Which Romo works with the app and SDK?
Any Romo with either 30pin or lightning port.

### Which iPhones work with Romo?
iPhones 4s and above. iPhone 6 needs some squeezing but works fine. iPhone SE is the last *Romo sized* iPhone that fits like a glove.

### Which iOS versions are compatible with Romo?
The updated app and SDK work from **iOS 9.0** up to **iOS 12**! Yes, iOS 12!

### Where can I buy a Romo robot?
There seems to be plenty of stock in online stores.

## Major Changes
* Updated dependency versions. Using Carthage for dependency management.
* Enabled bitcode
* **RMShared** and **RMCore** are now dynamic frameworks
* Minimum iOS version support is 9.0

## Current Progress
- [x] Refactor RMShared
- [x] Refactor RMCore
- [x] Refactor HelloRMCore
- [x] Refactor RMVision
- [x] Refactor HelloRMVision
- [x] Refactor RMCharacter
- [x] Refactor HelloRMCharacter
- [x] Refactor HelloRomo
- [x] Refactor Romo.xcworkspace
- [ ] Clean up duplicate projects and folder structure
- [ ] Fix warnings
- [ ] Add Swift example

If somebody has access to Romo's firmware or schematics I would love to add them to the repo.
Issues and pull requests are always welcome!

## Patrons
* Matt Duston
* Suschman
* Bruce Ownbey
* Shreyas Gite

<a href="https://www.patreon.com/bePatron?u=5127277" target="_blank"><img alt="become a patron" src="https://c5.patreon.com/external/logo/become_a_patron_button.png" height="35px"></a>



