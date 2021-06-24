export class GrpcError extends Error {
  constructor(public error: string, public code?: number) {
    super(error);
  }
}
