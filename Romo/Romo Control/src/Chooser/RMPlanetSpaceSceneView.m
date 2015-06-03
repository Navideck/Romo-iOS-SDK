//
//  RMPlanetSpaceSceneView.m
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMPlanetSpaceSceneView.h"
#import "RMSpaceScene.h"
#import "RMSpaceStar.h"
#import "UIView+Additions.h"

@interface RMPlanetSpaceSceneView ()

@property (nonatomic, strong) UIImageView *planetView;
@property (nonatomic, strong) RMSpaceScene *spaceScene;

@end

@implementation RMPlanetSpaceSceneView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.planetView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoChooserPlanet"]];
        
        CGSize imageSize = self.planetView.image.size;
        
        self.planetView.width = self.width * 1.25;
        self.planetView.height = self.width * imageSize.height / imageSize.width;
        self.planetView.centerX = self.boundsCenter.x;
        self.planetView.top = self.bottom - MIN(self.planetView.height, 300);
        
        [self addSubview:self.planetView];
        [self sendSubviewToBack:self.planetView];
        
        self.spaceScene = [[RMSpaceScene alloc] initWithFrame:self.bounds];
        [self.spaceScene addSpaceObjects:[RMSpaceStar generateRandomSpaceStarsWithCount:20]];
        self.spaceScene.cameraLocation = RMPoint3DMake(0, 0, 0.15);
        
        [self addSubview:self.spaceScene];
        [self sendSubviewToBack:self.spaceScene];
    }
    return self;
}

- (void)scrollToPosition:(CGPoint)position withTotalContentWidth:(CGFloat)contentWidth
{
    CGFloat planetCenterX = self.width / 2.0;
    CGFloat x = 0;
    
    if (contentWidth > 0) {
        CGFloat scrollPercent = position.x / contentWidth;
        x += scrollPercent * 0.08;
        
        // If the scrollView's content width is bigger than its frame width,
        // use the difference between the two. The ensures the percentage
        // will range from 0.0 - 1.0
        // Else, we risk dividing by zero, so use the normal scroll percent
        CGFloat horizontalExcess = contentWidth - self.width;
        CGFloat planetScrollPercent = (horizontalExcess > 0) ? (position.x / horizontalExcess) : scrollPercent;
        CGFloat planetHorizontalMargin = self.planetView.width * 0.4;
        
        planetCenterX -= (planetScrollPercent - 0.5) * (self.planetView.width / 2 - planetHorizontalMargin);
    }
    
    self.spaceScene.cameraLocation = RMPoint3DMake(x, 0, 0.15);
    self.planetView.centerX = planetCenterX;
}

@end
