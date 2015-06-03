//
//  Message.h
//  Romo
//

#import "RMSerializable.h"

#pragma mark - Message --

/**
 * Wraps data with its description, allowing it to be passed between objects
 * or devices easily. Can be used both for passing messages around the Application,
 * or for sending them over the Network.
 */
@interface RMMessage : RMSerializable

#pragma mark - Properties --

/// An NSInteger describing the Message's content to its recipient.
@property (nonatomic) NSInteger content;

/// An NSData containing the additional data held by the Message.
@property (nonatomic, copy) NSData *package;

#pragma mark - Creation --

/**
 * Creates an autoreleased Message instance with no package.
 * @return An autoreleased Message object.
 * @param content The content to identify this Message.
 */
+ (RMMessage *)messageWithContent:(NSInteger)content;

/**
 * Creates an autoreleased Message instance with the attached package.
 * @return An autoreleased Message object.
 * @param content The content to identify this Message.
 * @param data The data to use as the Message's package.
 */
+ (RMMessage *)messageWithContent:(NSInteger)content data:(NSData *)data;

/**
 * Creates an autoreleased Message instance, converting the provided string into its package.
 * @return An autoreleased Message object.
 * @param content The content to identify this Message.
 * @param string An NSString to convert into the Message's package.
 */
+ (RMMessage *)messageWithContent:(NSInteger)content string:(NSString *)string;

/**
 * Creates an autoreleased Message instance, serialzing the provided object into its package.
 * @return content An autoreleased Message object.
 * @param content The content to identify this Message.
 * @param package A Serializable object to serialize into the Message's package.
 */
+ (RMMessage *)messageWithContent:(NSInteger)content package:(id<Serializable>)package;

#pragma mark - Initialization --

/**
 * Initializes a Message instance with no package.
 * @return An initialized Message object.
 * @param content The content to identify this Message.
 */
- (id)initWithContent:(NSInteger)content;

/**
 * Initializes a Message instance with the attached package.
 * @return An initialized Message object.
 * @param content The content to identify this Message.
 * @param data The data for the Message's package.
 */
- (id)initWithContent:(NSInteger)content data:(NSData *)data;

/**
 * Initializes a Message instance, converting the provided string into its package.
 * @return An initialized Message object.
 * @param content The content to identify this Message.
 * @param string An NSString to convert into the Message's package.
 */
- (id)initWithContent:(NSInteger)content string:(NSString *)string;

/**
 * Initializes a Message instance, serialzing the provided object into its package.
 * @return content An initialized Message object.
 * @param content The content to identify this Message.
 * @param package A Serializable object to serialize into the Message's package.
 */
- (id)initWithContent:(NSInteger)content package:(id<Serializable>)package;

@end
