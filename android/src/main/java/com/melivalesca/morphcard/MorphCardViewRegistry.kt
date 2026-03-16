package com.melivalesca.morphcard

import android.view.View
import java.lang.ref.WeakReference

/**
 * Singleton registry mapping React view tags to native views.
 * Uses weak references so views can be garbage-collected normally.
 */
object MorphCardViewRegistry {
  private val views = mutableMapOf<Int, WeakReference<View>>()

  fun register(view: View, tag: Int) {
    views[tag] = WeakReference(view)
  }

  fun unregister(tag: Int) {
    views.remove(tag)
  }

  fun getView(tag: Int): View? {
    return views[tag]?.get()
  }
}
