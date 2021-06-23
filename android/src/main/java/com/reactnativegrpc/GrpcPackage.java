package com.reactnativegrpc;

import androidx.annotation.NonNull;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;

import java.util.ArrayList;
import java.util.List;

public class GrpcPackage implements ReactPackage {
  @NonNull
  @Override
  public ArrayList createNativeModules(@NonNull ReactApplicationContext reactContext) {
    ArrayList modules = new ArrayList();
    modules.add(new GrpcModule(reactContext));

    return modules;
  }

  @NonNull
  @Override
  public List<ViewManager> createViewManagers(@NonNull ReactApplicationContext reactContext) {
    return new ArrayList();
  }
}
