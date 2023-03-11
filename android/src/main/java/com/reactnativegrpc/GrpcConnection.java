package com.reactnativegrpc;

import com.facebook.react.bridge.ReadableMap;

import io.grpc.ManagedChannel;

public class GrpcConnection {
  private ManagedChannel channel;
  private ReadableMap settings;

  public GrpcConnection(ManagedChannel channel, ReadableMap settings) {
    this.channel = channel;
    this.settings = settings;
  }

  public ManagedChannel getChannel() {
    return channel;
  }

  public void setChannel(ManagedChannel channel) {
    this.channel = channel;
  }

  public ReadableMap getSettings() {
    return settings;
  }

  public void setSettings(ReadableMap settings) {
    this.settings = settings;
  }
}
