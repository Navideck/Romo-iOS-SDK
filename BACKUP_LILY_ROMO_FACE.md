\# BACKUP — Lily working with Romo Face



\## Status



This is the known-good checkpoint for Lily iOS.



Verified on physical iPhone:



\- Lily app launches normally

\- Lily connects to the existing Xiaozhi architecture

\- Existing MCP/Romo tools remain available

\- Romo Face is displayed successfully

\- Original Live2D cat is hidden

\- RMCharacterFace is displayed inside Lily

\- GitHub Actions successfully builds the IPA



\## Important



DO NOT modify this backup branch directly.



If a future change breaks Lily, return to:



&#x20;   backup/lily-romo-face-working



or restore the corresponding commit recorded below.



\## Main modified files



\### Lily UI bridge



&#x20;   Lily-Rebuild/LilyRebuild/LilySharedBridge.m



This file contains:



\- RMCharacterFace integration

\- Live2D WKWebView detection

\- Live2D hiding

\- Romo Face installation

\- Existing Lily/Xiaozhi/MCP bridge

\- Existing Romo control tools



\### CocoaPods



&#x20;   Lily-Rebuild/Podfile



Contains:



&#x20;   pod 'Romo/RMCharacter', path: '..'



This enables RMCharacter/RMCharacterFace.



\## Romo Face implementation



Current UI path:



&#x20;   Lily Shared MainViewController

&#x20;           ↓

&#x20;   LilyInstallRomoFace()

&#x20;           ↓

&#x20;   RMCharacterFace

&#x20;           ↓

&#x20;   Lily UI



Live2D is hidden by detecting:



&#x20;   WKWebView

&#x20;   URL scheme = live2dasset



The Romo face is installed as a child view controller of Lily's main view controller.



\## Existing Romo MCP tools



Do not break these tools:



&#x20;   robot.status

&#x20;   robot.forward

&#x20;   robot.backward

&#x20;   robot.stop

&#x20;   robot.turn\_left

&#x20;   robot.turn\_right

&#x20;   robot.head\_up

&#x20;   robot.head\_down

&#x20;   robot.head\_to

&#x20;   robot.turn\_angle



`robot.forward` and `robot.backward` support:



&#x20;   {"distance\_cm":20}



and the robot physically stops after the requested distance.



\## Build



GitHub Actions workflow:



&#x20;   .github/workflows/build-lily.yml



Build environment:



&#x20;   macOS 14

&#x20;   Xcode 16.2

&#x20;   iOS deployment target 12.0



IPA:



&#x20;   LilyRebuild-unsigned.ipa



\## Next development steps



Do NOT implement everything at once.



Proceed incrementally:



1\. Lily emotion → Romo emotion/expression

2\. Lily speech → Romo talking expression

3\. TTS mouth synchronization

4\. Additional Romo animations

5\. Additional Romo features



After every step:



&#x20;   build

&#x20;   install IPA

&#x20;   test Lily

&#x20;   test MCP tools

&#x20;   test physical Romo



Only then create the next commit.



\## Recovery rule



If a future modification breaks the application:



&#x20;   git checkout hello-gateway

&#x20;   git reset --hard backup/lily-romo-face-working



The backup branch represents the known-good Romo Face state.

