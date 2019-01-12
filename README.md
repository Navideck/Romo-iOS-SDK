# Romo iOS SDK
<a href="https://www.patreon.com/bePatron?u=5127277" target="_blank"><img alt="become a patron" src="https://c5.patreon.com/external/logo/become_a_patron_button.png" height="35px"></a>

<p align="center">
<img src="https://github.com/fotiDim/Romo/raw/master/Romo/Assets.xcassets/Missions/Editor/Actions/Turn/romoTurn28%401x.imageset/romoTurn28%401x.png"/>
</p>

<p align="center" >
<img src="https://img.shields.io/badge/platform-iOS%206,%207,%208,%209,%2010,%2011,%2012-blue.svg" alt="Platform: iOS 6, 7, 8, 9, 10, 11, 12" /> <img src="https://img.shields.io/gitter/room/nwjs/nw.js.svg" alt="chat on gitter" /></p>

This project is a continuation of the *Romo* app and *Romo SDK*, an attempt to breathe life into the lovable but sadly discontinued, iPhone robot, **Romo**.

## Where do I find the app?
Find the *Romo X* app on the [App Store](https://itunes.apple.com/us/app/romo-x/id1436292886)

## How do I use the SDK in my own app?
The Romo SDK is a set of frameworks that you can selectively use according to what you want to do. Those are:
* RMShared
* RMCore
* RMCharacter
* RMVision

You need at least **RMShared** and **RMCore** to be able to control Romo. Dependencies can be easily added to your project as local *Development Pods*. See the **Podfile** in the *Romo* folder or in the sample apps in *SDK/Sample Code* as guides for your own Podfile. Then use ```pod install``` to fetch the dependencies using [CocoaPods](https://cocoapods.org/).

Your app's *info.plist* should include the **Supported external accessory protocols** key with a value of **com.romotive.romo** to be able to connect to Romo.

## FAQ

### Where do I find the app?
Find the *Romo X* app on the [App Store](https://itunes.apple.com/us/app/romo-x/id1436292886)

### Where can I buy a Romo robot?
There seems to be plenty of stock in online stores.

### Which Romo works with the app and SDK?
Any Romo with either 30pin or lightning port. This includes Romo models 3A, 3B, 3L.

### Which iPhone work with Romo?
iPhone 3GS and above. iPhone 6 needs some squeezing but works just fine. iPhone SE is the last *Romo sized* iPhone that fits like a glove.

### Which iOS versions are compatible with Romo?
The *Romo X* app and SDK work from **iOS 6.0** up to **iOS 12**! Yes, iOS 12!

### How did this come to be?
Romotive, the company behind Romo, after shutting down were kind enough to open source their code stating:
*"We've decided to completely open-source every last bit of Romo's smarts. All of our projects live in this repo and you're free to use them however you like."*

## Major Changes
* Updated dependency versions. Using CocoaPods for dependency management.
* Enabled bitcode
* **RMShared** and **RMCore** are now bundled as frameworks
* Minimum iOS version support is 6.0

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

Issues and pull requests are always welcome!

## Patrons
* Matt Duston
* Suschman
* Bruce Ownbey
* Shreyas Gite


Support us by becoming a patron!

<a href="https://www.patreon.com/bePatron?u=5127277" target="_blank"><img alt="become a patron" src="https://c5.patreon.com/external/logo/become_a_patron_button.png" height="35px"></a>



