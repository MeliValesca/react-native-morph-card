package com.melivalesca.morphcard

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.Log
import android.view.View
import com.facebook.react.views.view.ReactViewGroup

class MorphCardTargetView(context: Context) : ReactViewGroup(context) {

  var targetBorderRadius: Float = -1f
  var collapseDuration: Double = 0.0
  var sourceTag: Int = 0

  // Snapshot drawn via canvas — Fabric can't remove it
  private var snapshotBitmap: Bitmap? = null
  private var snapshotFrame: RectF? = null
  private var snapshotCornerRadius: Float = 0f
  private var snapshotBgColor: Int? = null
  private val snapshotPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
  private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)

  private val density: Float
    get() = resources.displayMetrics.density

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    MorphCardViewRegistry.register(this, id)
    Log.d(TAG, "TargetView attached: id=$id sourceTag=$sourceTag")

    if (sourceTag > 0) {
      val screenContainer = findScreenContainer(this)
      if (screenContainer != null) {
        screenContainer.visibility = View.INVISIBLE
        Log.d(TAG, "TargetView: set screen INVISIBLE")
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

  /**
   * Draw the snapshot bitmap BEFORE children so React components
   * (X button, etc.) render on top of it.
   */
  override fun dispatchDraw(canvas: Canvas) {
    val bmp = snapshotBitmap
    val frame = snapshotFrame
    if (bmp != null && frame != null) {
      val radiusPx = snapshotCornerRadius

      // Clip to rounded rect if needed
      if (radiusPx > 0) {
        canvas.save()
        val clipPath = Path()
        clipPath.addRoundRect(
          0f, 0f, width.toFloat(), height.toFloat(),
          radiusPx, radiusPx, Path.Direction.CW
        )
        canvas.clipPath(clipPath)
      }

      // Draw background
      snapshotBgColor?.let { color ->
        bgPaint.color = color
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)
      }

      // Draw bitmap in the specified frame
      val src = android.graphics.Rect(0, 0, bmp.width, bmp.height)
      val dst = android.graphics.Rect(
        frame.left.toInt(), frame.top.toInt(),
        frame.right.toInt(), frame.bottom.toInt()
      )
      canvas.drawBitmap(bmp, src, dst, snapshotPaint)

      if (radiusPx > 0) {
        canvas.restore()
      }
    }

    // Draw React children on top
    super.dispatchDraw(canvas)
  }

  private fun applyBorderRadiusClipping() {
    val radiusPx = if (targetBorderRadius > 0f) targetBorderRadius * density else 0f
    setRoundedCorners(this, radiusPx)
  }

  fun showSnapshot(
    image: Bitmap,
    frame: RectF,
    cornerRadius: Float,
    backgroundColor: Int?
  ) {
    Log.d(TAG, "showSnapshot: viewSize=${width}x${height} frame=$frame cornerR=$cornerRadius bg=$backgroundColor")
    snapshotBitmap = image
    snapshotFrame = frame
    snapshotCornerRadius = cornerRadius
    snapshotBgColor = backgroundColor
    invalidate()
  }

  fun clearSnapshot() {
    if (snapshotBitmap != null) {
      Log.d(TAG, "clearSnapshot: clearing bitmap")
      snapshotBitmap = null
      snapshotFrame = null
      snapshotCornerRadius = 0f
      snapshotBgColor = null
      invalidate()
    }
  }

  companion object {
    private const val TAG = "MorphCard"
  }
}
