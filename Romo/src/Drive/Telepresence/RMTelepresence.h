//
//  RMTelepresence.h
//  Romo
//
//  Created on 11/7/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#ifndef Romo_RMTelepresence_h
#define Romo_RMTelepresence_h

extern NSString *const kTelepresenceErrorDomain;

typedef enum {
    RMTelepresenceErrorCodeConnectionFailed = 1000,
    RMTelepresenceErrorCodeConnectionTooManyParticipants = 1001,
    RMTelepresenceErrorCodeConnectionUpdateRequired = 1002,
    RMTelepresenceErrorCodeConnectionSubscriberFailed = 1003,
} RMTelepresenceErrorCode;

typedef enum {
    RMTelepresenceCallErrorCodeConnectionFailed = 2000,
    RMTelepresenceCallErrorCodeFailed = 2001
} RMTelepresenceCallErrorCode;

typedef enum {
    RMTelepresenceDriveCommandStop      = 0,
    RMTelepresenceDriveCommandForward   = 100,
    RMTelepresenceDriveCommandBackward  = 101,
    RMTelepresenceDriveCommandLeft      = 102,
    RMTelepresenceDriveCommandRight     = 103
} RMTelepresenceDriveCommand;

typedef enum {
    RMTelepresenceModeCommandVideo      = 200,
    RMTelepresenceModeCommandRomo       = 201
} RMTelepresenceModeCommand;

#endif
