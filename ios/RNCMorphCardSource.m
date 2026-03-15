#import "RNCMorphCardSource.h"
#import "RNCMorphCardViewRegistry.h"

// ──────────────────────────────────────────────────────
// HOW THE EXPAND/COLLAPSE WORKS:
//
// The card is a normal RCTView in the view hierarchy. When expand
// is called, we:
//
// 1. Save the card's original frame and superview position
// 2. Move the card to the key window (so it's above everything)
// 3. Animate the card's frame from its original position to fullscreen
// 4. The card's children (both the "collapsed" card content and the
//    "expanded" detail content) are inside it — JS controls which
//    is visible via state
//
// On collapse, we reverse: animate back to original frame, then
// reparent back into the original superview.
//
// This means the ACTUAL VIEW expands — not a snapshot, not an overlay.
// The user's content (images, text, etc.) is live throughout.
// ──────────────────────────────────────────────────────

@implementation RNCMorphCardSource {
  // Saved state for collapsing back.
  CGRect _originalFrame;
  UIView *_originalSuperview;
  NSInteger _originalIndex;
  CGFloat _originalCornerRadius;
  BOOL _isExpanded;
}

- (instancetype)init {
  if (self = [super init]) {
    _duration = 500.0;
  }
  return self;
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [[RNCMorphCardViewRegistry shared] registerView:self withTag:self.tag];
  } else {
    [[RNCMorphCardViewRegistry shared] unregisterViewWithTag:self.tag];
  }
}

- (void)expand {
  if (_isExpanded) return;
  _isExpanded = YES;

  // ── Save original position ──
  // We need to remember where this view was so we can put it back.
  _originalSuperview = self.superview;
  _originalIndex = [_originalSuperview.subviews indexOfObject:self];
  _originalCornerRadius = self.layer.cornerRadius;

  // Get current position in window coordinates.
  _originalFrame = [self convertRect:self.bounds toView:nil];

  // ── Reparent to window ──
  // Move the card to the key window so it sits above everything
  // (navigation bars, tab bars, other views).
  UIWindow *window = self.window;
  if (!window) return;

  // Set the frame in window coordinates BEFORE reparenting.
  // After removeFromSuperview, the view's frame is relative to the
  // new parent (window), so we use the window-relative frame.
  [self removeFromSuperview];
  self.frame = _originalFrame;
  [window addSubview:self];

  // Fire event so JS can swap to expanded content.
  if (self.onMorphStart) {
    self.onMorphStart(@{});
  }

  // ── Animate to fullscreen ──
  NSTimeInterval durationSeconds = _duration / 1000.0;
  CGRect fullscreen = window.bounds;

  UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
      initWithDuration:durationSeconds
          dampingRatio:0.85
            animations:^{
              self.frame = fullscreen;
              self.layer.cornerRadius = 0;
            }];

  [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
    if (self.onMorphComplete) {
      self.onMorphComplete(@{});
    }
  }];

  [animator startAnimation];
}

- (void)collapse {
  if (!_isExpanded) return;

  NSTimeInterval durationSeconds = _duration / 1000.0;

  UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
      initWithDuration:durationSeconds
          dampingRatio:0.85
            animations:^{
              self.frame = self->_originalFrame;
              self.layer.cornerRadius = self->_originalCornerRadius;
            }];

  [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
    self->_isExpanded = NO;

    // ── Reparent back to original superview ──
    // Put the card back where it was in the view hierarchy.
    [self removeFromSuperview];
    if (self->_originalSuperview) {
      NSInteger insertIndex =
          MIN(self->_originalIndex,
              (NSInteger)self->_originalSuperview.subviews.count);
      [self->_originalSuperview insertSubview:self atIndex:insertIndex];
    }

    // Restore the original frame relative to the parent.
    // Since we're back in the original superview, we need the
    // local frame, not the window frame. Convert back.
    if (self->_originalSuperview) {
      self.frame = [self->_originalSuperview
          convertRect:self->_originalFrame
             fromView:nil];
    }

    if (self.onDismissComplete) {
      self.onDismissComplete(@{});
    }
  }];

  [animator startAnimation];
}

@end
