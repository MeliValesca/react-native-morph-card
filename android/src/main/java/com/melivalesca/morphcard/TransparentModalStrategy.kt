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
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import com.facebook.react.bridge.Promise
import java.lang.ref.WeakReference
import kotlin.math.max
import kotlin.math.min

class TransparentModalStrategy : MorphAnimationStrategy {

  companion object {
    private const val TAG = "MorphCard"
    private fun lerp(start: Float, end: Float, fraction: Float): Float {
      return start + (end - start) * fraction
    }
  }

  override fun prepareExpand(sourceView: MorphCardSourceView, targetView: View?) {
    Log.d(TAG, "=== prepareExpand START === isExpanded=${sourceView.isExpanded} targetView=$targetView targetView.id=${targetView?.id}")
    if (sourceView.isExpanded) {
      Log.d(TAG, "prepareExpand: SKIPPED — already expanded")
      return
    }

    val decorView = sourceView.getDecorView() ?: return

    // Clean up any stale overlay from a previous cycle
    sourceView.overlayContainer?.let { stale ->
      Log.d(TAG, "prepareExpand: removing stale overlay")
      decorView.removeView(stale)
      sourceView.overlayContainer = null
    }
    // Clear snapshot from previous target view if any
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
    Log.d(TAG, "prepareExpand: source card=[${sourceView.cardLeft},${sourceView.cardTop},${sourceView.cardWidth}x${sourceView.cardHeight}] cornerR=${sourceView.cardCornerRadiusPx} hasWrapper=${sourceView.hasWrapper}")

    // Find screen containers
    val sourceScreen = findScreenContainer(sourceView)
    val targetScreen = findScreenContainer(targetView)
    sourceView.sourceScreenContainerRef = if (sourceScreen != null) WeakReference(sourceScreen) else null
    sourceView.targetScreenContainerRef = if (targetScreen != null) WeakReference(targetScreen) else null

    // Hide target screen with INVISIBLE (can't be overridden by alpha resets)
    if (targetScreen != null && targetScreen !== sourceScreen) {
      targetScreen.visibility = View.INVISIBLE
      Log.d(TAG, "prepareExpand: set target screen INVISIBLE")
    }

    // Watch the ScreenStack for new screens being added and hide them
    // immediately. This catches the target screen BEFORE it renders,
    // even before MorphCardTargetView.onAttachedToWindow fires.
    sourceView.removeHierarchyListener()
    val screenStack = sourceScreen?.parent as? ViewGroup
    if (screenStack != null) {
      val listener = object : ViewGroup.OnHierarchyChangeListener {
        override fun onChildViewAdded(parent: View?, child: View?) {
          if (child != null && child !== sourceScreen) {
            child.visibility = View.INVISIBLE
            Log.d(TAG, "prepareExpand: hierarchy intercepted new screen, set INVISIBLE")
          }
        }
        override fun onChildViewRemoved(parent: View?, child: View?) {}
      }
      screenStack.setOnHierarchyChangeListener(listener)
      sourceView.screenStackRef = WeakReference(screenStack)
      sourceView.hierarchyListener = listener
    }

    // Also install a pre-draw listener on the DecorView to catch modal screens
    // that are added to a different ScreenStack (e.g. transparentModal).
    // This fires before every frame draw, so we can hide screens before they render.
    val knownScreens = sourceView.collectExistingScreens(decorView)
    Log.d(TAG, "prepareExpand: tracking ${knownScreens.size} existing screens")
    val pdListener = ViewTreeObserver.OnPreDrawListener {
      val hidCount = sourceView.hideNewScreenContainers(decorView, knownScreens)
      if (hidCount > 0) {
        // Cancel this draw frame — the new screen was visible and we just hid it.
        // Returning false prevents this frame from rendering, so the screen
        // is never shown. The next frame will re-check and proceed.
        Log.d(TAG, "preDraw: cancelled draw frame (hid $hidCount screens)")
        false
      } else {
        true
      }
    }
    decorView.viewTreeObserver.addOnPreDrawListener(pdListener)
    sourceView.preDrawListener = pdListener

    // Capture snapshot
    val cardImage = sourceView.captureSnapshot()

    // Create a full-screen overlay that blocks the modal target screen from
    // being visible. We use PixelCopy to capture the current screen with
    // hardware rendering preserved (clipToOutline, borderRadius, etc.).
    val fullScreenOverlay = FrameLayout(sourceView.context)
    fullScreenOverlay.layoutParams = FrameLayout.LayoutParams(decorView.width, decorView.height)
    fullScreenOverlay.isClickable = true
    // Ensure the overlay renders above any views with elevation (e.g. ScreenStack children)
    fullScreenOverlay.translationZ = 1000f

    // PixelCopy captures the current screen with hardware rendering preserved
    // (clipToOutline, borderRadius, etc.). The result is delivered on a background
    // HandlerThread, then posted to main to add the blocker image.
    // Note: context may be ThemedReactContext, not Activity directly.
    val activity = (sourceView.context as? android.app.Activity)
      ?: (sourceView.context as? com.facebook.react.bridge.ReactContext)?.currentActivity
    val window = activity?.window
    if (window != null) {
      val blockerBitmap = Bitmap.createBitmap(decorView.width, decorView.height, Bitmap.Config.ARGB_8888)
      val copyThread = android.os.HandlerThread("PixelCopyThread")
      copyThread.start()
      val copyHandler = Handler(copyThread.looper)
      android.view.PixelCopy.request(window, blockerBitmap, { result ->
        copyThread.quitSafely()
        if (result == android.view.PixelCopy.SUCCESS) {
          sourceView.mainHandler.post {
            val blockerImg = ImageView(sourceView.context)
            blockerImg.setImageBitmap(blockerBitmap)
            blockerImg.scaleType = ImageView.ScaleType.FIT_XY
            blockerImg.layoutParams = FrameLayout.LayoutParams(
              FrameLayout.LayoutParams.MATCH_PARENT,
              FrameLayout.LayoutParams.MATCH_PARENT
            )
            // Insert behind the card wrapper (index 0)
            fullScreenOverlay.addView(blockerImg, 0)
          }
        } else {
          Log.w(TAG, "prepareExpand: PixelCopy failed with result=$result")
          blockerBitmap.recycle()
        }
      }, copyHandler)
    }

    // Create card overlay at source position (on top of screen capture)
    val bgColor = sourceView.cardBgColor
    val wrapper = FrameLayout(sourceView.context)
    wrapper.layoutParams = FrameLayout.LayoutParams(sourceView.cardWidth.toInt(), sourceView.cardHeight.toInt())
    wrapper.x = sourceView.cardLeft
    wrapper.y = sourceView.cardTop
    wrapper.clipChildren = true
    wrapper.clipToPadding = true
    setRoundedCorners(wrapper, sourceView.cardCornerRadiusPx)
    if (bgColor != null) {
      wrapper.setBackgroundColor(bgColor)
    }

    val content = ImageView(sourceView.context)
    content.setImageBitmap(cardImage)
    content.scaleType = ImageView.ScaleType.FIT_XY
    content.layoutParams = FrameLayout.LayoutParams(sourceView.cardWidth.toInt(), sourceView.cardHeight.toInt())
    wrapper.addView(content)
    wrapper.tag = "morphCardWrapper"
    fullScreenOverlay.addView(wrapper)

    decorView.addView(fullScreenOverlay)
    sourceView.overlayContainer = fullScreenOverlay

    // Hide source card — overlay covers it
    sourceView.alpha = 0f

    Log.d(TAG, "=== prepareExpand DONE === overlay at [${sourceView.cardLeft},${sourceView.cardTop}]")
  }

  override fun isTargetScreenReady(sourceView: MorphCardSourceView, targetView: View?): Boolean {
    if (targetView == null) return true
    val screenContainer = findScreenContainer(targetView) ?: return false
    // Also check position isn't the same as source (stale layout)
    val loc = IntArray(2)
    targetView.getLocationInWindow(loc)
    val targetAtSource = loc[0].toFloat() == sourceView.cardLeft && loc[1].toFloat() == sourceView.cardTop
    if (targetAtSource && targetView.width > 0) {
      Log.d(TAG, "isTargetScreenReady: target still at source position [${loc[0]},${loc[1]}], waiting...")
      return false
    }
    return true
  }

  override fun animateExpand(sourceView: MorphCardSourceView, targetView: View?, promise: Promise) {
    Log.d(TAG, "=== animateExpand START ===")
    val wrapper = sourceView.overlayContainer
    if (wrapper == null) {
      Log.d(TAG, "animateExpand: NO OVERLAY — falling back to expandToTarget")
      sourceView.expandToTarget(targetView, promise)
      return
    }

    sourceView.isExpanded = true
    // Save target view reference for collapse (prepareExpand may have been called with null)
    if (targetView != null) {
      sourceView.targetViewRef = targetView
    }

    val decorView = sourceView.getDecorView()
    if (decorView == null) {
      promise.resolve(false)
      return
    }

    // Re-hide target screen right before animation starts (belt-and-suspenders)
    val preTargetScreen = sourceView.targetScreenContainerRef?.get()
    val preSourceScreen = sourceView.sourceScreenContainerRef?.get()
    // Ensure target screen stays INVISIBLE (belt-and-suspenders)
    if (preTargetScreen != null && preTargetScreen !== preSourceScreen) {
      preTargetScreen.visibility = View.INVISIBLE
    }

    // Stop intercepting new screens — animation is taking over
    sourceView.removeHierarchyListener()

    // The PixelCopy blocker bitmap contains the source card at its original position.
    // Replace the card area with the surrounding background color so the card wrapper
    // animates without a duplicate underneath, and no transparent hole is visible.
    val blockerImg = wrapper.findViewWithTag<FrameLayout>("morphCardWrapper")?.let { cardW ->
      (0 until wrapper.childCount).map { wrapper.getChildAt(it) }.firstOrNull { it !== cardW }
    } as? ImageView
    if (blockerImg != null) {
      val bmp = (blockerImg.drawable as? BitmapDrawable)?.bitmap
      if (bmp != null) {
        val clearCanvas = Canvas(bmp)
        // Sample the background color from a pixel just outside the card area
        val sampleX = max(0, sourceView.cardLeft.toInt() - 1)
        val sampleY = min(bmp.height - 1, (sourceView.cardTop + sourceView.cardHeight / 2).toInt())
        val bgColor = if (sampleX >= 0 && sampleX < bmp.width && sampleY >= 0 && sampleY < bmp.height) {
          bmp.getPixel(sampleX, sampleY)
        } else {
          Color.WHITE
        }
        // First clear the card area to transparent
        val clearPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        clearPaint.xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
        clearCanvas.drawRect(sourceView.cardLeft, sourceView.cardTop, sourceView.cardLeft + sourceView.cardWidth, sourceView.cardTop + sourceView.cardHeight, clearPaint)
        // Then fill with the sampled background color (no transparent hole)
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        fillPaint.color = bgColor
        clearCanvas.drawRect(sourceView.cardLeft, sourceView.cardTop, sourceView.cardLeft + sourceView.cardWidth, sourceView.cardTop + sourceView.cardHeight, fillPaint)
        blockerImg.invalidate()
      }
    }

    // Read target position (now settled after delay)
    val d = sourceView.density
    val targetLoc = if (targetView != null) sourceView.getLocationInWindow(targetView) else intArrayOf(sourceView.cardLeft.toInt(), sourceView.cardTop.toInt())
    val twPx = if (sourceView.pendingTargetWidth > 0) sourceView.pendingTargetWidth * d else sourceView.cardWidth
    val thPx = if (sourceView.pendingTargetHeight > 0) sourceView.pendingTargetHeight * d else sourceView.cardHeight
    val tbrPx = if (sourceView.pendingTargetBorderRadius >= 0) sourceView.pendingTargetBorderRadius * d else sourceView.cardCornerRadiusPx

    val targetLeft = targetLoc[0].toFloat()
    val targetTop = targetLoc[1].toFloat()
    val targetWidthPx = twPx
    val targetHeightPx = thPx
    val targetCornerRadiusPx = tbrPx

    // Log target view details
    if (targetView != null) {
      Log.d(TAG, "animateExpand: targetView.id=${targetView.id} isAttached=${targetView.isAttachedToWindow} isLaidOut=${targetView.isLaidOut}")
      Log.d(TAG, "animateExpand: targetView size=${targetView.width}x${targetView.height}")
    }
    Log.d(TAG, "animateExpand: source=[${sourceView.cardLeft},${sourceView.cardTop},${sourceView.cardWidth}x${sourceView.cardHeight}]")
    Log.d(TAG, "animateExpand: target=[${targetLeft},${targetTop},${targetWidthPx}x${targetHeightPx}] cornerR=$targetCornerRadiusPx")
    Log.d(TAG, "animateExpand: pendingTarget w=${sourceView.pendingTargetWidth} h=${sourceView.pendingTargetHeight} br=${sourceView.pendingTargetBorderRadius}")

    val dur = (if (sourceView.expandDuration > 0) sourceView.expandDuration else sourceView.duration).toLong()
    // Find the card wrapper inside the full-screen overlay
    val cardWrapper = wrapper.findViewWithTag<FrameLayout>("morphCardWrapper") ?: wrapper
    val content = if (cardWrapper.childCount > 0) cardWrapper.getChildAt(0) else null

    // Compute content offset for wrapper mode
    val contentCx = if (sourceView.hasWrapper && sourceView.pendingContentCentered) (targetWidthPx - sourceView.cardWidth) / 2f else 0f
    val contentCy = if (sourceView.hasWrapper && sourceView.pendingContentCentered) (targetHeightPx - sourceView.cardHeight) / 2f
      else if (sourceView.hasWrapper) sourceView.pendingContentOffsetY * d else 0f

    // For no-wrapper mode, compute image frame
    val targetImageFrame = if (!sourceView.hasWrapper && content != null) {
      sourceView.imageFrameForScaleMode(sourceView.scaleMode, sourceView.cardWidth, sourceView.cardHeight, targetWidthPx, targetHeightPx)
    } else null

    val totalAngle = (sourceView.rotations * 360.0 + sourceView.rotationEndAngle).toFloat()

    val animator = ValueAnimator.ofFloat(0f, 1f)
    animator.duration = dur
    animator.interpolator = sourceView.springInterpolator

    animator.addUpdateListener { anim ->
      val t = anim.animatedValue as Float

      cardWrapper.x = lerp(sourceView.cardLeft, targetLeft, t)
      cardWrapper.y = lerp(sourceView.cardTop, targetTop, t)
      val lp = cardWrapper.layoutParams
      lp.width = lerp(sourceView.cardWidth, targetWidthPx, t).toInt()
      lp.height = lerp(sourceView.cardHeight, targetHeightPx, t).toInt()
      cardWrapper.layoutParams = lp
      setRoundedCorners(cardWrapper, lerp(sourceView.cardCornerRadiusPx, targetCornerRadiusPx, t))
      cardWrapper.rotation = lerp(0f, totalAngle, t)

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

    // Crossfade: at 15% of animation, make target screen VISIBLE with alpha=0
    // then fade alpha to 1 over 50% of duration.
    val targetScreen = sourceView.targetScreenContainerRef?.get()
    val sourceScreen2 = sourceView.sourceScreenContainerRef?.get()
    if (targetScreen != null && targetScreen !== sourceScreen2) {
      sourceView.mainHandler.postDelayed({
        // Remove the blocker so the target screen can fade in underneath the card wrapper
        val blocker = wrapper.findViewWithTag<FrameLayout>("morphCardWrapper")?.let { cardW ->
          (0 until wrapper.childCount).map { wrapper.getChildAt(it) }.firstOrNull { it !== cardW }
        }
        if (blocker != null) {
          (blocker.parent as? ViewGroup)?.removeView(blocker)
        }
        // Switch from INVISIBLE to VISIBLE but with alpha=0
        targetScreen.alpha = 0f
        targetScreen.visibility = View.VISIBLE
        val fadeAnimator = ValueAnimator.ofFloat(0f, 1f)
        fadeAnimator.duration = (dur * 0.5f).toLong()
        fadeAnimator.addUpdateListener { a ->
          targetScreen.alpha = a.animatedValue as Float
        }
        fadeAnimator.start()
      }, (dur * 0.15f).toLong())
    }

    animator.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationEnd(animation: android.animation.Animator) {
        Log.d(TAG, "=== animateExpand COMPLETE ===")
        sourceView.targetScreenContainerRef?.get()?.let {
          it.visibility = View.VISIBLE
          it.alpha = 1f
        }
        sourceView.alpha = 1f

        // Apply end rotation to target view
        if (sourceView.rotationEndAngle != 0.0) {
          targetView?.rotation = sourceView.rotationEndAngle.toFloat()
        }

        transferSnapshotToTarget(sourceView, decorView, wrapper, targetView,
          targetWidthPx, targetHeightPx, targetCornerRadiusPx, 200L)

        promise.resolve(true)
      }
    })

    animator.start()
  }

  /**
   * Transfer the snapshot INTO the MorphCardTargetView via showSnapshot(),
   * then make the target screen VISIBLE and fade out the DecorView overlay.
   * This allows absolutely positioned elements (X button, etc.) to render
   * on top of the snapshot, just like iOS.
   */
  private fun transferSnapshotToTarget(
    sourceView: MorphCardSourceView,
    decorView: ViewGroup,
    overlay: FrameLayout,
    targetView: View?,
    targetWidthPx: Float,
    targetHeightPx: Float,
    cornerRadius: Float,
    fadeDuration: Long = 100
  ) {
    val target = targetView as? MorphCardTargetView
    if (target == null) {
      Log.d(TAG, "transferSnapshot: targetView is not MorphCardTargetView, removing overlay")
      decorView.removeView(overlay)
      sourceView.overlayContainer = null
      return
    }

    // Get the bitmap from the card wrapper inside the overlay
    val cardWrap = overlay.findViewWithTag<FrameLayout>("morphCardWrapper") ?: overlay
    val origImg = if (cardWrap.childCount > 0) cardWrap.getChildAt(0) as? ImageView else null
    val bitmap = if (origImg != null) {
      // Extract the bitmap from the drawable
      val drawable = origImg.drawable
      if (drawable is android.graphics.drawable.BitmapDrawable) {
        drawable.bitmap
      } else {
        // Fallback: render the overlay content to a bitmap
        val bmp = Bitmap.createBitmap(overlay.width, overlay.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        overlay.draw(canvas)
        bmp
      }
    } else null

    if (bitmap != null) {
      // Compute the image frame within the target view
      val frame = if (sourceView.hasWrapper) {
        val cx = if (sourceView.pendingContentCentered) (targetWidthPx - sourceView.cardWidth) / 2f else 0f
        val cy = if (sourceView.pendingContentCentered) (targetHeightPx - sourceView.cardHeight) / 2f
          else sourceView.pendingContentOffsetY * sourceView.density
        RectF(cx, cy, cx + sourceView.cardWidth, cy + sourceView.cardHeight)
      } else {
        sourceView.imageFrameForScaleMode(sourceView.scaleMode, sourceView.cardWidth, sourceView.cardHeight,
          target.width.toFloat(), target.height.toFloat())
      }

      target.showSnapshot(bitmap, frame, cornerRadius, null)
      Log.d(TAG, "transferSnapshot: handed snapshot to MorphCardTargetView")
      // Crossfade snapshot out to reveal live React children underneath
      sourceView.mainHandler.postDelayed({ target.fadeOutSnapshot() }, 50)
    }

    val fadeOut = ValueAnimator.ofFloat(1f, 0f)
    fadeOut.duration = fadeDuration
    fadeOut.addUpdateListener { anim ->
      overlay.alpha = anim.animatedValue as Float
    }
    fadeOut.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationEnd(animation: android.animation.Animator) {
        decorView.removeView(overlay)
        sourceView.overlayContainer = null
        Log.d(TAG, "transferSnapshot: overlay fade-out complete")
      }
    })
    fadeOut.start()
  }

  override fun collapse(sourceView: MorphCardSourceView, promise: Promise) {
    val targetView = sourceView.targetViewRef
    Log.d(TAG, "=== collapseFromTarget START === isExpanded=${sourceView.isExpanded} hasWrapper=${sourceView.hasWrapper} overlayContainer=${sourceView.overlayContainer != null}")
    if (!sourceView.isExpanded) {
      promise.resolve(false)
      return
    }

    val decorView = sourceView.getDecorView()
    if (decorView == null) {
      promise.resolve(false)
      return
    }

    val d = sourceView.density
    val targetCollapseDur = (targetView as? MorphCardTargetView)?.collapseDuration ?: 0.0
    val dur = (if (targetCollapseDur > 0) targetCollapseDur else sourceView.duration).toLong()

    // Create DecorView overlay for collapse animation.
    // Get snapshot from MorphCardTargetView if available, otherwise recapture.
    var wrapper = sourceView.overlayContainer
    if (wrapper == null) {
      val target = targetView as? MorphCardTargetView
      // Read position BEFORE clearing rotation — visual position depends on rotation
      val targetLoc = if (targetView != null) sourceView.getLocationInWindow(targetView) else intArrayOf(sourceView.cardLeft.toInt(), sourceView.cardTop.toInt())
      val twPx = if (sourceView.pendingTargetWidth > 0) sourceView.pendingTargetWidth * d else sourceView.cardWidth
      val thPx = if (sourceView.pendingTargetHeight > 0) sourceView.pendingTargetHeight * d else sourceView.cardHeight
      val tbrPx = if (sourceView.pendingTargetBorderRadius >= 0) sourceView.pendingTargetBorderRadius * d else sourceView.cardCornerRadiusPx

      // Recapture snapshot from source (the image hasn't changed)
      sourceView.alpha = 1f
      val cardImage = sourceView.captureSnapshot()
      sourceView.alpha = 0f

      // Clear the snapshot from the target
      target?.clearSnapshot()

      // Use target view's actual size if available for exact match
      val wrapW = if (targetView != null && targetView.width > 0) targetView.width.toFloat() else twPx
      val wrapH = if (targetView != null && targetView.height > 0) targetView.height.toFloat() else thPx

      wrapper = FrameLayout(sourceView.context)
      wrapper.layoutParams = FrameLayout.LayoutParams(wrapW.toInt(), wrapH.toInt())
      wrapper.x = targetLoc[0].toFloat()
      wrapper.y = targetLoc[1].toFloat()
      wrapper.clipChildren = true
      wrapper.clipToPadding = true
      setRoundedCorners(wrapper, tbrPx)

      val bgColor = sourceView.cardBgColor
      if (bgColor != null) {
        wrapper.setBackgroundColor(bgColor)
      }

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
      wrapper.translationZ = 1000f

      // Match the target's exact rotation center by reading its actual size
      val actualW = targetView?.width?.toFloat() ?: wrapW
      val actualH = targetView?.height?.toFloat() ?: wrapH
      // Clear target rotation first so getLocationInWindow gives un-rotated pos
      // then position wrapper at same un-rotated pos with same rotation
      targetView?.rotation = 0f
      val unrotatedLoc = if (targetView != null) sourceView.getLocationInWindow(targetView) else targetLoc
      wrapper.x = unrotatedLoc[0].toFloat()
      wrapper.y = unrotatedLoc[1].toFloat()
      wrapper.layoutParams = FrameLayout.LayoutParams(actualW.toInt(), actualH.toInt())
      wrapper.rotation = sourceView.rotationEndAngle.toFloat()

      decorView.addView(wrapper)
      sourceView.overlayContainer = wrapper
      // Hide target view so live children don't show behind the animating wrapper
      targetView?.visibility = View.INVISIBLE
    }

    // Show source screen underneath
    val sourceScreen = sourceView.sourceScreenContainerRef?.get()
    val targetScreen = sourceView.targetScreenContainerRef?.get()
    sourceScreen?.alpha = 1f

    val content = if (wrapper.childCount > 0) wrapper.getChildAt(0) else null

    val startLeft = wrapper.x
    val startTop = wrapper.y
    val startWidth = wrapper.layoutParams.width.toFloat()
    val startHeight = wrapper.layoutParams.height.toFloat()
    val startCx = content?.x ?: 0f
    val startCy = content?.y ?: 0f
    val startCr = if (sourceView.pendingTargetBorderRadius >= 0) sourceView.pendingTargetBorderRadius * d else sourceView.cardCornerRadiusPx

    val startImgW = content?.layoutParams?.width?.toFloat() ?: sourceView.cardWidth
    val startImgH = content?.layoutParams?.height?.toFloat() ?: sourceView.cardHeight

    // Lock pivot to center so rotation stays stable as size changes
    if (sourceView.rotationEndAngle != 0.0) {
      wrapper.pivotX = startWidth / 2f
      wrapper.pivotY = startHeight / 2f
    }

    // Match iOS collapse curve: cubic bezier (0.25, 1.0, 0.5, 1.0)
    val collapseInterpolator = PathInterpolator(0.25f, 1.0f, 0.5f, 1.0f)

    val animator = ValueAnimator.ofFloat(0f, 1f)
    animator.duration = dur
    animator.interpolator = collapseInterpolator

    animator.addUpdateListener { anim ->
      val t = anim.animatedValue as Float
      wrapper.x = lerp(startLeft, sourceView.cardLeft, t)
      wrapper.y = lerp(startTop, sourceView.cardTop, t)
      val lp = wrapper.layoutParams
      lp.width = lerp(startWidth, sourceView.cardWidth, t).toInt()
      lp.height = lerp(startHeight, sourceView.cardHeight, t).toInt()
      wrapper.layoutParams = lp
      setRoundedCorners(wrapper, lerp(startCr, sourceView.cardCornerRadiusPx, t))
      if (sourceView.rotationEndAngle != 0.0) {
        wrapper.rotation = lerp(sourceView.rotationEndAngle.toFloat(), 0f, t)
        wrapper.pivotX = lp.width / 2f
        wrapper.pivotY = lp.height / 2f
      }

      if (content != null) {
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
    }

    // Crossfade: fade out target screen starting at 10%, over 65% of duration.
    // Set all parent backgrounds to transparent so the source screen shows
    // through cleanly during the fade (ScreenStack defaults are dark).
    if (targetScreen != null && targetScreen !== sourceScreen) {
      var parent = targetScreen.parent as? ViewGroup
      while (parent != null && parent !== decorView) {
        parent.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        parent = parent.parent as? ViewGroup
      }
      sourceView.mainHandler.postDelayed({
        val fadeAnimator = ValueAnimator.ofFloat(1f, 0f)
        fadeAnimator.duration = (dur * 0.65f).toLong()
        fadeAnimator.addUpdateListener { a ->
          targetScreen.alpha = a.animatedValue as Float
        }
        fadeAnimator.addListener(object : android.animation.AnimatorListenerAdapter() {
          override fun onAnimationEnd(animation: android.animation.Animator) {
            targetScreen.visibility = View.INVISIBLE
          }
        })
        fadeAnimator.start()
      }, (dur * 0.15f).toLong())
    }

    animator.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationEnd(animation: android.animation.Animator) {
        decorView.removeView(wrapper)
        sourceView.overlayContainer = null
        sourceView.removeHierarchyListener()
        sourceView.alpha = 1f
        sourceView.isExpanded = false
        sourceView.sourceScreenContainerRef = null
        sourceView.targetScreenContainerRef = null
        promise.resolve(true)
      }
    })

    animator.start()
  }

  override fun hideTargetScreen(sourceView: MorphCardSourceView, targetView: View?) {
    val targetScreen = findScreenContainer(targetView)
    val sourceScreen = sourceView.sourceScreenContainerRef?.get()
    sourceView.targetScreenContainerRef = if (targetScreen != null) WeakReference(targetScreen) else null
    if (targetScreen != null && targetScreen !== sourceScreen) {
      targetScreen.visibility = View.INVISIBLE
      Log.d(TAG, "hideTargetScreen: set target screen INVISIBLE")
    }
  }
}
