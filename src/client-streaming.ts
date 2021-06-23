import { fromByteArray } from 'base64-js';
import { Grpc } from './client';
import { GrpcServerInputStream } from './types';

export class ServerInputStream implements GrpcServerInputStream {
  // eslint-disable-next-line prettier/prettier
  constructor(private callId: number, private method: string) { }
  send(data: Uint8Array): Promise<void> {
    return Grpc.clientStreamingCall(this.callId, this.method, {
      data: fromByteArray(data),
    });
  }
  complete(): Promise<void> {
    return Grpc.finishClientStreaming(this.callId);
  }
}
