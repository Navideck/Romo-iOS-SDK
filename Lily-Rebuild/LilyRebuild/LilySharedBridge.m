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

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    NSString *countLine =
        [NSString stringWithFormat:@"INSTANCE METHOD COUNT = %u", count];

    NSLog(@"[Lily][MCP-DUMP] %@", countLine);
    LilyMCPWrite(countLine);

    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);

        NSString *selector = NSStringFromSelector(sel);

        NSString *line =
            [NSString stringWithFormat:@"INSTANCE %@ types=%s",
                                       selector,
                                       types ? types : ""];

        NSLog(@"[Lily][MCP-DUMP] %@", line);
        LilyMCPWrite(line);
    }

    free(methods);

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

        NSString *selector = NSStringFromSelector(sel);

        NSString *line =
            [NSString stringWithFormat:@"CLASS %@ types=%s",
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
    dispatch_once(&onceToken, ^{
        controller = [[LilyRomoController alloc] init];
    });
    return controller;
}

- (void)start {
    if (self.running) return;

    [RMCore allowBackground:YES];
    [RMCore setDelegate:self];

    for (RMCoreRobot *robot in [RMCore connectedRobots]) {
        if (robot.isDrivable) {
            self.robot = robot;
            break;
        }
    }

    self.running = YES;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self serverLoop];
    });

    NSLog(@"[Lily][Romo] controller started on 127.0.0.1:%d",
          kLilyRomoHTTPPort);
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
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] FORWARD ignored: no robot");
        return;
    }

    [romo driveForwardWithSpeed:0.5];

    NSLog(@"[Lily][Romo] FORWARD -> driveForwardWithSpeed:0.5");
}

- (void)backward {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] BACKWARD ignored: no robot");
        return;
    }

    [romo driveBackwardWithSpeed:0.5];

    NSLog(@"[Lily][Romo] BACKWARD -> driveBackwardWithSpeed:0.5");
}

- (void)stopDriving {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (romo) {
        [romo stopDriving];
    }
}

- (void)forwardDistance:(float)distanceCm {
    RMCoreRobot<DriveProtocol> *robot =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!robot) {
        NSLog(@"[Lily][Romo] FORWARD_DISTANCE ignored: no robot");
        return;
    }

    if (distanceCm <= 0.0f) {
        [robot stopDriving];
        return;
    }

    const float speed = 0.50f;
    const float topSpeedMetersPerSecond = 0.67f;

    float distance = distanceCm / 100.0f;

    float normalizeForSpeed =
        ((powf(0.06f * ((100.0f * speed) - 50.0f), 3.0f)
          + 85.0f) / 112.0f);

    float distanceInMeters =
        distance * normalizeForSpeed;

    float metersPerSecondAtSpeed =
        topSpeedMetersPerSecond * speed;

    float secondsAtSpeed =
        distanceInMeters / metersPerSecondAtSpeed;

    NSLog(@"[Lily][Romo] FORWARD_DISTANCE cm=%f sec=%f",
          distanceCm,
          secondsAtSpeed);

    [robot driveForwardWithSpeed:speed];

    dispatch_time_t popTime =
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(secondsAtSpeed * NSEC_PER_SEC));

    dispatch_after(popTime,
                   dispatch_get_main_queue(),
                   ^{
        [robot stopDriving];

        NSLog(@"[Lily][Romo] FORWARD_DISTANCE STOP");
    });
}

- (void)backwardDistance:(float)distanceCm {
    RMCoreRobot<DriveProtocol> *robot =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!robot) {
        NSLog(@"[Lily][Romo] BACKWARD_DISTANCE ignored: no robot");
        return;
    }

    if (distanceCm <= 0.0f) {
        [robot stopDriving];
        return;
    }

    const float speed = 0.50f;
    const float topSpeedMetersPerSecond = 0.67f;

    float distance = distanceCm / 100.0f;

    float normalizeForSpeed =
        ((powf(0.06f * ((100.0f * speed) - 50.0f), 3.0f)
          + 85.0f) / 112.0f);

    float distanceInMeters =
        distance * normalizeForSpeed;

    float metersPerSecondAtSpeed =
        topSpeedMetersPerSecond * speed;

    float secondsAtSpeed =
        distanceInMeters / metersPerSecondAtSpeed;

    NSLog(@"[Lily][Romo] BACKWARD_DISTANCE cm=%f sec=%f",
          distanceCm,
          secondsAtSpeed);

    [robot driveBackwardWithSpeed:speed];

    dispatch_time_t popTime =
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(secondsAtSpeed * NSEC_PER_SEC));

    dispatch_after(popTime,
                   dispatch_get_main_queue(),
                   ^{
        [robot stopDriving];

        NSLog(@"[Lily][Romo] BACKWARD_DISTANCE STOP");
    });
}

- (void)turnLeft {
    RMCoreRobot<DriveProtocol, RobotMotionProtocol> *robot =
        (RMCoreRobot<DriveProtocol, RobotMotionProtocol> *)self.robot;

    if (!robot) {
        NSLog(@"[Lily][Romo] TURN_LEFT ignored: no robot");
        return;
    }

    [robot stopDriving];

    NSLog(@"[Lily][Romo] TURN_LEFT -> 90 degrees");

    [robot turnByAngle:-90.0f
            withRadius:0.0f
       finishingAction:RMCoreTurnFinishingActionStopDriving
            completion:^(BOOL success, float heading) {
        [robot stopDriving];

        NSLog(@"[Lily][Romo] TURN_LEFT completed success=%d heading=%f",
              success,
              heading);
    }];
}

- (void)turnRight {
    RMCoreRobot<DriveProtocol, RobotMotionProtocol> *robot =
        (RMCoreRobot<DriveProtocol, RobotMotionProtocol> *)self.robot;

    if (!robot) {
        NSLog(@"[Lily][Romo] TURN_RIGHT ignored: no robot");
        return;
    }

    [robot stopDriving];

    NSLog(@"[Lily][Romo] TURN_RIGHT -> 90 degrees");

    [robot turnByAngle:90.0f
            withRadius:0.0f
       finishingAction:RMCoreTurnFinishingActionStopDriving
            completion:^(BOOL success, float heading) {
        [robot stopDriving];

        NSLog(@"[Lily][Romo] TURN_RIGHT completed success=%d heading=%f",
              success,
              heading);
    }];
}

- (void)turnAngle:(float)angle {
    RMCoreRobot<DriveProtocol, RobotMotionProtocol> *robot =
        (RMCoreRobot<DriveProtocol, RobotMotionProtocol> *)self.robot;

    if (!robot) {
        NSLog(@"[Lily][Romo] TURN_ANGLE ignored: no robot");
        return;
    }

    [robot stopDriving];

    NSLog(@"[Lily][Romo] TURN_ANGLE -> %f degrees", angle);

    [robot turnByAngle:angle
            withRadius:0.0f
       finishingAction:RMCoreTurnFinishingActionStopDriving
            completion:^(BOOL success, float heading) {
        [robot stopDriving];

        NSLog(@"[Lily][Romo] TURN_ANGLE completed success=%d heading=%f",
              success,
              heading);
    }];
}

- (void)headUp {
    RMCoreRobot<HeadTiltProtocol> *robot =
        (RMCoreRobot<HeadTiltProtocol> *)self.robot;

    if (!robot || !robot.isHeadTiltable) {
        NSLog(@"[Lily][Romo] HEAD_UP ignored");
        return;
    }

    float targetAngle = robot.headAngle + 10.0f;

    NSLog(@"[Lily][Romo] HEAD_UP current=%f target=%f",
          robot.headAngle,
          targetAngle);

    [robot tiltToAngle:targetAngle
            completion:^(BOOL success) {
        NSLog(@"[Lily][Romo] HEAD_UP completed success=%d angle=%f",
              success,
              robot.headAngle);
    }];
}

- (void)headDown {
    RMCoreRobot<HeadTiltProtocol> *robot =
        (RMCoreRobot<HeadTiltProtocol> *)self.robot;

    if (!robot || !robot.isHeadTiltable) {
        NSLog(@"[Lily][Romo] HEAD_DOWN ignored");
        return;
    }

    float targetAngle = robot.headAngle - 10.0f;

    NSLog(@"[Lily][Romo] HEAD_DOWN current=%f target=%f",
          robot.headAngle,
          targetAngle);

    [robot tiltToAngle:targetAngle
            completion:^(BOOL success) {
        NSLog(@"[Lily][Romo] HEAD_DOWN completed success=%d angle=%f",
              success,
              robot.headAngle);
    }];
}

- (void)sendHTTPResponse:(int)clientSocket
                  status:(const char *)status
                    body:(NSString *)body {
    NSData *bodyData =
        [body dataUsingEncoding:NSUTF8StringEncoding];

    NSString *response =
        [NSString stringWithFormat:
            @"HTTP/1.1 %s\r\n"
             "Content-Type: application/json; charset=utf-8\r\n"
             "Content-Length: %lu\r\n"
             "Connection: close\r\n"
             "Access-Control-Allow-Origin: *\r\n"
             "\r\n%@",
            status,
            (unsigned long)bodyData.length,
            body];

    NSData *responseData =
        [response dataUsingEncoding:NSUTF8StringEncoding];

    send(clientSocket,
         responseData.bytes,
         responseData.length,
         0);
}

- (void)handleHTTPClient:(int)clientSocket {
    char buffer[2048];

    ssize_t count =
        recv(clientSocket,
             buffer,
             sizeof(buffer) - 1,
             0);

    if (count <= 0) return;

    buffer[count] = '\0';

    NSString *request =
        [[NSString alloc]
            initWithBytes:buffer
            length:(NSUInteger)count
            encoding:NSUTF8StringEncoding];

    NSString *firstLine =
        [[request componentsSeparatedByString:@"\r\n"] firstObject];

    NSArray *parts =
        [firstLine componentsSeparatedByString:@" "];

    NSString *path =
        parts.count >= 2 ? parts[1] : @"";

    if ([path isEqualToString:@"/romo/forward"]) {
        [self forward];

        [self sendHTTPResponse:clientSocket
                        status:"200 OK"
                          body:@"{\"ok\":true,\"action\":\"forward\"}"];

    } else if ([path isEqualToString:@"/romo/backward"]) {
        [self backward];

        [self sendHTTPResponse:clientSocket
                        status:"200 OK"
                          body:@"{\"ok\":true,\"action\":\"backward\"}"];

    } else if ([path isEqualToString:@"/romo/stop"]) {
        [self stopDriving];

        [self sendHTTPResponse:clientSocket
                        status:"200 OK"
                          body:@"{\"ok\":true,\"action\":\"stop\"}"];

    } else if ([path isEqualToString:@"/romo/status"]) {
        NSString *body =
            [NSString stringWithFormat:
                @"{\"connected\":%@}",
                self.robot ? @"true" : @"false"];

        [self sendHTTPResponse:clientSocket
                        status:"200 OK"
                          body:body];

    } else {
        [self sendHTTPResponse:clientSocket
                        status:"404 Not Found"
                          body:@"{\"ok\":false,\"error\":\"unknown path\"}"];
    }
}

- (void)serverLoop {
    self.serverSocket =
        socket(AF_INET, SOCK_STREAM, 0);

    if (self.serverSocket < 0) {
        self.running = NO;
        return;
    }

    int yes = 1;

    setsockopt(self.serverSocket,
               SOL_SOCKET,
               SO_REUSEADDR,
               &yes,
               sizeof(yes));

    struct sockaddr_in address;

    memset(&address, 0, sizeof(address));

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(kLilyRomoHTTPPort);

    if (bind(self.serverSocket,
             (struct sockaddr *)&address,
             sizeof(address)) < 0 ||
        listen(self.serverSocket, 4) < 0) {

        close(self.serverSocket);
        self.serverSocket = -1;
        self.running = NO;
        return;
    }

    while (self.running) {
        int clientSocket =
            accept(self.serverSocket, NULL, NULL);

        if (clientSocket < 0) continue;

        [self handleHTTPClient:clientSocket];

        shutdown(clientSocket, SHUT_RDWR);
        close(clientSocket);
    }
}

@end


/* ============================================================
   Native Lily MCP -> Romo bridge
   ============================================================ */

static BOOL gLilyMCPHookInstalled = NO;
static BOOL gLilyNativeRegisterToolsPatchInstalled = NO;
static uintptr_t gLilyNativeRegisterToolsAddress = 0;
static uintptr_t gLilyNativeRegisterToolsTrampoline = 0;
static uint8_t gLilyOriginalRegisterToolsBytes[16];
static void *gLilyRomoInjectedServer = NULL;

static NSMutableArray *gLilyRomoToolWrappers = nil;

static void LilyRetainRomoToolWrapper(id tool) {
    if (!tool) return;

    @synchronized ([NSObject class]) {
        if (!gLilyRomoToolWrappers) {
            gLilyRomoToolWrappers = [[NSMutableArray alloc] init];
        }

        [gLilyRomoToolWrappers addObject:tool];
    }
}

static pthread_mutex_t gLilyNativeHookLock =
    PTHREAD_MUTEX_INITIALIZER;


static void LilyRomoForwardNoArgs(void) {
    LilyMCPWrite(@"MCP-ROMO CALLBACK: robot.forward");
    [[LilyRomoController sharedController] forward];
    LilyMCPWrite(@"MCP-ROMO RMCORE RETURN: robot.forward");
}

static void LilyRomoBackwardNoArgs(void) {
    LilyMCPWrite(@"MCP-ROMO CALLBACK: robot.backward");
    [[LilyRomoController sharedController] backward];
    LilyMCPWrite(@"MCP-ROMO RMCORE RETURN: robot.backward");
}

static void LilyRomoStopNoArgs(void) {
    LilyMCPWrite(@"MCP-ROMO CALLBACK: robot.stop");
    [[LilyRomoController sharedController] stopDriving];
    LilyMCPWrite(@"MCP-ROMO RMCORE RETURN: robot.stop");
}

static void LilyRomoTurnLeftNoArgs(void) {
    LilyMCPWrite(@"MCP-ROMO CALLBACK: robot.turn_left");
    [[LilyRomoController sharedController] turnLeft];
    LilyMCPWrite(@"MCP-ROMO RMCORE RETURN: robot.turn_left");
}

static void LilyRomoTurnRightNoArgs(void) {
    LilyMCPWrite(@"MCP-ROMO CALLBACK: robot.turn_right");
    [[LilyRomoController sharedController] turnRight];
    LilyMCPWrite(@"MCP-ROMO RMCORE RETURN: robot.turn_right");
}

static void LilyRomoHeadUpNoArgs(void) {
    LilyMCPWrite(@"MCP-ROMO CALLBACK: robot.head_up");
    [[LilyRomoController sharedController] headUp];
    LilyMCPWrite(@"MCP-ROMO RMCORE RETURN: robot.head_up");
}

static void LilyRomoHeadDownNoArgs(void) {
    LilyMCPWrite(@"MCP-ROMO CALLBACK: robot.head_down");
    [[LilyRomoController sharedController] headDown];
    LilyMCPWrite(@"MCP-ROMO RMCORE RETURN: robot.head_down");
}


static id LilyCreateSimpleRomoTool(NSString *name,
                                   NSString *description,
                                   id (^callback)(id)) {
    Class toolClass = NSClassFromString(@"SharedMcpTool");

    if (!toolClass) {
        LilyMCPWrite(@"MCP-ROMO TOOL: SharedMcpTool NOT FOUND");
        return nil;
    }

    SEL initSel =
        NSSelectorFromString(
            @"initWithName:description:properties:userOnly:callback:");

    if (![toolClass instancesRespondToSelector:initSel]) {
        LilyMCPWrite(@"MCP-ROMO TOOL: initializer NOT FOUND");
        return nil;
    }

    typedef id (*ToolInitFn)(id, SEL, id, id, id, BOOL, id);

    ToolInitFn initFn =
        (ToolInitFn)objc_msgSend;

    id tool =
        initFn([toolClass alloc],
               initSel,
               name,
               description,
               @[],
               NO,
               callback);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO TOOL: %@ %@",
        name,
        tool ? @"CREATED" : @"FAILED"]);

    return tool;
}


typedef void (*LilyMcpRegisterToolsFn)(void *server);

static uintptr_t LilyFindSharedImageSlide(void);

typedef void (*LilyMcpAddToolFn)(void *server,
                                 void *tool);


typedef void *(*LilySharedToKotlinFn)(id self,
                                      SEL _cmd,
                                      void **outNative);

static void *LilySharedMcpToolToKotlin(id tool) {
    if (!tool) {
        LilyMCPWrite(@"MCP-ROMO TOKOTLIN: tool=NULL");
        return NULL;
    }

    SEL toKotlinSel =
        sel_registerName("Shared_toKotlin:");

    if (![tool respondsToSelector:toKotlinSel]) {
        LilyMCPWrite(
            @"MCP-ROMO TOKOTLIN: Shared_toKotlin: NOT FOUND"
        );
        return NULL;
    }

    Class cls =
        object_getClass(tool);

    IMP imp =
        class_getMethodImplementation(
            cls,
            toKotlinSel
        );

    if (!imp) {
        LilyMCPWrite(
            @"MCP-ROMO TOKOTLIN: IMP NOT FOUND"
        );
        return NULL;
    }

    LilySharedToKotlinFn fn =
        (LilySharedToKotlinFn)imp;

    void *outNative = NULL;

    void *returnNative =
        fn(tool,
           toKotlinSel,
           &outNative);

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


static void LilyAddRomoToolNative(void *server,
                                  id objcTool) {
    if (!server || !objcTool) {
        LilyMCPWrite(
            @"MCP-ROMO ADDTOOL: missing server/objcTool"
        );
        return;
    }

    void *nativeTool =
        LilySharedMcpToolToKotlin(objcTool);

    if (!nativeTool) {
        LilyMCPWrite(
            @"MCP-ROMO ADDTOOL: Shared_toKotlin returned NULL"
        );
        return;
    }

    LilyRetainRomoToolWrapper(objcTool);

    uintptr_t slide =
        LilyFindSharedImageSlide();

    if (!slide) {
        LilyMCPWrite(
            @"MCP-ROMO ADDTOOL: Shared.framework slide NOT FOUND"
        );
        return;
    }

    uintptr_t target =
        slide + 0x126CC88;

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO ADDTOOL NATIVE ENTER "
         "server=%p objcTool=%p nativeTool=%p target=0x%llx",
        server,
        objcTool,
        nativeTool,
        (unsigned long long)target]);

    uintptr_t t =
        (uintptr_t)nativeTool;

    uintptr_t v00 = *(uintptr_t *)(t + 0x00);
    uintptr_t v08 = *(uintptr_t *)(t + 0x08);
    uintptr_t v10 = *(uintptr_t *)(t + 0x10);
    uintptr_t v18 = *(uintptr_t *)(t + 0x18);
    uintptr_t v20 = *(uintptr_t *)(t + 0x20);
    uintptr_t v28 = *(uintptr_t *)(t + 0x28);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO NATIVE TOOL "
         "native=%p +00=0x%llx +08=0x%llx +10=0x%llx "
         "+18=0x%llx +20=0x%llx +28=0x%llx",
        nativeTool,
        (unsigned long long)v00,
        (unsigned long long)v08,
        (unsigned long long)v10,
        (unsigned long long)v18,
        (unsigned long long)v20,
        (unsigned long long)v28]);

    LilyMCPWrite(
        @"MCP-ROMO CALL ADDTOOL BEGIN"
    );

    ((LilyMcpAddToolFn)target)(
        server,
        nativeTool
    );

    LilyMCPWrite(
        @"MCP-ROMO CALL ADDTOOL RETURNED"
    );
}


static void LilyDumpToolRaw73(id tool,
                              const char *tag) {
    if (!tool) return;

    uintptr_t t =
        (uintptr_t)tool;

    uintptr_t v00 = *(uintptr_t *)(t + 0x00);
    uintptr_t v08 = *(uintptr_t *)(t + 0x08);
    uintptr_t v10 = *(uintptr_t *)(t + 0x10);
    uintptr_t v18 = *(uintptr_t *)(t + 0x18);
    uintptr_t v20 = *(uintptr_t *)(t + 0x20);
    uintptr_t v28 = *(uintptr_t *)(t + 0x28);
    uintptr_t v30 = *(uintptr_t *)(t + 0x30);
    uintptr_t v38 = *(uintptr_t *)(t + 0x38);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO %s RAW tool=%p "
         "+00=0x%llx +08=0x%llx +10=0x%llx +18=0x%llx",
        tag,
        tool,
        (unsigned long long)v00,
        (unsigned long long)v08,
        (unsigned long long)v10,
        (unsigned long long)v18]);

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO %s RAW tool=%p "
         "+20=0x%llx +28=0x%llx +30=0x%llx +38=0x%llx",
        tag,
        tool,
        (unsigned long long)v20,
        (unsigned long long)v28,
        (unsigned long long)v30,
        (unsigned long long)v38]);
}


/* ============================================================
   FULL ROMO MCP REGISTRATION
   ============================================================ */

static void LilyInjectRobotToolsIntoServer(void *server) {
    if (!server) return;

    if (gLilyRomoInjectedServer == server) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO INJECT: already injected server=%p",
            server]);
        return;
    }

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO INJECT ENTER server=%p",
        server]);

    id forwardTool =
        LilyCreateSimpleRomoTool(
            @"robot.forward",
            @"Move Romo forward continuously.",
            ^id(id args) {
                (void)args;
                LilyRomoForwardNoArgs();
                return @"Romo moved forward";
            });

    id backwardTool =
        LilyCreateSimpleRomoTool(
            @"robot.backward",
            @"Move Romo backward continuously.",
            ^id(id args) {
                (void)args;
                LilyRomoBackwardNoArgs();
                return @"Romo moved backward";
            });

    id stopTool =
        LilyCreateSimpleRomoTool(
            @"robot.stop",
            @"Stop Romo immediately.",
            ^id(id args) {
                (void)args;
                LilyRomoStopNoArgs();
                return @"Romo stopped";
            });

    id turnLeftTool =
        LilyCreateSimpleRomoTool(
            @"robot.turn_left",
            @"Turn Romo left approximately 90 degrees, then stop.",
            ^id(id args) {
                (void)args;
                LilyRomoTurnLeftNoArgs();
                return @"Romo turned left";
            });

    id turnRightTool =
        LilyCreateSimpleRomoTool(
            @"robot.turn_right",
            @"Turn Romo right approximately 90 degrees, then stop.",
            ^id(id args) {
                (void)args;
                LilyRomoTurnRightNoArgs();
                return @"Romo turned right";
            });

    id headUpTool =
        LilyCreateSimpleRomoTool(
            @"robot.head_up",
            @"Tilt Romo head upward by approximately 10 degrees.",
            ^id(id args) {
                (void)args;
                LilyRomoHeadUpNoArgs();
                return @"Romo head moved up";
            });

    id headDownTool =
        LilyCreateSimpleRomoTool(
            @"robot.head_down",
            @"Tilt Romo head downward by approximately 10 degrees.",
            ^id(id args) {
                (void)args;
                LilyRomoHeadDownNoArgs();
                return @"Romo head moved down";
            });

    id tools[] = {
        forwardTool,
        backwardTool,
        stopTool,
        turnLeftTool,
        turnRightTool,
        headUpTool,
        headDownTool
    };

    const char *tags[] = {
        "FORWARD BEFORE",
        "BACKWARD BEFORE",
        "STOP BEFORE",
        "TURN_LEFT BEFORE",
        "TURN_RIGHT BEFORE",
        "HEAD_UP BEFORE",
        "HEAD_DOWN BEFORE"
    };

    for (NSUInteger i = 0; i < 7; i++) {
        if (tools[i]) {
            LilyDumpToolRaw73(tools[i], tags[i]);
        }
    }

    for (NSUInteger i = 0; i < 7; i++) {
        if (!tools[i]) continue;

        LilyAddRomoToolNative(
            server,
            tools[i]
        );
    }

    gLilyRomoInjectedServer = server;

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO INJECT RETURNED server=%p tools=7",
        server]);
}


static BOOL LilyProtectCodePage(void *address,
                                BOOL writable) {
    vm_address_t page =
        (vm_address_t)address &
        ~(vm_address_t)(vm_page_size - 1);

    vm_prot_t prot =
        writable
        ? (VM_PROT_READ | VM_PROT_WRITE)
        : (VM_PROT_READ | VM_PROT_EXECUTE);

    kern_return_t kr =
        vm_protect(
            mach_task_self(),
            page,
            vm_page_size,
            FALSE,
            prot
        );

    if (kr != KERN_SUCCESS) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO PATCH: vm_protect failed kr=%d",
            kr]);
        return NO;
    }

    return YES;
}


static uintptr_t LilyFindSharedImageSlide(void) {
    uint32_t count =
        _dyld_image_count();

    for (uint32_t i = 0; i < count; i++) {
        const char *name =
            _dyld_get_image_name(i);

        if (name &&
            strstr(name,
                   @"Shared.framework/Shared".UTF8String)) {
            return (uintptr_t)
                _dyld_get_image_vmaddr_slide(i);
        }
    }

    return 0;
}


static BOOL LilyWriteBranch(void *address,
                            uintptr_t destination) {
    uintptr_t source =
        (uintptr_t)address;

    int64_t delta =
        (int64_t)destination -
        (int64_t)source;

    if ((delta & 0x3) != 0 ||
        delta < -(128LL * 1024 * 1024) ||
        delta >= (128LL * 1024 * 1024)) {

        LilyMCPWrite(
            @"MCP-ROMO PATCH: hook outside AArch64 B range"
        );

        return NO;
    }

    int64_t imm26 =
        delta >> 2;

    uint32_t instruction =
        0x14000000u |
        ((uint32_t)imm26 & 0x03ffffffu);

    if (!LilyProtectCodePage(address, YES))
        return NO;

    memcpy(address,
           &instruction,
           sizeof(instruction));

    sys_icache_invalidate(
        address,
        sizeof(instruction)
    );

    return LilyProtectCodePage(
        address,
        NO
    );
}


static BOOL LilyAllocateRegisterToolsTrampoline(
    uintptr_t target) {

    if (gLilyNativeRegisterToolsTrampoline)
        return YES;

    vm_address_t page = 0;

    kern_return_t kr =
        vm_allocate(
            mach_task_self(),
            &page,
            vm_page_size,
            VM_FLAGS_ANYWHERE
        );

    if (kr != KERN_SUCCESS) {
        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO PATCH: vm_allocate trampoline failed kr=%d",
            kr]);
        return NO;
    }

    kr =
        vm_protect(
            mach_task_self(),
            page,
            vm_page_size,
            FALSE,
            VM_PROT_READ | VM_PROT_WRITE
        );

    if (kr != KERN_SUCCESS) {
        vm_deallocate(
            mach_task_self(),
            page,
            vm_page_size
        );

        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO PATCH: trampoline RW protect failed kr=%d",
            kr]);

        return NO;
    }

    memcpy(
        (void *)page,
        (void *)target,
        sizeof(gLilyOriginalRegisterToolsBytes)
    );

    uint8_t *jumpAt =
        (uint8_t *)page +
        sizeof(gLilyOriginalRegisterToolsBytes);

    uint32_t jump[2] = {
        0x58000050,
        0xD61F0200
    };

    uint64_t continuation =
        (uint64_t)(
            target +
            sizeof(gLilyOriginalRegisterToolsBytes)
        );

    memcpy(
        jumpAt,
        jump,
        sizeof(jump)
    );

    memcpy(
        jumpAt + 8,
        &continuation,
        sizeof(continuation)
    );

    sys_icache_invalidate(
        (void *)page,
        32
    );

    kr =
        vm_protect(
            mach_task_self(),
            page,
            vm_page_size,
            FALSE,
            VM_PROT_READ | VM_PROT_EXECUTE
        );

    if (kr != KERN_SUCCESS) {
        vm_deallocate(
            mach_task_self(),
            page,
            vm_page_size
        );

        LilyMCPWrite([NSString stringWithFormat:
            @"MCP-ROMO PATCH: trampoline RX protect failed kr=%d",
            kr]);

        return NO;
    }

    gLilyNativeRegisterToolsTrampoline =
        (uintptr_t)page;

    return YES;
}


static void LilyNativeRegisterToolsHook(
    void *server);


static BOOL LilyPatchNativeRegisterTools(void) {
    pthread_mutex_lock(
        &gLilyNativeHookLock
    );

    if (gLilyNativeRegisterToolsPatchInstalled) {
        pthread_mutex_unlock(
            &gLilyNativeHookLock
        );
        return YES;
    }

    uintptr_t slide =
        LilyFindSharedImageSlide();

    if (!slide) {
        LilyMCPWrite(
            @"MCP-ROMO PATCH: Shared.framework slide NOT FOUND"
        );

        pthread_mutex_unlock(
            &gLilyNativeHookLock
        );

        return NO;
    }

    uintptr_t registerTarget =
        slide + 0x126B040;

    memcpy(
        gLilyOriginalRegisterToolsBytes,
        (void *)registerTarget,
        16
    );

    const uint8_t expected[16] = {
        0xe9, 0x23, 0xb9, 0x6d,
        0xfc, 0x6f, 0x01, 0xa9,
        0xfa, 0x67, 0x02, 0xa9,
        0xf8, 0x5f, 0x03, 0xa9
    };

    if (memcmp(
            gLilyOriginalRegisterToolsBytes,
            expected,
            16) != 0) {

        LilyMCPWrite(
            @"MCP-ROMO PATCH: registerTools prologue mismatch"
        );

        pthread_mutex_unlock(
            &gLilyNativeHookLock
        );

        return NO;
    }

    if (!LilyAllocateRegisterToolsTrampoline(
            registerTarget)) {

        pthread_mutex_unlock(
            &gLilyNativeHookLock
        );

        return NO;
    }

    if (!LilyWriteBranch(
            (void *)registerTarget,
            (uintptr_t)&LilyNativeRegisterToolsHook)) {

        vm_deallocate(
            mach_task_self(),
            (vm_address_t)
                gLilyNativeRegisterToolsTrampoline,
            vm_page_size
        );

        gLilyNativeRegisterToolsTrampoline = 0;

        pthread_mutex_unlock(
            &gLilyNativeHookLock
        );

        return NO;
    }

    gLilyNativeRegisterToolsAddress =
        registerTarget;

    gLilyNativeRegisterToolsPatchInstalled =
        YES;

    LilyMCPWrite(
        @"MCP-ROMO PATCH ENABLED: registerTools ONLY"
    );

    pthread_mutex_unlock(
        &gLilyNativeHookLock
    );

    return YES;
}


static void LilyNativeRegisterToolsHook(
    void *server) {

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO REGISTER ENTER server=%p",
        server]);

    uintptr_t trampoline =
        gLilyNativeRegisterToolsTrampoline;

    if (!trampoline) {
        LilyMCPWrite(
            @"MCP-ROMO ERROR: registerTools trampoline NULL"
        );
        return;
    }

    ((LilyMcpRegisterToolsFn)trampoline)(
        server
    );

    LilyMCPWrite([NSString stringWithFormat:
        @"MCP-ROMO REGISTER RETURN server=%p",
        server]);

    if (server) {
        LilyInjectRobotToolsIntoServer(
            server
        );
    }

    LilyMCPWrite(
        @"MCP-ROMO REGISTER HOOK DONE"
    );
}


static void LilyInstallMCPRomoHook(void) {
    gLilyMCPHookInstalled =
        LilyPatchNativeRegisterTools();

    LilyMCPWrite(
        gLilyMCPHookInstalled
        ? @"MCP-ROMO PATCH: ENABLED"
        : @"MCP-ROMO PATCH: FAILED"
    );
}


@implementation LilySharedBridge

+ (BOOL)initializeSharedWithAPIKey:(NSString *)apiKey
                             wsURL:(NSString *)wsURL
                            otaURL:(NSString *)otaURL {

    Class cls =
        NSClassFromString(@"SharedIosModuleKt");

    if (!cls) return NO;

    SEL sel =
        NSSelectorFromString(
            @"doInitKoinApiEncryptionKey:wsUrl:otaUrl:");

    if (![cls respondsToSelector:sel])
        return NO;

    LilyInstallMCPRomoHook();

    typedef void (*InitFn)(
        id,
        SEL,
        NSString *,
        NSString *,
        NSString *
    );

    InitFn fn =
        (InitFn)objc_msgSend;

    fn(
        cls,
        sel,
        apiKey,
        wsURL,
        otaURL
    );

    NSLog(
        @"[Lily] Shared Koin initialization invoked"
    );

    [[LilyRomoController sharedController]
        start];

    LilyDumpMethods(@"SharedMcpServer");
    LilyDumpMethods(@"SharedMcpServerCompanion");
    LilyDumpMethods(@"SharedMcpTool");
    LilyDumpMethods(@"SharedMcpToolInfo");
    LilyDumpMethods(@"SharedMcpToolRegistry");
    LilyDumpMethods(@"SharedSkillToolFactory");

    return YES;
}


+ (UIViewController *)mainViewController {
    Class cls =
        NSClassFromString(@"SharedAppKt");

    if (!cls) return nil;

    SEL sel =
        NSSelectorFromString(@"MainViewController");

    if (![cls respondsToSelector:sel])
        return nil;

    typedef UIViewController *(*MainFn)(id, SEL);

    MainFn fn =
        (MainFn)objc_msgSend;

    return fn(cls, sel);
}

@end
