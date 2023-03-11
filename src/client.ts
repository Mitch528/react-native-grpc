import { AbortController, AbortSignal } from 'abort-controller';
import { fromByteArray, toByteArray } from 'base64-js';
import {
  EmitterSubscription,
  NativeEventEmitter,
  NativeModules,
} from 'react-native';
import { GrpcError } from './errors';
import {
  GrpcServerStreamingCall,
  ServerOutputStream,
} from './server-streaming';
import type { GrpcClientSettings, GrpcMetadata } from './types';
import { GrpcUnaryCall } from './unary';

type GrpcRequestObject = {
  data: string;
};

type GrpcOptions = GrpcClientSettings;

type GrpcType = {
  setGrpcSettings(id: number, settings: GrpcOptions): void;
  destroyClient(id: number): void;
  unaryCall(
    callId: number,
    clientId: number,
    path: string,
    obj: GrpcRequestObject,
    requestHeaders?: GrpcMetadata
  ): Promise<void>;
  serverStreamingCall(
    callId: number,
    clientId: number,
    path: string,
    obj: GrpcRequestObject,
    requestHeaders?: GrpcMetadata
  ): Promise<void>;
  cancelGrpcCall: (id: number) => Promise<boolean>;
  clientStreamingCall(
    callId: number,
    clientId: number,
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
    trailers?: GrpcMetadata;
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
  completed: boolean;
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

type DeferredCallMap = Map<number, DeferredCalls>;

function createDeferred<T>(signal: AbortSignal) {
  const deferred: Deferred<T> = { completed: false } as Deferred<T>;

  deferred.promise = new Promise<T>((resolve, reject) => {
    deferred.resolve = (value) => {
      deferred.completed = true;

      resolve(value);
    };
    deferred.reject = (reason) => {
      deferred.completed = true;

      reject(reason);
    };
  });

  signal.addEventListener('abort', () => {
    if (!deferred.completed) {
      deferred.reject('aborted');
    }
  });

  return deferred;
}

let idCtr = 1;

function getId(): number {
  return idCtr++;
}

export class GrpcClient {
  #deferredMap: DeferredCallMap = new Map<number, DeferredCalls>();

  #handleGrpcEvent = (event: GrpcEvent) => {
    const deferred = this.#deferredMap.get(event.id);

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

          this.#deferredMap.delete(event.id);
          break;
        case 'error':
          const error = new GrpcError(event.error, event.code, event.trailers);

          deferred.response?.reject(error);
          deferred.data?.noitfyError(error);

          break;
      }
    }
  };

  public clientId: number;

  private callSubscription: EmitterSubscription;

  constructor(settings: GrpcClientSettings) {
    this.clientId = getId();
    this.updateSettings(settings);

    this.callSubscription = Emitter.addListener(
      'grpc-call',
      this.#handleGrpcEvent
    );
  }
  destroy() {
    Emitter.removeSubscription(this.callSubscription);

    Grpc.destroyClient(this.clientId);
  }
  updateSettings(settings: GrpcClientSettings) {
    Grpc.setGrpcSettings(this.clientId, settings);
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

    this.#deferredMap.set(id, {
      response,
      headers,
      trailers,
    });

    Grpc.unaryCall(id, this.clientId, method, obj, requestHeaders || {});

    const call = new GrpcUnaryCall(
      method,
      data,
      requestHeaders || {},
      headers.promise,
      response.promise,
      trailers.promise,
      abort
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

    this.#deferredMap.set(id, {
      headers,
      trailers,
      data: stream,
    });

    Grpc.serverStreamingCall(
      id,
      this.clientId,
      method,
      obj,
      requestHeaders || {}
    );

    const call = new GrpcServerStreamingCall(
      method,
      data,
      requestHeaders || {},
      headers.promise,
      stream,
      trailers.promise,
      abort
    );

    return call;
  }
}

export { Grpc };
