package com.melivalesca.morphcard

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Outline
import android.graphics.RectF
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import android.widget.ImageView
import com.facebook.react.views.view.ReactViewGroup

class MorphCardTargetView(context: Context) : ReactViewGroup(context) {

  var targetWidth: Float = 0f
  var targetHeight: Float = 0f
  var targetBorderRadius: Float = -1f
  var sourceTag: Int = 0

  private var snapshotContainer: FrameLayout? = null

  private val density: Float
    get() = resources.displayMetrics.density

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    MorphCardViewRegistry.register(this, id)
    Log.d("MorphCard", "TargetView attached: id=$id sourceTag=$sourceTag")

    // Hide the target screen container immediately to prevent flicker.
    // The expand animation will fade it in at 15%.
    if (sourceTag > 0) {
      val screenContainer = findScreenContainer(this)
      if (screenContainer != null) {
        // Use INVISIBLE instead of alpha=0 — this completely prevents
        // the screen from drawing and can't be overridden by
        // react-native-screens resetting alpha.
        screenContainer.visibility = View.INVISIBLE
        Log.d("MorphCard", "TargetView: set screen INVISIBLE")
      }
    }
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    MorphCardViewRegistry.unregister(id)
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    super.onLayout(changed, left, top, right, bottom)
    applyBorderRadiusClipping()
  }

  private fun applyBorderRadiusClipping() {
    val radiusPx = if (targetBorderRadius > 0f) targetBorderRadius * density else 0f
    if (radiusPx > 0f) {
      clipToOutline = true
      outlineProvider = object : ViewOutlineProvider() {
        override fun getOutline(v: View, outline: Outline) {
          outline.setRoundRect(0, 0, v.width, v.height, radiusPx)
        }
      }
    } else {
      clipToOutline = false
    }
  }

  private fun findScreenContainer(view: View?): View? {
    if (view == null) return null
    var current: View? = view
    while (current != null) {
      val parent = current.parent
      if (parent is ViewGroup) {
        val parentName = parent.javaClass.name
        if (parentName.contains("ScreenStack") || parentName.contains("ScreenContainer")) {
          return current
        }
      }
      current = if (current.parent is View) current.parent as View else null
    }
    return null
  }

  fun showSnapshot(
    image: Bitmap,
    scaleType: ImageView.ScaleType,
    frame: RectF,
    cornerRadius: Float,
    backgroundColor: Int?
  ) {
    Log.d("MorphCard", "showSnapshot: viewSize=${width}x${height} frame=$frame cornerR=$cornerRadius bg=$backgroundColor childCount=$childCount")
    clearSnapshot()

    val container = FrameLayout(context)
    container.layoutParams = FrameLayout.LayoutParams(width, height)
    container.clipChildren = true
    container.clipToPadding = true

    if (cornerRadius > 0) {
      container.clipToOutline = true
      container.outlineProvider = object : ViewOutlineProvider() {
        override fun getOutline(v: View, outline: Outline) {
          outline.setRoundRect(0, 0, v.width, v.height, cornerRadius)
        }
      }
    }

    if (backgroundColor != null) {
      container.setBackgroundColor(backgroundColor)
    }

    val iv = ImageView(context)
    iv.setImageBitmap(image)
    iv.scaleType = ImageView.ScaleType.FIT_XY
    iv.layoutParams = FrameLayout.LayoutParams(
      frame.width().toInt(), frame.height().toInt()
    )
    iv.x = frame.left
    iv.y = frame.top
    container.addView(iv)

    addView(container)
    snapshotContainer = container
    Log.d("MorphCard", "showSnapshot: added container, new childCount=$childCount")
  }

  fun clearSnapshot() {
    snapshotContainer?.let {
      Log.d("MorphCard", "clearSnapshot: removing snapshot container")
      removeView(it)
      snapshotContainer = null
    }
  }
}
