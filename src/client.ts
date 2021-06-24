import { AbortController, AbortSignal } from 'abort-controller';
import { fromByteArray, toByteArray } from 'base64-js';
import { NativeEventEmitter, NativeModules } from 'react-native';
import { GrpcError } from './errors';
import {
  GrpcServerStreamingCall,
  ServerOutputStream,
} from './server-streaming';
import { GrpcMetadata } from './types';
import { GrpcUnaryCall } from './unary';

type GrpcRequestObject = {
  data: string;
};

type GrpcType = {
  getHost: () => Promise<string>;
  getIsInsecure: () => Promise<boolean>;
  setHost(host: string): void;
  setInsecure(insecure: boolean): void;
  unaryCall(
    id: number,
    path: string,
    obj: GrpcRequestObject,
    requestHeaders?: GrpcMetadata
  ): Promise<void>;
  serverStreamingCall(
    id: number,
    path: string,
    obj: GrpcRequestObject,
    requestHeaders?: GrpcMetadata
  ): Promise<void>;
  cancelGrpcCall: (id: number) => Promise<boolean>;
  clientStreamingCall(
    id: number,
    path: string,
    obj: GrpcRequestObject,
    requestHeaders?: GrpcMetadata
  ): Promise<void>;
  finishClientStreaming(id: number): Promise<void>;
};

type GrpcEventType = 'response' | 'error' | 'headers' | 'trailers';

/* prettier-ignore */
type GrpcEventPayload =
  {
    type: 'response';
    payload: string;
  } | {
    type: 'error';
    error: string;
    code?: number;
  } | {
    type: 'headers';
    payload: GrpcMetadata;
  } | {
    type: 'trailers';
    payload: GrpcMetadata;
  } | {
    type: 'status';
    payload: number;
  };

type GrpcEvent = {
  id: number;
  type: GrpcEventType;
} & GrpcEventPayload;

const { Grpc } = NativeModules as { Grpc: GrpcType };

const Emitter = new NativeEventEmitter(NativeModules.Grpc);

type Deferred<T> = {
  promise: Promise<T>;
  resolve: (value: T) => void;
  reject: (reason: any) => void;
};

type DeferredCalls = {
  headers?: Deferred<GrpcMetadata>;
  response?: Deferred<Uint8Array>;
  trailers?: Deferred<GrpcMetadata>;
  data?: ServerOutputStream;
};

type DeferredCallMap = {
  [id: number]: DeferredCalls;
};

function createDeferred<T>(signal: AbortSignal) {
  let completed = false;

  const deferred: Deferred<T> = {} as any;

  deferred.promise = new Promise<T>((resolve, reject) => {
    deferred.resolve = (value) => {
      completed = true;

      resolve(value);
    };
    deferred.reject = (reason) => {
      completed = true;

      reject(reason);
    };
  });

  signal.addEventListener('abort', () => {
    if (!completed) {
      deferred.reject('aborted');
    }
  });

  return deferred;
}

let idCtr = 1;

const deferredMap: DeferredCallMap = {};

function handleGrpcEvent(event: GrpcEvent) {
  const deferred = deferredMap[event.id];

  if (deferred) {
    switch (event.type) {
      case 'headers':
        deferred.headers?.resolve(event.payload);
        break;
      case 'response':
        const data = toByteArray(event.payload);

        deferred.data?.notifyData(data);
        deferred.response?.resolve(data);
        break;
      case 'trailers':
        deferred.trailers?.resolve(event.payload);
        deferred.data?.notifyComplete();

        delete deferredMap[event.id];
        break;
      case 'error':
        const error = new GrpcError(event.error, event.code);

        deferred.headers?.reject(error);
        deferred.trailers?.reject(error);
        deferred.response?.reject(error);
        deferred.data?.noitfyError(error);

        delete deferredMap[event.id];
        break;
    }
  }
}

function getId(): number {
  return idCtr++;
}

export class GrpcClient {
  constructor() {
    Emitter.addListener('grpc-call', handleGrpcEvent);
  }
  destroy() {
    Emitter.removeAllListeners('grpc-call');
  }
  getHost(): Promise<string> {
    return Grpc.getHost();
  }
  setHost(host: string): void {
    Grpc.setHost(host);
  }
  getInsecure(): Promise<boolean> {
    return Grpc.getIsInsecure();
  }
  setInsecure(insecure: boolean): void {
    Grpc.setInsecure(insecure);
  }
  unaryCall(
    method: string,
    data: Uint8Array,
    requestHeaders?: GrpcMetadata
  ): GrpcUnaryCall {
    const requestData = fromByteArray(data);
    const obj: GrpcRequestObject = {
      data: requestData,
    };

    const id = getId();
    const abort = new AbortController();

    abort.signal.addEventListener('abort', () => {
      Grpc.cancelGrpcCall(id);
    });

    const response = createDeferred<Uint8Array>(abort.signal);
    const headers = createDeferred<GrpcMetadata>(abort.signal);
    const trailers = createDeferred<GrpcMetadata>(abort.signal);

    deferredMap[id] = {
      response,
      headers,
      trailers,
    };

    Grpc.unaryCall(id, method, obj, requestHeaders || {});

    const call = new GrpcUnaryCall(
      method,
      data,
      requestHeaders || {},
      headers.promise,
      response.promise,
      trailers.promise,
      abort
    );

    call.then(
      (result) => result,
      () => abort.abort()
    );

    return call;
  }
  serverStreamCall(
    method: string,
    data: Uint8Array,
    requestHeaders?: GrpcMetadata
  ): GrpcServerStreamingCall {
    const requestData = fromByteArray(data);
    const obj: GrpcRequestObject = {
      data: requestData,
    };

    const id = getId();
    const abort = new AbortController();

    abort.signal.addEventListener('abort', () => {
      Grpc.cancelGrpcCall(id);
    });

    const headers = createDeferred<GrpcMetadata>(abort.signal);
    const trailers = createDeferred<GrpcMetadata>(abort.signal);

    const stream = new ServerOutputStream();

    deferredMap[id] = {
      headers,
      trailers,
      data: stream,
    };

    Grpc.serverStreamingCall(id, method, obj, requestHeaders || {});

    const call = new GrpcServerStreamingCall(
      method,
      data,
      requestHeaders || {},
      headers.promise,
      stream,
      trailers.promise,
      abort
    );

    call.then(
      (result) => result,
      () => abort.abort()
    );

    return call;
  }
}

export { Grpc };
