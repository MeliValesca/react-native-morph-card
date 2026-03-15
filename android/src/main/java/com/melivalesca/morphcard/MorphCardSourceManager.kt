package com.melivalesca.morphcard

import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.views.view.ReactViewGroup

class MorphCardSourceManager : ViewGroupManager<ReactViewGroup>() {
  override fun getName(): String = "RNCMorphCardSource"

  override fun createViewInstance(reactContext: ThemedReactContext): ReactViewGroup {
    return ReactViewGroup(reactContext)
  }
}
