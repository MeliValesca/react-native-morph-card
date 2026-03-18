package com.melivalesca.morphcard

import android.graphics.Outline
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider

/**
 * Walk up the view hierarchy until the parent is a ScreenStack or ScreenContainer,
 * returning the immediate child (the "screen container" for that view).
 */
internal fun findScreenContainer(view: View?): View? {
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
 * Apply rounded-corner clipping to a view via its outline provider.
 * If [radiusPx] is <= 0, clipping is disabled.
 */
internal fun setRoundedCorners(view: View, radiusPx: Float) {
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
