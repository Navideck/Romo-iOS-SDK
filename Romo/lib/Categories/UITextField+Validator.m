//
//  UITextField+Validator.m
//  Romo
//
//  Created on 9/4/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "UITextField+Validator.h"

@implementation UITextField (Validator)

- (BOOL)hasValidInput
{
    // Make sure we have a text object
    NSString *rawString = self.text;
    if (!rawString) {
        return NO;
    }
    
    // Trim out the whitespace!
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimmed = [rawString stringByTrimmingCharactersInSet:whitespace];
    
    // If we have nothing left, we don't have valid input (just whitespace or empty)
    if ([trimmed length] == 0) {
        return NO;
    }
    return YES;
}

@end
