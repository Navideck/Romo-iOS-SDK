//
//  RMLineView.m
//  RomoLineFollow
//
//  Created on 8/28/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>

#import "RMLineView.h"

#define DEFAULT_WIDTH 5.0f


@interface RMLineView ()

@property (nonatomic) CGPoint location;
@end

@implementation RMLineView

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    self.location = [touch locationInView:self];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self];
    
    UIGraphicsBeginImageContext(self.frame.size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [self.image drawInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineWidth(ctx, DEFAULT_WIDTH);
    
    if (self.drawingPositives)
    {
        CGFloat red, green, blue, alpha;
        UIColor *color = RMLINE_POSITIVE_COLOR;
        [color getRed:&red green:&green blue:&blue alpha:&alpha];
        CGContextSetRGBStrokeColor(ctx, red, green, blue, alpha);
    }
    else
    {
        CGFloat red, green, blue, alpha;
        UIColor *color = RMLINE_NEGATIVE_COLOR;
        [color getRed:&red green:&green blue:&blue alpha:&alpha];
        CGContextSetRGBStrokeColor(ctx, red, green, blue, alpha);
    }
    
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, self.location.x, self.location.y);
    CGContextAddLineToPoint(ctx, currentLocation.x, currentLocation.y);
    CGContextStrokePath(ctx);
    self.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.location = currentLocation;
}

//- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
//    UITouch *touch = [touches anyObject];
//    CGPoint currentLocation = [touch locationInView:self];
//    
//    UIGraphicsBeginImageContext(self.frame.size);
//    CGContextRef ctx = UIGraphicsGetCurrentContext();
//    [self.image drawInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
//    CGContextSetLineCap(ctx, kCGLineCapRound);
//    CGContextSetLineWidth(ctx, DEFAULT_WIDTH);
//    
//    if (self.drawingPositives)
//    {
//        CGFloat red, green, blue, alpha;
//        UIColor *color = RMLINE_POSITIVE_COLOR;
//        [color getRed:&red green:&green blue:&blue alpha:&alpha];
//        CGContextSetRGBStrokeColor(ctx, red, green, blue, alpha);
//    }
//    else
//    {
//        CGFloat red, green, blue, alpha;
//        UIColor *color = RMLINE_NEGATIVE_COLOR;
//        [color getRed:&red green:&green blue:&blue alpha:&alpha];
//        CGContextSetRGBStrokeColor(ctx, red, green, blue, alpha);
//    }
//    
//    CGContextBeginPath(ctx);
//    CGContextMoveToPoint(ctx, self.location.x, self.location.y);
//    CGContextAddLineToPoint(ctx, currentLocation.x, currentLocation.y);
//    CGContextStrokePath(ctx);
//    self.image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    
//    self.location = currentLocation;
//}


@end

