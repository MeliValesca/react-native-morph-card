package com.melivalesca.morphcard

import android.animation.ValueAnimator
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
  private var snapshotAlpha: Float = 1f
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
      // Hide children until snapshot is in place to avoid flash of un-rotated content
      hideChildren()
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
    if (bmp != null && frame != null && snapshotAlpha > 0f) {
      snapshotPaint.alpha = (snapshotAlpha * 255).toInt()
      bgPaint.alpha = (snapshotAlpha * 255).toInt()
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

  fun showChildren() {
    for (i in 0 until childCount) {
      getChildAt(i).alpha = 1f
    }
  }

  fun hideChildren() {
    for (i in 0 until childCount) {
      getChildAt(i).alpha = 0f
    }
  }

  fun fadeOutSnapshot() {
    if (snapshotBitmap == null) return
    // Only fade out if there are React children underneath to reveal.
    // If no children (scaleMode bitmap-only), keep the snapshot.
    if (childCount == 0) return
    val anim = ValueAnimator.ofFloat(1f, 0f)
    anim.duration = 150
    anim.addUpdateListener {
      snapshotAlpha = it.animatedValue as Float
      invalidate()
    }
    // Show children before snapshot fades so they're visible underneath
    showChildren()
    anim.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationEnd(animation: android.animation.Animator) {
        clearSnapshot()
        snapshotAlpha = 1f
      }
    })
    anim.start()
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
