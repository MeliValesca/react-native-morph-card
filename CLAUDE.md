# React Native Morph Card

## Architecture

- **Strategy pattern**: iOS uses protocol-based strategies (`RNCMorphCardAnimationStrategy.h`), Android uses interface-based (`MorphAnimationStrategy.kt`)
- Two strategies per platform: `TransparentModalStrategy` and `PushStrategy`
- Timer-driven animations on iOS (NSTimer at 120fps) for per-frame position/size/cornerRadius control
- ValueAnimator on Android with DecelerateInterpolator(2.0f)

## Known Bugs & Fixes (DO NOT re-introduce)

### Rotation must stay on wrapper, NOT on content
- **Symptom**: Content gets clipped/cut off when rotated inside wrapper
- **Cause**: Wrapper has `clipToOutline` for border radius — rotating content inside clips the rotated corners
- **Fix**: Apply `rotation` to the wrapper itself (with pivotX/pivotY at center). The wrapper's outline rotates with it so border radius stays correct. Do NOT rotate content ImageView.
- **Files**: `PushStrategy.kt` (expand + collapse), `RNCMorphCardPushStrategy.mm`

### outlineProvider = null kills border radius clipping on Android
- **Symptom**: No rounded corners on overlay during animation
- **Cause**: `setRoundedCorners()` uses `clipToOutline` which requires an outlineProvider. Setting `outlineProvider = null` removes it.
- **Fix**: Use `elevation = 0f` and `translationZ = 0f` for no shadow. Do NOT set `outlineProvider = null`.
- **Files**: `PushStrategy.kt`

### Border radius resets on press (Android)
- **Symptom**: Brief frame without rounded corners when pressing source card
- **Cause**: React Native resets clipping on invalidate (press state change)
- **Fix**: Override `invalidate()` in `MorphCardSourceView.kt` to re-apply `applyBorderRadiusClipping()`

### Source must stay hidden between expand and collapse
- **Symptom**: Source card reappears at original position during push animation
- **Cause**: Expand completion was restoring `sourceView.alpha = 1`
- **Fix**: Do NOT restore source alpha at expand end. Only restore it at collapse end.
- **Files**: `PushStrategy.kt` (both platforms), `RNCMorphCardPushStrategy.mm`

### Do NOT hide targetView during expand
- **Symptom**: Visible hole in screen where target should be during fade-in
- **Cause**: Setting `targetView.alpha = 0` hides the target but the rest of the screen fades in normally, creating a rectangular gap
- **Fix**: Keep target visible. The overlay's `translationZ` keeps it rendered on top. Do NOT set targetView.alpha = 0 during expand.
- **Files**: `PushStrategy.kt`

### Overlay needs translationZ for z-ordering above navigation screens
- **Symptom**: Fade flash — the fading-in screen renders on top of the morph overlay
- **Cause**: Without translationZ, Android's view ordering lets the navigation screen render above the overlay despite bringToFront()
- **Fix**: Use `translationZ = 0.1f` (tiny, no visible shadow). Do NOT use 0f. Do NOT use `outlineProvider = null`.
- **Files**: `PushStrategy.kt`

### Overlay must crossfade to target immediately (no delay)
- **Symptom**: Image snaps to wrong position at end of expand (scaled snapshot crop differs from target's native Image rendering)
- **Cause**: Overlay's aspectFill of source snapshot has different crop than target's native Image component rendering the full-resolution original
- **Fix**: Crossfade overlay to target immediately with 250ms fade (no 300ms delay). The gradual fade masks the position difference. Do NOT add a delay.
- **Files**: `PushStrategy.kt`

### Rotation completes at 80% of expand animation
- **Symptom**: Visual bounding-box expansion at end of expand when wrapper is large and rotated
- **Cause**: Rotating a large rectangle creates a much larger axis-aligned bounding box. Near the end of animation, the wrapper is at its largest and rotation is at its max, making the expansion most visible.
- **Fix**: Map rotation progress to complete at 80% of the animation time: `(t / 0.8f).coerceAtMost(1f)`. The last 20% is just size/position settling with no rotation change.
- **Files**: `PushStrategy.kt`

### No shadows on overlays (both platforms)
- **Symptom**: Unwanted shadow around morph overlay
- **Cause**: elevation/translationZ cast shadows; clipsToBounds blocks shadows on iOS
- **Fix**: Android: `elevation = 0f`, `translationZ = 0.1f` (z-order only, no visible shadow). iOS: no shadow layers at all.

### Snapshot capture must use renderInContext (iOS)
- **Symptom**: Snapshot has baked-in corner clipping (double-clipping during animation)
- **Cause**: `drawViewHierarchyInRect:afterScreenUpdates:` respects parent clipping
- **Fix**: Use `renderInContext:` which captures without parent clip masks
- **Files**: `RNCMorphCardSourceComponentView.mm`

### Collapse must not use autoresizingMask (iOS)
- **Symptom**: Content stretches at beginning of collapse animation
- **Cause**: autoresizingMask auto-resizes content when wrapper bounds change
- **Fix**: Remove autoresizingMask before collapse, use timer-driven per-frame computation
- **Files**: `RNCMorphCardPushStrategy.mm`

### Poll loop replaces fixed delay for expand timing (iOS)
- **Symptom**: Race condition — target not ready when expand starts
- **Cause**: Fixed 150ms delay was unreliable across devices
- **Fix**: Poll loop checking target registered + non-zero bounds + pendingTargetWidth set
- **Files**: `RNCMorphCardModule.mm`

### isCollapsing guard prevents premature cleanup
- **Symptom**: Target detach cleanup runs during collapse, breaking animation
- **Cause**: didMoveToWindow fires when target screen is removed during goBack()
- **Fix**: Check `isCollapsing` flag in target's didMoveToWindow — skip cleanup if collapsing
- **Files**: `RNCMorphCardTargetComponentView.mm`

## Style Conventions

- Always use inline styles in TSX, never `StyleSheet.create`
- No `Co-Authored-By` lines in git commits
