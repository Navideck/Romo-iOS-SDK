#import "LilySharedBridge.h"
#import <objc/message.h>
#import <Romo/RMCore.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <string.h>
#import <objc/runtime.h>
#import <libkern/OSCacheControl.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <pthread.h>
#import <math.h>


static void LilyMCPWrite(NSString *line) {
    NSString *documents =
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES
        ).firstObject;

    if (!documents) {
        return;
    }

    NSString *path =
        [documents stringByAppendingPathComponent:@"LilyMCPDump.txt"];

    NSString *text =
        [line stringByAppendingString:@"\n"];

    NSFileHandle *fh =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (!fh) {
        [[NSFileManager defaultManager]
            createFileAtPath:path
            contents:nil
            attributes:nil];

        fh =
            [NSFileHandle fileHandleForWritingAtPath:path];
    }

    if (!fh) {
        return;
    }

    [fh seekToEndOfFile];

    NSData *data =
        [text dataUsingEncoding:NSUTF8StringEncoding];

    if (data) {
        [fh writeData:data];
    }

    [fh closeFile];
}


static void LilyDumpMethods(NSString *className) {
    Class cls = NSClassFromString(className);

    NSString *header =
        [NSString stringWithFormat:@"========== MCP DUMP %@ ==========", className];

    NSLog(@"[Lily][MCP-DUMP] %@", header);
    LilyMCPWrite(header);

    NSString *classLine =
        [NSString stringWithFormat:@"CLASS %@ = %@", className, cls];

    NSLog(@"[Lily][MCP-DUMP] %@", classLine);
    LilyMCPWrite(classLine);

    if (!cls) {
        NSString *line =
            [NSString stringWithFormat:@"CLASS %@ NOT FOUND", className];

        NSLog(@"[Lily][MCP-DUMP] %@", line);
        LilyMCPWrite(line);
        return;
    }

    // ============================================================
    // INSTANCE METHODS
    // ============================================================

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    NSString *countLine =
        [NSString stringWithFormat:@"INSTANCE METHOD COUNT = %u", count];

    NSLog(@"[Lily][MCP-DUMP] %@", countLine);
    LilyMCPWrite(countLine);

    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);

        NSString *selector =
            NSStringFromSelector(sel);

        NSString *line =
            [NSString stringWithFormat:
                @"INSTANCE %@ types=%s",
                selector,
                types ? types : ""];

        NSLog(@"[Lily][MCP-DUMP] %@", line);
        LilyMCPWrite(line);
    }

    free(methods);

    // ============================================================
    // CLASS METHODS
    // ============================================================

    Class meta = object_getClass(cls);
    count = 0;

    methods = class_copyMethodList(meta, &count);

    NSString *classCountLine =
        [NSString stringWithFormat:@"CLASS METHOD COUNT = %u", count];

    NSLog(@"[Lily][MCP-DUMP] %@", classCountLine);
    LilyMCPWrite(classCountLine);

    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);

        NSString *selector =
            NSStringFromSelector(sel);

        NSString *line =
            [NSString stringWithFormat:
                @"CLASS %@ types=%s",
                selector,
                types ? types : ""];

        NSLog(@"[Lily][MCP-DUMP] %@", line);
        LilyMCPWrite(line);
    }

    free(methods);

    NSString *footer =
        [NSString stringWithFormat:@"========== END %@ ==========", className];

    NSLog(@"[Lily][MCP-DUMP] %@", footer);
    LilyMCPWrite(footer);
}


static const int kLilyRomoHTTPPort = 5000;

@interface LilyRomoController : NSObject <RMCoreDelegate>
@property (nonatomic, strong) RMCoreRobot *robot;
@property (nonatomic) int serverSocket;
@property (nonatomic) BOOL running;
@end

@implementation LilyRomoController



+ (instancetype)sharedController {
    static LilyRomoController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ controller = [[LilyRomoController alloc] init]; });
    return controller;
}

- (void)start {
    if (self.running) return;
    [RMCore allowBackground:YES];
    [RMCore setDelegate:self];

    for (RMCoreRobot *robot in [RMCore connectedRobots]) {
        if (robot.isDrivable) { self.robot = robot; break; }
    }

    self.running = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self serverLoop];
    });
    NSLog(@"[Lily][Romo] controller started on 127.0.0.1:%d", kLilyRomoHTTPPort);
}

- (void)robotDidConnect:(RMCoreRobot *)robot {
    if (robot.isDrivable) {
        self.robot = robot;
        NSLog(@"[Lily][Romo] robot connected: %@", robot);
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot {
    if (robot == self.robot) {
        self.robot = nil;
        NSLog(@"[Lily][Romo] robot disconnected");
    }
}

- (void)forward {
    RMCoreRobot<DriveProtocol> *romo = (RMCoreRobot<DriveProtocol> *)self.robot;
    if (!romo) { NSLog(@"[Lily][Romo] FORWARD ignored: no robot"); return; }
    [romo driveForwardWithSpeed:0.5];
    NSLog(@"[Lily][Romo] FORWARD -> driveForwardWithSpeed:0.5");
}

- (void)backward {
    RMCoreRobot<DriveProtocol> *romo = (RMCoreRobot<DriveProtocol> *)self.robot;
    if (!romo) { NSLog(@"[Lily][Romo] BACKWARD ignored: no robot"); return; }
    [romo driveBackwardWithSpeed:0.5];
    NSLog(@"[Lily][Romo] BACKWARD -> driveBackwardWithSpeed:0.5");
}

- (void)stopDriving {
    RMCoreRobot<DriveProtocol> *romo = (RMCoreRobot<DriveProtocol> *)self.robot;
    if (romo) [romo stopDriving];
}

- (void)turnLeft {
    RMCoreRobot<DriveProtocol> *romo = (RMCoreRobot<DriveProtocol> *)self.robot;
    if (!romo) { NSLog(@"[Lily][Romo] LEFT ignored: no robot"); return; }
    [romo driveWithRadius:0.0 speed:0.5];
    NSLog(@"[Lily][Romo] LEFT -> driveWithRadius:0 speed:0.5");
}

- (void)turnRight {
    RMCoreRobot<DriveProtocol> *romo = (RMCoreRobot<DriveProtocol> *)self.robot;
    if (!romo) { NSLog(@"[Lily][Romo] RIGHT ignored: no robot"); return; }
    [romo driveWithRadius:0.0 speed:-0.5];
    NSLog(@"[Lily][Romo] RIGHT -> driveWithRadius:0 speed:-0.5");
}

- (void)turnByAngleDegrees:(float)angle {
    RMCoreRobot<DriveProtocol> *romo = (RMCoreRobot<DriveProtocol> *)self.robot;
    if (!romo) {
        NSLog(@"[Lily][Romo] TURN ANGLE ignored: no robot");
        return;
    }

    if (angle > 180.0f) angle = 180.0f;
    if (angle < -180.0f) angle = -180.0f;

    NSLog(@"[Lily][Romo] TURN ANGLE -> %.2f deg", angle);

    [romo turnByAngle:angle
          withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
               speed:0.3
     finishingAction:RMCoreTurnFinishingActionStopDriving
           completion:^(BOOL success, float completedAngle) {
        NSLog(@"[Lily][Romo] TURN ANGLE completion success=%d angle=%f",
              success,
              completedAngle);
    }];
}

- (void)headUpByDegrees:(float)degrees {
    RMCoreRobot<HeadTiltProtocol> *romo = (RMCoreRobot<HeadTiltProtocol> *)self.robot;
    if (!romo) { NSLog(@"[Lily][Romo] HEAD UP ignored: no robot"); return; }

    if (degrees < 0.0f) degrees = -degrees;

    float current = romo.headAngle;
    float maxAngle = romo.maximumHeadTiltAngle;
    float allowed = maxAngle - current;
    if (allowed < 0.0f) allowed = 0.0f;
    if (degrees > allowed) degrees = allowed;

    NSLog(@"[Lily][Romo] HEAD UP -> tiltByAngle:+%.2f current=%.2f max=%.2f",
          degrees, current, maxAngle);

    if (degrees > 0.0f) {
        [romo tiltByAngle:degrees completion:^(BOOL success) {
            NSLog(@"[Lily][Romo] HEAD UP completion success=%d angle=%.2f",
                  success, romo.headAngle);
        }];
    }
}

- (void)headDownByDegrees:(float)degrees {
    RMCoreRobot<HeadTiltProtocol> *romo = (RMCoreRobot<HeadTiltProtocol> *)self.robot;
    if (!romo) { NSLog(@"[Lily][Romo] HEAD DOWN ignored: no robot"); return; }

    if (degrees < 0.0f) degrees = -degrees;

    float current = romo.headAngle;
    float minAngle = romo.minimumHeadTiltAngle;
    float allowed = current - minAngle;
    if (allowed < 0.0f) allowed = 0.0f;
    if (degrees > allowed) degrees = allowed;

    NSLog(@"[Lily][Romo] HEAD DOWN -> tiltByAngle:-%.2f current=%.2f min=%.2f",
          degrees, current, minAngle);

    if (degrees > 0.0f) {
        [romo tiltByAngle:-degrees completion:^(BOOL success) {
            NSLog(@"[Lily][Romo] HEAD DOWN completion success=%d angle=%.2f",
                  success, romo.headAngle);
        }];
    }
}

- (void)headToAngleDegrees:(float)angle {
    RMCoreRobot<HeadTiltProtocol> *romo = (RMCoreRobot<HeadTiltProtocol> *)self.robot;
    if (!romo) { NSLog(@"[Lily][Romo] HEAD TO ignored: no robot"); return; }

    float minAngle = romo.minimumHeadTiltAngle;
    float maxAngle = romo.maximumHeadTiltAngle;

    if (angle < minAngle) angle = minAngle;
    if (angle > maxAngle) angle = maxAngle;

    NSLog(@"[Lily][Romo] HEAD TO -> tiltToAngle:%.2f range=[%.2f, %.2f]",
          angle, minAngle, maxAngle);

    [romo tiltToAngle:angle completion:^(BOOL success) {
        NSLog(@"[Lily][Romo] HEAD TO completion success=%d angle=%.2f",
              success, romo.headAngle);
    }];
}

- (NSString *)statusText {
    RMCoreRobot *robot = self.robot;
    if (!robot) return @"Romo is not connected.";

    float battery = 0.0f;
    BOOL charging = NO;
    if (robot.vitals) {
        battery = robot.vitals.batteryLevel;
        charging = robot.vitals.isCharging;
    }

    int percent = (int)(MAX(0.0f, MIN(1.0f, battery)) * 100.0f);

    return [NSString stringWithFormat:
        @"Romo is connected. Battery: %d%%. Charging: %@.",
        percent, charging ? @"yes" : @"no"];
}

- (void)sendHTTPResponse:(int)clientSocket status:(const char *)status body:(NSString *)body {
    NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString *response = [NSString stringWithFormat:
        @"HTTP/1.1 %s\r\nContent-Type: application/json; charset=utf-8\r\n"
         "Content-Length: %lu\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n%@",
        status, (unsigned long)bodyData.length, body];
    NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
    send(clientSocket, responseData.bytes, responseData.length, 0);
}

- (void)handleHTTPClient:(int)clientSocket {
    char buffer[2048];
    ssize_t count = recv(clientSocket, buffer, sizeof(buffer) - 1, 0);
    if (count <= 0) return;
    buffer[count] = '\0';

    NSString *request = [[NSString alloc] initWithBytes:buffer length:(NSUInteger)count encoding:NSUTF8StringEncoding];
    NSString *firstLine = [[request componentsSeparatedByString:@"\r\n"] firstObject];
    NSArray *parts = [firstLine componentsSeparatedByString:@" "];
    NSString *path = parts.count >= 2 ? parts[1] : @"";

    if ([path isEqualToString:@"/romo/forward"]) {
        [self forward];
        [self sendHTTPResponse:clientSocket status:"200 OK" body:@"{\"ok\":true,\"action\":\"forward\"}"];
    } else if ([path isEqualToString:@"/romo/backward"]) {
        [self backward];
        [self sendHTTPResponse:clientSocket status:"200 OK" body:@"{\"ok\":true,\"action\":\"backward\"}"];
    } else if ([path isEqualToString:@"/romo/stop"]) {
        [self stopDriving];
        [self sendHTTPResponse:clientSocket status:"200 OK" body:@"{\"ok\":true,\"action\":\"stop\"}"];
    } else if ([path isEqualToString:@"/romo/status"]) {
        NSString *body = [NSString stringWithFormat:@"{\"connected\":%@}", self.robot ? @"true" : @"false"];
        [self sendHTTPResponse:clientSocket status:"200 OK" body:body];
    } else {
        [self sendHTTPResponse:clientSocket status:"404 Not Found" body:@"{\"ok\":false,\"error\":\"unknown path\"}"];
    }
}

- (void)serverLoop {
    self.serverSocket = socket(AF_INET, SOCK_STREAM, 0);
    if (self.serverSocket < 0) { self.running = NO; return; }

    int yes = 1;
    setsockopt(self.serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(kLilyRomoHTTPPort);

    if (bind(self.serverSocket, (struct sockaddr *)&address, sizeof(address)) < 0 ||
        listen(self.serverSocket, 4) < 0) {
        close(self.serverSocket);
        self.serverSocket = -1;
        self.running = NO;
        return;
    }

    while (self.running) {
        int clientSocket = accept(self.serverSocket, NULL, NULL);
        if (clientSocket < 0) continue;
        [self handleHTTPClient:clientSocket];
        shutdown(clientSocket, SHUT_RDWR);
        close(clientSocket);
    }
}

@end

/* ============================================================
   Native Lily MCP -> Romo bridge â€” BUILD #73

   Correct lifecycle:
       WebsocketProtocol.openAudioChannel
           -> new McpServer
           -> registerTools()
           -> RETURN
           -> inject Romo tools into the LIVE server
           -> later tools/list reads server + 0x70

   We deliberately DO NOT hook McpServer#addTool(). Build #47 proved that
   injecting synchronously from inside addTool() can corrupt/invalidly re-enter
   Kotlin/Native collection/runtime dispatch. The safe boundary is the native
   registerTools() return.

   Confirmed native target in this exact Shared binary:
       Shared + 0x126B040 = McpServer#registerTools()
       x0 = live McpServer
       return = Unit / void

   First 16 bytes are:
       stp d9,d8,[sp,#-0x70]!
       stp x28,x27,[sp,#0x10]
       stp x26,x25,[sp,#0x20]
       stp x24,x23,[sp,#0x30]
   No PC-relative instruction occurs in this relocated prologue.
   ============================================================ */

static BOOL gLilyMCPHookInstalled = NO;
static BOOL gLilyNativeRegisterToolsPatchInstalled = NO;
static uintptr_t gLilyNativeRegisterToolsAddress = 0;
static uintptr_t gLilyNativeRegisterToolsTrampoline = 0;
static uint8_t gLilyOriginalRegisterToolsBytes[16];
static void *gLilyRomoInjectedServer = NULL;

/*
 * IMPORTANT:
 *
 * SharedMcpTool is an Objective-C wrapper.
 * McpServer#addTool expects the underlying Kotlin/Native McpTool.
 *
 * Keep the Objective-C wrappers alive because their callbacks are
 * owned by the wrapper object.
 */
static NSMutableArray *gLilyRomoToolWrappers = nil;

static void LilyRetainRomoToolWrapper(id tool) {
    if (!tool) {
        return;
    }

    @synchronized ([NSObject class]) {
        if (!gLilyRomoToolWrappers) {
            gLilyRomoToolWrappers = [[NSMutableArray alloc] init];
        }

        [gLilyRomoToolWrappers addObject:tool];
    }
}
static pthread_mutex_t gLilyNativeHookLock = PTHREAD_MUTEX_INITIALIZER;

static void LilyRomoForwardNoArgs(void) {
    [[LilyRomoController sharedController] forward];
}

static void LilyRomoBackwardNoArgs(void) {
    [[LilyRomoController sharedController] backward];
}

static void LilyRomoStopNoArgs(void) {
    [[LilyRomoController sharedController] stopDriving];
}


static id LilyCreateAngleProperty(NSString *name) {
    Class propertyClass = NSClassFromString(@"SharedMcpProperty");
    if (!propertyClass) return nil;

    SEL typeSel = NSSelectorFromString(@"integer");
    Class typeClass = NSClassFromString(@"SharedMcpPropertyType");
    if (!typeClass || ![typeClass respondsToSelector:typeSel]) return nil;

    typedef id (*EnumGetterFn)(id, SEL);
    id type = ((EnumGetterFn)objc_msgSend)(typeClass, typeSel);
    if (!type) return nil;

    SEL initSel = NSSelectorFromString(@"initWithName:type:min:max:value:hasDefault:");
    if (![propertyClass instancesRespondToSelector:initSel]) return nil;

    typedef id (*PropertyInitFn)(id, SEL, id, id, id, id, id, BOOL);
    PropertyInitFn initFn = (PropertyInitFn)objc_msgSend;

    return initFn([propertyClass alloc],
                  initSel,
                  name,
                  type,
                  @-180,
                  @180,
                  @0,
                  YES);
}


static id LilyCreateHeadRelativeProperty(NSString *name) {
    Class propertyClass = NSClassFromString(@"SharedMcpProperty");
    Class typeClass = NSClassFromString(@"SharedMcpPropertyType");
    if (!propertyClass || !typeClass) return nil;

    SEL typeSel = NSSelectorFromString(@"integer");
    if (![typeClass respondsToSelector:typeSel]) return nil;

    typedef id (*EnumGetterFn)(id, SEL);
    id type = ((EnumGetterFn)objc_msgSend)(typeClass, typeSel);
    if (!type) return nil;

    SEL initSel = NSSelectorFromString(@"initWithName:type:min:max:value:hasDefault:");
    if (![propertyClass instancesRespondToSelector:initSel]) return nil;

    typedef id (*PropertyInitFn)(id, SEL, id, id, id, id, id, BOOL);
    PropertyInitFn initFn = (PropertyInitFn)objc_msgSend;

    return initFn([propertyClass alloc], initSel,
                  name, type, @1, @90, @10, YES);
}

static id LilyCreateHeadAbsoluteProperty(NSString *name) {
    Class propertyClass = NSClassFromString(@"SharedMcpProperty");
    Class typeClass = NSClassFromString(@"SharedMcpPropertyType");
    if (!propertyClass || !typeClass) return nil;

    SEL typeSel = NSSelectorFromString(@"integer");
    if (![typeClass respondsToSelector:typeSel]) return nil;

    typedef id (*EnumGetterFn)(id, SEL);
    id type = ((EnumGetterFn)objc_msgSend)(typeClass, typeSel);
    if (!type) return nil;

    SEL initSel = NSSelectorFromString(@"initWithName:type:min:max:value:hasDefault:");
    if (![propertyClass instancesRespondToSelector:initSel]) return nil;

    typedef id (*PropertyInitFn)(id, SEL, id, id, id, id, id, BOOL);
    PropertyInitFn initFn = (PropertyInitFn)objc_msgSend;

    return initFn([propertyClass alloc], initSel,
                  name, type, @-90, @90, @0, YES);
}

/* Forward declaration: head/turn tool factories use this helper before its full definition. */
static id LilyCreateRomoToolWithProperties(NSString *name,
                                           NSString *description,
                                           NSArray *properties,
                                           id (^callback)(id));

static id LilyCreateHeadUpRomoTool(void) {
    id property = LilyCreateHeadRelativeProperty(@"angle_deg");
    NSArray *properties = property ? @[property] : @[];

    return LilyCreateRomoToolWithProperties(
        @"robot.head_up",
        @"Raise the Romo robot head by a relative angle in degrees.",
        properties,
        ^id(id args) {
            NSNumber *value = [args isKindOfClass:[NSDictionary class]] ? args[@"angle_deg"] : nil;
            if (!value) return @"Missing required argument: angle_deg";
            float degrees = value.floatValue;
            if (degrees <= 0.0f) return @"angle_deg must be greater than 0";
            if (degrees > 90.0f) degrees = 90.0f;
            [[LilyRomoController sharedController] headUpByDegrees:degrees];
            return [NSString stringWithFormat:@"Romo head up %.0f degrees", degrees];
        });
}

static id LilyCreateHeadDownRomoTool(void) {
    id property = LilyCreateHeadRelativeProperty(@"angle_deg");
    NSArray *properties = property ? @[property] : @[];

    return LilyCreateRomoToolWithProperties(
        @"robot.head_down",
        @"Lower the Romo robot head by a relative angle in degrees.",
        properties,
        ^id(id args) {
            NSNumber *value = [args isKindOfClass:[NSDictionary class]] ? args[@"angle_deg"] : nil;
            if (!value) return @"Missing required argument: angle_deg";
            float degrees = value.floatValue;
            if (degrees <= 0.0f) return @"angle_deg must be greater than 0";
            if (degrees > 90.0f) degrees = 90.0f;
            [[LilyRomoController sharedController] headDownByDegrees:degrees];
            return [NSString stringWithFormat:@"Romo head down %.0f degrees", degrees];
        });
}

static id LilyCreateHeadToRomoTool(void) {
    id property = LilyCreateHeadAbsoluteProperty(@"angle_deg");
    NSArray *properties = property ? @[property] : @[];

    return LilyCreateRomoToolWithProperties(
        @"robot.head_to",
        @"Move the Romo robot head to an absolute angle in degrees.",
        properties,
        ^id(id args) {
            NSNumber *value = [args isKindOfClass:[NSDictionary class]] ? args[@"angle_deg"] : nil;
            if (!value) return @"Missing required argument: angle_deg";
            float angle = value.floatValue;
            if (angle < -90.0f) angle = -90.0f;
            if (angle > 90.0f) angle = 90.0f;
            [[LilyRomoController sharedController] headToAngleDegrees:angle];
            return [NSString stringWithFormat:@"Romo head to %.0f degrees", angle];
        });
}

static id LilyCreateTurnAngleRomoTool(void) {
    id property = LilyCreateAngleProperty(@"angle_deg");
    NSArray *properties = property ? @[property] : @[];

    return LilyCreateRomoToolWithProperties(
        @"robot.turn_angle",
        @"Turn the physical Romo robot by an exact angle in degrees. Positive angle turns left/counter-clockwise; negative angle turns right/clockwise. Range -180 to 180 degrees.",
        properties,
        ^id(id args) {
            NSNumber *angle = nil;
            if ([args isKindOfClass:[NSDictionary class]]) {
                id value = [(NSDictionary *)args objectForKey:@"angle_deg"];
                if ([value respondsToSelector:@selector(floatValue)]) {
                    angle = @([value floatValue]);
                }
            }

            if (!angle) {
                return @"Missing required argument: angle_deg";
            }

            float degrees = angle.floatValue;
            if (degrees == 0.0f) {
                return @"Angle must not be 0 degrees";
            }

            if (degrees > 180.0f) degrees = 180.0f;
            if (degrees < -180.0f) degrees = -180.0f;

            [[LilyRomoController sharedController] turnByAngleDegrees:degrees];

            return [NSString stringWithFormat:@"Romo turning %.0f degrees", degrees];
        });
}

static id LilyCreateRomoToolWithProperties(NSString *name,
                                              NSString *description,
                                              NSArray *properties,
                                              id (^callback)(id)) {
    Class toolClass = NSClassFromString(@"SharedMcpTool");
    if (!toolClass) {
        LilyMCPWrite(@"MCP-ROMO #73 TOOL: SharedMcpTool NOT FOUND");
        return nil;
    }

    SEL initSel = NSSelectorFromString(
        @"initWithName:description:properties:userOnly:callback:");

    if (![toolClass instancesRespondToSelector:initSel]) {
        LilyMCPWrite(@"MCP-ROMO #73 TOOL: initializer NOT FOUND");
        return nil;
    }

    /*
     * Use the same verified SharedMcpTool initializer ABI as the
     * already-working robot.forward tool:
     *
     * self, _cmd, name, description, properties, userOnly, callback
     */
    typedef id (*ToolInitFn)(id, SEL, id, id, id, BOOL, id);
    ToolInitFn initFn = (ToolInitFn)objc_msgSend;

    id tool = initFn([toolClass alloc],
                     initSel,
                     name,
                     description,
                     properties ?: @[],
                     NO,
                     callback);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 TOOL: %@ %@", name,
        tool ? @"CREATED" : @"FAILED"]);
    return tool;
}

static id LilyCreateSimpleRomoTool(NSString *name,
                                   NSString *description,
                                   id (^callback)(id)) {
    return LilyCreateRomoToolWithProperties(name, description, @[], callback);
}

typedef void (*LilyMcpRegisterToolsFn)(void *server);

/* BUILD #52: addTool is completely untouched at the native code level.
   Injection uses the normal ObjC-visible selector and therefore reaches the
   original SharedMcpServer implementation. */
static uintptr_t LilyFindSharedImageSlide(void);

typedef void (*LilyMcpAddToolFn)(void *server, void *tool);

/*
 * Shared_toKotlin: ABI verified from the Lily Shared framework.
 *
 * type encoding:
 *
 *     ^{ObjHeader=^{TypeInfo}}24@0:8^^{ObjHeader}16
 *
 * Therefore:
 *
 *     x0 = Objective-C wrapper
 *     x1 = selector
 *     x2 = ObjHeader **
 *
 * return:
 *
 *     x0 = ObjHeader *
 *
 * The implementation was verified statically at:
 *
 *     Shared + 0x32D06F0
 *
 * IMPORTANT:
 *
 * SharedMcpTool is NOT itself the native Kotlin McpTool pointer.
 * We must convert it through Shared_toKotlin: before calling
 * McpServer#addTool.
 */
typedef void *(*LilySharedToKotlinFn)(id self, SEL _cmd, void **outNative);

static void *LilySharedMcpToolToKotlin(id tool) {
    if (!tool) {
        LilyMCPWrite(@"MCP-ROMO TOKOTLIN: tool=NULL");
        return NULL;
    }

    SEL toKotlinSel = sel_registerName("Shared_toKotlin:");

    if (![tool respondsToSelector:toKotlinSel]) {
        LilyMCPWrite(@"MCP-ROMO TOKOTLIN: Shared_toKotlin: NOT FOUND");
        return NULL;
    }

    Class cls = object_getClass(tool);

    IMP imp = class_getMethodImplementation(cls, toKotlinSel);

    if (!imp) {
        LilyMCPWrite(@"MCP-ROMO TOKOTLIN: IMP NOT FOUND");
        return NULL;
    }

    LilySharedToKotlinFn fn =
        (LilySharedToKotlinFn)imp;

    void *outNative = NULL;

    void *returnNative =
        fn(tool, toKotlinSel, &outNative);

    /*
     * Verified implementation writes the native pointer through x2
     * and also returns a native pointer.
     *
     * Prefer the explicit out parameter when present.
     */
    void *nativeTool =
        outNative ? outNative : returnNative;

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO TOKOTLIN: objc=%p native=%p return=%p out=%p",
        tool,
        nativeTool,
        returnNative,
        outNative]);

    return nativeTool;
}

/* BUILD #70: real Kotlin/Native call to McpServer#addTool.
   Verified ABI: x0 = McpServer*, x1 = McpTool*.
   Verified symbol: Shared + 0x126CC88. */
static void LilyAddRomoToolNative(void *server, id objcTool) {
    if (!server || !objcTool) {
        LilyMCPWrite(@"MCP-ROMO #73 ADDTOOL: missing server/objcTool");
        return;
    }

    /*
     * objcTool is SharedMcpTool.
     *
     * DO NOT pass:
     *
     *     (__bridge void *)objcTool
     *
     * directly to Kotlin/Native.
     *
     * McpServer#addTool expects:
     *
     *     McpTool *
     *
     * Convert the Objective-C wrapper to its underlying Kotlin object.
     */
    void *nativeTool = LilySharedMcpToolToKotlin(objcTool);

    if (!nativeTool) {
        LilyMCPWrite(@"MCP-ROMO #73 ADDTOOL: Shared_toKotlin returned NULL");
        return;
    }

    /*
     * Keep the Objective-C wrapper alive.
     *
     * The wrapper owns/bridges the callback used by the MCP tool.
     */
    LilyRetainRomoToolWrapper(objcTool);

    uintptr_t slide = LilyFindSharedImageSlide();

    if (!slide) {
        LilyMCPWrite(@"MCP-ROMO #73 ADDTOOL: Shared.framework slide NOT FOUND");
        return;
    }

    uintptr_t target = slide + 0x126CC88;

    pthread_t tid = pthread_self();
    int isMain = pthread_main_np();

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 ADDTOOL NATIVE ENTER server=%p objcTool=%p nativeTool=%p target=0x%llx pthread=%p main=%d",
        server,
        objcTool,
        nativeTool,
        (unsigned long long)target,
        (void *)tid,
        isMain]);

    /*
     * Raw dump of the REAL Kotlin McpTool.
     *
     * Verified layout:
     *
     * +0x00 typeinfo
     * +0x08 name
     * +0x10 description
     * +0x18 properties
     * +0x20 callback
     * +0x28 userOnly
     *
     * We intentionally do NOT dereference the fields beyond reading
     * their pointer values.
     */
    uintptr_t t = (uintptr_t)nativeTool;

    uintptr_t v00 = *(uintptr_t *)(t + 0x00);
    uintptr_t v08 = *(uintptr_t *)(t + 0x08);
    uintptr_t v10 = *(uintptr_t *)(t + 0x10);
    uintptr_t v18 = *(uintptr_t *)(t + 0x18);
    uintptr_t v20 = *(uintptr_t *)(t + 0x20);
    uintptr_t v28 = *(uintptr_t *)(t + 0x28);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 NATIVE TOOL native=%p +00=0x%llx +08=0x%llx +10=0x%llx +18=0x%llx +20=0x%llx +28=0x%llx",
        nativeTool,
        (unsigned long long)v00,
        (unsigned long long)v08,
        (unsigned long long)v10,
        (unsigned long long)v18,
        (unsigned long long)v20,
        (unsigned long long)v28]);

    LilyMCPWrite(@"MCP-ROMO #73 CALL ADDTOOL BEGIN");

    /*
     * CRITICAL:
     *
     * x0 = McpServer *
     * x1 = Kotlin/Native McpTool *
     *
     * NOT the Objective-C SharedMcpTool wrapper.
     */
    ((LilyMcpAddToolFn)target)(server, nativeTool);

    LilyMCPWrite(@"MCP-ROMO #73 CALL ADDTOOL RETURNED");

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 ADDTOOL NATIVE RETURN server=%p objcTool=%p nativeTool=%p",
        server,
        objcTool,
        nativeTool]);
}
static void LilyDumpToolRaw73(id tool, const char *tag) {
    if (!tool) return;

    uintptr_t t = (uintptr_t)tool;
    uintptr_t v00 = *(uintptr_t *)(t + 0x00);
    uintptr_t v08 = *(uintptr_t *)(t + 0x08);
    uintptr_t v10 = *(uintptr_t *)(t + 0x10);
    uintptr_t v18 = *(uintptr_t *)(t + 0x18);
    uintptr_t v20 = *(uintptr_t *)(t + 0x20);
    uintptr_t v28 = *(uintptr_t *)(t + 0x28);
    uintptr_t v30 = *(uintptr_t *)(t + 0x30);
    uintptr_t v38 = *(uintptr_t *)(t + 0x38);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 %s RAW tool=%p +00=0x%llx +08=0x%llx +10=0x%llx +18=0x%llx",
        tag, tool,
        (unsigned long long)v00, (unsigned long long)v08,
        (unsigned long long)v10, (unsigned long long)v18]);
    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 %s RAW tool=%p +20=0x%llx +28=0x%llx +30=0x%llx +38=0x%llx",
        tag, tool,
        (unsigned long long)v20, (unsigned long long)v28,
        (unsigned long long)v30, (unsigned long long)v38]);
}

/* BUILD #74 â€” MERGED STATUS + ROMO CONTROLS */

static id LilyCreateStatusRomoTool(void) {
    return LilyCreateSimpleRomoTool(
        @"robot.status",
        @"Read the physical Romo robot status, including connection, battery percentage, and charging state.",
        ^id(id args) {
            (void)args;
            NSString *status = [[LilyRomoController sharedController] statusText];
            LilyMCPWrite([NSString stringWithFormat:@"MCP-ROMO #74 STATUS CALLBACK: %@", status]);
            return status;
        });
}

static void LilyInjectRobotToolsIntoServer(void *server) {
    if (!server) return;

    if (gLilyRomoInjectedServer == server) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #74 INJECT: already injected server=%p", server]);
        return;
    }

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #74 INJECT ENTER live McpServer=%p", server]);

    id statusTool = LilyCreateStatusRomoTool();

    id forwardTool = LilyCreateSimpleRomoTool(
        @"robot.forward",
        @"Move the physical Romo robot connected to Lily forward. Use this when the user asks Romo to move forward, go forward, drive forward, or tien len.",
        ^id(id args) {
            (void)args;
            LilyRomoForwardNoArgs();
            return @"Romo moved forward";
        });

    id backwardTool = LilyCreateSimpleRomoTool(
        @"robot.backward",
        @"Move the physical Romo robot connected to Lily backward. Use this when the user asks Romo to move backward, reverse, or lui lai.",
        ^id(id args) {
            (void)args;
            LilyRomoBackwardNoArgs();
            return @"Romo moved backward";
        });

    id stopTool = LilyCreateSimpleRomoTool(
        @"robot.stop",
        @"Stop the physical Romo robot connected to Lily immediately.",
        ^id(id args) {
            (void)args;
            LilyRomoStopNoArgs();
            return @"Romo stopped";
        });

    id leftTool = LilyCreateSimpleRomoTool(
        @"robot.turn_left",
        @"Turn the physical Romo robot left in place. Use this when the user asks Romo to turn left, go left, or quay trai.",
        ^id(id args) {
            (void)args;
            [[LilyRomoController sharedController] turnLeft];
            return @"Romo turned left";
        });

    id rightTool = LilyCreateSimpleRomoTool(
        @"robot.turn_right",
        @"Turn the physical Romo robot right in place. Use this when the user asks Romo to turn right, go right, or quay phai.",
        ^id(id args) {
            (void)args;
            [[LilyRomoController sharedController] turnRight];
            return @"Romo turned right";
        });

    id headUpTool = LilyCreateHeadUpRomoTool();
    id headDownTool = LilyCreateHeadDownRomoTool();
    id headToTool = LilyCreateHeadToRomoTool();

    id turnAngleTool = LilyCreateTurnAngleRomoTool();

    if (statusTool)   LilyDumpToolRaw73(statusTool, "STATUS BEFORE");
    if (forwardTool)  LilyDumpToolRaw73(forwardTool, "FORWARD BEFORE");
    if (backwardTool) LilyDumpToolRaw73(backwardTool, "BACKWARD BEFORE");
    if (stopTool)     LilyDumpToolRaw73(stopTool, "STOP BEFORE");
    if (leftTool)     LilyDumpToolRaw73(leftTool, "LEFT BEFORE");
    if (rightTool)    LilyDumpToolRaw73(rightTool, "RIGHT BEFORE");
    if (headUpTool)   LilyDumpToolRaw73(headUpTool, "HEAD UP BEFORE");
    if (headDownTool) LilyDumpToolRaw73(headDownTool, "HEAD DOWN BEFORE");
    if (headToTool)   LilyDumpToolRaw73(headToTool, "HEAD TO BEFORE");

    if (turnAngleTool) LilyDumpToolRaw73(turnAngleTool, "TURN ANGLE BEFORE");

    if (statusTool) {
        LilyAddRomoToolNative(server, statusTool);
        LilyDumpToolRaw73(statusTool, "STATUS AFTER");
    }
    if (forwardTool) {
        LilyAddRomoToolNative(server, forwardTool);
        LilyDumpToolRaw73(forwardTool, "FORWARD AFTER");
    }
    if (backwardTool) {
        LilyAddRomoToolNative(server, backwardTool);
        LilyDumpToolRaw73(backwardTool, "BACKWARD AFTER");
    }
    if (stopTool) {
        LilyAddRomoToolNative(server, stopTool);
        LilyDumpToolRaw73(stopTool, "STOP AFTER");
    }
    if (leftTool) {
        LilyAddRomoToolNative(server, leftTool);
        LilyDumpToolRaw73(leftTool, "LEFT AFTER");
    }
    if (rightTool) {
        LilyAddRomoToolNative(server, rightTool);
        LilyDumpToolRaw73(rightTool, "RIGHT AFTER");
    }
    if (headUpTool) {
        LilyAddRomoToolNative(server, headUpTool);
        LilyDumpToolRaw73(headUpTool, "HEAD UP AFTER");
    }
    if (headDownTool) {
        LilyAddRomoToolNative(server, headDownTool);
        LilyDumpToolRaw73(headDownTool, "HEAD DOWN AFTER");
    }
        if (headToTool) {
        LilyAddRomoToolNative(server, headToTool);
        LilyDumpToolRaw73(headToTool, "HEAD TO AFTER");
    }

if (turnAngleTool) {
        LilyAddRomoToolNative(server, turnAngleTool);
        LilyDumpToolRaw73(turnAngleTool, "TURN ANGLE AFTER");
    }

    gLilyRomoInjectedServer = server;

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #74 INJECT RETURNED server=%p; tools=status,forward,backward,stop,turn_left,turn_right,head_up,head_down,turn_angle",
        server]);
}

static BOOL LilyProtectCodePage(void *address, BOOL writable) {
    vm_address_t page = (vm_address_t)address & ~(vm_address_t)(vm_page_size - 1);
    vm_prot_t prot = writable
        ? (VM_PROT_READ | VM_PROT_WRITE)
        : (VM_PROT_READ | VM_PROT_EXECUTE);

    kern_return_t kr = vm_protect(mach_task_self(), page, vm_page_size,
                                  FALSE, prot);
    if (kr != KERN_SUCCESS) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 PATCH: vm_protect failed kr=%d", kr]);
        return NO;
    }
    return YES;
}

static uintptr_t LilyFindSharedImageSlide(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, @"Shared.framework/Shared".UTF8String)) {
            return (uintptr_t)_dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

static BOOL LilyWriteBranch(void *address, uintptr_t destination) {
    uintptr_t source = (uintptr_t)address;
    int64_t delta = (int64_t)destination - (int64_t)source;

    if ((delta & 0x3) != 0 || delta < -(128LL * 1024 * 1024) ||
        delta >= (128LL * 1024 * 1024)) {
        LilyMCPWrite(@"MCP-ROMO #73 PATCH: hook outside AArch64 B range");
        return NO;
    }

    int64_t imm26 = delta >> 2;
    uint32_t instruction = 0x14000000u |
        ((uint32_t)imm26 & 0x03ffffffu);

    if (!LilyProtectCodePage(address, YES)) return NO;
    memcpy(address, &instruction, sizeof(instruction));
    sys_icache_invalidate(address, sizeof(instruction));
    return LilyProtectCodePage(address, NO);
}

static BOOL LilyAllocateRegisterToolsTrampoline(uintptr_t target) {
    if (gLilyNativeRegisterToolsTrampoline) return YES;

    vm_address_t page = 0;
    kern_return_t kr = vm_allocate(mach_task_self(), &page, vm_page_size,
                                   VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 PATCH: vm_allocate trampoline failed kr=%d", kr]);
        return NO;
    }

    kr = vm_protect(mach_task_self(), page, vm_page_size, FALSE,
                    VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        vm_deallocate(mach_task_self(), page, vm_page_size);
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 PATCH: trampoline RW protect failed kr=%d", kr]);
        return NO;
    }

    memcpy((void *)page, (void *)target,
           sizeof(gLilyOriginalRegisterToolsBytes));

    uint8_t *jumpAt = (uint8_t *)page + sizeof(gLilyOriginalRegisterToolsBytes);
    uint32_t jump[2] = { 0x58000050, 0xD61F0200 }; /* ldr x16,#8; br x16 */
    uint64_t continuation = (uint64_t)(target +
                                       sizeof(gLilyOriginalRegisterToolsBytes));
    memcpy(jumpAt, jump, sizeof(jump));
    memcpy(jumpAt + 8, &continuation, sizeof(continuation));
    sys_icache_invalidate((void *)page, 32);

    kr = vm_protect(mach_task_self(), page, vm_page_size, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        vm_deallocate(mach_task_self(), page, vm_page_size);
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 PATCH: trampoline RX protect failed kr=%d", kr]);
        return NO;
    }

    gLilyNativeRegisterToolsTrampoline = (uintptr_t)page;
    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 PATCH: registerTools trampoline=%p continue=0x%llx",
        (void *)page,
        (unsigned long long)(target + sizeof(gLilyOriginalRegisterToolsBytes))]);
    return YES;
}

static void LilyNativeRegisterToolsHook(void *server);

static BOOL LilyPatchNativeRegisterTools(void) {
    pthread_mutex_lock(&gLilyNativeHookLock);

    if (gLilyNativeRegisterToolsPatchInstalled) {
        pthread_mutex_unlock(&gLilyNativeHookLock);
        return YES;
    }

    uintptr_t slide = LilyFindSharedImageSlide();
    if (!slide) {
        LilyMCPWrite(@"MCP-ROMO #73 PATCH: Shared.framework slide NOT FOUND");
        pthread_mutex_unlock(&gLilyNativeHookLock);
        return NO;
    }

    /* BUILD #52: patch ONLY McpServer#registerTools.
       McpServer#addTool at +0x126CC88 is deliberately never patched. */
    uintptr_t registerTarget = slide + 0x126B040;

    memcpy(gLilyOriginalRegisterToolsBytes, (void *)registerTarget, 16);

    const uint8_t expected[16] = {
        0xe9, 0x23, 0xb9, 0x6d,
        0xfc, 0x6f, 0x01, 0xa9,
        0xfa, 0x67, 0x02, 0xa9,
        0xf8, 0x5f, 0x03, 0xa9
    };

    if (memcmp(gLilyOriginalRegisterToolsBytes, expected, 16) != 0) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 PATCH: registerTools prologue mismatch @ 0x%llx",
            (unsigned long long)registerTarget]);
        pthread_mutex_unlock(&gLilyNativeHookLock);
        return NO;
    }

    if (!LilyAllocateRegisterToolsTrampoline(registerTarget)) {
        pthread_mutex_unlock(&gLilyNativeHookLock);
        return NO;
    }

    if (!LilyWriteBranch((void *)registerTarget,
                         (uintptr_t)&LilyNativeRegisterToolsHook)) {
        vm_deallocate(mach_task_self(),
                      (vm_address_t)gLilyNativeRegisterToolsTrampoline,
                      vm_page_size);
        gLilyNativeRegisterToolsTrampoline = 0;
        pthread_mutex_unlock(&gLilyNativeHookLock);
        return NO;
    }

    gLilyNativeRegisterToolsAddress = registerTarget;
    gLilyNativeRegisterToolsPatchInstalled = YES;

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 PATCH ENABLED: registerTools ONLY @ 0x%llx; addTool UNTOUCHED -> %p",
        (unsigned long long)registerTarget,
        (void *)&LilyNativeRegisterToolsHook]);

    pthread_mutex_unlock(&gLilyNativeHookLock);
    return YES;
}

static void LilyNativeRegisterToolsHook(void *server) {
    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 REGISTER ENTER server=%p", server]);

    uintptr_t trampoline = gLilyNativeRegisterToolsTrampoline;
    if (!trampoline) {
        LilyMCPWrite(@"MCP-ROMO #73 ERROR: registerTools trampoline NULL");
        return;
    }

    /* FIRST: let Lily complete every built-in/custom registration normally. */
    ((LilyMcpRegisterToolsFn)trampoline)(server);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 REGISTER RETURN server=%p", server]);

    /* BUILD #73: SAME-THREAD POST-RETURN experiment.
       Do NOT dispatch to main/global queue. We call addTool only after the
       original registerTools() has returned, but on the exact same thread
       and native call context that entered this hook.

       This is intentionally different from BUILD #47: #47 injected while
       already executing inside addTool(). Here registerTools() has fully
       returned first. We also do NOT bridge/capture McpServer as an
       Objective-C id; the native addTool ABI takes the underlying Kotlin McpTool pointer returned by Shared_toKotlin:. */
    if (server) {
        pthread_t tid = pthread_self();
        int isMain = pthread_main_np();
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 SAME-THREAD BEFORE INJECT server=%p pthread=%p main=%d",
            server, (void *)tid, isMain]);

        LilyInjectRobotToolsIntoServer(server);

        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 SAME-THREAD AFTER INJECT server=%p pthread=%p main=%d",
            server, (void *)tid, isMain]);
    }

    LilyMCPWrite(@"MCP-ROMO #73 REGISTER HOOK DONE (same-thread post-return injection)");
}

static void LilyInstallMCPRomoHook(void) {
    gLilyMCPHookInstalled = LilyPatchNativeRegisterTools();
    LilyMCPWrite(gLilyMCPHookInstalled
        ? @"MCP-ROMO PATCH: ENABLED FOR BUILD #73 (native registerTools post-return)"
        : @"MCP-ROMO PATCH: FAILED FOR BUILD #50");
}

@implementation LilySharedBridge

+ (BOOL)initializeSharedWithAPIKey:(NSString *)apiKey wsURL:(NSString *)wsURL otaURL:(NSString *)otaURL {
    Class cls = NSClassFromString(@"SharedIosModuleKt");
    if (!cls) return NO;

    SEL sel = NSSelectorFromString(@"doInitKoinApiEncryptionKey:wsUrl:otaUrl:");
    if (![cls respondsToSelector:sel]) return NO;

    LilyInstallMCPRomoHook();

    typedef void (*InitFn)(id, SEL, NSString *, NSString *, NSString *);
    InitFn fn = (InitFn)objc_msgSend;
    fn(cls, sel, apiKey, wsURL, otaURL);

    NSLog(@"[Lily] Shared Koin initialization invoked");

    /*
     * BUILD #44 DIAGNOSTIC:
     * Keep Koin initialization, Romo startup, and MCP reflection dumps ON.
     * Native addTool patch is enabled, but the hook only logs and returns.
     */
    [[LilyRomoController sharedController] start];

    LilyDumpMethods(@"SharedMcpServer");
    LilyDumpMethods(@"SharedMcpServerCompanion");
    LilyDumpMethods(@"SharedMcpTool");
    LilyDumpMethods(@"SharedMcpToolInfo");
    LilyDumpMethods(@"SharedMcpToolRegistry");
    LilyDumpMethods(@"SharedSkillToolFactory");
    return YES;
}

+ (UIViewController *)mainViewController {
    Class cls = NSClassFromString(@"SharedAppKt");
    if (!cls) return nil;

    SEL sel = NSSelectorFromString(@"MainViewController");
    if (![cls respondsToSelector:sel]) return nil;

    typedef UIViewController *(*MainFn)(id, SEL);
    MainFn fn = (MainFn)objc_msgSend;
    return fn(cls, sel);
}

@end



