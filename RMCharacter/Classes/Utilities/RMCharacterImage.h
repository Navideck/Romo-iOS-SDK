//
//  RMCharacterImage.h
//  RMCharacter
//

#import <UIKit/UIKit.h>

@interface RMCharacterImage : UIImage

+ (void)emptyCache;
+ (RMCharacterImage *)imageNamed:(NSString*)name;

@end
