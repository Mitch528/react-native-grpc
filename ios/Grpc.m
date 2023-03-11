#import "React/RCTBridgeModule.h"
#import "RCTEventEmitter.h"

@interface RCT_EXTERN_MODULE(Grpc, RCTEventEmitter)

RCT_EXTERN_METHOD(setGrpcSettings:
                  (nonnull NSNumber *) clientId options: (NSDictionary*) options)

RCT_EXTERN_METHOD(destroyClient:
                  (NSString *)host)

RCT_EXTERN_METHOD(unaryCall:
    (nonnull NSNumber *) callId clientId: (nonnull NSNumber *) clientId path: (NSString*) path obj: (NSDictionary*) obj headers:(NSDictionary*) headers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(serverStreamingCall:
    (nonnull NSNumber *) callId clientId: (nonnull NSNumber *) clientId path: (NSString*) path obj: (NSDictionary*) obj headers:(NSDictionary*) headers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(clientStreamingCall:
    (nonnull NSNumber *) callIdclientId: (nonnull NSNumber *) path: (NSString*) path obj: (NSDictionary*) obj headers:(NSDictionary*) headers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(finishClientStreaming:
    (nonnull NSNumber *) callId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(cancelGrpcCall:
    (nonnull NSNumber *) callId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
@end
