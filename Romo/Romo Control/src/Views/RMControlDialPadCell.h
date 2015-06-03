//
//  RMControlDialPadCell.h
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^RMControlDialPadCellCallButtonPress)(NSString *number);

@interface RMControlDialPadCell : UICollectionViewCell

@property (nonatomic, copy) RMControlDialPadCellCallButtonPress callPressBlock;

@end
