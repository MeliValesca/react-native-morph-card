package com.melivalesca.morphcard

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class MorphCardModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = NAME

  @ReactMethod
  fun morph(sourceTag: Double, targetTag: Double, duration: Double) {
    // TODO: Implement native morph transition using Android Transition framework
  }

  @ReactMethod
  fun dismiss(targetTag: Double, duration: Double) {
    // TODO: Implement native dismiss transition
  }

  companion object {
    const val NAME = "RNCMorphCardModule"
  }
}
