//
//  RMCharacterImage.h
//  RMCharacter
//

#import <UIKit/UIKit.h>

@interface RMCharacterImage : UIImage

+ (void)emptyCache;
+ (RMCharacterImage *)imageNamed:(NSString*)name;
+ (RMCharacterImage *)smartImageNamed:(NSString *)name;

@end
