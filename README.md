# react-native-grpc

gRPC for react-native

## Installation

```sh
npm install @mitch528/react-native-grpc
```

## Usage

```js
import { GrpcClient, GrpcMetadata } from '@mitch528/react-native-grpc';

GrpcClient.setHost('example.com');

// Bring your own protobuf library
// This example uses https://github.com/timostamm/protobuf-ts

const message = ExampleMessage.create({
  message: 'Hello World!',
});

const data: Uint8Array = ExampleMessage.toBinary(message);
const headers: GrpcMetadata = {};

const { response } = await GrpcClient.unaryCall(
  '/example.grpc.service.Examples/SendExampleMessage',
  data,
  headers
);

const responseMessage = ExampleMessage.fromBinary(response);
```

See `examples` project for more advanced usage.

## Limitations

This library currently only supports unary and server-side streaming type RPC calls. PRs are welcome.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
