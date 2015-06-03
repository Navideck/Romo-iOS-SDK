//
//  RMLineView.h
//  RomoLineFollow
//
//  Created on 8/28/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#define RMLINE_POSITIVE_COLOR [UIColor colorWithRed:(1.0/255.0) green:(174.0/255.0) blue:(221.0/255.0) alpha:1.0];
#define RMLINE_NEGATIVE_COLOR [UIColor colorWithRed:(184.0/255.0) green:(1.0/255.0) blue:(40.0/255.0) alpha:1.0];

@interface RMLineView : UIImageView
{
}

@property (nonatomic) BOOL drawingPositives;

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
//- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;


@end
