package com.melivalesca.morphcard

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Outline
import android.graphics.RectF
import android.graphics.drawable.ColorDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
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
  private var transferredSnapshot: FrameLayout? = null
  private var sourceScreenContainerRef: WeakReference<View>? = null
  private var targetScreenContainerRef: WeakReference<View>? = null
  private var screenStackRef: WeakReference<ViewGroup>? = null
  private var hierarchyListener: ViewGroup.OnHierarchyChangeListener? = null

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

  /**
   * Find the screen container for a view (ScreensCoordinatorLayout).
   * Walks up until parent is ScreenStack/ScreenContainer.
   */
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

  /**
   * Find a non-Fabric ancestor (like ScreensCoordinatorLayout) where we can
   * safely add views without Fabric removing them.
   */
  private fun findNonFabricParent(view: View?): ViewGroup? {
    // The screen container (ScreensCoordinatorLayout) is a CoordinatorLayout,
    // not managed by Fabric — safe to add children.
    return findScreenContainer(view) as? ViewGroup
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

  private fun setRoundedCorners(view: View, radiusPx: Float) {
    if (radiusPx <= 0f) {
      view.clipToOutline = false
      return
    }
    view.clipToOutline = true
    view.outlineProvider = object : ViewOutlineProvider() {
      override fun getOutline(v: View, outline: Outline) {
        outline.setRoundRect(0, 0, v.width, v.height, radiusPx)
      }
    }
  }

  private fun removeHierarchyListener() {
    screenStackRef?.get()?.setOnHierarchyChangeListener(null)
    screenStackRef = null
    hierarchyListener = null
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
    // Clean up transferred snapshot from previous cycle
    val hadTransferred = transferredSnapshot != null
    cleanupTransferredSnapshot()
    if (hadTransferred) Log.d(TAG, "prepareExpand: cleaned up transferred snapshot")

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
            Log.d(TAG, "prepareExpand: intercepted new screen, set INVISIBLE")
          }
        }
        override fun onChildViewRemoved(parent: View?, child: View?) {}
      }
      screenStack.setOnHierarchyChangeListener(listener)
      screenStackRef = WeakReference(screenStack)
      hierarchyListener = listener
    }

    // Capture snapshot
    val cardImage = captureSnapshot()

    // Create overlay at source position
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

    decorView.addView(wrapper)
    overlayContainer = wrapper

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

    val dur = duration.toLong()
    val content = if (wrapper.childCount > 0) wrapper.getChildAt(0) else null

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
      wrapper.x = lerp(cardLeft, targetLeft, t)
      wrapper.y = lerp(cardTop, targetTop, t)
      val lp = wrapper.layoutParams
      lp.width = lerp(cardWidth, targetWidthPx, t).toInt()
      lp.height = lerp(cardHeight, targetHeightPx, t).toInt()
      wrapper.layoutParams = lp
      setRoundedCorners(wrapper, lerp(cardCornerRadiusPx, targetCornerRadiusPx, t))

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
    // then fade alpha to 1 over 50% of duration
    val targetScreen = targetScreenContainerRef?.get()
    val sourceScreen = sourceScreenContainerRef?.get()
    if (targetScreen != null && targetScreen !== sourceScreen) {
      mainHandler.postDelayed({
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

        // Transfer snapshot from DecorView overlay to the target's
        // non-Fabric parent (ScreensCoordinatorLayout). This allows
        // absolutely positioned elements (X button) to render on top.
        transferSnapshotToTarget(decorView, wrapper, targetView, targetLeft, targetTop,
          targetWidthPx.toInt(), targetHeightPx.toInt(), targetCornerRadiusPx)

        promise.resolve(true)
      }
    })

    animator.start()
  }

  /**
   * Transfer the overlay snapshot from DecorView to the target screen's
   * CoordinatorLayout. Like iOS, we add the snapshot first, then fade out
   * the DecorView overlay over 200ms to prevent any frame gap.
   */
  private fun transferSnapshotToTarget(
    decorView: ViewGroup,
    overlay: FrameLayout,
    targetView: View?,
    targetLeft: Float,
    targetTop: Float,
    targetWidth: Int,
    targetHeight: Int,
    cornerRadius: Float
  ) {
    val targetParent = findNonFabricParent(targetView)
    if (targetParent == null) {
      Log.d(TAG, "transferSnapshot: no non-Fabric parent found, keeping overlay")
      return
    }

    // Get the target view's position relative to its screen container
    val parentLoc = IntArray(2)
    targetParent.getLocationInWindow(parentLoc)
    val relativeLeft = targetLeft - parentLoc[0]
    val relativeTop = targetTop - parentLoc[1]

    // Capture the bitmap from the overlay's ImageView (copy, don't move)
    val snapshotFrame = FrameLayout(context)
    snapshotFrame.layoutParams = FrameLayout.LayoutParams(targetWidth, targetHeight)
    snapshotFrame.x = relativeLeft
    snapshotFrame.y = relativeTop
    snapshotFrame.clipChildren = overlay.clipChildren
    snapshotFrame.clipToPadding = overlay.clipToPadding
    setRoundedCorners(snapshotFrame, cornerRadius)

    val bgColor = cardBgColor
    if (bgColor != null) {
      snapshotFrame.setBackgroundColor(bgColor)
    }

    // Clone the image into the snapshot frame (keep original in overlay for fade)
    if (overlay.childCount > 0) {
      val origImg = overlay.getChildAt(0) as? ImageView
      if (origImg != null) {
        val cloneImg = ImageView(context)
        cloneImg.setImageDrawable(origImg.drawable)
        cloneImg.scaleType = origImg.scaleType
        cloneImg.layoutParams = FrameLayout.LayoutParams(
          origImg.layoutParams.width, origImg.layoutParams.height
        )
        cloneImg.x = origImg.x
        cloneImg.y = origImg.y
        snapshotFrame.addView(cloneImg)
      }
    }

    // Step 1: Add snapshot to target parent (now visible under the overlay)
    targetParent.addView(snapshotFrame)
    transferredSnapshot = snapshotFrame
    Log.d(TAG, "transferSnapshot: added to ${targetParent.javaClass.simpleName} at [$relativeLeft,$relativeTop]")

    // Step 2: Fade out the DecorView overlay over 200ms (like iOS)
    val fadeOut = ValueAnimator.ofFloat(1f, 0f)
    fadeOut.duration = 200
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

  private fun cleanupTransferredSnapshot() {
    transferredSnapshot?.let { snap ->
      (snap.parent as? ViewGroup)?.removeView(snap)
      transferredSnapshot = null
    }
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
    Log.d(TAG, "=== collapseFromTarget START === isExpanded=$isExpanded hasWrapper=$hasWrapper overlayContainer=${overlayContainer != null} transferredSnapshot=${transferredSnapshot != null}")
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
    val dur = duration.toLong()

    // Move snapshot back to DecorView overlay for collapse animation
    var wrapper = overlayContainer
    if (wrapper == null) {
      // Get position from transferred snapshot or target view
      val snap = transferredSnapshot
      if (snap != null) {
        // Convert snapshot's position to window coordinates
        val snapLoc = IntArray(2)
        snap.getLocationInWindow(snapLoc)
        val snapW = snap.width
        val snapH = snap.height

        wrapper = FrameLayout(context)
        wrapper.layoutParams = FrameLayout.LayoutParams(snapW, snapH)
        wrapper.x = snapLoc[0].toFloat()
        wrapper.y = snapLoc[1].toFloat()
        wrapper.clipChildren = true
        wrapper.clipToPadding = true
        val tbrPx = if (pendingTargetBorderRadius >= 0) pendingTargetBorderRadius * d else cardCornerRadiusPx
        setRoundedCorners(wrapper, tbrPx)

        val bgColor = cardBgColor
        if (bgColor != null) {
          wrapper.setBackgroundColor(bgColor)
        }

        // Move image from transferred snapshot to new overlay
        if (snap.childCount > 0) {
          val img = snap.getChildAt(0)
          snap.removeView(img)
          wrapper.addView(img)
        }

        // Clean up transferred snapshot
        cleanupTransferredSnapshot()

        decorView.addView(wrapper)
        overlayContainer = wrapper
      } else {
        // No overlay and no transferred snapshot — recreate from scratch
        alpha = 1f
        val cardImage = captureSnapshot()
        alpha = 0f

        val targetLoc = if (targetView != null) getLocationInWindow(targetView) else intArrayOf(cardLeft.toInt(), cardTop.toInt())
        val twPx = if (pendingTargetWidth > 0) pendingTargetWidth * d else cardWidth
        val thPx = if (pendingTargetHeight > 0) pendingTargetHeight * d else cardHeight
        val tbrPx = if (pendingTargetBorderRadius >= 0) pendingTargetBorderRadius * d else cardCornerRadiusPx

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
    }

    // Ensure wrapper is valid
    if (wrapper == null) {
      isExpanded = false
      promise.resolve(false)
      return
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

    // Crossfade: fade out target screen starting at 10%, over remaining 90%
    if (targetScreen != null && targetScreen !== sourceScreen) {
      mainHandler.postDelayed({
        val fadeAnimator = ValueAnimator.ofFloat(1f, 0f)
        fadeAnimator.duration = (dur * 0.9f).toLong()
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
        cleanupTransferredSnapshot()
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
