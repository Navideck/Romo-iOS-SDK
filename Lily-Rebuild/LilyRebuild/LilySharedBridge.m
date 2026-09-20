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


/*
 * Distance control follows the verified RMActionRunner algorithm:
 *
 *   topSpeedMetersPerSecond = 0.67
 *   speed = 0.5
 *
 * The requested distance is in centimeters.
 * The same normalization/timing formula used by RMActionRunner is applied,
 * then the robot is stopped automatically after the calculated duration.
 */
- (void)forwardDistanceCm:(float)distanceCm {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] FORWARD_DISTANCE ignored: no robot");
        return;
    }

    if (!(distanceCm > 0.0f)) {
        NSLog(@"[Lily][Romo] FORWARD_DISTANCE ignored: invalid distance=%f", distanceCm);
        return;
    }

    const float speed = 0.5f;
    const float topSpeedMetersPerSecond = 0.67f;

    float normalizeForSpeed =
        (powf(0.06f * ((100.0f * speed) - 50.0f), 3.0f) + 85.0f) / 112.0f;

    float distanceInMeters = (distanceCm / 100.0f) * normalizeForSpeed;
    float metersPerSecondAtSpeed = topSpeedMetersPerSecond * speed;
    float secondsAtSpeed = distanceInMeters / metersPerSecondAtSpeed;

    if (!(secondsAtSpeed > 0.0f) || !isfinite(secondsAtSpeed)) {
        NSLog(@"[Lily][Romo] FORWARD_DISTANCE invalid duration=%f", secondsAtSpeed);
        return;
    }

    [romo driveForwardWithSpeed:speed];

    NSLog(@"[Lily][Romo] FORWARD_DISTANCE %.2f cm -> %.3f sec",
          distanceCm, secondsAtSpeed);

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(secondsAtSpeed * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            RMCoreRobot<DriveProtocol> *r =
                (RMCoreRobot<DriveProtocol> *)self.robot;
            if (r) {
                [r stopDriving];
            }
            NSLog(@"[Lily][Romo] FORWARD_DISTANCE %.2f cm -> STOP",
                  distanceCm);
        });
}

- (void)backwardDistanceCm:(float)distanceCm {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] BACKWARD_DISTANCE ignored: no robot");
        return;
    }

    if (!(distanceCm > 0.0f)) {
        NSLog(@"[Lily][Romo] BACKWARD_DISTANCE ignored: invalid distance=%f", distanceCm);
        return;
    }

    const float speed = 0.5f;
    const float topSpeedMetersPerSecond = 0.67f;

    float normalizeForSpeed =
        (powf(0.06f * ((100.0f * speed) - 50.0f), 3.0f) + 85.0f) / 112.0f;

    float distanceInMeters = (distanceCm / 100.0f) * normalizeForSpeed;
    float metersPerSecondAtSpeed = topSpeedMetersPerSecond * speed;
    float secondsAtSpeed = distanceInMeters / metersPerSecondAtSpeed;

    if (!(secondsAtSpeed > 0.0f) || !isfinite(secondsAtSpeed)) {
        NSLog(@"[Lily][Romo] BACKWARD_DISTANCE invalid duration=%f", secondsAtSpeed);
        return;
    }

    [romo driveBackwardWithSpeed:speed];

    NSLog(@"[Lily][Romo] BACKWARD_DISTANCE %.2f cm -> %.3f sec",
          distanceCm, secondsAtSpeed);

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(secondsAtSpeed * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            RMCoreRobot<DriveProtocol> *r =
                (RMCoreRobot<DriveProtocol> *)self.robot;
            if (r) {
                [r stopDriving];
            }
            NSLog(@"[Lily][Romo] BACKWARD_DISTANCE %.2f cm -> STOP",
                  distanceCm);
        });
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
   Native Lily MCP -> Romo bridge — BUILD #73

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


/*
 * SharedMcpProperty is exported by Kotlin/Native.
 *
 * Verified constructor encoding:
 *   initWithName:type:min:max:value:hasDefault:
 *   @57@0:8@16@24@32@40@48c56
 *
 * Verified enum metadata contains:
 *   SharedMcpProperty
 *   string
 *   integer
 *   boolean
 *
 * We resolve the enum value dynamically so this bridge does not depend on
 * generated Swift/ObjC enum symbol spelling.
 */
static id LilyMcpIntegerPropertyType(void) {
    Class typeClass = NSClassFromString(@"SharedMcpPropertyType");
    if (!typeClass) {
        LilyMCPWrite(@"MCP-ROMO DISTANCE: SharedMcpPropertyType NOT FOUND");
        return nil;
    }

    SEL sel = NSSelectorFromString(@"integer");
    if (![typeClass respondsToSelector:sel]) {
        LilyMCPWrite(@"MCP-ROMO DISTANCE: SharedMcpPropertyType.integer NOT FOUND");
        return nil;
    }

    typedef id (*EnumGetterFn)(id, SEL);
    return ((EnumGetterFn)objc_msgSend)(typeClass, sel);
}

static id LilyCreateDistanceProperty(NSString *name) {
    Class propertyClass = NSClassFromString(@"SharedMcpProperty");
    if (!propertyClass) {
        LilyMCPWrite(@"MCP-ROMO DISTANCE: SharedMcpProperty NOT FOUND");
        return nil;
    }

    SEL initSel =
        NSSelectorFromString(@"initWithName:type:min:max:value:hasDefault:");

    if (![propertyClass instancesRespondToSelector:initSel]) {
        LilyMCPWrite(@"MCP-ROMO DISTANCE: property initializer NOT FOUND");
        return nil;
    }

    id type = LilyMcpIntegerPropertyType();
    if (!type) return nil;

    typedef id (*PropertyInitFn)(id, SEL, id, id, id, id, BOOL);
    PropertyInitFn initFn = (PropertyInitFn)objc_msgSend;

    id property =
        initFn([propertyClass alloc],
               initSel,
               name,
               type,
               @1,
               @500,
               @1,
               YES);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO DISTANCE PROPERTY: %@ %@",
        name,
        property ? @"CREATED" : @"FAILED"]);

    return property;
}

static id LilyCreateDistanceRomoTool(NSString *name,
                                     NSString *description,
                                     id (^callback)(id)) {
    id property = LilyCreateDistanceProperty(@"distance_cm");
    if (!property) {
        return nil;
    }

    NSArray *properties = @[property];

    Class toolClass = NSClassFromString(@"SharedMcpTool");
    if (!toolClass) {
        LilyMCPWrite(@"MCP-ROMO DISTANCE: SharedMcpTool NOT FOUND");
        return nil;
    }

    SEL initSel =
        NSSelectorFromString(@"initWithName:description:properties:userOnly:callback:");

    if (![toolClass instancesRespondToSelector:initSel]) {
        LilyMCPWrite(@"MCP-ROMO DISTANCE: tool initializer NOT FOUND");
        return nil;
    }

    typedef id (*ToolInitFn)(id, SEL, id, id, id, BOOL, id);
    ToolInitFn initFn = (ToolInitFn)objc_msgSend;

    id tool =
        initFn([toolClass alloc],
               initSel,
               name,
               description,
               properties,
               NO,
               callback);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO DISTANCE TOOL: %@ %@",
        name,
        tool ? @"CREATED" : @"FAILED"]);

    return tool;
}

static float LilyDistanceArgumentCm(id args) {
    if (![args isKindOfClass:[NSDictionary class]]) {
        LilyMCPWrite(@"MCP-ROMO DISTANCE CALLBACK: args is not NSDictionary");
        return 0.0f;
    }

    id value = [(NSDictionary *)args objectForKey:@"distance_cm"];

    if ([value respondsToSelector:@selector(floatValue)]) {
        return [value floatValue];
    }

    /* Accept the common alternate spelling too, without changing the schema. */
    value = [(NSDictionary *)args objectForKey:@"distance"];
    if ([value respondsToSelector:@selector(floatValue)]) {
        return [value floatValue];
    }

    return 0.0f;
}

static id LilyRomoForwardDistanceCallback(id args) {
    float distanceCm = LilyDistanceArgumentCm(args);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO DISTANCE CALLBACK: forward distance_cm=%.2f",
        distanceCm]);

    if (distanceCm <= 0.0f) {
        return @"Invalid distance_cm";
    }

    [[LilyRomoController sharedController] forwardDistanceCm:distanceCm];

    return [NSString stringWithFormat:
        @"Romo moved forward %.2f cm", distanceCm];
}

static id LilyRomoBackwardDistanceCallback(id args) {
    float distanceCm = LilyDistanceArgumentCm(args);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO DISTANCE CALLBACK: backward distance_cm=%.2f",
        distanceCm]);

    if (distanceCm <= 0.0f) {
        return @"Invalid distance_cm";
    }

    [[LilyRomoController sharedController] backwardDistanceCm:distanceCm];

    return [NSString stringWithFormat:
        @"Romo moved backward %.2f cm", distanceCm];
}

static id LilyCreateSimpleRomoTool(NSString *name,
                                   NSString *description,
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

    typedef id (*ToolInitFn)(id, SEL, id, id, id, BOOL, id);
    ToolInitFn initFn = (ToolInitFn)objc_msgSend;

    id tool = initFn([toolClass alloc],
                     initSel,
                     name,
                     description,
                     @[],
                     NO,
                     callback);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 TOOL: %@ %@", name,
        tool ? @"CREATED" : @"FAILED"]);
    return tool;
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

/*
 * BUILD #73 — isolation experiment.
 *
 * MODE selects exactly what is inserted after registerTools returns:
 *   1 = forward only
 *   2 = backward only
 *   3 = forward then backward
 *   4 = backward then forward
 *   5 = forward, backward, stop (original #70 sequence)
 *
 * Change this one constant and rebuild for each experiment.
 */
#ifndef LILY73_MODE
#define LILY73_MODE 1
#endif

static void LilyInjectRobotToolsIntoServer(void *server) {
    if (!server) return;

    if (gLilyRomoInjectedServer == server) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO #73 INJECT: already injected server=%p", server]);
        return;
    }

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 INJECT ENTER live McpServer=%p MODE=%d", server, LILY73_MODE]);

    id forwardTool = nil;
    id backwardTool = nil;
    id stopTool = nil;

#if LILY73_MODE == 1 || LILY73_MODE == 3 || LILY73_MODE == 4 || LILY73_MODE == 5
    forwardTool = LilyCreateSimpleRomoTool(
        @"robot.forward",
        @"Move the physical Romo robot connected to Lily forward. Use this when the user asks Romo to move forward, go forward, drive forward, or tien len.",
        ^id(id args) {
            (void)args;
            LilyRomoForwardNoArgs();
            return @"Romo moved forward";
        });
#endif

#if LILY73_MODE == 2 || LILY73_MODE == 3 || LILY73_MODE == 4 || LILY73_MODE == 5
    backwardTool = LilyCreateSimpleRomoTool(
        @"robot.backward",
        @"Move the physical Romo robot connected to Lily backward. Use this when the user asks Romo to move backward, reverse, or lui lai.",
        ^id(id args) {
            (void)args;
            LilyRomoBackwardNoArgs();
            return @"Romo moved backward";
        });
#endif

#if LILY73_MODE == 5
    stopTool = LilyCreateSimpleRomoTool(
        @"robot.stop",
        @"Stop the physical Romo robot connected to Lily immediately.",
        ^id(id args) {
            (void)args;
            LilyRomoStopNoArgs();
            return @"Romo stopped";
        });
#endif

    /* Dump before any native insertion. */
    if (forwardTool)  LilyDumpToolRaw73(forwardTool,  "FORWARD BEFORE");
    if (backwardTool) LilyDumpToolRaw73(backwardTool, "BACKWARD BEFORE");
    if (stopTool)     LilyDumpToolRaw73(stopTool,     "STOP BEFORE");

#if LILY73_MODE == 1
    if (forwardTool) {
        LilyAddRomoToolNative(server, forwardTool);
        LilyDumpToolRaw73(forwardTool, "FORWARD AFTER");
    }
#elif LILY73_MODE == 2
    if (backwardTool) {
        LilyAddRomoToolNative(server, backwardTool);
        LilyDumpToolRaw73(backwardTool, "BACKWARD AFTER");
    }
#elif LILY73_MODE == 3
    if (forwardTool) {
        LilyAddRomoToolNative(server, forwardTool);
        LilyDumpToolRaw73(forwardTool, "FORWARD AFTER");
    }
    if (backwardTool) {
        LilyAddRomoToolNative(server, backwardTool);
        LilyDumpToolRaw73(backwardTool, "BACKWARD AFTER");
    }
#elif LILY73_MODE == 4
    if (backwardTool) {
        LilyAddRomoToolNative(server, backwardTool);
        LilyDumpToolRaw73(backwardTool, "BACKWARD AFTER");
    }
    if (forwardTool) {
        LilyAddRomoToolNative(server, forwardTool);
        LilyDumpToolRaw73(forwardTool, "FORWARD AFTER");
    }
#elif LILY73_MODE == 5
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
#endif


    /*
     * Parameterized Romo distance tools.
     *
     * These are intentionally added after the proven no-argument forward tool.
     * The schema exposes distance_cm as an integer, so Lily can produce:
     *
     *     robot.forward_distance({ "distance_cm": 20 })
     *
     * instead of treating "20 cm" as plain text.
     */
    id forwardDistanceTool = LilyCreateDistanceRomoTool(
        @"robot.forward_distance",
        @"Move the physical Romo robot forward by the requested distance in centimeters. The argument distance_cm is a number of centimeters. Example: 20 means exactly 20 cm.",
        ^id(id args) {
            return LilyRomoForwardDistanceCallback(args);
        });

    id backwardDistanceTool = LilyCreateDistanceRomoTool(
        @"robot.backward_distance",
        @"Move the physical Romo robot backward by the requested distance in centimeters. The argument distance_cm is a number of centimeters. Example: 30 means exactly 30 cm.",
        ^id(id args) {
            return LilyRomoBackwardDistanceCallback(args);
        });

    if (forwardDistanceTool) {
        LilyDumpToolRaw73(forwardDistanceTool, "FORWARD_DISTANCE BEFORE");
        LilyAddRomoToolNative(server, forwardDistanceTool);
        LilyDumpToolRaw73(forwardDistanceTool, "FORWARD_DISTANCE AFTER");
    }

    if (backwardDistanceTool) {
        LilyDumpToolRaw73(backwardDistanceTool, "BACKWARD_DISTANCE BEFORE");
        LilyAddRomoToolNative(server, backwardDistanceTool);
        LilyDumpToolRaw73(backwardDistanceTool, "BACKWARD_DISTANCE AFTER");
    }

    /* Mark only after every selected native addTool call has returned. */
    gLilyRomoInjectedServer = server;
    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO #73 INJECT RETURNED server=%p MODE=%d", server, LILY73_MODE]);
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


