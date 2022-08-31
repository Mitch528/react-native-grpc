#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface Grpc : RCTEventEmitter <RCTBridgeModule>

@property (nonatomic, copy) NSString* grpcHost;
@property (nonatomic, copy) NSNumber* grpcResponseSizeLimit;
@property (nonatomic, assign) BOOL grpcInsecure;

@end
