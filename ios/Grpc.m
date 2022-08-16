#import "Grpc.h"
#import <GRPCClient/GRPCCall.h>
#import <GRPCClient/GRPCTransport.h>

@interface GrpcResponseHandler : NSObject <GRPCResponseHandler>

- (instancetype)initWithInitialMetadataCallback:(void (^)(NSDictionary *))initialMetadataCallback
                                messageCallback:(void (^)(id))messageCallback
                                  closeCallback:(void (^)(NSDictionary *, NSError *))closeCallback
                              writeDataCallback:(void (^)(void))writeDataCallback;

- (instancetype)initWithInitialMetadataCallback:(void (^)(NSDictionary *))initialMetadataCallback
                                messageCallback:(void (^)(id))messageCallback
                                  closeCallback:(void (^)(NSDictionary *, NSError *))closeCallback;

@end

@implementation GrpcResponseHandler {
    void (^_initialMetadataCallback)(NSDictionary *);

    void (^_messageCallback)(id);

    void (^_closeCallback)(NSDictionary *, NSError *);

    void (^_writeDataCallback)(void);

    dispatch_queue_t _dispatchQueue;
}

- (instancetype)initWithInitialMetadataCallback:(void (^)(NSDictionary *))initialMetadataCallback
                                messageCallback:(void (^)(id))messageCallback
                                  closeCallback:(void (^)(NSDictionary *, NSError *))closeCallback
                              writeDataCallback:(void (^)(void))writeDataCallback {
    if ((self = [super init])) {
        _initialMetadataCallback = initialMetadataCallback;
        _messageCallback = messageCallback;
        _closeCallback = closeCallback;
        _writeDataCallback = writeDataCallback;
        _dispatchQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)initWithInitialMetadataCallback:(void (^)(NSDictionary *))initialMetadataCallback
                                messageCallback:(void (^)(id))messageCallback
                                  closeCallback:(void (^)(NSDictionary *, NSError *))closeCallback {
    return [self initWithInitialMetadataCallback:initialMetadataCallback
                                 messageCallback:messageCallback
                                   closeCallback:closeCallback
                               writeDataCallback:nil];
}

- (void)didReceiveInitialMetadata:(NSDictionary *)initialMetadata {
    if (self->_initialMetadataCallback) {
        self->_initialMetadataCallback(initialMetadata);
    }
}

- (void)didReceiveRawMessage:(id)message {
    if (self->_messageCallback) {
        self->_messageCallback(message);
    }
}

- (void)didCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata error:(NSError *)error {
    if (self->_closeCallback) {
        self->_closeCallback(trailingMetadata, error);
    }
}

- (void)didWriteData {
    if (self->_writeDataCallback) {
        self->_writeDataCallback();
    }
}

- (dispatch_queue_t)dispatchQueue {
    return _dispatchQueue;
}

@end

@implementation Grpc {
    bool hasListeners;
    NSMutableDictionary<NSNumber *, GRPCCall2 *> *calls;
}

- (instancetype)init {
    if (self = [super init]) {
        calls = [[NSMutableDictionary alloc] init];
    }

    return self;
}

// Will be called when this module's first listener is added.
- (void)startObserving {
    hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
- (void)stopObserving {
    hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"grpc-call"];
}

- (GRPCCallOptions *)getCallOptionsWithHeaders:(NSDictionary *)headers {
    GRPCMutableCallOptions *options = [[GRPCMutableCallOptions alloc] init];
    options.initialMetadata = headers;
    options.transport = self.grpcInsecure ? GRPCDefaultTransportImplList.core_insecure : GRPCDefaultTransportImplList.core_secure;

    return options;
}

RCT_EXPORT_METHOD(getHost:
    (RCTPromiseResolveBlock) resolve) {
    resolve(self.grpcHost);
}

RCT_EXPORT_METHOD(getIsInsecure:
    (RCTPromiseResolveBlock) resolve) {
    resolve([NSNumber numberWithBool:self.grpcInsecure]);
}

RCT_EXPORT_METHOD(setHost:
    (NSString *) host) {
    self.grpcHost = host;
}


RCT_EXPORT_METHOD(setInsecure:
    (nonnull NSNumber*) insecure) {
    self.grpcInsecure = [insecure boolValue];
}

RCT_EXPORT_METHOD(unaryCall:
    (nonnull NSNumber*)callId
        path:(NSString*)path
        obj:(NSDictionary*)obj
        headers:(NSDictionary*)headers
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject) {
    NSData *requestData = [[NSData alloc] initWithBase64EncodedString:[obj valueForKey:@"data"] options:NSDataBase64DecodingIgnoreUnknownCharacters];

    GRPCCall2 *call = [self startGrpcCallWithId:callId path:path headers:headers];

    [call writeData:requestData];
    [call finish];

    [calls setObject:call forKey:callId];

    resolve([NSNull null]);
}

RCT_EXPORT_METHOD(serverStreamingCall:
    (nonnull NSNumber*)callId
        path:(NSString*)path
        obj:(NSDictionary*)obj
        headers:(NSDictionary*)headers
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject) {
    NSData *requestData = [[NSData alloc] initWithBase64EncodedString:[obj valueForKey:@"data"] options:NSDataBase64DecodingIgnoreUnknownCharacters];

    GRPCCall2 *call = [self startGrpcCallWithId:callId path:path headers:headers];

    [call writeData:requestData];
    [call finish];

    [calls setObject:call forKey:callId];

    resolve([NSNull null]);
}

RCT_EXPORT_METHOD(cancelGrpcCall:
    (nonnull NSNumber*)callId
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject) {
    GRPCCall2 *call = [calls objectForKey:callId];

    if (call != nil) {
        [call cancel];

        resolve([NSNumber numberWithBool:true]);
    } else {
        resolve([NSNumber numberWithBool:false]);
    }
}

RCT_EXPORT_METHOD(clientStreamingCall:
    (nonnull NSNumber*)callId
        path:(NSString*)path
        obj:(NSDictionary*)obj
        headers:(NSDictionary*)headers
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject) {
    NSData *requestData = [[NSData alloc] initWithBase64EncodedString:[obj valueForKey:@"data"] options:NSDataBase64DecodingIgnoreUnknownCharacters];

    GRPCCall2 *call = [calls objectForKey:callId];

    if (call == nil) {
        call = [self startGrpcCallWithId:callId path:path headers:headers];

        [calls setObject:call forKey:callId];
    }

    [call writeData:requestData];

    resolve([NSNull null]);
}

RCT_EXPORT_METHOD(finishClientStreaming:
    (nonnull NSNumber*)callId
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject) {
    GRPCCall2 *call = [calls objectForKey:callId];

    if (call != nil) {
        [call finish];

        resolve([NSNumber numberWithBool:true]);
    } else {
        resolve([NSNumber numberWithBool:false]);
    }
}

- (GRPCCall2 *)startGrpcCallWithId:(NSNumber *)callId path:(NSString *)path headers:(NSDictionary *)headers {
    GRPCRequestOptions *requestOptions = [[GRPCRequestOptions alloc] initWithHost:self.grpcHost
                                                                             path:path
                                                                           safety:GRPCCallSafetyDefault];

    GRPCCallOptions *callOptions = [self getCallOptionsWithHeaders:headers];

    GrpcResponseHandler *handler = [[GrpcResponseHandler alloc] initWithInitialMetadataCallback:^(NSDictionary *initialMetadata) {
                if (self->hasListeners) {
                    NSDictionary *responseHeaders = [[NSMutableDictionary alloc] initWithDictionary:initialMetadata];

                    [responseHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *exit) {
                        if ([object isKindOfClass:[NSData class]]) {
                            [responseHeaders setValue:[object base64EncodedStringWithOptions:0] forKey:key];
                        }
                    }];

                    NSDictionary *event = @{
                            @"id": callId,
                            @"type": @"headers",
                            @"payload": responseHeaders,
                    };

                    [self sendEventWithName:@"grpc-call" body:event];
                }
            }
                                                                                messageCallback:^(id message) {
                                                                                    NSData *data = (NSData *) message;

                                                                                    if (self->hasListeners) {
                                                                                        NSDictionary *event = @{
                                                                                                @"id": callId,
                                                                                                @"type": @"response",
                                                                                                @"payload": [data base64EncodedStringWithOptions:nil],
                                                                                        };

                                                                                        [self sendEventWithName:@"grpc-call" body:event];
                                                                                    }
                                                                                }
                                                                                  closeCallback:^(NSDictionary *trailingMetadata, NSError *error) {
                                                                                      [calls removeObjectForKey:callId];

                                                                                      NSDictionary *responseTrailers = [[NSMutableDictionary alloc] initWithDictionary:trailingMetadata];

                                                                                      [responseTrailers enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *exit) {
                                                                                          if ([object isKindOfClass:[NSData class]]) {
                                                                                              [responseTrailers setValue:[object base64EncodedStringWithOptions:0] forKey:key];
                                                                                          }
                                                                                      }];

                                                                                      if (self->hasListeners) {
                                                                                          if (error != nil) {
                                                                                              NSDictionary *event = @{
                                                                                                      @"id": callId,
                                                                                                      @"type": @"error",
                                                                                                      @"error": error.localizedDescription,
                                                                                                      @"code": [NSNumber numberWithLong:error.code],
                                                                                                      @"trailers": responseTrailers,
                                                                                              };

                                                                                              [self sendEventWithName:@"grpc-call" body:event];
                                                                                          } else {
                                                                                              NSDictionary *event = @{
                                                                                                      @"id": callId,
                                                                                                      @"type": @"trailers",
                                                                                                      @"payload": responseTrailers,
                                                                                              };

                                                                                              [self sendEventWithName:@"grpc-call" body:event];
                                                                                          }
                                                                                      }
                                                                                  }
    ];

    GRPCCall2 *call = [[GRPCCall2 alloc] initWithRequestOptions:requestOptions
                                                responseHandler:handler
                                                    callOptions:callOptions];

    [call start];

    return call;
}

RCT_EXPORT_MODULE()

@end
