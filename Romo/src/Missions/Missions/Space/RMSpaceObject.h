//
//  RMSpaceObject.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Romo/RMCharacter.h>

@interface RMSpaceObject : UIImageView

/**
 The 3D point in space
 The "camera" is at (0,0,0)
 x: [-1, 1] where positive is right
 y: [-1, 1] where positive is down
 z: [-1, 1] positive is in front of the camera
 */
@property (nonatomic) RMPoint3D location;

@end
