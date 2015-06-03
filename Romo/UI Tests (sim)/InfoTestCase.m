//
//  InfoTestCase.m
//  Romo
//
//  Created on 9/18/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import <KIF/KIF.h>
#import "RMProgressManager.h"
#import "RMAppDelegate.h"
#import "KIFUITestActor+RMInteractions.h"

@interface InfoTestCase : KIFTestCase

@end



@implementation InfoTestCase

- (void)beforeEach
{
    
    [[RMProgressManager sharedInstance] resetProgress];
    [[RMProgressManager sharedInstance] setStatus:RMChapterStatusSeenUnlock
                                       forChapter:RMChapterOne];
    [[RMProgressManager sharedInstance] updateStoryElement:@"Character-Script-1-0"
                                                withStatus:RMStoryStatusRevealed];
    RMAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    // so long as the defaultController is the RMProgressRobotController, this
    // line will have it -transitionToNextTask. Combined with the previous
    // -resetProgress, this will kick off the intro cutscene
    delegate.robotController = delegate.defaultController;
    
}

- (void)invalidRomoNames:(NSString *)name
{
    [tester waitForViewWithAccessibilityLabel:@"main view"];
    [tester tapViewWithAccessibilityLabel:@"Help Button"];
    [tester waitForViewWithAccessibilityLabel:@"Info View"];

    [tester clearTextFromAndThenEnterText:@"Some Valid Name" intoViewWithAccessibilityLabel:@"Input Name"];
    [tester tapViewWithAccessibilityLabel:@"done"];
    [tester clearTextFromAndThenEnterText:name
           intoViewWithAccessibilityLabel:@"Input Name"];
    // Won't let us tap Done since empty string in Input Name field.
    //[tester tapViewWithAccessibilityLabel:@"done"];
    [tester tapViewWithAccessibilityLabel:@"back"];
    [tester tapViewWithAccessibilityLabel:@"Help Button"];
    // A way to test that the text field for Input Name has remained after exiting Info View w/out a valid name.
    [tester enterText:@"" intoViewWithAccessibilityLabel:@"Info View" traits:UIAccessibilityTraitNone expectedResult:@"Some Valid Name"];
}

- (void)testBlankName
{
    [self invalidRomoNames:@""];
}

@end
