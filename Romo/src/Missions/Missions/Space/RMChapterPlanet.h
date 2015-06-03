//
//  RMChapterPlanet.h
//  Romo
//

#import "RMSpaceObject.h"
#import "RMProgressManager.h"

@interface RMChapterPlanet : UIView

@property (nonatomic, readonly) RMChapter chapter;
@property (nonatomic, readonly) RMChapterStatus status;

- (id)initWithChapter:(RMChapter)chapter status:(RMChapterStatus)status;

@end
