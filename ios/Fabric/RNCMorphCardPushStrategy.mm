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
  __block CFTimeInterval startTime = 0;
  __block BOOL animationStarted = NO;
  __block CGPoint lastKnownCenter = startCenter;

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
    // Ease-out for all modes — overshoot doesn't work well with position tracking
    CGFloat t = 1.0 - pow(1.0 - rawT, 3.0);

    // Poll target's CURRENT position (it moves as the screen slides in).
    // Lock position after 80% of animation to avoid end-of-slide jitter.
    CGPoint destCenter;
    if (tv.window) {
      CGPoint origin = [tv convertPoint:CGPointZero toView:nil];
      CGFloat tw = sourceView.pendingTargetWidth > 0 ? sourceView.pendingTargetWidth : cardFrame.size.width;
      CGFloat th = sourceView.pendingTargetHeight > 0 ? sourceView.pendingTargetHeight : cardFrame.size.height;
      CGPoint liveCenter = CGPointMake(origin.x + tw / 2.0, origin.y + th / 2.0);
      if (rawT < 0.8) {
        lastKnownCenter = liveCenter;
      }
      destCenter = lastKnownCenter;
    } else {
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
        // Center content in the CURRENT wrapper size at every frame
        CGFloat cx = contentCentered ? (w - contentSize.width) / 2.0 : 0;
        CGFloat cy = contentCentered ? (h - contentSize.height) / 2.0 : contentOffsetY * t;
        content.frame = CGRectMake(cx, cy, contentSize.width, contentSize.height);
      } else {
        // Compute image frame based on scaleMode to avoid stretching
        CGSize imgSize = cardFrame.size;
        CGSize containerSize = CGSizeMake(w, h);
        UIViewContentMode sm = sourceView.scaleMode;
        if (sm == UIViewContentModeScaleAspectFit) {
          CGFloat scale = MIN(w / imgSize.width, h / imgSize.height);
          CGFloat iw = imgSize.width * scale, ih = imgSize.height * scale;
          content.frame = CGRectMake((w - iw) / 2, (h - ih) / 2, iw, ih);
        } else if (sm == UIViewContentModeScaleToFill) {
          content.frame = CGRectMake(0, 0, w, h);
        } else {
          // AspectFill
          CGFloat scale = MAX(w / imgSize.width, h / imgSize.height);
          CGFloat iw = imgSize.width * scale, ih = imgSize.height * scale;
          content.frame = CGRectMake((w - iw) / 2, (h - ih) / 2, iw, ih);
        }
      }
    }

    if (totalAngleRad != 0) {
      wrapper.transform = CGAffineTransformMakeRotation(totalAngleRad * t);
    }

    if (rawT >= 1.0) {
      [timer invalidate];

      // Don't restore source alpha — stays hidden until collapse
      // Restore target visibility
      if (targetView) {
        targetView.alpha = 1;
        targetView.hidden = NO;
        CGFloat endAngleRad = sourceView.rotationEndAngle * M_PI / 180.0;
        if (endAngleRad != 0) {
          targetView.transform = CGAffineTransformMakeRotation(endAngleRad);
        }
        if ([targetView isKindOfClass:[RNCMorphCardTargetComponentView class]]) {
          RNCMorphCardTargetComponentView *target = (RNCMorphCardTargetComponentView *)targetView;
          // Always transfer snapshot — if live children exist, fadeOutSnapshot
          // reveals them. If not (resizeMode set), snapshot stays.
          if (content && [content isKindOfClass:[UIImageView class]]) {
            UIImage *img = ((UIImageView *)content).image;
            if (img) {
              CGRect frame = hasWrapper
                ? CGRectMake(
                    contentCentered ? (destW - contentSize.width) / 2.0 : 0,
                    contentCentered ? (destH - contentSize.height) / 2.0 : contentOffsetY,
                    contentSize.width, contentSize.height)
                : target.bounds;
              [target showSnapshot:img
                       contentMode:hasWrapper ? UIViewContentModeTopLeft : sourceView.scaleMode
                             frame:frame
                      cornerRadius:targetCornerRadius
                   backgroundColor:hasWrapper ? sourceView.backgroundColor : nil];
              dispatch_after(
                  dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                  dispatch_get_main_queue(), ^{
                    [target fadeOutSnapshot];
                  });
            }
          }
          [target showChildren];
        }
      }
      // Fade out overlay over 150ms — gives target time to render live content
      [UIView animateWithDuration:0.15
          animations:^{ wrapper.alpha = 0; }
          completion:^(BOOL finished) {
            wrapper.hidden = YES;
          }];
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

  UIView *content = wrapper.subviews.firstObject;
  if (sourceView.hasWrapper) {
    // Wrapper mode: recapture for live data
    sourceView.alpha = 1;
    UIImage *freshImage = [sourceView captureSnapshotAfterUpdates];
    sourceView.alpha = 0;
    if (content && [content isKindOfClass:[UIImageView class]]) {
      ((UIImageView *)content).image = freshImage;
      ((UIImageView *)content).contentMode = UIViewContentModeTopLeft;
    }
  }
  // No-wrapper: reuse expand content as-is (no recapture, no stretch)
  if (content) {
    content.alpha = 1;
    content.hidden = NO;
    CGFloat wrapW = wrapper.bounds.size.width;
    CGFloat wrapH = wrapper.bounds.size.height;
    if (sourceView.hasWrapper) {
      // Wrapper mode: position content at source size, centered or offset
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

  // Remove autoresizingMask BEFORE unhiding to prevent layout pass from resizing content
  for (UIView *sub in wrapper.subviews) {
    sub.autoresizingMask = UIViewAutoresizingNone;
  }

  // Unhide the wrapper at its existing position (saved from expand).
  wrapper.alpha = 1;
  wrapper.hidden = NO;
  wrapper.clipsToBounds = YES;
  [wrapper.layer removeAnimationForKey:@"morphRotation"];
  // Set the rotation transform explicitly (CA animation was removed above).
  // The timer will animate it back to identity.
  CGFloat startAngleForTransform = sourceView.rotationEndAngle * M_PI / 180.0;
  wrapper.transform = startAngleForTransform != 0
    ? CGAffineTransformMakeRotation(startAngleForTransform)
    : CGAffineTransformIdentity;
  // Ensure all subviews are visible
  for (UIView *sub in wrapper.subviews) {
    sub.alpha = 1;
    sub.hidden = NO;
  }
  NSLog(@"[MorphCard] push collapse: wrapper unhidden at center=(%f,%f) bounds=(%f,%f) → cardFrame=(%f,%f,%f,%f)",
        wrapper.center.x, wrapper.center.y,
        wrapper.bounds.size.width, wrapper.bounds.size.height,
        cardFrame.origin.x, cardFrame.origin.y, cardFrame.size.width, cardFrame.size.height);

  // Force content frame to match wrapper's current bounds with scaleMode
  // to prevent intermittent stretch from stale layout
  if (content && !sourceView.hasWrapper) {
    CGFloat ww = wrapper.bounds.size.width;
    CGFloat wh = wrapper.bounds.size.height;
    CGSize imgSize = cardFrame.size;
    UIViewContentMode sm = sourceView.scaleMode;
    if (sm == UIViewContentModeScaleAspectFit) {
      CGFloat scale = MIN(ww / imgSize.width, wh / imgSize.height);
      CGFloat iw = imgSize.width * scale, ih = imgSize.height * scale;
      content.frame = CGRectMake((ww - iw) / 2, (wh - ih) / 2, iw, ih);
    } else if (sm == UIViewContentModeScaleToFill) {
      content.frame = CGRectMake(0, 0, ww, wh);
    } else {
      CGFloat scale = MAX(ww / imgSize.width, wh / imgSize.height);
      CGFloat iw = imgSize.width * scale, ih = imgSize.height * scale;
      content.frame = CGRectMake((ww - iw) / 2, (wh - ih) / 2, iw, ih);
    }
  }

  // IMPORTANT: Hide source and target cards during collapse
  sourceView.alpha = 0;
  targetView.alpha = 0;

  // Remove autoresizingMask for manual frame control
  if (content) {
    content.autoresizingMask = UIViewAutoresizingNone;
  }

  NSTimeInterval dur = 0.45;
  CGPoint startCenter = wrapper.center;
  CGSize startSize = wrapper.bounds.size;
  CGFloat startCornerRadius = wrapper.layer.cornerRadius;
  CGRect startContentFrame = content ? content.frame : CGRectZero;
  CGFloat startAngle = sourceView.rotationEndAngle * M_PI / 180.0;

  // Timer-driven collapse (same approach as expand) for perfect per-frame control
  __block CFTimeInterval startTime = CACurrentMediaTime();
  __block NSTimer *collapseTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/120.0 repeats:YES block:^(NSTimer *timer) {
    CFTimeInterval elapsed = CACurrentMediaTime() - startTime;
    CGFloat rawT = MIN(1.0, elapsed / dur);
    // Ease-out (no overshoot)
    CGFloat t = 1.0 - pow(1.0 - rawT, 3.0);

    CGFloat w = startSize.width + (cardFrame.size.width - startSize.width) * t;
    CGFloat h = startSize.height + (cardFrame.size.height - startSize.height) * t;
    CGFloat cx = startCenter.x + (CGRectGetMidX(cardFrame) - startCenter.x) * t;
    CGFloat cy = startCenter.y + (CGRectGetMidY(cardFrame) - startCenter.y) * t;

    wrapper.bounds = CGRectMake(0, 0, w, h);
    wrapper.center = CGPointMake(cx, cy);
    wrapper.layer.cornerRadius = startCornerRadius + (cardCornerRadius - startCornerRadius) * t;

    if (content) {
      if (sourceView.hasWrapper) {
        // Wrapper: move content from centered offset to origin
        CGFloat fx = startContentFrame.origin.x * (1.0 - t);
        CGFloat fy = startContentFrame.origin.y * (1.0 - t);
        content.frame = CGRectMake(fx, fy, startContentFrame.size.width, startContentFrame.size.height);
      } else {
        // No-wrapper: compute image frame per scaleMode at current size
        CGSize imgSize = cardFrame.size;
        UIViewContentMode sm = sourceView.scaleMode;
        if (sm == UIViewContentModeScaleAspectFit) {
          CGFloat scale = MIN(w / imgSize.width, h / imgSize.height);
          CGFloat iw = imgSize.width * scale, ih = imgSize.height * scale;
          content.frame = CGRectMake((w - iw) / 2, (h - ih) / 2, iw, ih);
        } else if (sm == UIViewContentModeScaleToFill) {
          content.frame = CGRectMake(0, 0, w, h);
        } else {
          // AspectFill
          CGFloat scale = MAX(w / imgSize.width, h / imgSize.height);
          CGFloat iw = imgSize.width * scale, ih = imgSize.height * scale;
          content.frame = CGRectMake((w - iw) / 2, (h - ih) / 2, iw, ih);
        }
      }
    }

    if (startAngle != 0) {
      wrapper.transform = CGAffineTransformMakeRotation(startAngle * (1.0 - t));
    }

    // Keep source/target hidden every frame
    sourceView.alpha = 0;
    targetView.alpha = 0;

    if (rawT >= 1.0) {
      [timer invalidate];
      // Show source, then crossfade wrapper out over 100ms
      sourceView.alpha = 1;
      sourceView.hidden = NO;
      targetView.alpha = 1;
      sourceView.isCollapsing = NO;

      [UIView animateWithDuration:0.1
          animations:^{ wrapper.alpha = 0; }
          completion:^(BOOL finished) {
            wrapper.hidden = YES;
            [sourceView collapseCleanupWithContainer:wrapper resolve:resolve];
          }];
    }
  }];
}

@end
