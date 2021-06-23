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

  private String host;
  private boolean isInsecure = false;

  public GrpcModule(ReactApplicationContext context) {
    this.context = context;
  }

  @NonNull
  @Override
  public String getName() {
    return "Grpc";
  }

  @ReactMethod()
  public void getHost(final Promise promise) {
    promise.resolve(this.host);
  }

  @ReactMethod()
  public void getIsInsecure(final Promise promise) {
    promise.resolve(this.isInsecure);
  }

  @ReactMethod
  public void setHost(String host) {
    this.host = host;
  }

  @ReactMethod
  public void setInsecure(boolean insecure) {
    this.isInsecure = insecure;
  }

  @ReactMethod
  public void unaryCall(int id, String path, ReadableMap obj, ReadableMap headers, final Promise promise) {
    ClientCall call = this.startGrpcCall(id, path, MethodDescriptor.MethodType.UNARY, headers);

    byte[] data = Base64.decode(obj.getString("data"), Base64.NO_WRAP);

    call.sendMessage(data);
    call.request(1);
    call.halfClose();

    callsMap.put(id, call);

    promise.resolve(null);
  }

  @ReactMethod
  public void serverStreamingCall(int id, String path, ReadableMap obj, ReadableMap headers, final Promise promise) {
    ClientCall call = this.startGrpcCall(id, path, MethodDescriptor.MethodType.SERVER_STREAMING, headers);

    byte[] data = Base64.decode(obj.getString("data"), Base64.NO_WRAP);

    call.sendMessage(data);
    call.request(1);
    call.halfClose();

    callsMap.put(id, call);

    promise.resolve(null);
  }

  @ReactMethod
  public void clientStreamingCall(int id, String path, ReadableMap obj, ReadableMap headers, final Promise promise) {
    ClientCall call = callsMap.get(id);

    if (call == null) {
      call = this.startGrpcCall(id, path, MethodDescriptor.MethodType.CLIENT_STREAMING, headers);

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

  private ClientCall startGrpcCall(int id, String path, MethodDescriptor.MethodType methodType, ReadableMap headers) {
    path = normalizePath(path);

    final Metadata headersMetadata = new Metadata();

    for (Map.Entry<String, Object> headerEntry : headers.toHashMap().entrySet()) {
      headersMetadata.put(Metadata.Key.of(headerEntry.getKey(), Metadata.ASCII_STRING_MARSHALLER), headerEntry.getValue().toString());
    }

    ManagedChannelBuilder channelBuilder = ManagedChannelBuilder.forTarget(this.host);

    if (this.isInsecure) {
      channelBuilder = channelBuilder.usePlaintext();
    }

    ManagedChannel channel = channelBuilder.build();

    MethodDescriptor.Marshaller<byte[]> marshaller = new GrpcMarshaller();

    MethodDescriptor descriptor = MethodDescriptor.<byte[], byte[]>newBuilder()
      .setFullMethodName(path)
      .setType(methodType)
      .setRequestMarshaller(marshaller)
      .setResponseMarshaller(marshaller)
      .build();

    CallOptions callOptions = CallOptions.DEFAULT;

    ClientCall call = channel.newCall(descriptor, callOptions);

    call.start(new ClientCall.Listener() {
      @Override
      public void onHeaders(Metadata headers) {
        super.onHeaders(headers);

        WritableMap event = Arguments.createMap();
        WritableMap payload = Arguments.createMap();

        for (String key : headers.keys()) {
          payload.putString(key, headers.get(Metadata.Key.of(key, Metadata.ASCII_STRING_MARSHALLER)));
        }

        event.putInt("id", id);
        event.putString("type", "headers");
        event.putMap("payload", payload);

        emitEvent("grpc-call", event);
      }

      @Override
      public void onMessage(Object messageObj) {
        super.onMessage(messageObj);

        byte[] data = (byte[]) messageObj;

        WritableMap event = Arguments.createMap();

        event.putInt("id", id);
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

        callsMap.remove(id);

        WritableMap event = Arguments.createMap();
        event.putInt("id", id);

        if (!status.isOk()) {
          event.putString("type", "error");
          event.putString("error", status.asException(trailers).getLocalizedMessage());
          event.putInt("code", status.getCode().value());
        } else {
          event.putString("type", "trailers");

          WritableMap payload = Arguments.createMap();

          for (String key : trailers.keys()) {
            payload.putString(key, trailers.get(Metadata.Key.of(key, Metadata.ASCII_STRING_MARSHALLER)));
          }

          event.putMap("payload", payload);
        }

        emitEvent("grpc-call", event);
      }
    }, headersMetadata);

    return call;
  }

  private void emitEvent(String eventName, Object params) {
    context
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
      .emit(eventName, params);
  }

  private static String normalizePath(String path) {
    if (path.startsWith("/")) {
      path = path.substring(1);
    }

    return path;
  }
}
