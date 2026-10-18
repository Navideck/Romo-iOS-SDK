//
//  RMLogFormatter.h
//  Romo
//

#import <Foundation/Foundation.h>
#if __has_include(<CocoaLumberjack/CocoaLumberjack.h>)
#import <CocoaLumberjack/CocoaLumberjack.h>
#else
// CocoaLumberjack's SwiftPM package doesn't ship its umbrella header
#import <CocoaLumberjack/DDLog.h>
#import <CocoaLumberjack/DDLogMacros.h>
#endif

@interface RMLogFormatter : NSObject <DDLogFormatter>

- (id)initWithColors:(BOOL)colors;

@end
