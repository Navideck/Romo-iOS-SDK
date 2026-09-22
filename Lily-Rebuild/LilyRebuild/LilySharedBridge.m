#import "LilySharedBridge.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <Romo/RMCore.h>
#import <Romo/RMCharacter.h>
#import <Romo/RMCharacterFace.h>
#import <WebKit/WebKit.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <string.h>
#import <libkern/OSCacheControl.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <pthread.h>
#import <math.h>

#pragma mark - MCP logging

static void LilyMCPWrite(NSString *line) {
    NSString *documents =
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES
        ).firstObject;

    if (!documents) return;

    NSString *path =
        [documents stringByAppendingPathComponent:@"LilyMCPDump.txt"];

    NSString *text = [line stringByAppendingString:@"\n"];

    NSFileHandle *fh =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (!fh) {
        [[NSFileManager defaultManager]
            createFileAtPath:path
            contents:nil
            attributes:nil];

        fh = [NSFileHandle fileHandleForWritingAtPath:path];
    }

    if (!fh) return;

    [fh seekToEndOfFile];

    NSData *data =
        [text dataUsingEncoding:NSUTF8StringEncoding];

    if (data) [fh writeData:data];

    [fh closeFile];
}

static void LilyDumpMethods(NSString *className) {
    Class cls = NSClassFromString(className);

    LilyMCPWrite([NSString stringWithFormat:
        @"========== MCP DUMP %@ ==========", className]);

    if (!cls) {
        LilyMCPWrite([NSString stringWithFormat:
            @"CLASS %@ NOT FOUND", className]);
        return;
    }

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    LilyMCPWrite([NSString stringWithFormat:
        @"CLASS %@ INSTANCE METHOD COUNT=%u", className, count]);

    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);

        LilyMCPWrite([NSString stringWithFormat:
            @"INSTANCE %@ types=%s",
            NSStringFromSelector(sel),
            types ? types : ""]);
    }

    free(methods);

    Class meta = object_getClass(cls);
    count = 0;
    methods = class_copyMethodList(meta, &count);

    LilyMCPWrite([NSString stringWithFormat:
        @"CLASS %@ CLASS METHOD COUNT=%u", className, count]);

    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);

        LilyMCPWrite([NSString stringWithFormat:
            @"CLASS %@ types=%s",
            NSStringFromSelector(sel),
            types ? types : ""]);
    }

    free(methods);

    LilyMCPWrite([NSString stringWithFormat:
        @"========== END %@ ==========", className]);
}

#pragma mark - Romo controller

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

    dispatch_async(
        dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
        ^{
            [self serverLoop];
        }
    );

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

#pragma mark Drive

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

- (void)turnLeft {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] LEFT ignored: no robot");
        return;
    }

    [romo driveWithRadius:0.0 speed:0.5];

    NSLog(@"[Lily][Romo] LEFT -> driveWithRadius:0 speed:0.5");
}

- (void)turnRight {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] RIGHT ignored: no robot");
        return;
    }

    [romo driveWithRadius:0.0 speed:-0.5];

    NSLog(@"[Lily][Romo] RIGHT -> driveWithRadius:0 speed:-0.5");
}

#pragma mark Distance movement

/*
 * Source-backed RMActionRunner timing:
 *
 * speed = 0.5
 * topSpeedMetersPerSecond = 0.67
 *
 * normalizeForSpeed =
 *     (powf(0.06 * ((100 * speed) - 50), 3) + 85) / 112
 *
 * distanceInMeters = distance * normalizeForSpeed
 * metersPerSecondAtSpeed = topSpeedMetersPerSecond * speed
 * seconds = distanceInMeters / metersPerSecondAtSpeed
 *
 * At speed 0.5 the normalization factor is about 0.7589286.
 */
- (void)driveDistanceCm:(float)distanceCm forward:(BOOL)forward {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] DISTANCE ignored: no robot");
        return;
    }

    if (distanceCm <= 0.0f) {
        NSLog(@"[Lily][Romo] DISTANCE ignored: invalid %.2f cm",
              distanceCm);
        return;
    }

    if (distanceCm > 500.0f) {
        distanceCm = 500.0f;
    }

    const float speed = 0.5f;
    const float topSpeedMetersPerSecond = 0.67f;

    float normalizeForSpeed =
        (powf(
            0.06f * ((100.0f * speed) - 50.0f),
            3.0f
        ) + 85.0f) / 112.0f;

    float distanceInMeters =
        (distanceCm / 100.0f) * normalizeForSpeed;

    float metersPerSecondAtSpeed =
        topSpeedMetersPerSecond * speed;

    float secondsAtSpeed =
        distanceInMeters / metersPerSecondAtSpeed;

    NSLog(
        @"[Lily][Romo] DISTANCE %@ %.2f cm -> %.4f sec",
        forward ? @"FORWARD" : @"BACKWARD",
        distanceCm,
        secondsAtSpeed
    );

    if (forward) {
        [romo driveForwardWithSpeed:speed];
    } else {
        [romo driveBackwardWithSpeed:speed];
    }

    dispatch_time_t popTime =
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(secondsAtSpeed * NSEC_PER_SEC)
        );

    dispatch_after(
        popTime,
        dispatch_get_main_queue(),
        ^{
            /*
             * Do not blindly operate on a stale robot object.
             * Stop the currently connected robot if present.
             */
            RMCoreRobot<DriveProtocol> *current =
                (RMCoreRobot<DriveProtocol> *)self.robot;

            if (current) {
                [current stopDriving];
            }

            NSLog(
                @"[Lily][Romo] DISTANCE %@ %.2f cm -> stopDriving",
                forward ? @"FORWARD" : @"BACKWARD",
                distanceCm
            );
        }
    );
}

- (void)forwardDistanceCm:(float)distanceCm {
    [self driveDistanceCm:distanceCm forward:YES];
}

- (void)backwardDistanceCm:(float)distanceCm {
    [self driveDistanceCm:distanceCm forward:NO];
}

#pragma mark Turn angle

- (void)turnByAngleDegrees:(float)angle {
    RMCoreRobot<DriveProtocol> *romo =
        (RMCoreRobot<DriveProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] TURN ANGLE ignored: no robot");
        return;
    }

    if (angle > 180.0f) angle = 180.0f;
    if (angle < -180.0f) angle = -180.0f;

    if (angle == 0.0f) {
        NSLog(@"[Lily][Romo] TURN ANGLE ignored: zero angle");
        return;
    }

    NSLog(@"[Lily][Romo] TURN ANGLE -> %.2f deg", angle);

    [romo turnByAngle:angle
          withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
               speed:0.3
     finishingAction:RMCoreTurnFinishingActionStopDriving
           completion:^(BOOL success, float completedAngle) {
        NSLog(
            @"[Lily][Romo] TURN ANGLE completion success=%d angle=%f",
            success,
            completedAngle
        );
    }];
}

#pragma mark Head

- (void)headUpByDegrees:(float)degrees {
    RMCoreRobot<HeadTiltProtocol> *romo =
        (RMCoreRobot<HeadTiltProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] HEAD UP ignored: no robot");
        return;
    }

    if (degrees < 0.0f) degrees = -degrees;

    float current = romo.headAngle;
    float maxAngle = romo.maximumHeadTiltAngle;

    float allowed = maxAngle - current;
    if (allowed < 0.0f) allowed = 0.0f;

    if (degrees > allowed) degrees = allowed;

    NSLog(
        @"[Lily][Romo] HEAD UP -> %.2f current=%.2f max=%.2f",
        degrees,
        current,
        maxAngle
    );

    if (degrees <= 0.0f) return;

    [romo tiltByAngle:degrees
           completion:^(BOOL success) {
        NSLog(
            @"[Lily][Romo] HEAD UP completion success=%d angle=%.2f",
            success,
            romo.headAngle
        );
    }];
}

- (void)headDownByDegrees:(float)degrees {
    RMCoreRobot<HeadTiltProtocol> *romo =
        (RMCoreRobot<HeadTiltProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] HEAD DOWN ignored: no robot");
        return;
    }

    if (degrees < 0.0f) degrees = -degrees;

    float current = romo.headAngle;
    float minAngle = romo.minimumHeadTiltAngle;

    float allowed = current - minAngle;
    if (allowed < 0.0f) allowed = 0.0f;

    if (degrees > allowed) degrees = allowed;

    NSLog(
        @"[Lily][Romo] HEAD DOWN -> %.2f current=%.2f min=%.2f",
        degrees,
        current,
        minAngle
    );

    if (degrees <= 0.0f) return;

    [romo tiltByAngle:-degrees
           completion:^(BOOL success) {
        NSLog(
            @"[Lily][Romo] HEAD DOWN completion success=%d angle=%.2f",
            success,
            romo.headAngle
        );
    }];
}

- (void)headToAngleDegrees:(float)angle {
    RMCoreRobot<HeadTiltProtocol> *romo =
        (RMCoreRobot<HeadTiltProtocol> *)self.robot;

    if (!romo) {
        NSLog(@"[Lily][Romo] HEAD TO ignored: no robot");
        return;
    }

    float minAngle = romo.minimumHeadTiltAngle;
    float maxAngle = romo.maximumHeadTiltAngle;

    if (angle < minAngle) angle = minAngle;
    if (angle > maxAngle) angle = maxAngle;

    NSLog(
        @"[Lily][Romo] HEAD TO -> %.2f range=[%.2f, %.2f]",
        angle,
        minAngle,
        maxAngle
    );

    [romo tiltToAngle:angle
           completion:^(BOOL success) {
        NSLog(
            @"[Lily][Romo] HEAD TO completion success=%d angle=%.2f",
            success,
            romo.headAngle
        );
    }];
}

#pragma mark Status

- (NSString *)statusText {
    RMCoreRobot *robot = self.robot;

    if (!robot) {
        return @"Romo is not connected.";
    }

    float battery = 0.0f;
    BOOL charging = NO;

    if (robot.vitals) {
        battery = robot.vitals.batteryLevel;
        charging = robot.vitals.isCharging;
    }

    int percent =
        (int)(
            MAX(0.0f, MIN(1.0f, battery))
            * 100.0f
        );

    return [NSString stringWithFormat:
        @"Romo is connected. Battery: %d%%. Charging: %@.",
        percent,
        charging ? @"yes" : @"no"];
}

#pragma mark Local HTTP compatibility

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

    send(
        clientSocket,
        responseData.bytes,
        responseData.length,
        0
    );
}

- (void)handleHTTPClient:(int)clientSocket {
    char buffer[2048];

    ssize_t count =
        recv(
            clientSocket,
            buffer,
            sizeof(buffer) - 1,
            0
        );

    if (count <= 0) return;

    buffer[count] = '\0';

    NSString *request =
        [[NSString alloc]
            initWithBytes:buffer
            length:(NSUInteger)count
            encoding:NSUTF8StringEncoding];

    NSString *firstLine =
        [[request componentsSeparatedByString:@"\r\n"]
            firstObject];

    NSArray *parts =
        [firstLine componentsSeparatedByString:@" "];

    NSString *path =
        parts.count >= 2 ? parts[1] : @"";

    if ([path isEqualToString:@"/romo/forward"]) {
        [self forward];

        [self sendHTTPResponse:
            clientSocket
            status:"200 OK"
            body:@"{\"ok\":true,\"action\":\"forward\"}"];
    }
    else if ([path isEqualToString:@"/romo/backward"]) {
        [self backward];

        [self sendHTTPResponse:
            clientSocket
            status:"200 OK"
            body:@"{\"ok\":true,\"action\":\"backward\"}"];
    }
    else if ([path isEqualToString:@"/romo/stop"]) {
        [self stopDriving];

        [self sendHTTPResponse:
            clientSocket
            status:"200 OK"
            body:@"{\"ok\":true,\"action\":\"stop\"}"];
    }
    else if ([path isEqualToString:@"/romo/status"]) {
        NSString *body =
            [NSString stringWithFormat:
                @"{\"connected\":%@}",
                self.robot ? @"true" : @"false"];

        [self sendHTTPResponse:
            clientSocket
            status:"200 OK"
            body:body];
    }
    else {
        [self sendHTTPResponse:
            clientSocket
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

    setsockopt(
        self.serverSocket,
        SOL_SOCKET,
        SO_REUSEADDR,
        &yes,
        sizeof(yes)
    );

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(kLilyRomoHTTPPort);

    if (
        bind(
            self.serverSocket,
            (struct sockaddr *)&address,
            sizeof(address)
        ) < 0
        ||
        listen(self.serverSocket, 4) < 0
    ) {
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

#pragma mark - MCP tool bridge

/*
 * IMPORTANT BASELINE
 *
 * SharedMcpTool is the Objective-C wrapper.
 * McpServer#addTool expects the real Kotlin/Native McpTool.
 *
 * Required:
 *
 *     SharedMcpTool
 *          |
 *          v
 *     Shared_toKotlin:
 *          |
 *          v
 *     native McpTool
 *          |
 *          v
 *     McpServer.addTool
 *
 * Do NOT pass (__bridge void *)objcTool directly.
 */

static NSMutableArray *gLilyRomoToolWrappers = nil;

static void LilyRetainRomoToolWrapper(id tool) {
    if (!tool) return;

    @synchronized ([NSObject class]) {
        if (!gLilyRomoToolWrappers) {
            gLilyRomoToolWrappers =
                [[NSMutableArray alloc] init];
        }

        [gLilyRomoToolWrappers addObject:tool];
    }
}

static void LilyRomoForwardNoArgs(void) {
    [[LilyRomoController sharedController] forward];
}

static void LilyRomoBackwardNoArgs(void) {
    [[LilyRomoController sharedController] backward];
}

static void LilyRomoStopNoArgs(void) {
    [[LilyRomoController sharedController] stopDriving];
}

static id LilyCreateRomoToolWithProperties(
    NSString *name,
    NSString *description,
    NSArray *properties,
    id (^callback)(id)
);

static id LilyCreateSimpleRomoTool(
    NSString *name,
    NSString *description,
    id (^callback)(id)
);

#pragma mark MCP properties

static id LilyCreateIntegerProperty(
    NSString *name,
    NSNumber *minValue,
    NSNumber *maxValue,
    NSNumber *defaultValue
) {
    Class propertyClass =
        NSClassFromString(@"SharedMcpProperty");

    Class typeClass =
        NSClassFromString(@"SharedMcpPropertyType");

    if (!propertyClass || !typeClass) {
        LilyMCPWrite(
            @"MCP-ROMO PROPERTY: class not found"
        );
        return nil;
    }

    SEL typeSel =
        NSSelectorFromString(@"integer");

    if (![typeClass respondsToSelector:typeSel]) {
        LilyMCPWrite(
            @"MCP-ROMO PROPERTY: integer type not found"
        );
        return nil;
    }

    typedef id (*EnumGetterFn)(id, SEL);

    id type =
        ((EnumGetterFn)objc_msgSend)(
            typeClass,
            typeSel
        );

    if (!type) return nil;

    SEL initSel =
        NSSelectorFromString(
            @"initWithName:type:min:max:value:hasDefault:"
        );

    if (![propertyClass instancesRespondToSelector:initSel]) {
        LilyMCPWrite(
            @"MCP-ROMO PROPERTY: initializer not found"
        );
        return nil;
    }

    typedef id (*PropertyInitFn)(
        id,
        SEL,
        id,
        id,
        id,
        id,
        id,
        BOOL
    );

    PropertyInitFn initFn =
        (PropertyInitFn)objc_msgSend;

    return initFn(
        [propertyClass alloc],
        initSel,
        name,
        type,
        minValue,
        maxValue,
        defaultValue,
        YES
    );
}

#pragma mark MCP tool factories

static id LilyCreateHeadUpRomoTool(void) {
    id property =
        LilyCreateIntegerProperty(
            @"angle_deg",
            @1,
            @90,
            @10
        );

    return LilyCreateRomoToolWithProperties(
        @"robot.head_up",
        @"Raise the physical Romo robot head by a relative angle in degrees. Use angle_deg from 1 to 90.",
        property ? @[property] : @[],
        ^id(id args) {
            NSNumber *value =
                [args isKindOfClass:[NSDictionary class]]
                    ? args[@"angle_deg"]
                    : nil;

            if (!value) {
                return @"Missing required argument: angle_deg";
            }

            float degrees = value.floatValue;

            if (degrees <= 0.0f) {
                return @"angle_deg must be greater than 0";
            }

            if (degrees > 90.0f) {
                degrees = 90.0f;
            }

            [[LilyRomoController sharedController]
                headUpByDegrees:degrees];

            return [NSString stringWithFormat:
                @"Romo head up %.0f degrees",
                degrees];
        }
    );
}

static id LilyCreateHeadDownRomoTool(void) {
    id property =
        LilyCreateIntegerProperty(
            @"angle_deg",
            @1,
            @90,
            @10
        );

    return LilyCreateRomoToolWithProperties(
        @"robot.head_down",
        @"Lower the physical Romo robot head by a relative angle in degrees. Use angle_deg from 1 to 90.",
        property ? @[property] : @[],
        ^id(id args) {
            NSNumber *value =
                [args isKindOfClass:[NSDictionary class]]
                    ? args[@"angle_deg"]
                    : nil;

            if (!value) {
                return @"Missing required argument: angle_deg";
            }

            float degrees = value.floatValue;

            if (degrees <= 0.0f) {
                return @"angle_deg must be greater than 0";
            }

            if (degrees > 90.0f) {
                degrees = 90.0f;
            }

            [[LilyRomoController sharedController]
                headDownByDegrees:degrees];

            return [NSString stringWithFormat:
                @"Romo head down %.0f degrees",
                degrees];
        }
    );
}

static id LilyCreateHeadToRomoTool(void) {
    id property =
        LilyCreateIntegerProperty(
            @"angle_deg",
            @-90,
            @90,
            @0
        );

    return LilyCreateRomoToolWithProperties(
        @"robot.head_to",
        @"Move the physical Romo robot head to an absolute angle in degrees. Range -90 to 90.",
        property ? @[property] : @[],
        ^id(id args) {
            NSNumber *value =
                [args isKindOfClass:[NSDictionary class]]
                    ? args[@"angle_deg"]
                    : nil;

            if (!value) {
                return @"Missing required argument: angle_deg";
            }

            float angle = value.floatValue;

            if (angle < -90.0f) angle = -90.0f;
            if (angle > 90.0f) angle = 90.0f;

            [[LilyRomoController sharedController]
                headToAngleDegrees:angle];

            return [NSString stringWithFormat:
                @"Romo head to %.0f degrees",
                angle];
        }
    );
}

static id LilyCreateTurnAngleRomoTool(void) {
    id property =
        LilyCreateIntegerProperty(
            @"angle_deg",
            @-180,
            @180,
            @0
        );

    return LilyCreateRomoToolWithProperties(
        @"robot.turn_angle",
        @"Turn the physical Romo robot by an angle in degrees. Positive is left/counter-clockwise; negative is right/clockwise. Range -180 to 180.",
        property ? @[property] : @[],
        ^id(id args) {
            NSNumber *value =
                [args isKindOfClass:[NSDictionary class]]
                    ? args[@"angle_deg"]
                    : nil;

            if (!value) {
                return @"Missing required argument: angle_deg";
            }

            float angle = value.floatValue;

            if (angle == 0.0f) {
                return @"angle_deg must not be 0";
            }

            if (angle > 180.0f) angle = 180.0f;
            if (angle < -180.0f) angle = -180.0f;

            [[LilyRomoController sharedController]
                turnByAngleDegrees:angle];

            return [NSString stringWithFormat:
                @"Romo turning %.0f degrees",
                angle];
        }
    );
}

static id LilyCreateDistanceRomoTool(
    NSString *toolName,
    NSString *description,
    BOOL forward
) {
    id property =
        LilyCreateIntegerProperty(
            @"distance_cm",
            @1,
            @500,
            @1
        );

    return LilyCreateRomoToolWithProperties(
        toolName,
        description,
        property ? @[property] : @[],
        ^id(id args) {
            NSNumber *value =
                [args isKindOfClass:[NSDictionary class]]
                    ? args[@"distance_cm"]
                    : nil;

            if (!value) {
                return @"Missing required argument: distance_cm";
            }

            float distanceCm = value.floatValue;

            if (distanceCm <= 0.0f) {
                return @"distance_cm must be greater than 0";
            }

            if (distanceCm > 500.0f) {
                distanceCm = 500.0f;
            }

            if (forward) {
                [[LilyRomoController sharedController]
                    forwardDistanceCm:distanceCm];
            } else {
                [[LilyRomoController sharedController]
                    backwardDistanceCm:distanceCm];
            }

            return [NSString stringWithFormat:
                @"Romo %@ %.0f cm",
                forward ? @"moving forward" : @"moving backward",
                distanceCm];
        }
    );
}

static id LilyCreateStatusRomoTool(void) {
    return LilyCreateSimpleRomoTool(
        @"robot.status",
        @"Read the physical Romo robot status, including connection, battery percentage, and charging state.",
        ^id(id args) {
            (void)args;

            NSString *status =
                [[LilyRomoController sharedController]
                    statusText];

            LilyMCPWrite(
                [NSString stringWithFormat:
                    @"MCP-ROMO STATUS CALLBACK: %@",
                    status]
            );

            return status;
        }
    );
}

#pragma mark SharedMcpTool creation

static id LilyCreateRomoToolWithProperties(
    NSString *name,
    NSString *description,
    NSArray *properties,
    id (^callback)(id)
) {
    Class toolClass =
        NSClassFromString(@"SharedMcpTool");

    if (!toolClass) {
        LilyMCPWrite(
            @"MCP-ROMO TOOL: SharedMcpTool NOT FOUND"
        );
        return nil;
    }

    SEL initSel =
        NSSelectorFromString(
            @"initWithName:description:properties:userOnly:callback:"
        );

    if (![toolClass instancesRespondToSelector:initSel]) {
        LilyMCPWrite(
            @"MCP-ROMO TOOL: initializer NOT FOUND"
        );
        return nil;
    }

    /*
     * Verified initializer ABI:
     *
     * self, _cmd, name, description, properties,
     * userOnly, callback
     */
    typedef id (*ToolInitFn)(
        id,
        SEL,
        id,
        id,
        id,
        BOOL,
        id
    );

    ToolInitFn initFn =
        (ToolInitFn)objc_msgSend;

    id tool =
        initFn(
            [toolClass alloc],
            initSel,
            name,
            description,
            properties ?: @[],
            NO,
            callback
        );

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO TOOL: %@ %@",
            name,
            tool ? @"CREATED" : @"FAILED"]
    );

    return tool;
}

static id LilyCreateSimpleRomoTool(
    NSString *name,
    NSString *description,
    id (^callback)(id)
) {
    return LilyCreateRomoToolWithProperties(
        name,
        description,
        @[],
        callback
    );
}

#pragma mark Kotlin bridge

typedef void *(*LilySharedToKotlinFn)(
    id self,
    SEL _cmd,
    void **outNative
);

static void *LilySharedMcpToolToKotlin(id tool) {
    if (!tool) {
        LilyMCPWrite(
            @"MCP-ROMO TOKOTLIN: tool=NULL"
        );
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

    Class cls = object_getClass(tool);

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
        fn(
            tool,
            toKotlinSel,
            &outNative
        );

    void *nativeTool =
        outNative
            ? outNative
            : returnNative;

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO TOKOTLIN: objc=%p native=%p return=%p out=%p",
            tool,
            nativeTool,
            returnNative,
            outNative]
    );

    return nativeTool;
}

typedef void (*LilyMcpAddToolFn)(
    void *server,
    void *tool
);

static uintptr_t LilyFindSharedImageSlide(void);

static void LilyAddRomoToolNative(
    void *server,
    id objcTool
) {
    if (!server || !objcTool) {
        LilyMCPWrite(
            @"MCP-ROMO ADDTOOL: missing server/objcTool"
        );
        return;
    }

    /*
     * CRITICAL:
     *
     * objcTool is SharedMcpTool.
     * addTool expects Kotlin/Native McpTool.
     */
    void *nativeTool =
        LilySharedMcpToolToKotlin(objcTool);

    if (!nativeTool) {
        LilyMCPWrite(
            @"MCP-ROMO ADDTOOL: Shared_toKotlin returned NULL"
        );
        return;
    }

    /*
     * Callback lifetime:
     * retain the ObjC wrapper for the life of the MCP server.
     */
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

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO ADDTOOL BEGIN server=%p objc=%p native=%p target=0x%llx",
            server,
            objcTool,
            nativeTool,
            (unsigned long long)target]
    );

    /*
     * Verified McpTool layout:
     *
     * +0x00 typeinfo / kclass
     * +0x08 name
     * +0x10 description
     * +0x18 properties
     * +0x20 callback
     * +0x28 Boolean flag
     */
    uintptr_t t = (uintptr_t)nativeTool;

    uintptr_t v00 = *(uintptr_t *)(t + 0x00);
    uintptr_t v08 = *(uintptr_t *)(t + 0x08);
    uintptr_t v10 = *(uintptr_t *)(t + 0x10);
    uintptr_t v18 = *(uintptr_t *)(t + 0x18);
    uintptr_t v20 = *(uintptr_t *)(t + 0x20);
    uintptr_t v28 = *(uintptr_t *)(t + 0x28);

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO TOOL NATIVE=%p +00=0x%llx +08=0x%llx +10=0x%llx +18=0x%llx +20=0x%llx +28=0x%llx",
            nativeTool,
            (unsigned long long)v00,
            (unsigned long long)v08,
            (unsigned long long)v10,
            (unsigned long long)v18,
            (unsigned long long)v20,
            (unsigned long long)v28]
    );

    LilyMCPWrite(
        @"MCP-ROMO CALL ADDTOOL BEGIN"
    );

    /*
     * Verified ABI:
     * x0 = McpServer *
     * x1 = Kotlin/Native McpTool *
     *
     * DO NOT pass objcTool here.
     */
    ((LilyMcpAddToolFn)target)(
        server,
        nativeTool
    );

    LilyMCPWrite(
        @"MCP-ROMO CALL ADDTOOL RETURNED"
    );
}

#pragma mark Tool injection

static void *gLilyRomoInjectedServer = NULL;

static void LilyInjectRobotToolsIntoServer(void *server) {
    if (!server) return;

    if (gLilyRomoInjectedServer == server) {
        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO INJECT: already injected server=%p",
                server]
        );
        return;
    }

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO INJECT ENTER server=%p",
            server]
    );

    /*
     * IMPORTANT:
     * robot.forward and robot.backward themselves now accept
     * distance_cm. No separate forward_distance/backward_distance
     * tools are created.
     */
    id statusTool =
        LilyCreateStatusRomoTool();

    /*
     * Compatibility alias requested by user:
     * robot.satus -> same status callback/schema as robot.status.
     */
    id satusTool =
        LilyCreateSimpleRomoTool(
            @"robot.satus",
            @"Read the physical Romo robot status, including connection, battery percentage, and charging state.",
            ^id(id args) {
                (void)args;
                return [[LilyRomoController sharedController] statusText];
            }
        );

    id forwardTool =
        LilyCreateDistanceRomoTool(
            @"robot.forward",
            @"Move the physical Romo robot connected to Lily forward. Required distance_cm is the requested travel distance in centimeters, from 1 to 500.",
            YES
        );

    id backwardTool =
        LilyCreateDistanceRomoTool(
            @"robot.backward",
            @"Move the physical Romo robot connected to Lily backward. Required distance_cm is the requested travel distance in centimeters, from 1 to 500.",
            NO
        );

    id stopTool =
        LilyCreateSimpleRomoTool(
            @"robot.stop",
            @"Stop the physical Romo robot connected to Lily immediately.",
            ^id(id args) {
                (void)args;

                LilyRomoStopNoArgs();

                return @"Romo stopped";
            }
        );

    id leftTool =
        LilyCreateSimpleRomoTool(
            @"robot.turn_left",
            @"Turn the physical Romo robot left in place. Use this when the user asks Romo to turn left or quay trai.",
            ^id(id args) {
                (void)args;

                [[LilyRomoController sharedController]
                    turnLeft];

                return @"Romo turned left";
            }
        );

    id rightTool =
        LilyCreateSimpleRomoTool(
            @"robot.turn_right",
            @"Turn the physical Romo robot right in place. Use this when the user asks Romo to turn right or quay phai.",
            ^id(id args) {
                (void)args;

                [[LilyRomoController sharedController]
                    turnRight];

                return @"Romo turned right";
            }
        );

    id headUpTool =
        LilyCreateHeadUpRomoTool();

    id headDownTool =
        LilyCreateHeadDownRomoTool();

    id headToTool =
        LilyCreateHeadToRomoTool();

    id turnAngleTool =
        LilyCreateTurnAngleRomoTool();

    /*
     * Register every tool only after registerTools() has returned.
     */
    if (statusTool)
        LilyAddRomoToolNative(server, statusTool);

    if (satusTool)
        LilyAddRomoToolNative(server, satusTool);

    if (forwardTool)
        LilyAddRomoToolNative(server, forwardTool);

    if (backwardTool)
        LilyAddRomoToolNative(server, backwardTool);

    if (stopTool)
        LilyAddRomoToolNative(server, stopTool);

    if (leftTool)
        LilyAddRomoToolNative(server, leftTool);

    if (rightTool)
        LilyAddRomoToolNative(server, rightTool);

    if (headUpTool)
        LilyAddRomoToolNative(server, headUpTool);

    if (headDownTool)
        LilyAddRomoToolNative(server, headDownTool);

    if (headToTool)
        LilyAddRomoToolNative(server, headToTool);

    if (turnAngleTool)
        LilyAddRomoToolNative(server, turnAngleTool);

    gLilyRomoInjectedServer = server;

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO INJECT RETURNED server=%p; tools=status,satus,forward,backward,stop,turn_left,turn_right,head_up,head_down,head_to,turn_angle",
            server]
    );
}

#pragma mark Native registerTools hook

/*
 * Exact Shared.framework/build baseline:
 *
 * McpServer.registerTools = Shared + 0x126B040
 * McpServer.addTool     = Shared + 0x126CC88
 *
 * We deliberately patch registerTools, not addTool.
 *
 * Original registerTools prologue verified:
 *
 * e9 23 b9 6d fc 6f 01 a9
 * fa 67 02 a9 f8 5f 03 a9
 */

static BOOL gLilyMCPHookInstalled = NO;
static BOOL gLilyNativeRegisterToolsPatchInstalled = NO;
static uintptr_t gLilyNativeRegisterToolsAddress = 0;
static uintptr_t gLilyNativeRegisterToolsTrampoline = 0;
static uint8_t gLilyOriginalRegisterToolsBytes[16];

static pthread_mutex_t gLilyNativeHookLock =
    PTHREAD_MUTEX_INITIALIZER;

typedef void (*LilyMcpRegisterToolsFn)(
    void *server
);

static BOOL LilyProtectCodePage(
    void *address,
    BOOL writable
) {
    vm_address_t page =
        (vm_address_t)address
        & ~(vm_address_t)(vm_page_size - 1);

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
        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO PATCH: vm_protect failed kr=%d",
                kr]
        );
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

        if (
            name
            &&
            strstr(
                name,
                @"Shared.framework/Shared".UTF8String
            )
        ) {
            return
                (uintptr_t)_dyld_get_image_vmaddr_slide(i);
        }
    }

    return 0;
}

static BOOL LilyWriteBranch(
    void *address,
    uintptr_t destination
) {
    uintptr_t source =
        (uintptr_t)address;

    int64_t delta =
        (int64_t)destination
        - (int64_t)source;

    if (
        (delta & 0x3) != 0
        ||
        delta < -(128LL * 1024 * 1024)
        ||
        delta >= (128LL * 1024 * 1024)
    ) {
        LilyMCPWrite(
            @"MCP-ROMO PATCH: hook outside AArch64 B range"
        );
        return NO;
    }

    int64_t imm26 =
        delta >> 2;

    uint32_t instruction =
        0x14000000u
        |
        ((uint32_t)imm26 & 0x03ffffffu);

    if (!LilyProtectCodePage(address, YES)) {
        return NO;
    }

    memcpy(
        address,
        &instruction,
        sizeof(instruction)
    );

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
    uintptr_t target
) {
    if (gLilyNativeRegisterToolsTrampoline) {
        return YES;
    }

    vm_address_t page = 0;

    kern_return_t kr =
        vm_allocate(
            mach_task_self(),
            &page,
            vm_page_size,
            VM_FLAGS_ANYWHERE
        );

    if (kr != KERN_SUCCESS) {
        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO PATCH: vm_allocate trampoline failed kr=%d",
                kr]
        );
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

        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO PATCH: trampoline RW protect failed kr=%d",
                kr]
        );

        return NO;
    }

    memcpy(
        (void *)page,
        (void *)target,
        sizeof(gLilyOriginalRegisterToolsBytes)
    );

    uint8_t *jumpAt =
        (uint8_t *)page
        + sizeof(gLilyOriginalRegisterToolsBytes);

    uint32_t jump[2] = {
        0x58000050, /* ldr x16,#8 */
        0xD61F0200  /* br x16 */
    };

    uint64_t continuation =
        (uint64_t)(
            target
            + sizeof(gLilyOriginalRegisterToolsBytes)
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

        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO PATCH: trampoline RX protect failed kr=%d",
                kr]
        );

        return NO;
    }

    gLilyNativeRegisterToolsTrampoline =
        (uintptr_t)page;

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO PATCH: trampoline=%p continue=0x%llx",
            (void *)page,
            (unsigned long long)continuation]
    );

    return YES;
}

static void LilyNativeRegisterToolsHook(
    void *server
);

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

    if (
        memcmp(
            gLilyOriginalRegisterToolsBytes,
            expected,
            16
        ) != 0
    ) {
        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO PATCH: registerTools prologue mismatch @ 0x%llx",
                (unsigned long long)registerTarget]
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
            (vm_address_t)gLilyNativeRegisterToolsTrampoline,
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
        [NSString stringWithFormat:
            @"MCP-ROMO PATCH ENABLED: registerTools ONLY @ 0x%llx; addTool UNTOUCHED",
            (unsigned long long)registerTarget]
    );

    pthread_mutex_unlock(
        &gLilyNativeHookLock
    );

    return YES;
}

static void LilyNativeRegisterToolsHook(
    void *server
) {
    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO REGISTER ENTER server=%p",
            server]
    );

    uintptr_t trampoline =
        gLilyNativeRegisterToolsTrampoline;

    if (!trampoline) {
        LilyMCPWrite(
            @"MCP-ROMO ERROR: registerTools trampoline NULL"
        );
        return;
    }

    /*
     * Let the original Kotlin registerTools()
     * finish completely first.
     */
    ((LilyMcpRegisterToolsFn)trampoline)(
        server
    );

    LilyMCPWrite(
        [NSString stringWithFormat:
            @"MCP-ROMO REGISTER RETURN server=%p",
            server]
    );

    /*
     * Same native thread/context, after registerTools()
     * has returned.
     */
    if (server) {
        pthread_t tid = pthread_self();
        int isMain = pthread_main_np();

        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO BEFORE INJECT server=%p pthread=%p main=%d",
                server,
                (void *)tid,
                isMain]
        );

        LilyInjectRobotToolsIntoServer(
            server
        );

        LilyMCPWrite(
            [NSString stringWithFormat:
                @"MCP-ROMO AFTER INJECT server=%p pthread=%p main=%d",
                server,
                (void *)tid,
                isMain]
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

#pragma mark - Lily Romo Character Face

static RMCharacterFace *gLilyRomoFace = nil;
static BOOL gLilyRomoFaceInstalled = NO;

static void LilyHideLive2DViews(UIView *root) {
    if (!root) return;

    Class wkClass = NSClassFromString(@"WKWebView");

    if (wkClass && [root isKindOfClass:wkClass]) {
        WKWebView *web = (WKWebView *)root;
        NSURL *url = web.URL;

        if (url &&
            [[url.scheme lowercaseString]
                isEqualToString:@"live2dasset"]) {

            NSLog(
                @"[Lily][RomoFace] Hiding Live2D WKWebView: %@",
                url.absoluteString
            );

            web.hidden = YES;
            web.alpha = 0.0;
        }

        return;
    }

    NSArray<UIView *> *subviews = [root.subviews copy];

    for (UIView *subview in subviews) {
        LilyHideLive2DViews(subview);
    }
}

static void LilyInstallRomoFace(UIViewController *hostVC) {
    if (!hostVC) {
        NSLog(@"[Lily][RomoFace] ERROR: hostVC is nil");
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (gLilyRomoFaceInstalled) {
            return;
        }

        UIView *hostView = hostVC.view;

        if (!hostView) {
            NSLog(@"[Lily][RomoFace] ERROR: hostView is nil");
            return;
        }

        NSLog(
            @"[Lily][RomoFace] Host VC = %@",
            NSStringFromClass([hostVC class])
        );

        NSLog(
            @"[Lily][RomoFace] Host view = %@",
            NSStringFromClass([hostView class])
        );

        LilyHideLive2DViews(hostView);

        gLilyRomoFace =
            [RMCharacterFace faceWithCharacterType:RMCharacterRomo];

        if (!gLilyRomoFace) {
            NSLog(
                @"[Lily][RomoFace] ERROR: "
                @"faceWithCharacterType returned nil"
            );
            return;
        }

        [hostVC addChildViewController:gLilyRomoFace];

        UIView *faceView = gLilyRomoFace.view;

        if (!faceView) {
            NSLog(
                @"[Lily][RomoFace] ERROR: face view is nil"
            );

            [gLilyRomoFace removeFromParentViewController];
            gLilyRomoFace = nil;
            return;
        }

        faceView.frame = hostView.bounds;
        faceView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [hostView addSubview:faceView];

        [gLilyRomoFace didMoveToParentViewController:hostVC];

        gLilyRomoFace.emotion = RMCharacterEmotionHappy;
        gLilyRomoFace.expression = RMCharacterExpressionHappy;

        gLilyRomoFaceInstalled = YES;

        NSLog(
            @"[Lily][RomoFace] RMCharacterFace INSTALLED"
        );

        NSLog(
            @"[Lily][RomoFace] frame = %@",
            NSStringFromCGRect(faceView.frame)
        );
    });
}

#pragma mark - LilySharedBridge

@implementation LilySharedBridge

+ (BOOL)initializeSharedWithAPIKey:(NSString *)apiKey
                             wsURL:(NSString *)wsURL
                            otaURL:(NSString *)otaURL {
    Class cls =
        NSClassFromString(@"SharedIosModuleKt");

    if (!cls) return NO;

    SEL sel =
        NSSelectorFromString(
            @"doInitKoinApiEncryptionKey:wsUrl:otaUrl:"
        );

    if (![cls respondsToSelector:sel]) {
        return NO;
    }

    /*
     * Install the MCP bridge before Koin starts
     * constructing the live McpServer.
     */
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

    /*
     * Start Romo control.
     */
    [[LilyRomoController sharedController] start];

    /*
     * Keep the old reflection diagnostics.
     */
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

    if (![cls respondsToSelector:sel]) {
        return nil;
    }

    typedef UIViewController *(*MainFn)(
        id,
        SEL
    );

    MainFn fn =
        (MainFn)objc_msgSend;

    UIViewController *vc =
        fn(
            cls,
            sel
        );

    if (!vc) {
        NSLog(
            @"[Lily][RomoFace] ERROR: "
            @"MainViewController returned nil"
        );

        return nil;
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            LilyInstallRomoFace(vc);
        }
    );

    return vc;
}

@end
