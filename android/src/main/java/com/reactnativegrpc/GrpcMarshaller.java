package com.reactnativegrpc;

import com.google.common.io.ByteStreams;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;

import io.grpc.MethodDescriptor;

public class GrpcMarshaller implements MethodDescriptor.Marshaller<byte[]> {
  @Override
  public InputStream stream(byte[] value) {
    return new ByteArrayInputStream(value);
  }

  @Override
  public byte[] parse(InputStream stream) {
    try {
      return ByteStreams.toByteArray(stream);
    } catch (IOException e) {
      e.printStackTrace();

      return null;
    }
  }
}
