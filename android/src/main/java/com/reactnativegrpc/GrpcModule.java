package com.reactnativegrpc;

import android.util.Base64;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import io.grpc.CallOptions;
import io.grpc.ClientCall;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.Metadata;
import io.grpc.MethodDescriptor;
import io.grpc.Status;

public class GrpcModule extends ReactContextBaseJavaModule {
  private final ReactApplicationContext context;
  private final HashMap<Integer, ClientCall> callsMap = new HashMap<>();
  private final HashMap<Integer, GrpcConnection> connections = new HashMap<>();
  private final Executor executor = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());

  public GrpcModule(ReactApplicationContext context) {
    this.context = context;
  }

  @NonNull
  @Override
  public String getName() {
    return "Grpc";
  }


  @ReactMethod
  public void setGrpcSettings(int id, ReadableMap settings) {
    this.destroyClient(id);

    ManagedChannel channel = this.createManagedChannel(id, settings);

    this.connections.put(id, new GrpcConnection(channel, settings));
  }

  @ReactMethod
  public void unaryCall(int callId, Integer id, String path, ReadableMap obj, ReadableMap headers, final Promise promise) {
    ClientCall call;

    try {
      call = this.startGrpcCall(callId, id, path, MethodDescriptor.MethodType.UNARY, headers);
    } catch (Exception e) {
      promise.reject(e);

      return;
    }

    byte[] data = Base64.decode(obj.getString("data"), Base64.NO_WRAP);

    call.sendMessage(data);
    call.request(1);
    call.halfClose();

    callsMap.put(id, call);

    promise.resolve(null);
  }

  @ReactMethod
  public void serverStreamingCall(int id, int clientId, String path, ReadableMap obj, ReadableMap headers, final Promise promise) {
    ClientCall call;

    try {
      call = this.startGrpcCall(id, clientId, path, MethodDescriptor.MethodType.SERVER_STREAMING, headers);
    } catch (Exception e) {
      promise.reject(e);

      return;
    }

    byte[] data = Base64.decode(obj.getString("data"), Base64.NO_WRAP);

    call.sendMessage(data);
    call.request(1);
    call.halfClose();

    callsMap.put(id, call);

    promise.resolve(null);
  }

  @ReactMethod
  public void clientStreamingCall(int id, int clientId, String path, ReadableMap obj, ReadableMap headers, final Promise promise) {
    ClientCall call = callsMap.get(id);

    if (call == null) {
      try {
        call = this.startGrpcCall(id, clientId, path, MethodDescriptor.MethodType.CLIENT_STREAMING, headers);
      } catch (Exception e) {
        promise.reject(e);

        return;
      }

      callsMap.put(id, call);
    }

    byte[] data = Base64.decode(obj.getString("data"), Base64.NO_WRAP);

    call.sendMessage(data);
    call.request(1);

    promise.resolve(null);
  }

  @ReactMethod
  public void finishClientStreaming(int id, final Promise promise) {
    if (callsMap.containsKey(id)) {
      ClientCall call = callsMap.get(id);

      call.halfClose();

      promise.resolve(true);
    } else {
      promise.resolve(false);
    }
  }

  @ReactMethod
  public void cancelGrpcCall(int id, final Promise promise) {
    if (callsMap.containsKey(id)) {
      ClientCall call = callsMap.get(id);
      call.cancel("Cancelled", new Exception("Cancelled by app"));

      promise.resolve(true);
    } else {
      promise.resolve(false);
    }
  }

  private ClientCall startGrpcCall(int callId, int clientId, String path, MethodDescriptor.MethodType methodType, ReadableMap headers) throws Exception {
    if (!this.connections.containsKey(clientId)) {
      throw new Exception("Channel not created");
    }

    GrpcConnection connection = this.connections.get(clientId);
    ReadableMap settings = connection.getSettings();
    ManagedChannel channel = connection.getChannel();

    path = normalizePath(path);

    final Metadata headersMetadata = new Metadata();

    for (Map.Entry<String, Object> headerEntry : headers.toHashMap().entrySet()) {
      headersMetadata.put(Metadata.Key.of(headerEntry.getKey(), Metadata.ASCII_STRING_MARSHALLER), headerEntry.getValue().toString());
    }

    MethodDescriptor.Marshaller<byte[]> marshaller = new GrpcMarshaller();

    MethodDescriptor descriptor = MethodDescriptor.<byte[], byte[]>newBuilder()
      .setFullMethodName(path)
      .setType(methodType)
      .setRequestMarshaller(marshaller)
      .setResponseMarshaller(marshaller)
      .build();

    CallOptions callOptions = CallOptions.DEFAULT;

    if (settings.hasKey("requestTimeout")) {
      int callTimeout = settings.getInt("requestTimeout");

      callOptions = callOptions.withDeadlineAfter(callTimeout, TimeUnit.MILLISECONDS);
    }

    if (settings.hasKey("compressionName")) {
      callOptions = callOptions.withCompression(settings.getString("compressionName"));
    }

    ClientCall call = channel.newCall(descriptor, callOptions);

    call.start(new ClientCall.Listener() {
      @Override
      public void onHeaders(Metadata headers) {
        super.onHeaders(headers);

        WritableMap event = Arguments.createMap();
        WritableMap payload = Arguments.createMap();

        for (String key : headers.keys()) {
          if (key.endsWith(Metadata.BINARY_HEADER_SUFFIX)) {
            byte[] data = headers.get(Metadata.Key.of(key, Metadata.BINARY_BYTE_MARSHALLER));

            payload.putString(key, new String(Base64.encode(data, Base64.NO_WRAP)));
          } else if (!key.startsWith(":")) {
            String data = headers.get(Metadata.Key.of(key, Metadata.ASCII_STRING_MARSHALLER));

            payload.putString(key, data);
          }
        }

        event.putInt("id", callId);
        event.putString("type", "headers");
        event.putMap("payload", payload);

        emitEvent("grpc-call", event);
      }

      @Override
      public void onMessage(Object messageObj) {
        super.onMessage(messageObj);

        byte[] data = (byte[]) messageObj;

        WritableMap event = Arguments.createMap();

        event.putInt("id", callId);
        event.putString("type", "response");
        event.putString("payload", Base64.encodeToString(data, Base64.NO_WRAP));

        emitEvent("grpc-call", event);

        if (methodType == MethodDescriptor.MethodType.SERVER_STREAMING) {
          call.request(1);
        }
      }

      @Override
      public void onClose(Status status, Metadata trailers) {
        super.onClose(status, trailers);

        callsMap.remove(callId);

        WritableMap trailersEvent = Arguments.createMap();
        WritableMap trailersMap = Arguments.createMap();

        trailersEvent.putInt("id", callId);
        trailersEvent.putString("type", "trailers");

        for (String key : trailers.keys()) {
          if (key.endsWith(Metadata.BINARY_HEADER_SUFFIX)) {
            byte[] data = trailers.get(Metadata.Key.of(key, Metadata.BINARY_BYTE_MARSHALLER));

            trailersMap.putString(key, new String(Base64.encode(data, Base64.NO_WRAP)));
          } else if (!key.startsWith(":")) {
            String data = trailers.get(Metadata.Key.of(key, Metadata.ASCII_STRING_MARSHALLER));

            trailersMap.putString(key, data);
          }
        }

        if (!status.isOk()) {
          WritableMap errorEvent = Arguments.createMap();

          errorEvent.putInt("id", callId);
          errorEvent.putString("type", "error");
          errorEvent.putString("error", status.asException(trailers).getLocalizedMessage());
          errorEvent.putInt("code", status.getCode().value());
          errorEvent.putMap("trailers", trailersMap.copy());

          emitEvent("grpc-call", errorEvent);
        }

        trailersEvent.putMap("payload", trailersMap);

        emitEvent("grpc-call", trailersEvent);
      }
    }, headersMetadata);

    if (settings.hasKey("compression") && settings.getBoolean("compression")) {
      call.setMessageCompression(true);
    }

    return call;
  }

  @ReactMethod
  public void destroyClient(int id) {
    if (this.connections.containsKey(id)) {
      GrpcConnection connection = this.connections.get(id);

      connection.getChannel().shutdown();

      this.connections.remove(id);
    }
  }

  @ReactMethod
  public void addListener(String eventName) {
  }

  @ReactMethod
  public void removeListeners(Integer count) {
  }

  private void emitEvent(String eventName, Object params) {
    context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(eventName, params);
  }

  private static String normalizePath(String path) {
    if (path.startsWith("/")) {
      path = path.substring(1);
    }

    return path;
  }

  private ManagedChannel createManagedChannel(int id, ReadableMap options) {
    if (!options.hasKey("host")) {
      throw new IllegalArgumentException("host is required");
    }

    String host = options.getString("host");

    ManagedChannelBuilder channelBuilder = ManagedChannelBuilder.forTarget(host).executor(executor);

    if (options.hasKey("insecure") && options.getBoolean("insecure")) {
      channelBuilder = channelBuilder.usePlaintext();
    }

    if (options.hasKey("responseSizeLimit")) {
      int responseSizeLimit = options.getInt("responseSizeLimit");

      channelBuilder = channelBuilder.maxInboundMessageSize(responseSizeLimit);
    }

    boolean keepalive = true;

    if (options.hasKey("keepalive")) {
      keepalive = options.getBoolean("keepalive");
    }

    if (keepalive) {
      int keepAliveTimeout = 20;
      long keepaliveInterval = Long.MAX_VALUE;

      if (options.hasKey("keepaliveInterval")) {
        keepaliveInterval = options.getInt("keepaliveInterval");
      }

      if (options.hasKey("keepaliveTimeout")) {
        keepAliveTimeout = options.getInt("keepaliveTimeout");
      }

      channelBuilder = channelBuilder
        .keepAliveWithoutCalls(true)
        .keepAliveTime(keepaliveInterval, TimeUnit.SECONDS)
        .keepAliveTimeout(keepAliveTimeout, TimeUnit.SECONDS);
    }

    return channelBuilder.build();
  }
}
