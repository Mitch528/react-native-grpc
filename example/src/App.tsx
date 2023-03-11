import 'text-encoding';
import { GrpcClient } from '@mitch528/react-native-grpc';
import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { RNGrpcTransport } from './transport';
import { ExampleRequest } from './_proto/example';
import { ExamplesClient } from './_proto/example.client';

export default function App() {
  const [result, setResult] = useState<string>();

  useEffect(() => {
    const nativeClient = new GrpcClient({
      host: 'localhost:5010',
      insecure: true,
      compression: true,
      keepalive: true,
    });

    const client = new ExamplesClient(new RNGrpcTransport(nativeClient));
    const request = ExampleRequest.create({
      message: 'Hello World',
    });

    const abort = new AbortController();

    const unaryCall = client.sendExampleMessage(request, {
      abort: abort.signal,
    });

    unaryCall.response.then((response) => setResult(response.message));

    const stream = client.getExampleMessages(request, {
      abort: abort.signal,
    });

    stream.responses.onMessage((msg) => console.log(msg.message));
    stream.responses.onComplete(() => console.log('Completed!'));
    stream.responses.onError((err) => console.log(err));
  }, []);

  return (
    <View style={styles.container}>
      <Text>Result: {result}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
