import { AbortController } from 'abort-controller';
import { CompletedGrpcUnaryCall, GrpcMetadata } from './types';

export class GrpcUnaryCall implements PromiseLike<CompletedGrpcUnaryCall> {
  readonly method: string;
  readonly requestHeaders: GrpcMetadata;
  readonly request: Uint8Array;
  readonly headers: Promise<GrpcMetadata>;
  readonly response: Promise<Uint8Array>;
  readonly trailers: Promise<GrpcMetadata>;

  #abort: AbortController;

  constructor(
    method: string,
    data: Uint8Array,
    requestHeaders: GrpcMetadata,
    headers: Promise<GrpcMetadata>,
    response: Promise<Uint8Array>,
    trailers: Promise<GrpcMetadata>,
    abort: AbortController
  ) {
    this.method = method;
    this.request = data;
    this.requestHeaders = requestHeaders;
    this.headers = headers;
    this.response = response;
    this.trailers = trailers;
    this.#abort = abort;
  }

  then<TResult1 = CompletedGrpcUnaryCall, TResult2 = unknown>(
    onfulfilled?:
      | ((value: CompletedGrpcUnaryCall) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null
  ): PromiseLike<TResult1 | TResult2> {
    return this.completedPromise().then(
      (value) =>
        onfulfilled
          ? Promise.resolve(onfulfilled(value))
          : (value as unknown as TResult1),
      (reason) =>
        onrejected
          ? Promise.resolve(onrejected(reason))
          : Promise.reject(reason)
    );
  }

  cancel() {
    this.#abort.abort();
  }

  private async completedPromise(): Promise<CompletedGrpcUnaryCall> {
    const [headers, response, trailers] = await Promise.all([
      this.headers,
      this.response,
      this.trailers,
    ]);

    return {
      method: this.method,
      requestHeaders: this.requestHeaders,
      request: this.request,
      headers,
      trailers,
      response: response,
      status: 0,
    };
  }
}
