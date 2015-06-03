//
//  IntroTestCase.m
//  Romo
//
//  Created on 9/10/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <KIF/KIF.h>
#import "RMProgressManager.h"
#import "RMProgressRobotController.h"
#import "RMAppDelegate.h"
#import "KIFUITestActor+RMInteractions.h"

static NSDictionary *introScript;

@interface IntroTestCase : KIFTestCase
@end

@implementation IntroTestCase

- (void)beforeAll
{
    NSError *error;
    NSString *scriptPath;
    scriptPath = [[NSBundle mainBundle] pathForResource:@"Character-Script-1-0"
                                                 ofType:@"json"];
    NSString *scriptText = [NSString stringWithContentsOfFile:scriptPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:&error];
    if (error) {
        [tester failWithError:[NSError errorWithDomain:@"UITestError"
                                                  code:1
                                              userInfo:nil]
                    stopTest:YES];
    }
    NSData *scriptData = [scriptText dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *script = [NSJSONSerialization JSONObjectWithData:scriptData
                                                           options:0
                                                             error:&error];
    if (error) {
        [tester failWithError:[NSError errorWithDomain:@"UITestError"
                                                  code:2
                                              userInfo:nil]
                     stopTest:YES];
    }
    introScript = script[@"script"];
}

- (void)beforeEach
{
    [[RMProgressManager sharedInstance] resetProgress];
    RMAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    // so long as the defaultController is the RMProgressRobotController, this
    // line will have it -transitionToNextTask. Combined with the previous
    // -resetProgress, this will kick off the intro cutscene
    delegate.robotController = delegate.defaultController;
}

- (void)chatBlock:(int)blockIndex withDescription:(NSString *)desc
{
    // casting hell!
    NSDictionary *script = ((NSDictionary *)
                            ((NSArray *)introScript[@"blocks"])[blockIndex]);
    // make sure the block loaded has the description we're expecting. This
    // protects us from the script changing but the tests not matching.
    if ([desc compare:((NSString *)script[@"description"])] != NSOrderedSame) {
        [tester failWithError:[NSError errorWithDomain:@"UITestError"
                                                  code:3
                                              userInfo:nil]
                     stopTest:NO];
    }
    
    // run quickly through each "say" action
    for (NSDictionary *action in ((NSArray *)script[@"actions"])) {
        NSString *actionName = ((NSString *)action[@"name"]);
        if ([actionName compare:@"say"] == NSOrderedSame
            || [actionName compare:@"expressionWithText"] == NSOrderedSame) {
            [tester romoSays:((NSString *)[action[@"args"] lastObject])];
            [tester pokeRomo];
        }
    }
}

- (void)introScript
{
    [tester crashLand];
    
    [tester romoSays:@"Who are\nyou?"];
    [tester pokeRomo];
    
    // Let Romo look at the human
    [tester waitForTimeInterval:10];
    
    [self chatBlock:6
     withDescription:@"Realize it's a human & Earth"];
    
    [tester romoSays:@"So what's your name,\nhuman?"];
}

// tests are run in alphabetical order, hence the naming on these next two
- (void)testAAAPreReset
{
    [tester crashLand];
}

- (void)testAAAResetWorks
{
    // run a test to just skip the cutscene twice, to make sure the resetting in
    // -beforeEach works for us.
    [tester crashLand];
}
/*
- (void)testHelpRomo
{
    [self introScriptWithHumanHelp:YES];
}

- (void)testDoNotHelpRomo
{
    [self introScriptWithHumanHelp:NO];
}
*/
- (void)testValidHumanAndRomoNames
{
    [self introScript];
    [tester romoSays:@"So what's your name,\nhuman?"];

    [tester enterText:@"Fry" intoViewWithAccessibilityLabel:@"Input Field"];
    [tester tapViewWithAccessibilityLabel:@"done"];

    [tester romoSays:@"Fry?!"];
    [tester pokeRomo];
    
    [tester romoSays:@"Now that I'm here,\nI need an Earth name."];
    [tester pokeRomo];
    
    [tester romoSays:@"What do you\nwanna call me?"];
    [tester enterText:@"Bender\n" intoViewWithAccessibilityLabel:@"Input Field"];
    
    [tester romoSays:@"Ooooh!\nBender!"];
    [tester pokeRomo];
    
    [tester romoSays:@"Back to\nbusiness!"];
}

- (void)rejectHumanName:(NSString *)name
{
    [self introScript];
    [tester enterText:name intoViewWithAccessibilityLabel:@"Input Field"];
    [tester waitForTimeInterval:5];
    // make sure the question isn't gone, and that the textfield is still around
    [tester romoSays:@"So what's your name,"];
    [tester waitForViewWithAccessibilityLabel:@"Input Field"];
}

- (void)rejectRomoName:(NSString *)name
{
    [self introScript];
    [tester enterText:@"Fry\n" intoViewWithAccessibilityLabel:@"Input Field"];
    
    [tester romoSays:@"Fry?!"];
    [tester pokeRomo];
    
    [tester romoSays:@"Now that I'm here,\nI need an Earth name."];
    [tester pokeRomo];
    
    [tester romoSays:@"What do you\nwanna call me?"];
    [tester enterText:name intoViewWithAccessibilityLabel:@"Input Field"];
    
    [tester waitForTimeInterval:5];
    // make sure the question isn't gone, and that the textfield is still around
    [tester romoSays:@"What do you\nwanna call me?"];
    [tester waitForViewWithAccessibilityLabel:@"Input Field"];
}

- (void)testRejectNullHumanName
{
    [self rejectHumanName:@"\n"];
}

- (void)testRejectWhitespaceHumanName
{
    [self rejectHumanName:@"    \n"];
}

- (void)testRejectNullRomoName
{
    [self rejectRomoName:@"\n"];
}

- (void)testRejectWhitespaceRomoName
{
    [self rejectRomoName:@" \n"];
}

@end
