//
//  main.m
//  HelloRMVision
//
//  Created by Adam Setapen on 6/16/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RMAppDelegate.h"

int main(int argc, char *argv[])
{
//    @autoreleasepool {
//        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RMAppDelegate class]));
//    }
    
    int retVal = 0;
    @autoreleasepool {
        NSString *classString = NSStringFromClass([RMAppDelegate class]);
        @try {
            retVal = UIApplicationMain(argc, argv, nil, classString);
        }
        @catch (NSException *exception) {
            NSLog(@"Exception - %@", exception);
            [exception callStackSymbols];
            exit(EXIT_FAILURE);
        }
    }
    return retVal;
}
