package com.melivalesca.morphcard

import android.view.View
import com.facebook.react.bridge.Promise

/**
 * Strategy interface for morph card animations.
 * Different presentation modes (transparentModal, modal, fullScreenModal)
 * use different strategies for expand/collapse.
 */
interface MorphAnimationStrategy {
  /** Phase 1: Create overlay immediately before navigation. */
  fun prepareExpand(sourceView: MorphCardSourceView, targetView: View?)

  /** Phase 2: Animate from source to target position. */
  fun animateExpand(sourceView: MorphCardSourceView, targetView: View?, promise: Promise)

  /** Collapse: animate from target back to source. */
  fun collapse(sourceView: MorphCardSourceView, promise: Promise)

  /** Check if target screen is ready for animation. */
  fun isTargetScreenReady(sourceView: MorphCardSourceView, targetView: View?): Boolean

  /** Hide the target screen container (called by module after target is found). */
  fun hideTargetScreen(sourceView: MorphCardSourceView, targetView: View?)
}
