package com.melivalesca.morphcard

import android.os.Handler
import android.os.Looper
import android.view.View
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableNativeMap

class MorphCardModule(reactContext: ReactApplicationContext) :
  NativeMorphCardModuleSpec(reactContext) {

  private val mainHandler = Handler(Looper.getMainLooper())

  override fun prepareExpand(sourceTag: Double) {
    mainHandler.post {
      val sourceView = MorphCardViewRegistry.getView(sourceTag.toInt())
      if (sourceView is MorphCardSourceView) {
        sourceView.prepareExpand(null)
      }
    }
  }

  override fun setTargetConfig(
    sourceTag: Double,
    targetWidth: Double,
    targetHeight: Double,
    targetBorderRadius: Double,
    contentOffsetY: Double,
    contentCentered: Boolean
  ) {
    mainHandler.post {
      val sourceView = MorphCardViewRegistry.getView(sourceTag.toInt())
      if (sourceView is MorphCardSourceView) {
        sourceView.pendingTargetWidth = targetWidth.toFloat()
        sourceView.pendingTargetHeight = targetHeight.toFloat()
        sourceView.pendingTargetBorderRadius = targetBorderRadius.toFloat()
        sourceView.pendingContentOffsetY = contentOffsetY.toFloat()
        sourceView.pendingContentCentered = contentCentered
      }
    }
  }

  override fun expand(sourceTag: Double, targetTag: Double, promise: Promise) {
    mainHandler.post {
      val sourceView = MorphCardViewRegistry.getView(sourceTag.toInt())
      val targetView = MorphCardViewRegistry.getView(targetTag.toInt())

      if (sourceView is MorphCardSourceView) {
        // If prepareExpand wasn't called yet (e.g. via morphExpand API),
        // create the overlay now.
        if (!sourceView.hasOverlay) {
          sourceView.prepareExpand(targetView)
        }

        // Wait until the target view is registered AND its
        // screen container is ready, then animate.
        animateWhenReady(sourceView, targetTag.toInt(), promise, 0)
      } else {
        promise.resolve(false)
      }
    }
  }

  private fun animateWhenReady(
    sourceView: MorphCardSourceView,
    targetTag: Int,
    promise: Promise,
    attempt: Int
  ) {
    val targetView = MorphCardViewRegistry.getView(targetTag)

    // Wait if: target not registered yet, OR screen container not found
    val needsWait = targetView == null || !sourceView.isTargetScreenReady(targetView)
    if (needsWait && attempt < 20) {
      mainHandler.postDelayed({
        animateWhenReady(sourceView, targetTag, promise, attempt + 1)
      }, 50)
      return
    }

    // Re-hide target screen if we found the target late
    if (targetView != null) {
      sourceView.hideTargetScreen(targetView)
    }

    sourceView.animateExpand(targetView, promise)
  }

  override fun collapse(sourceTag: Double, promise: Promise) {
    mainHandler.post {
      val sourceView = MorphCardViewRegistry.getView(sourceTag.toInt())
      if (sourceView is MorphCardSourceView) {
        sourceView.collapseWithResolve(promise)
      } else {
        promise.resolve(false)
      }
    }
  }

  override fun getSourceSize(sourceTag: Double, promise: Promise) {
    mainHandler.post {
      val sourceView = MorphCardViewRegistry.getView(sourceTag.toInt())
      val map = WritableNativeMap()
      if (sourceView != null) {
        val density = sourceView.resources.displayMetrics.density
        map.putDouble("width", (sourceView.width / density).toDouble())
        map.putDouble("height", (sourceView.height / density).toDouble())
      } else {
        map.putDouble("width", 0.0)
        map.putDouble("height", 0.0)
      }
      promise.resolve(map)
    }
  }

  companion object {
    const val NAME = "RNCMorphCardModule"
  }
}
