//
//  RMHTTPLogger.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface RMWebSocketLogger : NSObject <DDLogger>

@property (nonatomic, strong) id <DDLogFormatter> logFormatter;

+ (id)sharedInstance;

@end
