package com.melivalesca.morphcard

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.RNCMorphCardTargetManagerDelegate
import com.facebook.react.viewmanagers.RNCMorphCardTargetManagerInterface

@ReactModule(name = MorphCardTargetManager.REACT_CLASS)
class MorphCardTargetManager :
  ViewGroupManager<MorphCardTargetView>(),
  RNCMorphCardTargetManagerInterface<MorphCardTargetView> {

  private val delegate = RNCMorphCardTargetManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<MorphCardTargetView> = delegate

  override fun getName(): String = REACT_CLASS

  override fun createViewInstance(reactContext: ThemedReactContext): MorphCardTargetView {
    return MorphCardTargetView(reactContext)
  }

  override fun setDuration(view: MorphCardTargetView, value: Double) {
    // Duration is managed by the source view
  }

  override fun setCollapseDuration(view: MorphCardTargetView, value: Double) {
    view.collapseDuration = value
  }

  override fun setSourceTag(view: MorphCardTargetView, value: Int) {
    view.sourceTag = value
  }

  override fun setTargetWidth(view: MorphCardTargetView, value: Double) {
    view.targetWidth = value.toFloat()
  }

  override fun setTargetHeight(view: MorphCardTargetView, value: Double) {
    view.targetHeight = value.toFloat()
  }

  override fun setTargetBorderRadius(view: MorphCardTargetView, value: Double) {
    view.targetBorderRadius = value.toFloat()
  }

  companion object {
    const val REACT_CLASS = "RNCMorphCardTarget"
  }
}
