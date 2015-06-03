//
//  RMPeerRomoCell.h
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RMPeerRomoCell : UICollectionViewCell

@property (nonatomic, strong) id data;
@property (nonatomic, strong) UIImageView *romoImageView;

- (void)update;
- (NSString *)labelText;

@end
