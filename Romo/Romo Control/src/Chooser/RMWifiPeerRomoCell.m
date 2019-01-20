//
//  RMWifiPeerRomoView.m
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMWifiPeerRomoCell.h"
#import "RMPeer.h"
#import "UIFont+RMFont.h"
#import "UIView+Additions.h"

@interface RMWifiPeerRomoCell ()

@property (nonatomic, strong) RMPeer *data;

@end

@implementation RMWifiPeerRomoCell

@dynamic data;

- (NSString *)labelText
{
    return self.data.name;
}

@end
