import { GrpcMetadata } from './types';

export class GrpcError extends Error {
  constructor(
    public error: string,
    public code?: number,
    public trailers?: GrpcMetadata
  ) {
    super(error);
  }
}
