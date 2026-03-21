#import "RNCMorphCardTransparentModalStrategy.h"
#import "RNCMorphCardSourceComponentView.h"
#import "RNCMorphCardTargetComponentView.h"

static UIWindow *getKeyWindow(void);
extern UIView *RNCMorphCardFindScreenContainer(UIView *view);
static BOOL hasVisibleBackgroundColor(UIView *view);
static CGRect imageFrameForScaleMode(UIViewContentMode mode,
                                     CGSize imageSize,
                                     CGSize containerSize);

// These C functions are defined in the source view's .mm —
// we re-declare them here as extern or duplicates depending on linkage.
// Since the originals are static in the .mm, we duplicate them here.

static UIWindow *getKeyWindow(void) {
  for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
    if ([scene isKindOfClass:[UIWindowScene class]]) {
      UIWindowScene *windowScene = (UIWindowScene *)scene;
      for (UIWindow *w in windowScene.windows) {
        if (w.isKeyWindow) {
          return w;
        }
      }
    }
  }
  return nil;
}

static BOOL hasVisibleBackgroundColor(UIView *view) {
  UIColor *bg = view.backgroundColor;
  if (!bg) return NO;
  CGFloat alpha = 0;
  [bg getRed:nil green:nil blue:nil alpha:&alpha];
  return alpha > 0.01;
}

static CGRect imageFrameForScaleMode(UIViewContentMode mode,
                                     CGSize imageSize,
                                     CGSize containerSize) {
  if (mode == UIViewContentModeScaleAspectFit) {
    CGFloat scale = MIN(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height);
    CGFloat w = imageSize.width * scale;
    CGFloat h = imageSize.height * scale;
    return CGRectMake((containerSize.width - w) / 2,
                      (containerSize.height - h) / 2, w, h);
  } else if (mode == UIViewContentModeScaleToFill) {
    return (CGRect){CGPointZero, containerSize};
  } else {
    // AspectFill
    CGFloat scale = MAX(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height);
    CGFloat w = imageSize.width * scale;
    CGFloat h = imageSize.height * scale;
    return CGRectMake((containerSize.width - w) / 2,
                      (containerSize.height - h) / 2, w, h);
  }
}

@implementation RNCMorphCardTransparentModalStrategy

#pragma mark - Expand

- (void)expandToTarget:(UIView *)targetView
            sourceView:(RNCMorphCardSourceComponentView *)sourceView
               resolve:(RCTPromiseResolveBlock)resolve {
  if (sourceView.isExpanded) {
    resolve(@(NO));
    return;
  }
  sourceView.isExpanded = YES;

  UIWindow *window = getKeyWindow();
  if (!window) {
    resolve(@(NO));
    return;
  }

  sourceView.targetView = targetView;

  // ── 1. Save card geometry ──
  sourceView.cardFrame = [sourceView convertRect:sourceView.bounds toView:nil];
  sourceView.cardCornerRadius = sourceView.layer.cornerRadius;
  BOOL hasWrapper = hasVisibleBackgroundColor(sourceView);

  // ── 2. Snapshot the card ──
  UIImage *cardImage = [sourceView captureSnapshot];

  // ── 3. Keep source screen visible during navigation transition ──
  UIView *sourceScreen = RNCMorphCardFindScreenContainer(sourceView);
  sourceView.sourceScreenContainer = sourceScreen;
  sourceView.targetScreenContainer = RNCMorphCardFindScreenContainer(targetView);

  if (sourceScreen) {
    sourceScreen.alpha = 1;
  }

  // ── 4. Compute target frame and corner radius ──
  CGFloat targetCornerRadius = 0;
  CGRect targetFrame = [sourceView targetFrameForView:targetView
                                         cornerRadius:&targetCornerRadius];

  CGRect cardFrame = sourceView.cardFrame;
  CGFloat cardCornerRadius = sourceView.cardCornerRadius;
  NSTimeInterval dur = (sourceView.expandDuration > 0 ? sourceView.expandDuration : sourceView.duration) / 1000.0;

  if (hasWrapper) {
    // ══ WRAPPER MODE ══
    UIView *wrapper = [[UIView alloc] initWithFrame:cardFrame];
    wrapper.backgroundColor = sourceView.backgroundColor;
    wrapper.layer.cornerRadius = cardCornerRadius;
    wrapper.clipsToBounds = YES;

    UIImageView *content = [[UIImageView alloc] initWithImage:cardImage];
    content.contentMode = UIViewContentModeTopLeft;
    content.clipsToBounds = YES;
    content.frame = (CGRect){CGPointZero, cardFrame.size};
    [wrapper addSubview:content];

    [window addSubview:wrapper];
    sourceView.wrapperView = wrapper;

    // Hide source AFTER overlay is on screen to avoid flicker
    sourceView.alpha = 0;

    CGFloat contentOffsetY = sourceView.pendingContentOffsetY;
    BOOL contentCentered = sourceView.pendingContentCentered;
    CGSize contentSize = cardFrame.size;

    CGFloat targetCx = contentCentered
        ? (targetFrame.size.width - contentSize.width) / 2.0
        : 0;
    CGFloat targetCy = contentCentered
        ? (targetFrame.size.height - contentSize.height) / 2.0
        : contentOffsetY;

    // Use bounds/center instead of frame so rotation transforms work correctly
    CGFloat totalAngleDeg = sourceView.rotations * 360.0 + sourceView.rotationEndAngle;
    CGFloat totalAngleRad = totalAngleDeg * M_PI / 180.0;
    wrapper.bounds = CGRectMake(0, 0, cardFrame.size.width, cardFrame.size.height);
    wrapper.center = CGPointMake(CGRectGetMidX(cardFrame), CGRectGetMidY(cardFrame));

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:dur
            dampingRatio:0.85
              animations:^{
                wrapper.bounds = CGRectMake(0, 0, targetFrame.size.width, targetFrame.size.height);
                wrapper.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
                wrapper.layer.cornerRadius = targetCornerRadius;
                content.frame = CGRectMake(targetCx, targetCy,
                                           contentSize.width,
                                           contentSize.height);
              }];

    // Use CABasicAnimation for rotation — UIViewPropertyAnimator takes the
    // shortest path and can't do multiple full spins.
    if (totalAngleRad != 0) {
      CABasicAnimation *rotAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
      rotAnim.fromValue = @(0);
      rotAnim.toValue = @(totalAngleRad);
      rotAnim.duration = dur;
      rotAnim.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.25 :1.0 :0.5 :1.0];
      rotAnim.fillMode = kCAFillModeForwards;
      rotAnim.removedOnCompletion = NO;
      [wrapper.layer addAnimation:rotAnim forKey:@"morphRotation"];
    }

    // Hide the target view itself so it doesn't double-render over the morph overlay.
    if (targetView) {
      targetView.hidden = YES;
    }

    // Start fading in screen content early (at 15% of the animation).
    __weak RNCMorphCardSourceComponentView *weakSource = sourceView;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          RNCMorphCardSourceComponentView *strongSource = weakSource;
          if (!strongSource || !strongSource.isExpanded) return;
          UIView *ts = strongSource.targetScreenContainer;
          if (ts) {
            [UIView animateWithDuration:dur * 0.5
                animations:^{ ts.alpha = 1; }
                completion:nil];
          }
        });

    UIColor *wrapperBg = wrapper.backgroundColor;

    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
      if (targetView && [targetView isKindOfClass:[RNCMorphCardTargetComponentView class]]) {
        RNCMorphCardTargetComponentView *target = (RNCMorphCardTargetComponentView *)targetView;
        UIView *contentView = wrapper.subviews.firstObject;
        if ([contentView isKindOfClass:[UIImageView class]]) {
          CGRect contentFrame = contentView.frame;
          [target showSnapshot:((UIImageView *)contentView).image
                   contentMode:UIViewContentModeTopLeft
                         frame:contentFrame
                  cornerRadius:targetCornerRadius
               backgroundColor:wrapperBg];
        }
        // Crossfade snapshot out to reveal live React children underneath
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
              [target fadeOutSnapshot];
            });
      }
      if (targetView) {
        targetView.hidden = NO;
        CGFloat endAngleRad = sourceView.rotationEndAngle * M_PI / 180.0;
        if (endAngleRad != 0) {
          targetView.transform = CGAffineTransformMakeRotation(endAngleRad);
        }
      }
      sourceView.alpha = 1;
      UIView *ts = sourceView.targetScreenContainer;
      if (ts) { ts.alpha = 1; }
      [wrapper removeFromSuperview];
      sourceView.wrapperView = nil;
      resolve(@(YES));
    }];

    [animator startAnimation];

  } else {
    // ══ NO-WRAPPER MODE ══
    UIViewContentMode scaleMode = sourceView.scaleMode;
    CGSize imageSize = cardImage.size;

    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.bounds = CGRectMake(0, 0, cardFrame.size.width, cardFrame.size.height);
    container.center = CGPointMake(CGRectGetMidX(cardFrame), CGRectGetMidY(cardFrame));
    container.clipsToBounds = YES;
    container.layer.cornerRadius = cardCornerRadius;

    UIImageView *snapshot = [[UIImageView alloc] initWithImage:cardImage];
    snapshot.clipsToBounds = YES;
    snapshot.frame = (CGRect){CGPointZero, cardFrame.size};
    [container addSubview:snapshot];

    [window addSubview:container];
    sourceView.snapshotView = snapshot;
    sourceView.wrapperView = container;

    // Hide source AFTER overlay is on screen to avoid flicker
    sourceView.alpha = 0;

    if (targetView) {
      targetView.hidden = YES;
    }

    // Compute final image frame based on scaleMode
    CGRect targetImageFrame = imageFrameForScaleMode(
        scaleMode, imageSize, targetFrame.size);

    CGFloat totalAngleDegNoWrap = sourceView.rotations * 360.0 + sourceView.rotationEndAngle;
    CGFloat totalAngleRadNoWrap = totalAngleDegNoWrap * M_PI / 180.0;

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:dur
            dampingRatio:0.85
              animations:^{
                container.bounds = CGRectMake(0, 0, targetFrame.size.width, targetFrame.size.height);
                container.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
                container.layer.cornerRadius = targetCornerRadius;
                snapshot.frame = targetImageFrame;
              }];

    // Use CABasicAnimation for rotation — supports multiple full spins
    if (totalAngleRadNoWrap != 0) {
      CABasicAnimation *rotAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
      rotAnim.fromValue = @(0);
      rotAnim.toValue = @(totalAngleRadNoWrap);
      rotAnim.duration = dur;
      rotAnim.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.25 :1.0 :0.5 :1.0];
      rotAnim.fillMode = kCAFillModeForwards;
      rotAnim.removedOnCompletion = NO;
      [container.layer addAnimation:rotAnim forKey:@"morphRotation"];
    }

    // Start fading in screen content early (at 15% of the animation).
    __weak RNCMorphCardSourceComponentView *weakSource2 = sourceView;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          RNCMorphCardSourceComponentView *strongSource2 = weakSource2;
          if (!strongSource2 || !strongSource2.isExpanded) return;
          UIView *ts = strongSource2.targetScreenContainer;
          if (ts) {
            [UIView animateWithDuration:dur * 0.5
                animations:^{ ts.alpha = 1; }
                completion:nil];
          }
        });

    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
      if (targetView && [targetView isKindOfClass:[RNCMorphCardTargetComponentView class]]) {
        RNCMorphCardTargetComponentView *target = (RNCMorphCardTargetComponentView *)targetView;
        [target showSnapshot:snapshot.image
                 contentMode:scaleMode
                       frame:target.bounds
                cornerRadius:targetCornerRadius
             backgroundColor:nil];
        // Crossfade snapshot out to reveal live React children underneath
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
              [target fadeOutSnapshot];
            });
      }
      if (targetView) {
        targetView.hidden = NO;
        CGFloat endAngleRad = sourceView.rotationEndAngle * M_PI / 180.0;
        if (endAngleRad != 0) {
          targetView.transform = CGAffineTransformMakeRotation(endAngleRad);
        }
      }
      sourceView.alpha = 1;
      UIView *ts = sourceView.targetScreenContainer;
      if (ts) { ts.alpha = 1; }
      [container removeFromSuperview];
      sourceView.wrapperView = nil;
      sourceView.snapshotView = nil;
      resolve(@(YES));
    }];

    [animator startAnimation];
  }
}

#pragma mark - Collapse

- (void)collapseFromTarget:(UIView *)targetView
                sourceView:(RNCMorphCardSourceComponentView *)sourceView
                   resolve:(RCTPromiseResolveBlock)resolve {
  if (!sourceView.isExpanded) {
    resolve(@(NO));
    return;
  }

  UIWindow *window = getKeyWindow();
  if (!window) {
    resolve(@(NO));
    return;
  }

  UIView *targetScreen = sourceView.targetScreenContainer;
  UIView *sourceScreen = sourceView.sourceScreenContainer;
  CGRect cardFrame = sourceView.cardFrame;
  CGFloat cardCornerRadius = sourceView.cardCornerRadius;
  BOOL hasWrapper = sourceView.hasWrapper;

  // Clear the snapshot and hide the target view so live children
  // don't show behind the animating collapse overlay
  if (targetView && [targetView isKindOfClass:[RNCMorphCardTargetComponentView class]]) {
    [(RNCMorphCardTargetComponentView *)targetView clearSnapshot];
    targetView.hidden = YES;
    targetView.transform = CGAffineTransformIdentity;
  }

  CGFloat collapseDur = 0;
  if (targetView && [targetView isKindOfClass:[RNCMorphCardTargetComponentView class]]) {
    collapseDur = ((RNCMorphCardTargetComponentView *)targetView).collapseDuration;
  }
  NSTimeInterval dur = (collapseDur > 0 ? collapseDur : sourceView.duration) / 1000.0;

  if (hasWrapper) {
    // ══ WRAPPER MODE COLLAPSE ══
    UIView *wrapper = sourceView.wrapperView;
    if (!wrapper) {
      sourceView.alpha = 1;
      UIImage *cardImage = [sourceView captureSnapshot];
      sourceView.alpha = 0;

      CGFloat targetCornerRadius = 0;
      CGRect targetFrame = [sourceView targetFrameForView:targetView
                                             cornerRadius:&targetCornerRadius];

      CGFloat contentOffsetY = sourceView.pendingContentOffsetY;
      BOOL contentCentered = sourceView.pendingContentCentered;
      CGSize contentSize = cardFrame.size;
      CGFloat cx = contentCentered
          ? (targetFrame.size.width - contentSize.width) / 2.0 : 0;
      CGFloat cy = contentCentered
          ? (targetFrame.size.height - contentSize.height) / 2.0
          : contentOffsetY;

      wrapper = [[UIView alloc] initWithFrame:CGRectZero];
      wrapper.bounds = CGRectMake(0, 0, targetFrame.size.width, targetFrame.size.height);
      wrapper.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
      wrapper.backgroundColor = sourceView.backgroundColor;
      wrapper.layer.cornerRadius = targetCornerRadius;
      wrapper.clipsToBounds = YES;

      UIImageView *content = [[UIImageView alloc] initWithImage:cardImage];
      content.contentMode = UIViewContentModeTopLeft;
      content.clipsToBounds = YES;
      content.frame = CGRectMake(cx, cy, contentSize.width, contentSize.height);
      [wrapper addSubview:content];

      [window addSubview:wrapper];
      sourceView.wrapperView = wrapper;
    }

    // Show source screen underneath before starting collapse
    if (sourceScreen) {
      sourceScreen.alpha = 1;
    }

    UIView *content = wrapper.subviews.firstObject;

    UICubicTimingParameters *timing = [[UICubicTimingParameters alloc]
        initWithControlPoint1:CGPointMake(0.25, 1.0)
                controlPoint2:CGPointMake(0.5, 1.0)];
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:dur
        timingParameters:timing];
    [animator addAnimations:^{
      wrapper.bounds = CGRectMake(0, 0, cardFrame.size.width, cardFrame.size.height);
      wrapper.center = CGPointMake(CGRectGetMidX(cardFrame), CGRectGetMidY(cardFrame));
      wrapper.layer.cornerRadius = cardCornerRadius;
      if (content) {
        content.frame = (CGRect){CGPointZero, content.frame.size};
      }
    }];

    // Animate rotation back to 0
    CGFloat collapseStartAngle = sourceView.rotationEndAngle * M_PI / 180.0;
    if (collapseStartAngle != 0) {
      CABasicAnimation *rotAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
      rotAnim.fromValue = @(collapseStartAngle);
      rotAnim.toValue = @(0);
      rotAnim.duration = dur;
      rotAnim.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.25 :1.0 :0.5 :1.0];
      rotAnim.fillMode = kCAFillModeForwards;
      rotAnim.removedOnCompletion = NO;
      [wrapper.layer addAnimation:rotAnim forKey:@"morphRotation"];
    }

    // Fade out target screen (only if different from source screen)
    if (targetScreen && targetScreen != sourceScreen) {
      [sourceView scheduleScreenFadeOut:targetScreen duration:dur];
    }

    [animator addCompletion:^(UIViewAnimatingPosition pos) {
      [sourceView collapseCleanupWithContainer:wrapper resolve:resolve];
    }];

    [animator startAnimation];

  } else {
    // ══ NO-WRAPPER MODE COLLAPSE ══
    UIView *container = sourceView.wrapperView;
    UIImageView *snapshot = sourceView.snapshotView;

    if (!container) {
      sourceView.alpha = 1;
      UIImage *cardImage = [sourceView captureSnapshot];
      sourceView.alpha = 0;

      CGFloat targetCornerRadius = 0;
      CGRect targetFrame = [sourceView targetFrameForView:targetView
                                             cornerRadius:&targetCornerRadius];

      CGSize imageSize = cardImage.size;
      CGRect imageFrame = imageFrameForScaleMode(
          sourceView.scaleMode, imageSize, targetFrame.size);

      container = [[UIView alloc] initWithFrame:CGRectZero];
      container.bounds = CGRectMake(0, 0, targetFrame.size.width, targetFrame.size.height);
      container.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
      container.clipsToBounds = YES;
      container.layer.cornerRadius = targetCornerRadius;

      snapshot = [[UIImageView alloc] initWithImage:cardImage];
      snapshot.clipsToBounds = YES;
      snapshot.frame = imageFrame;
      [container addSubview:snapshot];

      [window addSubview:container];
      sourceView.wrapperView = container;
      sourceView.snapshotView = snapshot;
    }

    // Show source screen underneath before starting collapse
    if (sourceScreen) {
      sourceScreen.alpha = 1;
    }

    UICubicTimingParameters *timing = [[UICubicTimingParameters alloc]
        initWithControlPoint1:CGPointMake(0.25, 1.0)
                controlPoint2:CGPointMake(0.5, 1.0)];
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:dur
        timingParameters:timing];
    [animator addAnimations:^{
      container.bounds = CGRectMake(0, 0, cardFrame.size.width, cardFrame.size.height);
      container.center = CGPointMake(CGRectGetMidX(cardFrame), CGRectGetMidY(cardFrame));
      container.layer.cornerRadius = cardCornerRadius;
      snapshot.frame = (CGRect){CGPointZero, cardFrame.size};
    }];

    // Animate rotation back to 0
    CGFloat collapseStartAngleNW = sourceView.rotationEndAngle * M_PI / 180.0;
    if (collapseStartAngleNW != 0) {
      CABasicAnimation *rotAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
      rotAnim.fromValue = @(collapseStartAngleNW);
      rotAnim.toValue = @(0);
      rotAnim.duration = dur;
      rotAnim.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.25 :1.0 :0.5 :1.0];
      rotAnim.fillMode = kCAFillModeForwards;
      rotAnim.removedOnCompletion = NO;
      [container.layer addAnimation:rotAnim forKey:@"morphRotation"];
    }

    // Fade out target screen (only if different from source screen)
    if (targetScreen && targetScreen != sourceScreen) {
      [sourceView scheduleScreenFadeOut:targetScreen duration:dur];
    }

    [animator addCompletion:^(UIViewAnimatingPosition pos) {
      [sourceView collapseCleanupWithContainer:container resolve:resolve];
    }];

    [animator startAnimation];
  }
}

@end
