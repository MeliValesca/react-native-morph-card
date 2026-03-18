package com.melivalesca.morphcard

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.RectF
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.ColorDrawable
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
import com.facebook.react.views.view.ReactViewGroup
import java.lang.ref.WeakReference
import kotlin.math.max
import kotlin.math.min

class MorphCardSourceView(context: Context) : ReactViewGroup(context) {

  // ── Props (all in dp) ──
  var duration: Double = 500.0
  var expandDuration: Double = 0.0
  var scaleMode: String = "aspectFill"
  var borderRadiusDp: Float = 0f

  // ── Target config (set by module, in dp from JS) ──
  var pendingTargetWidth: Float = 0f
  var pendingTargetHeight: Float = 0f
  var pendingTargetBorderRadius: Float = -1f
  var pendingContentOffsetY: Float = 0f
  var pendingContentCentered: Boolean = false

  // ── Internal state (all in px) ──
  var isExpanded = false
    private set
  private var hasWrapper = false
  private var cardLeft = 0f
  private var cardTop = 0f
  private var cardWidth = 0f
  private var cardHeight = 0f
  private var cardCornerRadiusPx = 0f
  private var cardBgColor: Int? = null
  private var targetViewRef: View? = null
  private var overlayContainer: FrameLayout? = null
  val hasOverlay: Boolean get() = overlayContainer != null
  private var sourceScreenContainerRef: WeakReference<View>? = null
  private var targetScreenContainerRef: WeakReference<View>? = null
  private var screenStackRef: WeakReference<ViewGroup>? = null
  private var hierarchyListener: ViewGroup.OnHierarchyChangeListener? = null
  private var preDrawListener: ViewTreeObserver.OnPreDrawListener? = null

  // Spring-like interpolator (approximates iOS dampingRatio:0.85)
  private val springInterpolator = PathInterpolator(0.25f, 1.0f, 0.5f, 1.0f)

  private val mainHandler = Handler(Looper.getMainLooper())

  private val density: Float
    get() = resources.displayMetrics.density

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    MorphCardViewRegistry.register(this, id)
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
    val radiusPx = if (borderRadiusDp > 0f) borderRadiusDp * density else 0f
    setRoundedCorners(this, radiusPx)
  }

  // ── Snapshot ──

  private fun captureSnapshot(): Bitmap {
    val w = width
    val h = height
    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    for (i in 0 until childCount) {
      val child = getChildAt(i)
      if (child.visibility != VISIBLE) continue
      canvas.save()
      canvas.translate(child.left.toFloat(), child.top.toFloat())
      child.draw(canvas)
      canvas.restore()
    }
    return bitmap
  }

  // ── Helpers ──

  private fun getLocationInWindow(view: View): IntArray {
    val loc = IntArray(2)
    view.getLocationInWindow(loc)
    return loc
  }

  private fun extractBackgroundColor(): Int? {
    val bg = background ?: return null
    if (bg is ColorDrawable) return bg.color
    try {
      val clazz = bg.javaClass
      try {
        val bgField = clazz.getDeclaredField("background")
        bgField.isAccessible = true
        val bgDrawable = bgField.get(bg)
        if (bgDrawable != null) {
          val colorField = bgDrawable.javaClass.getDeclaredField("backgroundColor")
          colorField.isAccessible = true
          val color = colorField.getInt(bgDrawable)
          if (Color.alpha(color) > 3) return color
        }
      } catch (_: Exception) {}
      try {
        val cssField = clazz.getDeclaredField("cssBackground")
        cssField.isAccessible = true
        val cssBg = cssField.get(bg)
        if (cssBg != null) {
          val colorField = cssBg.javaClass.getDeclaredField("mColor")
          colorField.isAccessible = true
          val color = colorField.getInt(cssBg)
          if (Color.alpha(color) > 3) return color
        }
      } catch (_: Exception) {}
    } catch (_: Exception) {}
    return null
  }

  private fun getDecorView(): ViewGroup? {
    var v: View = this
    while (v.parent is View) {
      v = v.parent as View
    }
    return v as? ViewGroup
  }

  private fun getCornerRadiusPx(): Float {
    if (borderRadiusDp > 0f) return borderRadiusDp * density
    return 0f
  }

  private fun imageFrameForScaleMode(
    mode: String,
    imageWidth: Float,
    imageHeight: Float,
    containerWidth: Float,
    containerHeight: Float
  ): RectF {
    return when (mode) {
      "aspectFit" -> {
        val scale = min(containerWidth / imageWidth, containerHeight / imageHeight)
        val w = imageWidth * scale
        val h = imageHeight * scale
        RectF((containerWidth - w) / 2f, (containerHeight - h) / 2f,
          (containerWidth + w) / 2f, (containerHeight + h) / 2f)
      }
      "stretch" -> RectF(0f, 0f, containerWidth, containerHeight)
      else -> {
        val scale = max(containerWidth / imageWidth, containerHeight / imageHeight)
        val w = imageWidth * scale
        val h = imageHeight * scale
        RectF((containerWidth - w) / 2f, (containerHeight - h) / 2f,
          (containerWidth + w) / 2f, (containerHeight + h) / 2f)
      }
    }
  }

  /**
   * Walk the view tree and hide any screen container that isn't already known.
   * This catches modal screens added to separate ScreenStacks (e.g. transparentModal).
   */
  private fun hideNewScreenContainers(root: ViewGroup, knownScreens: Set<View>): Int {
    var count = 0
    fun walk(group: ViewGroup) {
      val name = group.javaClass.name
      if (name.contains("ScreenStack") || name.contains("ScreenContainer")) {
        for (i in 0 until group.childCount) {
          val child = group.getChildAt(i)
          if (!knownScreens.contains(child) && child.visibility == View.VISIBLE) {
            child.visibility = View.INVISIBLE
            count++
            Log.d(TAG, "preDraw: hid new screen ${child.javaClass.simpleName} in ${group.javaClass.simpleName}")
          }
        }
      }
      for (i in 0 until group.childCount) {
        val child = group.getChildAt(i)
        if (child is ViewGroup) walk(child)
      }
    }
    walk(root)
    return count
  }

  /**
   * Collect all current children of ScreenStack/ScreenContainer views.
   */
  private fun collectExistingScreens(root: ViewGroup): Set<View> {
    val screens = mutableSetOf<View>()
    fun walk(group: ViewGroup) {
      val name = group.javaClass.name
      if (name.contains("ScreenStack") || name.contains("ScreenContainer")) {
        for (i in 0 until group.childCount) {
          screens.add(group.getChildAt(i))
        }
      }
      for (i in 0 until group.childCount) {
        val child = group.getChildAt(i)
        if (child is ViewGroup) walk(child)
      }
    }
    walk(root)
    return screens
  }

  private fun removeHierarchyListener() {
    screenStackRef?.get()?.setOnHierarchyChangeListener(null)
    screenStackRef = null
    hierarchyListener = null
    preDrawListener?.let { listener ->
      getDecorView()?.viewTreeObserver?.removeOnPreDrawListener(listener)
      preDrawListener = null
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PHASE 1: prepareExpand — called IMMEDIATELY, before delay
  // Creates overlay at source position + hides target screen.
  // ══════════════════════════════════════════════════════════════

  fun prepareExpand(targetView: View?) {
    Log.d(TAG, "=== prepareExpand START === isExpanded=$isExpanded targetView=$targetView targetView.id=${targetView?.id}")
    if (isExpanded) {
      Log.d(TAG, "prepareExpand: SKIPPED — already expanded")
      return
    }

    val decorView = getDecorView() ?: return

    // Clean up any stale overlay from a previous cycle
    overlayContainer?.let { stale ->
      Log.d(TAG, "prepareExpand: removing stale overlay")
      decorView.removeView(stale)
      overlayContainer = null
    }
    // Clear snapshot from previous target view if any
    (targetViewRef as? MorphCardTargetView)?.clearSnapshot()

    targetViewRef = targetView
    cardBgColor = extractBackgroundColor()
    hasWrapper = cardBgColor != null

    // Save card geometry
    val loc = getLocationInWindow(this)
    cardLeft = loc[0].toFloat()
    cardTop = loc[1].toFloat()
    cardWidth = width.toFloat()
    cardHeight = height.toFloat()
    cardCornerRadiusPx = getCornerRadiusPx()
    Log.d(TAG, "prepareExpand: source card=[${cardLeft},${cardTop},${cardWidth}x${cardHeight}] cornerR=$cardCornerRadiusPx hasWrapper=$hasWrapper")

    // Find screen containers
    val sourceScreen = findScreenContainer(this)
    val targetScreen = findScreenContainer(targetView)
    sourceScreenContainerRef = if (sourceScreen != null) WeakReference(sourceScreen) else null
    targetScreenContainerRef = if (targetScreen != null) WeakReference(targetScreen) else null

    // Hide target screen with INVISIBLE (can't be overridden by alpha resets)
    if (targetScreen != null && targetScreen !== sourceScreen) {
      targetScreen.visibility = View.INVISIBLE
      Log.d(TAG, "prepareExpand: set target screen INVISIBLE")
    }

    // Watch the ScreenStack for new screens being added and hide them
    // immediately. This catches the target screen BEFORE it renders,
    // even before MorphCardTargetView.onAttachedToWindow fires.
    removeHierarchyListener()
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
      screenStackRef = WeakReference(screenStack)
      hierarchyListener = listener
    }

    // Also install a pre-draw listener on the DecorView to catch modal screens
    // that are added to a different ScreenStack (e.g. transparentModal).
    // This fires before every frame draw, so we can hide screens before they render.
    val knownScreens = collectExistingScreens(decorView)
    Log.d(TAG, "prepareExpand: tracking ${knownScreens.size} existing screens")
    val pdListener = ViewTreeObserver.OnPreDrawListener {
      val hidCount = hideNewScreenContainers(decorView, knownScreens)
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
    preDrawListener = pdListener

    // Capture snapshot
    val cardImage = captureSnapshot()

    // Create a full-screen overlay that blocks the modal target screen from
    // being visible. We use PixelCopy to capture the current screen with
    // hardware rendering preserved (clipToOutline, borderRadius, etc.).
    val fullScreenOverlay = FrameLayout(context)
    fullScreenOverlay.layoutParams = FrameLayout.LayoutParams(decorView.width, decorView.height)
    fullScreenOverlay.isClickable = true
    // Ensure the overlay renders above any views with elevation (e.g. ScreenStack children)
    fullScreenOverlay.translationZ = 1000f

    // PixelCopy captures the current screen with hardware rendering preserved
    // (clipToOutline, borderRadius, etc.). The result is delivered on a background
    // HandlerThread, then posted to main to add the blocker image.
    // Note: context may be ThemedReactContext, not Activity directly.
    val activity = (context as? android.app.Activity)
      ?: (context as? com.facebook.react.bridge.ReactContext)?.currentActivity
    val window = activity?.window
    if (window != null) {
      val blockerBitmap = Bitmap.createBitmap(decorView.width, decorView.height, Bitmap.Config.ARGB_8888)
      val copyThread = android.os.HandlerThread("PixelCopyThread")
      copyThread.start()
      val copyHandler = Handler(copyThread.looper)
      android.view.PixelCopy.request(window, blockerBitmap, { result ->
        copyThread.quitSafely()
        if (result == android.view.PixelCopy.SUCCESS) {
          mainHandler.post {
            val blockerImg = ImageView(context)
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
    val bgColor = cardBgColor
    val wrapper = FrameLayout(context)
    wrapper.layoutParams = FrameLayout.LayoutParams(cardWidth.toInt(), cardHeight.toInt())
    wrapper.x = cardLeft
    wrapper.y = cardTop
    wrapper.clipChildren = true
    wrapper.clipToPadding = true
    setRoundedCorners(wrapper, cardCornerRadiusPx)
    if (bgColor != null) {
      wrapper.setBackgroundColor(bgColor)
    }

    val content = ImageView(context)
    content.setImageBitmap(cardImage)
    content.scaleType = ImageView.ScaleType.FIT_XY
    content.layoutParams = FrameLayout.LayoutParams(cardWidth.toInt(), cardHeight.toInt())
    wrapper.addView(content)
    wrapper.tag = "morphCardWrapper"
    fullScreenOverlay.addView(wrapper)

    decorView.addView(fullScreenOverlay)
    overlayContainer = fullScreenOverlay

    // Hide source card — overlay covers it
    alpha = 0f

    Log.d(TAG, "=== prepareExpand DONE === overlay at [${cardLeft},${cardTop}]")
  }

  /**
   * Check if the target view's screen container is set up and positioned.
   * Returns false if the screen container can't be found yet.
   */
  fun isTargetScreenReady(targetView: View?): Boolean {
    if (targetView == null) return true
    val screenContainer = findScreenContainer(targetView) ?: return false
    // Also check position isn't the same as source (stale layout)
    val loc = IntArray(2)
    targetView.getLocationInWindow(loc)
    val targetAtSource = loc[0].toFloat() == cardLeft && loc[1].toFloat() == cardTop
    if (targetAtSource && targetView.width > 0) {
      Log.d(TAG, "isTargetScreenReady: target still at source position [${loc[0]},${loc[1]}], waiting...")
      return false
    }
    return true
  }

  // ══════════════════════════════════════════════════════════════
  // PHASE 2: animateExpand — called after delay, positions stable
  // Animates overlay from source to target position.
  // ══════════════════════════════════════════════════════════════

  fun animateExpand(targetView: View?, promise: Promise) {
    Log.d(TAG, "=== animateExpand START ===")
    val wrapper = overlayContainer
    if (wrapper == null) {
      Log.d(TAG, "animateExpand: NO OVERLAY — falling back to expandToTarget")
      expandToTarget(targetView, promise)
      return
    }

    isExpanded = true
    // Save target view reference for collapse (prepareExpand may have been called with null)
    if (targetView != null) {
      targetViewRef = targetView
    }

    val decorView = getDecorView()
    if (decorView == null) {
      promise.resolve(false)
      return
    }

    // Re-hide target screen right before animation starts (belt-and-suspenders)
    val preTargetScreen = targetScreenContainerRef?.get()
    val preSourceScreen = sourceScreenContainerRef?.get()
    // Ensure target screen stays INVISIBLE (belt-and-suspenders)
    if (preTargetScreen != null && preTargetScreen !== preSourceScreen) {
      preTargetScreen.visibility = View.INVISIBLE
    }

    // Stop intercepting new screens — animation is taking over
    removeHierarchyListener()

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
        val sampleX = max(0, cardLeft.toInt() - 1)
        val sampleY = min(bmp.height - 1, (cardTop + cardHeight / 2).toInt())
        val bgColor = if (sampleX >= 0 && sampleX < bmp.width && sampleY >= 0 && sampleY < bmp.height) {
          bmp.getPixel(sampleX, sampleY)
        } else {
          Color.WHITE
        }
        // First clear the card area to transparent
        val clearPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        clearPaint.xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
        clearCanvas.drawRect(cardLeft, cardTop, cardLeft + cardWidth, cardTop + cardHeight, clearPaint)
        // Then fill with the sampled background color (no transparent hole)
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        fillPaint.color = bgColor
        clearCanvas.drawRect(cardLeft, cardTop, cardLeft + cardWidth, cardTop + cardHeight, fillPaint)
        blockerImg.invalidate()
      }
    }

    // Read target position (now settled after delay)
    val d = density
    val targetLoc = if (targetView != null) getLocationInWindow(targetView) else intArrayOf(cardLeft.toInt(), cardTop.toInt())
    val twPx = if (pendingTargetWidth > 0) pendingTargetWidth * d else cardWidth
    val thPx = if (pendingTargetHeight > 0) pendingTargetHeight * d else cardHeight
    val tbrPx = if (pendingTargetBorderRadius >= 0) pendingTargetBorderRadius * d else cardCornerRadiusPx

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
    Log.d(TAG, "animateExpand: source=[${cardLeft},${cardTop},${cardWidth}x${cardHeight}]")
    Log.d(TAG, "animateExpand: target=[${targetLeft},${targetTop},${targetWidthPx}x${targetHeightPx}] cornerR=$targetCornerRadiusPx")
    Log.d(TAG, "animateExpand: pendingTarget w=${pendingTargetWidth} h=${pendingTargetHeight} br=${pendingTargetBorderRadius}")

    val dur = (if (expandDuration > 0) expandDuration else duration).toLong()
    // Find the card wrapper inside the full-screen overlay
    val cardWrapper = wrapper.findViewWithTag<FrameLayout>("morphCardWrapper") ?: wrapper
    val content = if (cardWrapper.childCount > 0) cardWrapper.getChildAt(0) else null

    // Compute content offset for wrapper mode
    val contentCx = if (hasWrapper && pendingContentCentered) (targetWidthPx - cardWidth) / 2f else 0f
    val contentCy = if (hasWrapper && pendingContentCentered) (targetHeightPx - cardHeight) / 2f
      else if (hasWrapper) pendingContentOffsetY * d else 0f

    // For no-wrapper mode, compute image frame
    val targetImageFrame = if (!hasWrapper && content != null) {
      imageFrameForScaleMode(scaleMode, cardWidth, cardHeight, targetWidthPx, targetHeightPx)
    } else null

    val animator = ValueAnimator.ofFloat(0f, 1f)
    animator.duration = dur
    animator.interpolator = springInterpolator

    animator.addUpdateListener { anim ->
      val t = anim.animatedValue as Float

      cardWrapper.x = lerp(cardLeft, targetLeft, t)
      cardWrapper.y = lerp(cardTop, targetTop, t)
      val lp = cardWrapper.layoutParams
      lp.width = lerp(cardWidth, targetWidthPx, t).toInt()
      lp.height = lerp(cardHeight, targetHeightPx, t).toInt()
      cardWrapper.layoutParams = lp
      setRoundedCorners(cardWrapper, lerp(cardCornerRadiusPx, targetCornerRadiusPx, t))

      if (content != null) {
        if (hasWrapper) {
          content.x = lerp(0f, contentCx, t)
          content.y = lerp(0f, contentCy, t)
        } else if (targetImageFrame != null) {
          val slp = content.layoutParams as FrameLayout.LayoutParams
          slp.width = lerp(cardWidth, targetImageFrame.width(), t).toInt()
          slp.height = lerp(cardHeight, targetImageFrame.height(), t).toInt()
          content.layoutParams = slp
          content.x = lerp(0f, targetImageFrame.left, t)
          content.y = lerp(0f, targetImageFrame.top, t)
        }
      }
    }

    // Crossfade: at 15% of animation, make target screen VISIBLE with alpha=0
    // then fade alpha to 1 over 50% of duration.
    val targetScreen = targetScreenContainerRef?.get()
    val sourceScreen2 = sourceScreenContainerRef?.get()
    if (targetScreen != null && targetScreen !== sourceScreen2) {
      mainHandler.postDelayed({
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
        targetScreenContainerRef?.get()?.let {
          it.visibility = View.VISIBLE
          it.alpha = 1f
        }
        this@MorphCardSourceView.alpha = 1f

        transferSnapshotToTarget(decorView, wrapper, targetView,
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
      overlayContainer = null
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
      val frame = if (hasWrapper) {
        val cx = if (pendingContentCentered) (targetWidthPx - cardWidth) / 2f else 0f
        val cy = if (pendingContentCentered) (targetHeightPx - cardHeight) / 2f
          else pendingContentOffsetY * density
        RectF(cx, cy, cx + cardWidth, cy + cardHeight)
      } else {
        imageFrameForScaleMode(scaleMode, cardWidth, cardHeight,
          target.width.toFloat(), target.height.toFloat())
      }

      target.showSnapshot(bitmap, frame, cornerRadius, null)
      Log.d(TAG, "transferSnapshot: handed snapshot to MorphCardTargetView")
    }

    val fadeOut = ValueAnimator.ofFloat(1f, 0f)
    fadeOut.duration = fadeDuration
    fadeOut.addUpdateListener { anim ->
      overlay.alpha = anim.animatedValue as Float
    }
    fadeOut.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationEnd(animation: android.animation.Animator) {
        decorView.removeView(overlay)
        overlayContainer = null
        Log.d(TAG, "transferSnapshot: overlay fade-out complete")
      }
    })
    fadeOut.start()
  }

  // ══════════════════════════════════════════════════════════════
  // Fallback: expandToTarget (direct, used if prepareExpand wasn't called)
  // ══════════════════════════════════════════════════════════════

  fun expandToTarget(targetView: View?, promise: Promise) {
    Log.d(TAG, "expandToTarget: fallback path")
    if (isExpanded) {
      promise.resolve(false)
      return
    }
    prepareExpand(targetView)
    animateExpand(targetView, promise)
  }

  // ══════════════════════════════════════════════════════════════
  // COLLAPSE
  // ══════════════════════════════════════════════════════════════

  fun collapseWithResolve(promise: Promise) {
    collapseFromTarget(targetViewRef, promise)
  }

  private fun collapseFromTarget(targetView: View?, promise: Promise) {
    Log.d(TAG, "=== collapseFromTarget START === isExpanded=$isExpanded hasWrapper=$hasWrapper overlayContainer=${overlayContainer != null}")
    if (!isExpanded) {
      promise.resolve(false)
      return
    }

    val decorView = getDecorView()
    if (decorView == null) {
      promise.resolve(false)
      return
    }

    val d = density
    val targetCollapseDur = (targetView as? MorphCardTargetView)?.collapseDuration ?: 0.0
    val dur = (if (targetCollapseDur > 0) targetCollapseDur else duration).toLong()

    // Create DecorView overlay for collapse animation.
    // Get snapshot from MorphCardTargetView if available, otherwise recapture.
    var wrapper = overlayContainer
    if (wrapper == null) {
      val target = targetView as? MorphCardTargetView
      val targetLoc = if (targetView != null) getLocationInWindow(targetView) else intArrayOf(cardLeft.toInt(), cardTop.toInt())
      val twPx = if (pendingTargetWidth > 0) pendingTargetWidth * d else cardWidth
      val thPx = if (pendingTargetHeight > 0) pendingTargetHeight * d else cardHeight
      val tbrPx = if (pendingTargetBorderRadius >= 0) pendingTargetBorderRadius * d else cardCornerRadiusPx

      // Recapture snapshot from source (the image hasn't changed)
      alpha = 1f
      val cardImage = captureSnapshot()
      alpha = 0f

      // Clear the snapshot from the target view
      target?.clearSnapshot()

      wrapper = FrameLayout(context)
      wrapper.layoutParams = FrameLayout.LayoutParams(twPx.toInt(), thPx.toInt())
      wrapper.x = targetLoc[0].toFloat()
      wrapper.y = targetLoc[1].toFloat()
      wrapper.clipChildren = true
      wrapper.clipToPadding = true
      setRoundedCorners(wrapper, tbrPx)

      val bgColor = cardBgColor
      if (bgColor != null) {
        wrapper.setBackgroundColor(bgColor)
      }

      val content = ImageView(context)
      content.setImageBitmap(cardImage)
      content.scaleType = ImageView.ScaleType.FIT_XY

      if (hasWrapper) {
        val cx = if (pendingContentCentered) (twPx - cardWidth) / 2f else 0f
        val cy = if (pendingContentCentered) (thPx - cardHeight) / 2f else pendingContentOffsetY * d
        content.layoutParams = FrameLayout.LayoutParams(cardWidth.toInt(), cardHeight.toInt())
        content.x = cx
        content.y = cy
      } else {
        val imageFrame = imageFrameForScaleMode(scaleMode, cardWidth, cardHeight, twPx, thPx)
        content.layoutParams = FrameLayout.LayoutParams(imageFrame.width().toInt(), imageFrame.height().toInt())
        content.x = imageFrame.left
        content.y = imageFrame.top
      }

      wrapper.addView(content)
      decorView.addView(wrapper)
      overlayContainer = wrapper
    }

    // Show source screen underneath
    val sourceScreen = sourceScreenContainerRef?.get()
    val targetScreen = targetScreenContainerRef?.get()
    sourceScreen?.alpha = 1f

    val content = if (wrapper.childCount > 0) wrapper.getChildAt(0) else null

    val startLeft = wrapper.x
    val startTop = wrapper.y
    val startWidth = wrapper.layoutParams.width.toFloat()
    val startHeight = wrapper.layoutParams.height.toFloat()
    val startCx = content?.x ?: 0f
    val startCy = content?.y ?: 0f
    val startCr = if (pendingTargetBorderRadius >= 0) pendingTargetBorderRadius * d else cardCornerRadiusPx

    val startImgW = content?.layoutParams?.width?.toFloat() ?: cardWidth
    val startImgH = content?.layoutParams?.height?.toFloat() ?: cardHeight

    val animator = ValueAnimator.ofFloat(0f, 1f)
    animator.duration = dur
    animator.interpolator = springInterpolator

    animator.addUpdateListener { anim ->
      val t = anim.animatedValue as Float
      wrapper.x = lerp(startLeft, cardLeft, t)
      wrapper.y = lerp(startTop, cardTop, t)
      val lp = wrapper.layoutParams
      lp.width = lerp(startWidth, cardWidth, t).toInt()
      lp.height = lerp(startHeight, cardHeight, t).toInt()
      wrapper.layoutParams = lp
      setRoundedCorners(wrapper, lerp(startCr, cardCornerRadiusPx, t))

      if (content != null) {
        if (hasWrapper) {
          content.x = lerp(startCx, 0f, t)
          content.y = lerp(startCy, 0f, t)
        } else {
          content.x = lerp(startCx, 0f, t)
          content.y = lerp(startCy, 0f, t)
          val slp = content.layoutParams
          slp.width = lerp(startImgW, cardWidth, t).toInt()
          slp.height = lerp(startImgH, cardHeight, t).toInt()
          content.layoutParams = slp
        }
      }
    }

    // Crossfade: fade out target screen starting at 10%, over 65% of duration
    if (targetScreen != null && targetScreen !== sourceScreen) {
      mainHandler.postDelayed({
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
        overlayContainer = null
        removeHierarchyListener()
        this@MorphCardSourceView.alpha = 1f
        isExpanded = false
        sourceScreenContainerRef = null
        targetScreenContainerRef = null
        promise.resolve(true)
      }
    })

    animator.start()
  }

  /**
   * Hide the target screen container. Called by MorphCardModule after the
   * retry loop finds the target view, in case prepareExpand ran before
   * the target was registered.
   */
  fun hideTargetScreen(targetView: View?) {
    val targetScreen = findScreenContainer(targetView)
    val sourceScreen = sourceScreenContainerRef?.get()
    targetScreenContainerRef = if (targetScreen != null) WeakReference(targetScreen) else null
    if (targetScreen != null && targetScreen !== sourceScreen) {
      targetScreen.visibility = View.INVISIBLE
      Log.d(TAG, "hideTargetScreen: set target screen INVISIBLE")
    }
  }

  companion object {
    private const val TAG = "MorphCard"
    private fun lerp(start: Float, end: Float, fraction: Float): Float {
      return start + (end - start) * fraction
    }
  }
}
