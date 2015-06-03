//
//  ViewController.m
//  HelloRMCharacter
//

#import "ViewController.h"

@implementation ViewController

#pragma mark -- View Lifecycle --

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Grab a shared instance of the Romo character
    self.Romo = [RMCharacter Romo];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Add Romo's face to self.view whenever the view will appear
    [self.Romo addToSuperview:self.view];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Removing Romo from the superview stops animations and sounds
    [self.Romo removeFromSuperview];
}

#pragma mark -- Touch Events --

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [[touches anyObject] locationInView:self.view];
    [self lookAtTouchLocation:touchLocation];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [[touches anyObject] locationInView:self.view];
    [self lookAtTouchLocation:touchLocation];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.Romo lookAtDefault];

    // Constants for the number of expression & emotion enum values
    int numberOfExpressions = 19;
    int numberOfEmotions = 7;

    // Choose a random expression from 1 to numberOfExpressions
    RMCharacterExpression randomExpression = 1 + (arc4random() % numberOfExpressions);
    
    // Choose a random expression from 1 to numberOfEmotions
    RMCharacterEmotion randomEmotion = 1 + (arc4random() % numberOfEmotions);
    
    [self.Romo setExpression:randomExpression withEmotion:randomEmotion];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Tell Romo to reset his eyes
    [self.Romo lookAtDefault];
}

#pragma mark -- Private Methods --

- (void)lookAtTouchLocation:(CGPoint)touchLocation
{
    // Maxiumum distance from the center of the screen = half the width
    CGFloat w_2 = self.view.frame.size.width / 2;
    
    // Maximum distance from the middle of the screen = half the height
    CGFloat h_2 = self.view.frame.size.height / 2;
    
    // Ratio of horizontal location from center
    CGFloat x = (touchLocation.x - w_2)/w_2;

    // Ratio of vertical location from middle
    CGFloat y = (touchLocation.y - h_2)/h_2;
    
    // Since the touches are on Romo's face, they 
    CGFloat z = 0.0;
    
    // Romo expects a 3D point
    // x and y between -1 and 1, z between 0 and 1
    // z controls how far the eyes diverge
    // (z = 0 makes the eyes converge, z = 1 makes the eyes parallel)
    RMPoint3D lookPoint = RMPoint3DMake(x, y, z);
    
    // Tell Romo to look at the point
    // We don't animate because lookAtTouchLocation: runs at many Hertz
    [self.Romo lookAtPoint:lookPoint animated:NO];

}

@end
