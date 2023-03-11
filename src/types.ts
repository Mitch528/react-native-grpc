export type GrpcMetadata = Record<string, string>;

export type RemoveListener = () => void;

export type GrpcClientSettings = {
  host: string;
  insecure?: boolean;
  compression?: boolean;
  compressionName?: string;
  compressionLimit?: number;
  responseLimit?: number;
  keepalive?: boolean;
  keepaliveInterval?: number;
  keepaliveTimeout?: number;
};

export interface GrpcServerInputStream {
  send(data: Uint8Array): Promise<void>;
  complete(): Promise<void>;
}

export type DataCallback = (data: Uint8Array) => void;
export type ErrorCallback = (reason: any) => void;
export type CompleteCallback = () => void;

export type ServerOutputEvent = 'data' | 'error' | 'complete';
export type ServerOutputEventCallback<T> = T extends 'data'
  ? DataCallback
  : T extends 'complete'
  ? CompleteCallback
  : T extends 'error'
  ? ErrorCallback
  : never;

export interface GrpcServerOutputStream {
  on<T extends ServerOutputEvent>(
    event: T,
    callback: ServerOutputEventCallback<T>
  ): RemoveListener;
}

export type GrpcUnaryResponse = {
  data: Uint8Array;
  headers: GrpcMetadata;
};

export type CompletedGrpcUnaryCall = {
  readonly method: string;
  readonly requestHeaders: GrpcMetadata;
  readonly request: Uint8Array;
  readonly headers?: GrpcMetadata;
  readonly response?: Uint8Array;
  readonly status?: number;
  readonly trailers?: GrpcMetadata;
};

export type CompletedGrpcStreamingCall = {
  readonly method: string;
  readonly requestHeaders: GrpcMetadata;
  readonly request: Uint8Array;
  readonly headers?: GrpcMetadata;
  readonly responses?: GrpcServerOutputStream;
  readonly status?: number;
  readonly trailers?: GrpcMetadata;
};
