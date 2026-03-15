package com.melivalesca.morphcard

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.views.view.ReactViewGroup

@ReactModule(name = MorphCardTargetManager.REACT_CLASS)
class MorphCardTargetManager : ViewGroupManager<ReactViewGroup>() {
  override fun getName(): String = REACT_CLASS

  override fun createViewInstance(reactContext: ThemedReactContext): ReactViewGroup {
    return ReactViewGroup(reactContext)
  }

  @ReactProp(name = "duration", defaultDouble = 350.0)
  fun setDuration(view: ReactViewGroup, duration: Double) {
    // TODO: Store duration for animation
  }

  @ReactProp(name = "sourceTag")
  fun setSourceTag(view: ReactViewGroup, sourceTag: Int) {
    // TODO: Store source tag reference
  }

  companion object {
    const val REACT_CLASS = "RNCMorphCardTarget"
  }
}
