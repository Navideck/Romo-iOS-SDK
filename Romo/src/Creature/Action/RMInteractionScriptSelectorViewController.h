//
//  RMInteractionScriptSelectorViewController.h
//  Romo
//
//  Created on 10/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^RMInteractionScriptSelectorViewControllerCompletion)(BOOL success, NSDictionary *script);

/**
 
This ViewController lets you select an interaction script to run. These scripts are fetched from a
local server that is defined in the Environment Variable INTERACTION_SCRIPT_SERVER. The server
must be running in order to use this functionality. Changes to the scripts will be reflected even
during a running session.
 
To access this ViewController, in DEBUG perform a three finger swipe up when on the creature
controller.
 
Running the server:
 
    $ cd your-romo-project/iOS/Romo/node
    $ node app.js
 
Note you must have Node.js installed. This is simple with Homebrew: `brew install node`. Or you can
grab the latest stable on the Node.js website.
 
The environment variable INTERACTION_SCRIPT_SERVER should equal something like "koopa.local:8050"
 
 */

@interface RMInteractionScriptSelectorViewController : UIViewController

- (instancetype)initWithCompletion:(RMInteractionScriptSelectorViewControllerCompletion)completion;

@end
