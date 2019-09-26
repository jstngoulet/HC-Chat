//
//  SBDFileMessage.h
//  SendBirdSDK
//
//  Created by Jed Gyeong on 6/29/16.
//  Copyright © 2016 SENDBIRD.COM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBDBaseMessage.h"
#import "SBDBaseChannel.h"
#import "SBDSender.h"

/**
 The `SBDThumbnailSize` class represents the thumbnail size of thumbnail.
 */
@interface SBDThumbnailSize : NSObject <NSCopying>

/**
 The max size of the thumbnail.
 */
@property (nonatomic, readonly) CGSize maxSize;

/**
 Makes `SBDThumbnailSize` object with `CGSize`.

 @param size The max size of the thumbnail.
 @return `SBDThumbnailSize` object.
 */
+ (nullable instancetype)makeWithMaxCGSize:(CGSize)size;

/**
 Makes `SBDThumbnailSize` object with width and height.

 @param width The max width of the thumbnail.
 @param height The max height of the thumbnail.
 @return `SBDThumbnailSize` object.
 */
+ (nullable instancetype)makeWithMaxWidth:(CGFloat)width
                                maxHeight:(CGFloat)height;


@end


/**
 The `SBDThumbnail` class represents the thumbnail in the file message.
 */
@interface SBDThumbnail : NSObject <NSCopying>

/**
 The url of the thumbnail.
 */
@property (strong, nonatomic, readonly, nonnull, getter = url) NSString *url;


/**
 The maximum size of the thumbnail.
 */
@property (nonatomic, readonly) CGSize maxSize;


/**
 The real size of the thumbnail.
 */
@property (nonatomic, readonly) CGSize realSize;

/**
 Returns url
 
 @return Image url.
 */
- (nonnull NSString *)url;

@end

/**
 *  The `SBDFileMessage` class represents the file message which is generated by a user via [`sendFileMessageWithBinaryData:filename:type:size:data:completionHandler:`](../Classes/SBDBaseChannel.html#//api/name/sendFileMessageWithBinaryData:filename:type:size:data:completionHandler:), [`sendFileMessageWithUrl:size:type:data:completionHandler:`](../Classes/SBDBaseChannel.html#//api/name/sendFileMessageWithUrl:size:type:data:completionHandler:) or [`sendFileMessageWithBinaryData:filename:type:size:data:progressHandler:completionHandler:`](../Classes/SBDBaseChannel.html#//api/name/sendFileMessageWithBinaryData:filename:type:size:data:progressHandler:completionHandler:) in `SBDBaseChannel` or [Platform API](https://docs.sendbird.com/platform#messages_3_send). This class doesn't include a binary <span>data</span> for the file. It is just a URL.
 */
@interface SBDFileMessage : SBDBaseMessage

/**
 *  Sender of the message. This is represented by `SBDSender` class.
 */
@property (strong, nonatomic, nullable, getter = sender) SBDSender *sender;

/**
 *  The file URL.
 */
@property (strong, nonatomic, readonly, nonnull, getter = url) NSString *url;

/**
 *  The name of file.
 */
@property (strong, nonatomic, readonly, nonnull) NSString *name;

/**
 *  The size of file.
 */
@property (atomic, readonly) NSUInteger size;

/**
 *  The type of file.
 */
@property (strong, nonatomic, readonly, nonnull) NSString *type;

/**
 *  Request ID for ACK.
 */
@property (strong, nonatomic, readonly, nullable) NSString *requestId;

/**
 Image thumbnails.
 */
@property (strong, nonatomic, readonly, nullable) NSArray<SBDThumbnail *> *thumbnails;

/**
 *  Represents the dispatch state of the message.
 *  If message is not dispatched completely to the SendBird server, the value is `SBDMessageRequestStatePending`.
 *  If failed to send the message, the value is `SBDMessageRequestStateFailed`.
 *  And if success to send the message, the value is `SBDMessageRequestStateSucceeded`.
 *
 *  @since 3.0.141
 */
@property (assign, nonatomic, readonly) SBDMessageRequestState requestState;

/**
 Represents target user ids to mention when success to send the message.
 This value is valid only when the message is a pending message or failed message.
 If the message is a succeeded message, see `mentionedUserIds`
 
 @since 3.0.147
 @see see `mentionedUserIds` when the message is a succeeded message.
 */
@property (strong, nonatomic, readonly, nonnull) NSArray<NSString *> *requestedMentionUserIds;

/**
 *  Builds file message with the information which is releated to file.
 *
 *  @param url        The file URL.
 *  @param name       The <span>name</span> of file.
 *  @param size       The <span>size</span> of file.
 *  @param type       The <span>type</span> of file.
 *  @param data       The custom <span>data</span> for file.
 *  @param requestId  Request ID for ACK.
 *  @param sender     Sender of the message.
 *  @param channel    The channel which the file message is sent.
 *  @param customType Custom message type.
 *  @return File message object with request ID.
 *
 *  @deprecated in 3.0.116 DO NOT USE THIS METHOD.
 */
+ (nullable NSMutableDictionary<NSString *, NSObject *> *)buildWithFileUrl:(NSString * _Nonnull)url
                                                                      name:(NSString * _Nullable)name
                                                                      size:(NSUInteger)size
                                                                      type:(NSString * _Nonnull)type
                                                                      data:(NSString * _Nullable)data
                                                                 requestId:(NSString * _Nullable)requestId
                                                                    sender:(SBDUser * _Nonnull)sender
                                                                   channel:(SBDBaseChannel * _Nonnull)channel
                                                                customType:(NSString * _Nullable)customType
DEPRECATED_ATTRIBUTE;

/**
 *  Builds file message with the information which is releated to file.
 *
 *  @param url        The file URL.
 *  @param name       The <span>name</span> of file.
 *  @param size       The <span>size</span> of file.
 *  @param type       The <span>type</span> of file.
 *  @param data       The custom <span>data</span> for file.
 *  @param requestId  Request ID for ACK.
 *  @param sender     Sender of the message.
 *  @param channel    The channel which the file message is sent.
 *  @param customType Custom message type.
 *  @param thumbnailSizes Thumbnail sizes to require.
 *  @return File message object with request ID.
 *
 *  @deprecated in 3.0.116 DO NOT USE THIS METHOD.
 */
+ (nullable NSMutableDictionary<NSString *, NSObject *> *)buildWithFileUrl:(NSString * _Nonnull)url
                                                                      name:(NSString * _Nullable)name
                                                                      size:(NSUInteger)size
                                                                      type:(NSString * _Nonnull)type
                                                                      data:(NSString * _Nullable)data
                                                                 requestId:(NSString * _Nullable)requestId
                                                                    sender:(SBDUser * _Nonnull)sender
                                                                   channel:(SBDBaseChannel * _Nonnull)channel
                                                                customType:(NSString * _Nullable)customType
                                                            thumbnailSizes:(NSArray<SBDThumbnailSize *> * _Nullable)thumbnailSizes
DEPRECATED_ATTRIBUTE;

/**
 Returns url
 
 @return Image url.
 */
- (nonnull NSString *)url;

/**
 Serializes message object.
 
 @return Serialized <span>data</span>.
 */
- (nullable NSData *)serialize;

/**
 Returns sender.
 
 @return Sender of the message.
 */
- (nonnull SBDSender *)sender;

@end
