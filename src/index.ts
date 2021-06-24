import { GrpcClient as GrpcClientImpl } from './client';

const GrpcClient = new GrpcClientImpl();

export * from './types';
export * from './unary';
export * from './server-streaming';
export * from './errors';
export { GrpcClient };
