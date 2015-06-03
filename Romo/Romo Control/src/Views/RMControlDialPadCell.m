//
//  RMControlDialPadCell.m
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMControlDialPadCell.h"
#import "RMRomoDialer.h"
#import "UIView+Additions.h"
#import "RMSoundEffect.h"

#define inputNumberIsLongEnough(inputNumber) (((NSString *)(inputNumber)).length >= 7)

@interface RMControlDialPadCell ()

@property (nonatomic, strong) RMRomoDialer *dialer;

@end

@implementation RMControlDialPadCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _dialer = [[RMRomoDialer alloc] initWithFrame:CGRectMake(0, 0, self.width, [RMRomoDialer preferredHeight])];
        self.dialer.center = self.boundsCenter;
        
        [self addSubview:self.dialer];
        
        [self.dialer.callButton addTarget:self action:@selector(handleCallPress:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)prepareForReuse
{
    self.callPressBlock = nil;
}

- (void)handleCallPress:(id)sender
{
    if (inputNumberIsLongEnough(self.dialer.inputNumber)) {
        // If the input number is the correct length, try to dial
        if (self.callPressBlock) {
            self.callPressBlock(self.dialer.inputNumber);
        }
    } else {
        // Otherwise, make an error sound
        [RMSoundEffect playForegroundEffectWithName:@"Missions-Editor-Action-Edit-Disabled" repeats:NO gain:1.0];
    }
}

@end
