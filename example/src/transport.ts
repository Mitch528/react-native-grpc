/* eslint-disable eslint-comments/no-unlimited-disable */
import { ClientStreamingCall, DuplexStreamingCall, mergeExtendedRpcOptions, MethodInfo, RpcOptions, RpcOutputStreamController, RpcStatus, RpcTransport, ServerStreamingCall, UnaryCall } from '@protobuf-ts/runtime-rpc';
import { GrpcClient, GrpcMetadata } from '@mitch528/react-native-grpc';
import { AbortSignal } from 'abort-controller';

/* eslint-disable */

function makePath(method: MethodInfo): string {
  return `/${method.service.typeName}/${method.name}`;
}

export class RNGrpcTransport implements RpcTransport {
  mergeOptions(options?: Partial<RpcOptions>): RpcOptions {
    return mergeExtendedRpcOptions({}, options);
  }
  unary<I extends object, O extends object>(method: MethodInfo<I, O>, input: I, options: RpcOptions): UnaryCall<I, O> {
    const headers = options.meta || {};
    const data = method.I.toBinary(input, options.binaryOptions);
    const grpcMethod = makePath(method);

    const call = GrpcClient.unaryCall(
      grpcMethod,
      data,
      headers as GrpcMetadata
    );

    if (options.abort) {
      const signal = options.abort as AbortSignal;

      signal.addEventListener('abort', () => {
        call.cancel();
      });
    }

    const response = call.response.then(resp => method.O.fromBinary(resp));
    const status = call.trailers.then<RpcStatus, RpcStatus>(() => ({
      code: 0,
      detail: '',
    } as any), ({ error, code }) => ({
      code: code,
      detail: error
    }));

    return new UnaryCall(method, headers, input, call.headers, response, status, call.trailers);
  }
  serverStreaming<I extends object, O extends object>(method: MethodInfo<I, O>, input: I, options: RpcOptions): ServerStreamingCall<I, O> {
    const headers = options.meta || {};
    const data = method.I.toBinary(input, options.binaryOptions);
    const grpcMethod = makePath(method);

    const call = GrpcClient.serverStreamCall(grpcMethod, data, headers as GrpcMetadata);
    const status = call.trailers.then<RpcStatus, RpcStatus>(() => ({
      code: 0,
      detail: '',
    } as any), ({ error, code }) => ({
      code: code,
      detail: error
    }));

    const outStream = new RpcOutputStreamController<O>();

    call.responses.on('data', (data) => {
      outStream.notifyMessage(method.O.fromBinary(data));
    });

    call.responses.on('complete', () => {
      if (!outStream.closed) {
        outStream.notifyComplete();
      }
    });

    call.responses.on('error', (reason) => {
      outStream.notifyError(reason);
    });

    if (options.abort) {
      const signal = options.abort as AbortSignal;

      signal.addEventListener('abort', () => {
        call.cancel();
      });
    }

    return new ServerStreamingCall(method, headers, input, call.headers, outStream, status, call.trailers);
  }
  clientStreaming<I extends object, O extends object>(method: MethodInfo<I, O>, options: RpcOptions): ClientStreamingCall<I, O> {
    throw new Error('Method not implemented.');
  }
  duplex<I extends object, O extends object>(method: MethodInfo<I, O>, options: RpcOptions): DuplexStreamingCall<I, O> {
    throw new Error('Method not implemented.');
  }
}
