package com.melivalesca.morphcard

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.RNCMorphCardSourceManagerDelegate
import com.facebook.react.viewmanagers.RNCMorphCardSourceManagerInterface

@ReactModule(name = MorphCardSourceManager.REACT_CLASS)
class MorphCardSourceManager :
  ViewGroupManager<MorphCardSourceView>(),
  RNCMorphCardSourceManagerInterface<MorphCardSourceView> {

  private val delegate = RNCMorphCardSourceManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<MorphCardSourceView> = delegate

  override fun getName(): String = REACT_CLASS

  override fun createViewInstance(reactContext: ThemedReactContext): MorphCardSourceView {
    return MorphCardSourceView(reactContext)
  }

  override fun setDuration(view: MorphCardSourceView, value: Double) {
    view.duration = value
  }

  override fun setExpandDuration(view: MorphCardSourceView, value: Double) {
    view.expandDuration = value
  }

  override fun setScaleMode(view: MorphCardSourceView, value: String?) {
    view.scaleMode = value ?: "aspectFill"
  }

  override fun setCardBorderRadius(view: MorphCardSourceView, value: Double) {
    view.borderRadiusDp = value.toFloat()
  }

  override fun setRotations(view: MorphCardSourceView, value: Double) {
    view.rotations = value
  }

  override fun setRotationEndAngle(view: MorphCardSourceView, value: Double) {
    view.rotationEndAngle = value
  }

  companion object {
    const val REACT_CLASS = "RNCMorphCardSource"
  }
}
