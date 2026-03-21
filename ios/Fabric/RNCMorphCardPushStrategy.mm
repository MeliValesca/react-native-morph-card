#import "RNCMorphCardPushStrategy.h"
#import "RNCMorphCardSourceComponentView.h"
#import "RNCMorphCardTargetComponentView.h"

extern UIView *RNCMorphCardFindScreenContainer(UIView *view);

@implementation RNCMorphCardPushStrategy

#pragma mark - Expand

- (void)expandToTarget:(UIView *)targetView
            sourceView:(RNCMorphCardSourceComponentView *)sourceView
               resolve:(RCTPromiseResolveBlock)resolve {
  if (sourceView.isExpanded) {
    resolve(@(NO));
    return;
  }
  sourceView.isExpanded = YES;
  sourceView.targetView = targetView;
  sourceView.targetScreenContainer = RNCMorphCardFindScreenContainer(targetView);

  // The overlay was already created by prepareExpand (before push navigation).
  // It's on the window and above the pushed screen.
  UIView *wrapper = sourceView.wrapperView;
  if (!wrapper) {
    resolve(@(NO));
    return;
  }

  CGRect cardFrame = sourceView.cardFrame;
  CGFloat cardCornerRadius = sourceView.cardCornerRadius;

  // Compute target frame
  CGFloat targetCornerRadius = 0;
  CGRect targetFrame = [sourceView targetFrameForView:targetView
                                         cornerRadius:&targetCornerRadius];

  NSTimeInterval dur = (sourceView.expandDuration > 0 ? sourceView.expandDuration : sourceView.duration) / 1000.0;

  UIView *content = wrapper.subviews.firstObject;
  BOOL hasWrapper = sourceView.hasWrapper;

  CGFloat contentOffsetY = sourceView.pendingContentOffsetY;
  BOOL contentCentered = sourceView.pendingContentCentered;
  CGSize contentSize = cardFrame.size;

  CGFloat targetCx = contentCentered
      ? (targetFrame.size.width - contentSize.width) / 2.0
      : 0;
  CGFloat targetCy = contentCentered
      ? (targetFrame.size.height - contentSize.height) / 2.0
      : contentOffsetY;

  // Use bounds/center for rotation-safe animation
  CGFloat totalAngleDeg = sourceView.rotations * 360.0 + sourceView.rotationEndAngle;
  CGFloat totalAngleRad = totalAngleDeg * M_PI / 180.0;

  if (!hasWrapper) {
    // No-wrapper mode: set bounds/center instead of frame
    wrapper.bounds = CGRectMake(0, 0, cardFrame.size.width, cardFrame.size.height);
    wrapper.center = CGPointMake(CGRectGetMidX(cardFrame), CGRectGetMidY(cardFrame));
  }

  // IMPORTANT: Hide source and target cards during expand animation
  sourceView.alpha = 0;
  if (targetView) { targetView.alpha = 0; }

  // Use a timer-driven animation (like Android's ValueAnimator) so we can
  // poll the target's MOVING position each frame as it slides in.
  CGPoint startCenter = wrapper.center;
  CGSize startSize = cardFrame.size;
  CGFloat startCornerRadius = cardCornerRadius;
  __block CFTimeInterval startTime = 0; // Will be set when target appears
  __block BOOL animationStarted = NO;

  __block NSTimer *animTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/120.0 repeats:YES block:^(NSTimer *timer) {
    // IMPORTANT: Keep source and target hidden every frame (React may reset alpha)
    sourceView.alpha = 0;
    if (sourceView.targetView) { sourceView.targetView.alpha = 0; }

    // Wait for target to appear before starting the animation clock
    UIView *tv = sourceView.targetView;
    if (!tv || !tv.window) return;

    if (!animationStarted) {
      // Reset pre-animation scale on first frame
      wrapper.transform = CGAffineTransformIdentity;
      startTime = CACurrentMediaTime();
      animationStarted = YES;
    }

    CFTimeInterval elapsed = CACurrentMediaTime() - startTime;
    CGFloat rawT = MIN(1.0, elapsed / dur);
    // Overshoot curve matching Android's OvershootInterpolator(tension=1.0)
    // Formula: (t-1)^2 * ((tension+1)*(t-1) + tension) + 1
    CGFloat tension = 1.0;
    CGFloat shifted = rawT - 1.0;
    CGFloat t = shifted * shifted * ((tension + 1.0) * shifted + tension) + 1.0;

    // Poll target's CURRENT position (it moves as the screen slides in).
    CGPoint destCenter;
    if (tv.window) {
      CGPoint origin = [tv convertPoint:CGPointZero toView:nil];
      CGFloat tw = sourceView.pendingTargetWidth > 0 ? sourceView.pendingTargetWidth : cardFrame.size.width;
      CGFloat th = sourceView.pendingTargetHeight > 0 ? sourceView.pendingTargetHeight : cardFrame.size.height;
      destCenter = CGPointMake(origin.x + tw / 2.0, origin.y + th / 2.0);
    } else {
      // Target not ready yet — stay at source position
      destCenter = startCenter;
    }

    CGFloat cx = startCenter.x + (destCenter.x - startCenter.x) * t;
    CGFloat cy = startCenter.y + (destCenter.y - startCenter.y) * t;
    wrapper.center = CGPointMake(cx, cy);

    CGFloat destW = sourceView.pendingTargetWidth > 0 ? sourceView.pendingTargetWidth : targetFrame.size.width;
    CGFloat destH = sourceView.pendingTargetHeight > 0 ? sourceView.pendingTargetHeight : targetFrame.size.height;
    CGFloat w = startSize.width + (destW - startSize.width) * t;
    CGFloat h = startSize.height + (destH - startSize.height) * t;
    wrapper.bounds = CGRectMake(0, 0, w, h);
    wrapper.layer.cornerRadius = startCornerRadius + (targetCornerRadius - startCornerRadius) * t;

    if (content) {
      if (hasWrapper) {
        content.frame = CGRectMake(targetCx * t, targetCy * t, contentSize.width, contentSize.height);
      } else {
        content.frame = CGRectMake(0, 0, w, h);
      }
    }

    if (totalAngleRad != 0) {
      wrapper.transform = CGAffineTransformMakeRotation(totalAngleRad * t);
    }

    if (rawT >= 1.0) {
      [timer invalidate];

      // Restore source and target visibility
      sourceView.alpha = 1;
      if (targetView) {
        targetView.alpha = 1;
        targetView.hidden = NO;
        CGFloat endAngleRad = sourceView.rotationEndAngle * M_PI / 180.0;
        if (endAngleRad != 0) {
          targetView.transform = CGAffineTransformMakeRotation(endAngleRad);
        }
        if ([targetView isKindOfClass:[RNCMorphCardTargetComponentView class]]) {
          [(RNCMorphCardTargetComponentView *)targetView showChildren];
        }
      }
      // Hide overlay but keep it for collapse reuse
      wrapper.alpha = 0;
      wrapper.hidden = YES;
      resolve(@(YES));
    }
  }];
}

#pragma mark - Collapse

- (void)collapseFromTarget:(UIView *)targetView
                sourceView:(RNCMorphCardSourceComponentView *)sourceView
                   resolve:(RCTPromiseResolveBlock)resolve {
  if (!sourceView.isExpanded) {
    resolve(@(NO));
    return;
  }

  sourceView.isCollapsing = YES;

  CGRect cardFrame = sourceView.cardFrame;
  CGFloat cardCornerRadius = sourceView.cardCornerRadius;

  // Reuse the expand overlay (already above everything on the window)
  UIView *wrapper = sourceView.wrapperView;
  if (!wrapper) {
    sourceView.isExpanded = NO;
    sourceView.isCollapsing = NO;
    sourceView.alpha = 1;
    resolve(@(NO));
    return;
  }

  // Recapture fresh snapshot with afterScreenUpdates:YES for live data
  sourceView.alpha = 1;
  UIImage *freshImage = [sourceView captureSnapshotAfterUpdates];
  sourceView.alpha = 0;

  UIView *content = wrapper.subviews.firstObject;
  if (content && [content isKindOfClass:[UIImageView class]]) {
    ((UIImageView *)content).image = freshImage;
    // ScaleToFill: the source snapshot is small but the wrapper starts at target size.
    // ScaleToFill stretches to fill, then the wrapper shrinks back to source size.
    ((UIImageView *)content).contentMode = UIViewContentModeScaleToFill;
  }
  if (content) {
    content.alpha = 1;
    content.hidden = NO;
    CGFloat wrapW = wrapper.bounds.size.width;
    CGFloat wrapH = wrapper.bounds.size.height;
    if (sourceView.hasWrapper) {
      // Wrapper mode: position content centered or offset at source size
      CGFloat cx = sourceView.pendingContentCentered
          ? (wrapW - cardFrame.size.width) / 2.0 : 0;
      CGFloat cy = sourceView.pendingContentCentered
          ? (wrapH - cardFrame.size.height) / 2.0
          : sourceView.pendingContentOffsetY;
      content.frame = CGRectMake(cx, cy, cardFrame.size.width, cardFrame.size.height);
    } else {
      // No-wrapper mode: content auto-resizes with wrapper
      content.frame = CGRectMake(0, 0, wrapW, wrapH);
      content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
  }

  // Unhide the wrapper at its existing position (saved from expand).
  wrapper.alpha = 1;
  wrapper.hidden = NO;
  wrapper.clipsToBounds = YES;
  [wrapper.layer removeAnimationForKey:@"morphRotation"];
  wrapper.transform = CGAffineTransformIdentity;
  // Ensure all subviews are visible
  for (UIView *sub in wrapper.subviews) {
    sub.alpha = 1;
    sub.hidden = NO;
  }
  NSLog(@"[MorphCard] push collapse: wrapper unhidden at center=(%f,%f) bounds=(%f,%f) → cardFrame=(%f,%f,%f,%f)",
        wrapper.center.x, wrapper.center.y,
        wrapper.bounds.size.width, wrapper.bounds.size.height,
        cardFrame.origin.x, cardFrame.origin.y, cardFrame.size.width, cardFrame.size.height);

  // Content is already positioned from expand — no need to reposition

  // IMPORTANT: Hide source and target cards during collapse
  sourceView.alpha = 0;
  targetView.alpha = 0;

  // Fixed 450ms with spring timing
  NSTimeInterval dur = 0.45;
  UISpringTimingParameters *springTiming = [[UISpringTimingParameters alloc]
      initWithDampingRatio:0.75
           initialVelocity:CGVectorMake(0, 0)];
  UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
      initWithDuration:dur
      timingParameters:springTiming];

  [animator addAnimations:^{
    wrapper.bounds = CGRectMake(0, 0, cardFrame.size.width, cardFrame.size.height);
    wrapper.center = CGPointMake(CGRectGetMidX(cardFrame), CGRectGetMidY(cardFrame));
    wrapper.layer.cornerRadius = cardCornerRadius;
    if (content && !sourceView.hasWrapper) {
      // No-wrapper: autoresizingMask handles it, but explicitly set for wrapper mode
    }
    if (content && sourceView.hasWrapper) {
      content.frame = (CGRect){CGPointZero, content.frame.size};
    }
  }];

  // Rotation back to 0
  CGFloat collapseStartAngle = sourceView.rotationEndAngle * M_PI / 180.0;
  if (collapseStartAngle != 0) {
    wrapper.transform = CGAffineTransformMakeRotation(collapseStartAngle);
    [animator addAnimations:^{
      wrapper.transform = CGAffineTransformIdentity;
    }];
  }

  [animator addCompletion:^(UIViewAnimatingPosition pos) {
    // IMPORTANT: restore source visibility after collapse
    sourceView.alpha = 1;
    sourceView.hidden = NO;
    targetView.alpha = 1;
    sourceView.isCollapsing = NO;
    NSLog(@"[MorphCard] push collapse COMPLETE — restoring sourceView.alpha=1");
    [sourceView collapseCleanupWithContainer:wrapper resolve:resolve];
  }];

  [animator startAnimation];
}

@end
