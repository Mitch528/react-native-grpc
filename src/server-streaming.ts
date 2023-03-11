/* eslint-disable eslint-comments/no-unlimited-disable */
import { AbortController } from 'abort-controller';
import { EventEmitter } from 'eventemitter3';
import type {
  CompletedGrpcStreamingCall,
  GrpcMetadata,
  GrpcServerOutputStream,
  ServerOutputEvent,
  ServerOutputEventCallback,
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
  #emitter = new EventEmitter<ServerOutputEvent>();

  on<T extends ServerOutputEvent>(event: T, callback: ServerOutputEventCallback<T>) {
    this.#emitter.addListener(event, callback);

    return () => {
      this.#emitter.removeListener(event, callback);
    }
  }

  notifyData(data: Uint8Array): void {
    this.#emitter.emit('data', data);
  }

  notifyComplete(): void {
    this.#emitter.emit('complete')
  }

  noitfyError(reason: any): void {
    this.#emitter.emit('error', reason);
  }
}
