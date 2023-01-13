#import "React/RCTBridgeModule.h"
#import "RCTEventEmitter.h"

@interface RCT_EXTERN_MODULE(Grpc, RCTEventEmitter)

RCT_EXTERN_METHOD(setInsecure:
    (nonnull NSNumber *)insecure)

RCT_EXTERN_METHOD(setResponseSizeLimit:
    (nonnull NSNumber *)limit)

RCT_EXTERN_METHOD(setHost:
    (NSString *) host)

RCT_EXTERN_METHOD(setCompression:
    (nonnull NSNumber *) enabled
        compressorName: (NSString *) compressorName
        limit: (NSString *) limit)

RCT_EXTERN_METHOD(setKeepalive:
(nonnull NSNumber *) enabled
        time: (nonnull NSNumber *) time
        timeout: (nonnull NSNumber *) timeout
)

RCT_EXTERN_METHOD(getIsInsecure:
    (RCTPromiseResolveBlock) resolve reject:
    (RCTPromiseRejectBlock) reject)

RCT_EXTERN_METHOD(getResponseSizeLimit:
    (RCTPromiseResolveBlock) resolve reject:
    (RCTPromiseRejectBlock) reject)

RCT_EXTERN_METHOD(getHost:
    (RCTPromiseResolveBlock) resolve reject:
    (RCTPromiseRejectBlock) reject)

RCT_EXTERN_METHOD(unaryCall:
    (nonnull NSNumber *) callId path: (NSString*) path obj: (NSDictionary*) obj headers:(NSDictionary*) headers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(serverStreamingCall:
    (nonnull NSNumber *) callId path: (NSString*) path obj: (NSDictionary*) obj headers:(NSDictionary*) headers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(clientStreamingCall:
    (nonnull NSNumber *) callId path: (NSString*) path obj: (NSDictionary*) obj headers:(NSDictionary*) headers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(finishClientStreaming:
    (nonnull NSNumber *) callId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(cancelGrpcCall:
    (nonnull NSNumber *) callId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
@end