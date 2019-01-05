#import "UIImage+Retina.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#ifdef DEBUG
static int ddLogLevel __unused = DDLogLevelVerbose;
#else
static int ddLogLevel __unused = DDLogLevelInfo;
#endif

#ifdef DEBUG
#define DDLOG_ENABLE_DYNAMIC_LEVELS \
+ (int)ddLogLevel \
{ \
return ddLogLevel; \
} \
+ (void)ddSetLogLevel:(int)logLevel \
{ \
ddLogLevel = logLevel; \
}
#else
#define DDLOG_ENABLE_DYNAMIC_LEVELS
#endif

#define RMRomoWiFiDriveVersion @"3.0"

#define iPad (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

/** 
 For iPhones & iPods, supply a y-position on the screen for tall devices and short devices
 Returns the appropriate option
 e.g. iPhone 5 -> tall
 e.g. iPod 4 -> short
 */
#define y(tall,short) ([UIScreen mainScreen].bounds.size.height > 480 ? (tall) : (short))
