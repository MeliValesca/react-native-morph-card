package com.melivalesca.morphcard

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.RectF
import android.graphics.drawable.ColorDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
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
  var rotations: Double = 0.0
  var rotationEndAngle: Double = 0.0
  var presentation: String = "transparentModal"
    set(value) {
      field = value
      strategy = when (value) {
        "push" -> PushStrategy()
        else -> TransparentModalStrategy()
      }
    }

  private var strategy: MorphAnimationStrategy = TransparentModalStrategy()

  // ── Target config (set by module, in dp from JS) ──
  var pendingTargetWidth: Float = 0f
  var pendingTargetHeight: Float = 0f
  var pendingTargetBorderRadius: Float = -1f
  var pendingContentOffsetY: Float = 0f
  var pendingContentCentered: Boolean = false

  // ── Internal state (all in px) ──
  var isExpanded = false
    internal set
  internal var isCollapsing = false
  internal var hasWrapper = false
  internal var cardLeft = 0f
  internal var cardTop = 0f
  internal var cardWidth = 0f
  internal var cardHeight = 0f
  internal var cardCornerRadiusPx = 0f
  internal var cardBgColor: Int? = null
  internal var targetViewRef: View? = null
  internal var overlayContainer: FrameLayout? = null
  val hasOverlay: Boolean get() = overlayContainer != null
  internal var sourceScreenContainerRef: WeakReference<View>? = null
  internal var targetScreenContainerRef: WeakReference<View>? = null
  internal var screenStackRef: WeakReference<ViewGroup>? = null
  internal var hierarchyListener: ViewGroup.OnHierarchyChangeListener? = null
  internal var preDrawListener: ViewTreeObserver.OnPreDrawListener? = null

  // Spring-like interpolator (approximates iOS dampingRatio:0.85)
  internal val springInterpolator = PathInterpolator(0.25f, 1.0f, 0.5f, 1.0f)

  internal val mainHandler = Handler(Looper.getMainLooper())

  internal val density: Float
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

  internal fun captureSnapshot(): Bitmap {
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

  internal fun getLocationInWindow(view: View): IntArray {
    val loc = IntArray(2)
    view.getLocationInWindow(loc)
    return loc
  }

  internal fun extractBackgroundColor(): Int? {
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

  internal fun getDecorView(): ViewGroup? {
    var v: View = this
    while (v.parent is View) {
      v = v.parent as View
    }
    return v as? ViewGroup
  }

  internal fun getCornerRadiusPx(): Float {
    if (borderRadiusDp > 0f) return borderRadiusDp * density
    return 0f
  }

  internal fun imageFrameForScaleMode(
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

  internal fun hideNewScreenContainers(root: ViewGroup, knownScreens: Set<View>): Int {
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

  internal fun collectExistingScreens(root: ViewGroup): Set<View> {
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

  internal fun removeHierarchyListener() {
    screenStackRef?.get()?.setOnHierarchyChangeListener(null)
    screenStackRef = null
    hierarchyListener = null
    preDrawListener?.let { listener ->
      getDecorView()?.viewTreeObserver?.removeOnPreDrawListener(listener)
      preDrawListener = null
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PUBLIC API — delegates to the active strategy
  // ══════════════════════════════════════════════════════════════

  fun prepareExpand(targetView: View?) {
    strategy.prepareExpand(this, targetView)
  }

  fun animateExpand(targetView: View?, promise: Promise) {
    strategy.animateExpand(this, targetView, promise)
  }

  fun isTargetScreenReady(targetView: View?): Boolean {
    return strategy.isTargetScreenReady(this, targetView)
  }

  fun collapseWithResolve(promise: Promise) {
    strategy.collapse(this, promise)
  }

  fun expandToTarget(targetView: View?, promise: Promise) {
    Log.d(TAG, "expandToTarget: fallback path")
    if (isExpanded) {
      promise.resolve(false)
      return
    }
    prepareExpand(targetView)
    animateExpand(targetView, promise)
  }

  fun hideTargetScreen(targetView: View?) {
    strategy.hideTargetScreen(this, targetView)
  }

  companion object {
    internal const val TAG = "MorphCard"
    internal fun lerp(start: Float, end: Float, fraction: Float): Float {
      return start + (end - start) * fraction
    }
  }
}
