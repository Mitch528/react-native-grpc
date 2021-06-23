import { GrpcClient } from '@mitch528/react-native-grpc';
import 'fast-text-encoding';
import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { RNGrpcTransport } from './transport';
import { ExampleRequest, ExamplesClient } from './_proto/example';

export default function App() {
  const [result, setResult] = useState<string>();

  useEffect(() => {
    GrpcClient.setHost('example.com');
    GrpcClient.setInsecure(true);

    const client = new ExamplesClient(new RNGrpcTransport());
    const request = ExampleRequest.create({
      message: 'Hello World',
    });

    const abort = new AbortController();

    const unaryCall = client.sendExampleMessage(request, {
      abort: abort.signal,
    });

    // unaryCall.then(result => console.log(result));

    unaryCall.response.then((response) => setResult(response.message));

    // const stream = client.getExampleMessages(message, {
    //   abort: abort.signal,
    // });

    // // stream.response.onMessage(msg => console.log(msg.message))
    // // stream.response.onComplete(() => console.log('Completed!'));
    // // stream.response.onError(err => console.log(err))
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
