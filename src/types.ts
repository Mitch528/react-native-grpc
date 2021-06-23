export type GrpcMetadata = Record<string, string>;

export type RemoveListener = () => void;

export interface GrpcServerInputStream {
  send(data: Uint8Array): Promise<void>;
  complete(): Promise<void>;
}

export type DataCallback = (data: Uint8Array) => void;
export type ErrorCallback = (reason: any) => void;
export type FinishedCallback = () => void;

export interface GrpcServerOutputStream {
  onData(callback: DataCallback): RemoveListener;
  onFinish(callback: FinishedCallback): RemoveListener;
  onError(callback: ErrorCallback): RemoveListener;
  notifyData(data: Uint8Array): void;
  notifyFinish(): void;
  noitfyError(reason: any): void;
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
