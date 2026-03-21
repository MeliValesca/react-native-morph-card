package com.melivalesca.morphcard

import android.animation.ValueAnimator
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.RectF
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.drawable.BitmapDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import com.facebook.react.bridge.Promise
import java.lang.ref.WeakReference

/**
 * Strategy for push presentation — the target screen slides in from the right
 * while the card morph overlay tracks the target's moving position.
 */
class PushStrategy : MorphAnimationStrategy {

  companion object {
    private const val TAG = "MorphCard"
    private fun lerp(start: Float, end: Float, fraction: Float): Float {
      return start + (end - start) * fraction
    }
  }

  override fun prepareExpand(sourceView: MorphCardSourceView, targetView: View?) {
    Log.d(TAG, "=== PushStrategy prepareExpand START ===")
    if (sourceView.isExpanded) return

    val decorView = sourceView.getDecorView() ?: return

    // Clean up stale overlay
    sourceView.overlayContainer?.let { stale ->
      decorView.removeView(stale)
      sourceView.overlayContainer = null
    }
    (sourceView.targetViewRef as? MorphCardTargetView)?.clearSnapshot()

    sourceView.targetViewRef = targetView
    sourceView.cardBgColor = sourceView.extractBackgroundColor()
    sourceView.hasWrapper = sourceView.cardBgColor != null

    // Save card geometry
    val loc = sourceView.getLocationInWindow(sourceView)
    sourceView.cardLeft = loc[0].toFloat()
    sourceView.cardTop = loc[1].toFloat()
    sourceView.cardWidth = sourceView.width.toFloat()
    sourceView.cardHeight = sourceView.height.toFloat()
    sourceView.cardCornerRadiusPx = sourceView.getCornerRadiusPx()

    // Find screen containers
    val sourceScreen = findScreenContainer(sourceView)
    sourceView.sourceScreenContainerRef = if (sourceScreen != null) WeakReference(sourceScreen) else null

    // DON'T hide target screen — let it slide in normally

    // Capture card snapshot
    val cardImage = sourceView.captureSnapshot()

    // Simple card wrapper on decorView — the push slide is visible underneath
    val wrapper = FrameLayout(sourceView.context)
    wrapper.layoutParams = FrameLayout.LayoutParams(
      sourceView.cardWidth.toInt(), sourceView.cardHeight.toInt()
    )
    wrapper.x = sourceView.cardLeft
    wrapper.y = sourceView.cardTop
    wrapper.clipChildren = true
    wrapper.clipToPadding = true
    setRoundedCorners(wrapper, sourceView.cardCornerRadiusPx)

    val bgColor = sourceView.cardBgColor
    if (bgColor != null) {
      wrapper.setBackgroundColor(bgColor)
    }

    val content = ImageView(sourceView.context)
    content.setImageBitmap(cardImage)
    content.scaleType = ImageView.ScaleType.FIT_XY
    content.layoutParams = FrameLayout.LayoutParams(
      sourceView.cardWidth.toInt(), sourceView.cardHeight.toInt()
    )
    wrapper.addView(content)
    wrapper.translationZ = 16f

    // Force layout so the outline provider can read width/height for clipping
    val w = sourceView.cardWidth.toInt()
    val h = sourceView.cardHeight.toInt()
    wrapper.measure(
      View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY)
    )
    wrapper.layout(0, 0, w, h)

    decorView.addView(wrapper)
    sourceView.overlayContainer = wrapper

    // Hide source card so it doesn't show as a duplicate during expand animation
    sourceView.alpha = 0f

    Log.d(TAG, "=== PushStrategy prepareExpand DONE ===")
  }

  override fun animateExpand(sourceView: MorphCardSourceView, targetView: View?, promise: Promise) {
    Log.d(TAG, "=== PushStrategy animateExpand START ===")
    val wrapper = sourceView.overlayContainer
    if (wrapper == null) {
      promise.resolve(false)
      return
    }

    sourceView.isExpanded = true
    if (targetView != null) {
      sourceView.targetViewRef = targetView
    }

    val decorView = sourceView.getDecorView()
    if (decorView == null) {
      promise.resolve(false)
      return
    }

    // Find target screen container for later
    val targetScreen = findScreenContainer(targetView)
    sourceView.targetScreenContainerRef = if (targetScreen != null) WeakReference(targetScreen) else null

    val d = sourceView.density
    val dur = (if (sourceView.expandDuration > 0) sourceView.expandDuration else sourceView.duration).toLong()
    val twPx = if (sourceView.pendingTargetWidth > 0) sourceView.pendingTargetWidth * d else sourceView.cardWidth
    val thPx = if (sourceView.pendingTargetHeight > 0) sourceView.pendingTargetHeight * d else sourceView.cardHeight
    val tbrPx = if (sourceView.pendingTargetBorderRadius >= 0) sourceView.pendingTargetBorderRadius * d else sourceView.cardCornerRadiusPx

    val content = if (wrapper.childCount > 0) wrapper.getChildAt(0) else null

    // Compute content offset for wrapper mode
    val contentCx = if (sourceView.hasWrapper && sourceView.pendingContentCentered) (twPx - sourceView.cardWidth) / 2f else 0f
    val contentCy = if (sourceView.hasWrapper && sourceView.pendingContentCentered) (thPx - sourceView.cardHeight) / 2f
      else if (sourceView.hasWrapper) sourceView.pendingContentOffsetY * d else 0f

    // For no-wrapper mode, compute image frame
    val targetImageFrame = if (!sourceView.hasWrapper && content != null) {
      sourceView.imageFrameForScaleMode(sourceView.scaleMode, sourceView.cardWidth, sourceView.cardHeight, twPx, thPx)
    } else null

    val totalAngle = (sourceView.rotations * 360.0 + sourceView.rotationEndAngle).toFloat()

    val animator = ValueAnimator.ofFloat(0f, 1f)
    animator.duration = dur
    // Slight overshoot for a natural bouncy feel when landing at target
    animator.interpolator = android.view.animation.OvershootInterpolator(1.0f)

    animator.addUpdateListener { anim ->
      val t = anim.animatedValue as Float

      // Poll target's CURRENT position (it moves as the screen slides in)
      val currentTargetLoc = if (targetView != null && targetView.isAttachedToWindow) {
        sourceView.getLocationInWindow(targetView)
      } else {
        intArrayOf(sourceView.cardLeft.toInt(), sourceView.cardTop.toInt())
      }
      val currentTargetLeft = currentTargetLoc[0].toFloat()
      val currentTargetTop = currentTargetLoc[1].toFloat()

      wrapper.x = lerp(sourceView.cardLeft, currentTargetLeft, t)
      wrapper.y = lerp(sourceView.cardTop, currentTargetTop, t)
      val lp = wrapper.layoutParams
      lp.width = lerp(sourceView.cardWidth, twPx, t).toInt()
      lp.height = lerp(sourceView.cardHeight, thPx, t).toInt()
      wrapper.layoutParams = lp
      setRoundedCorners(wrapper, lerp(sourceView.cardCornerRadiusPx, tbrPx, t))

      if (totalAngle != 0f) {
        wrapper.rotation = lerp(0f, totalAngle, t)
      }

      if (content != null) {
        if (sourceView.hasWrapper) {
          content.x = lerp(0f, contentCx, t)
          content.y = lerp(0f, contentCy, t)
        } else if (targetImageFrame != null) {
          val slp = content.layoutParams as FrameLayout.LayoutParams
          slp.width = lerp(sourceView.cardWidth, targetImageFrame.width(), t).toInt()
          slp.height = lerp(sourceView.cardHeight, targetImageFrame.height(), t).toInt()
          content.layoutParams = slp
          content.x = lerp(0f, targetImageFrame.left, t)
          content.y = lerp(0f, targetImageFrame.top, t)
        }
      }
    }

    animator.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationEnd(animation: android.animation.Animator) {
        Log.d(TAG, "=== PushStrategy animateExpand COMPLETE ===")
        sourceView.alpha = 1f

        // Apply end rotation to target view
        if (sourceView.rotationEndAngle != 0.0) {
          targetView?.rotation = sourceView.rotationEndAngle.toFloat()
        }

        // For push mode, skip the snapshot handoff — just hide the overlay
        // and let the target view's live content show directly.
        // Show children that were hidden by onAttachedToWindow.
        val target = targetView as? MorphCardTargetView
        target?.showChildren()

        // Keep the overlay alive but hidden for collapse to reuse.
        wrapper.alpha = 0f
        wrapper.visibility = View.INVISIBLE
        promise.resolve(true)
      }
    })

    animator.start()
  }

  override fun collapse(sourceView: MorphCardSourceView, promise: Promise) {
    Log.d(TAG, "=== PushStrategy collapse START ===")
    val targetView = sourceView.targetViewRef
    if (!sourceView.isExpanded) {
      promise.resolve(false)
      return
    }

    sourceView.isCollapsing = true

    // Use the activity's decorView directly — sourceView might be detached
    // during back navigation so getDecorView() walks an incomplete tree.
    val activity = (sourceView.context as? android.app.Activity)
      ?: (sourceView.context as? com.facebook.react.bridge.ReactContext)?.currentActivity
    val decorView = activity?.window?.decorView as? ViewGroup
    if (decorView == null) {
      promise.resolve(false)
      return
    }

    val d = sourceView.density
    // Push collapse is always 410ms — matches the feel of a push transition.
    // The user's collapseDuration is ignored for push mode.
    val dur = 450L

    val target = targetView as? MorphCardTargetView
    target?.clearSnapshot()

    val twPx = if (targetView != null && targetView.width > 0) targetView.width.toFloat()
      else if (sourceView.pendingTargetWidth > 0) sourceView.pendingTargetWidth * d else sourceView.cardWidth
    val thPx = if (targetView != null && targetView.height > 0) targetView.height.toFloat()
      else if (sourceView.pendingTargetHeight > 0) sourceView.pendingTargetHeight * d else sourceView.cardHeight
    val tbrPx = if (sourceView.pendingTargetBorderRadius >= 0) sourceView.pendingTargetBorderRadius * d else sourceView.cardCornerRadiusPx

    // Read target position
    targetView?.rotation = 0f
    val unrotatedLoc = IntArray(2)
    if (targetView != null && targetView.isAttachedToWindow) {
      targetView.getLocationInWindow(unrotatedLoc)
    } else {
      unrotatedLoc[0] = sourceView.cardLeft.toInt()
      unrotatedLoc[1] = sourceView.cardTop.toInt()
    }
    Log.d(TAG, "collapse: start=[${unrotatedLoc[0]},${unrotatedLoc[1]}] dest=[${sourceView.cardLeft},${sourceView.cardTop}]")

    // Reuse the expand overlay (added before the push, so it's above the pushed screen).
    // Update its content and position for collapse animation.
    val wrapper = sourceView.overlayContainer
    if (wrapper == null) {
      Log.d(TAG, "collapse: no overlay to reuse — aborting")
      sourceView.isCollapsing = false
      promise.resolve(false)
      return
    }

    // Recapture snapshot
    val cardImage = sourceView.captureSnapshot()

    // Clear old content and add new snapshot
    wrapper.removeAllViews()
    val content = ImageView(sourceView.context)
    content.setImageBitmap(cardImage)
    content.scaleType = ImageView.ScaleType.FIT_XY

    if (sourceView.hasWrapper) {
      val cx = if (sourceView.pendingContentCentered) (twPx - sourceView.cardWidth) / 2f else 0f
      val cy = if (sourceView.pendingContentCentered) (thPx - sourceView.cardHeight) / 2f else sourceView.pendingContentOffsetY * d
      content.layoutParams = FrameLayout.LayoutParams(sourceView.cardWidth.toInt(), sourceView.cardHeight.toInt())
      content.x = cx
      content.y = cy
    } else {
      val imageFrame = sourceView.imageFrameForScaleMode(sourceView.scaleMode, sourceView.cardWidth, sourceView.cardHeight, twPx, thPx)
      content.layoutParams = FrameLayout.LayoutParams(imageFrame.width().toInt(), imageFrame.height().toInt())
      content.x = imageFrame.left
      content.y = imageFrame.top
    }

    wrapper.addView(content)

    // Position at current target location and make visible
    wrapper.layoutParams = FrameLayout.LayoutParams(twPx.toInt(), thPx.toInt())
    wrapper.x = unrotatedLoc[0].toFloat()
    wrapper.y = unrotatedLoc[1].toFloat()
    setRoundedCorners(wrapper, tbrPx)
    wrapper.rotation = sourceView.rotationEndAngle.toFloat()
    wrapper.alpha = 1f
    wrapper.visibility = View.VISIBLE

    // Hide source card during collapse
    sourceView.alpha = 0f

    val startWidth = twPx
    val startHeight = thPx
    val startCx = content.x
    val startCy = content.y
    val startImgW = content.layoutParams.width.toFloat()
    val startImgH = content.layoutParams.height.toFloat()

    // Snappy overshoot for a natural bouncy feel when landing
    val collapseInterpolator = android.view.animation.OvershootInterpolator(1.5f)

    val animator = ValueAnimator.ofFloat(0f, 1f)
    animator.duration = dur
    animator.interpolator = collapseInterpolator

    animator.addUpdateListener { anim ->
      val t = anim.animatedValue as Float

      // IMPORTANT: Keep source and target CARDS (not screens) hidden every frame.
      // React may reset alpha during goBack(). DO NOT REMOVE these lines —
      // without them, the source/target cards are visible behind the overlay.
      sourceView.alpha = 0f
      targetView?.alpha = 0f

      // Use saved source card position (stable, from prepareExpand)
      wrapper.x = lerp(unrotatedLoc[0].toFloat(), sourceView.cardLeft, t)
      wrapper.y = lerp(unrotatedLoc[1].toFloat(), sourceView.cardTop, t)
      val lp = wrapper.layoutParams
      lp.width = lerp(startWidth, sourceView.cardWidth, t).toInt()
      lp.height = lerp(startHeight, sourceView.cardHeight, t).toInt()
      wrapper.layoutParams = lp
      setRoundedCorners(wrapper, lerp(tbrPx, sourceView.cardCornerRadiusPx, t))

      if (sourceView.rotationEndAngle != 0.0) {
        wrapper.rotation = lerp(sourceView.rotationEndAngle.toFloat(), 0f, t)
        wrapper.pivotX = lp.width / 2f
        wrapper.pivotY = lp.height / 2f
      }

      if (sourceView.hasWrapper) {
        content.x = lerp(startCx, 0f, t)
        content.y = lerp(startCy, 0f, t)
      } else {
        content.x = lerp(startCx, 0f, t)
        content.y = lerp(startCy, 0f, t)
        val slp = content.layoutParams
        slp.width = lerp(startImgW, sourceView.cardWidth, t).toInt()
        slp.height = lerp(startImgH, sourceView.cardHeight, t).toInt()
        content.layoutParams = slp
      }
    }

    animator.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationCancel(animation: android.animation.Animator) {
        Log.d(TAG, "=== PushStrategy collapse CANCELLED ===")
      }
      override fun onAnimationEnd(animation: android.animation.Animator) {
        Log.d(TAG, "=== PushStrategy collapse COMPLETE ===")
        decorView.removeView(wrapper)
        sourceView.overlayContainer = null
        sourceView.removeHierarchyListener()
        sourceView.alpha = 1f
        targetView?.alpha = 1f
        sourceView.isExpanded = false
        sourceView.isCollapsing = false
        sourceView.sourceScreenContainerRef = null
        sourceView.targetScreenContainerRef = null
        promise.resolve(true)
      }
    })

    animator.start()
  }

  override fun isTargetScreenReady(sourceView: MorphCardSourceView, targetView: View?): Boolean {
    if (targetView == null) return true
    findScreenContainer(targetView) ?: return false
    return true
  }

  override fun hideTargetScreen(sourceView: MorphCardSourceView, targetView: View?) {
    // Don't hide for push — let the slide animation happen
    val targetScreen = findScreenContainer(targetView)
    sourceView.targetScreenContainerRef = if (targetScreen != null) WeakReference(targetScreen) else null
  }
}
