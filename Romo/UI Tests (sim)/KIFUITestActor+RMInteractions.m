//
//  KIFUITestActor+RMInteractions.m
//  Romo
//
//  Created on 9/10/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "KIFUITestActor+RMInteractions.h"

@implementation KIFUITestActor (RMInteractions)

- (void)romoSays:(NSString *)phrase
{
    for (NSString *str in [phrase componentsSeparatedByString:@"\n"]) {
        if (str.length > 0) {
            NSString *line = [NSString stringWithFormat:@"Romo:%@", str];
            [self waitForViewWithAccessibilityLabel:line];
        }
    }
}

- (void)crashLand
{
    [self waitForViewWithAccessibilityLabel:@"Cutscene"];
    // make sure it has time to start up
    [self waitForTimeInterval:0.5];
    for (int i = 0; i < 3; i++) {
        // triple-tap to skip through the cutscene
        [self tapScreenAtPoint:CGPointMake(100, 100)];
    }
    [self waitForAbsenceOfViewWithAccessibilityLabel:@"Cutscene"];
}

- (void)pokeRomo
{
    [self tapViewWithAccessibilityLabel:@"main view"];
}

@end
