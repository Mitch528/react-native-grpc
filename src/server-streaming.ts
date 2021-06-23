/* eslint-disable eslint-comments/no-unlimited-disable */
import { AbortController } from 'abort-controller';
import {
  CompletedGrpcStreamingCall,
  DataCallback,
  ErrorCallback,
  FinishedCallback,
  GrpcMetadata,
  GrpcServerOutputStream,
} from './types';

/* eslint-disable */

export class GrpcServerStreamingCall
  implements PromiseLike<CompletedGrpcStreamingCall> {
  readonly method: string;
  readonly requestHeaders: GrpcMetadata;
  readonly request: Uint8Array;
  readonly headers: Promise<GrpcMetadata>;
  readonly responses: GrpcServerOutputStream;
  readonly trailers: Promise<GrpcMetadata>;

  #abort: AbortController;

  constructor(
    method: string,
    data: Uint8Array,
    requestHeaders: GrpcMetadata,
    headers: Promise<GrpcMetadata>,
    responses: ServerOutputStream,
    trailers: Promise<GrpcMetadata>,
    abort: AbortController,
  ) {
    this.method = method;
    this.request = data;
    this.requestHeaders = requestHeaders;
    this.headers = headers;
    this.responses = responses;
    this.trailers = trailers;
    this.#abort = abort;
  }
  then<TResult1 = CompletedGrpcStreamingCall, TResult2 = unknown>(
    onfulfilled?:
      | ((
        value: CompletedGrpcStreamingCall
      ) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null
  ): PromiseLike<TResult1 | TResult2> {
    return this.completedPromise().then(
      (value) =>
        onfulfilled
          ? Promise.resolve(onfulfilled(value))
          : ((value as unknown) as TResult1),
      (reason) =>
        onrejected
          ? Promise.resolve(onrejected(reason))
          : Promise.reject(reason)
    );
  }

  cancel() {
    this.#abort.abort();
  }

  private async completedPromise(): Promise<CompletedGrpcStreamingCall> {
    const [headers, trailers] = await Promise.all([
      this.headers,
      this.trailers,
    ]);

    return {
      method: this.method,
      requestHeaders: this.requestHeaders,
      request: this.request,
      headers,
      trailers,
      status: 0,
    };
  }
}

export class ServerOutputStream implements GrpcServerOutputStream {
  #callbacks: {
    data: DataCallback[];
    finish: FinishedCallback[];
    error: ErrorCallback[];
  } = {
      data: [],
      finish: [],
      error: []
    };

  onData(callback: DataCallback) {
    return this.addCallback(this.#callbacks.data, callback);
  }
  onFinish(callback: FinishedCallback) {
    return this.addCallback(this.#callbacks.finish, callback);
  }

  onError(callback: ErrorCallback) {
    return this.addCallback(this.#callbacks.error, callback);
  }

  notifyData(data: Uint8Array): void {
    this.#callbacks.data.forEach(c => c(data));
  }

  notifyFinish(): void {
    this.#callbacks.finish.forEach(c => c());
  }

  noitfyError(reason: any) {
    this.#callbacks.error.forEach(e => e(reason));
  }

  private addCallback<C>(arr: C[], callback: C) {
    arr.push(callback);

    return () => {
      const index = arr.indexOf(callback);

      if (index > -1) {
        arr.splice(index, 1);
      }
    };
  }
}
