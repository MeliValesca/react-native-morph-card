#import "RNCMorphCardSourceComponentView.h"
#import "RNCMorphCardTargetComponentView.h"
#import "RNCMorphCardViewRegistry.h"

#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/morphcard/ComponentDescriptors.h>
#import <react/renderer/components/morphcard/Props.h>

using namespace facebook::react;

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

UIView *RNCMorphCardFindScreenContainer(UIView *view) {
  UIWindow *window = view.window;
  if (!window) return nil;

  CGRect windowBounds = window.bounds;
  UIView *current = view.superview;
  UIView *result = nil;

  while (current && current != window) {
    CGRect frameInWindow = [current convertRect:current.bounds toView:nil];
    if (CGRectEqualToRect(frameInWindow, windowBounds)) {
      result = current;
    }
    current = current.superview;
  }
  return result;
}

static BOOL hasVisibleBackgroundColor(UIView *view) {
  UIColor *bg = view.backgroundColor;
  if (!bg) return NO;
  CGFloat alpha = 0;
  [bg getRed:nil green:nil blue:nil alpha:&alpha];
  return alpha > 0.01;
}

/// Compute the image frame for a given scaleMode within a container of containerSize.
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

#pragma mark - Private interface

@interface RNCMorphCardSourceComponentView ()

- (void)collapseFromTarget:(nullable UIView *)targetView
                   resolve:(RCTPromiseResolveBlock)resolve;

@end

@implementation RNCMorphCardSourceComponentView {
  CGFloat _duration;
  CGFloat _expandDuration;
  UIViewContentMode _scaleMode;
  BOOL _isExpanded;
  BOOL _hasWrapper;
  CGRect _cardFrame;
  CGFloat _cardCornerRadius;
  __weak UIView *_targetView;
  __weak UIView *_sourceScreenContainer;
  __weak UIView *_targetScreenContainer;
  CGFloat _rotations;
  CGFloat _rotationEndAngle;
  UIView *_wrapperView;
  UIImageView *_snapshot;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      RNCMorphCardSourceComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _duration = 500.0;
    _scaleMode = UIViewContentModeScaleAspectFill;
    _pendingTargetBorderRadius = -1;
  }
  return self;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps =
      *std::static_pointer_cast<const RNCMorphCardSourceProps>(props);
  _duration = newProps.duration > 0 ? newProps.duration : 500.0;
  _expandDuration = newProps.expandDuration > 0 ? newProps.expandDuration : 0;
  auto sm = newProps.scaleMode;
  if (sm == RNCMorphCardSourceScaleMode::AspectFit) {
    _scaleMode = UIViewContentModeScaleAspectFit;
  } else if (sm == RNCMorphCardSourceScaleMode::Stretch) {
    _scaleMode = UIViewContentModeScaleToFill;
  } else {
    _scaleMode = UIViewContentModeScaleAspectFill;
  }
  _rotations = newProps.rotations;
  _rotationEndAngle = newProps.rotationEndAngle;
  [super updateProps:props oldProps:oldProps];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [[RNCMorphCardViewRegistry shared] registerView:self withTag:self.tag];
  } else {
    [[RNCMorphCardViewRegistry shared] unregisterViewWithTag:self.tag];
  }
}

#pragma mark - Snapshot helper

- (UIImage *)captureSnapshot {
  // Render children directly into a fresh context so the snapshot
  // captures full rectangular content without the source view's
  // cornerRadius clipping. No on-screen flash since we never
  // modify visible properties.
  UIGraphicsImageRendererFormat *format =
      [UIGraphicsImageRendererFormat defaultFormat];
  format.opaque = NO;
  CGSize size = self.bounds.size;
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    for (UIView *child in self.subviews) {
      CGContextSaveGState(ctx.CGContext);
      CGContextTranslateCTM(ctx.CGContext, child.frame.origin.x,
                            child.frame.origin.y);
      [child drawViewHierarchyInRect:(CGRect){CGPointZero, child.frame.size}
                  afterScreenUpdates:NO];
      CGContextRestoreGState(ctx.CGContext);
    }
  }];
}

#pragma mark - Shared helpers

/// Compute the target frame and corner radius from the given target view
/// (or fall back to _cardFrame if targetView is nil).
- (CGRect)targetFrameForView:(UIView *)targetView
                cornerRadius:(CGFloat *)outCornerRadius {
  CGPoint targetOrigin = targetView
      ? [targetView convertPoint:CGPointZero toView:nil]
      : _cardFrame.origin;

  CGFloat tw = self.pendingTargetWidth;
  CGFloat th = self.pendingTargetHeight;
  CGFloat tbr = self.pendingTargetBorderRadius;

  CGRect targetFrame = CGRectMake(
      targetOrigin.x,
      targetOrigin.y,
      tw > 0 ? tw : _cardFrame.size.width,
      th > 0 ? th : _cardFrame.size.height);

  if (outCornerRadius) {
    *outCornerRadius = tbr >= 0 ? tbr : _cardCornerRadius;
  }
  return targetFrame;
}

/// Shared cleanup performed at the end of every collapse animation.
- (void)collapseCleanupWithContainer:(UIView *)container
                             resolve:(RCTPromiseResolveBlock)resolve {
  [container removeFromSuperview];
  _wrapperView = nil;
  _snapshot = nil;
  self.alpha = 1;
  _isExpanded = NO;
  _sourceScreenContainer = nil;
  _targetScreenContainer = nil;
  resolve(@(YES));
}

/// Schedule the screen-fade dispatch_after used by both collapse modes.
/// Guards against the race where the animation completes before the
/// dispatch fires — if cleanup already ran, _isExpanded is NO.
- (void)scheduleScreenFadeOut:(UIView *)screenView
                     duration:(NSTimeInterval)dur {
  __weak RNCMorphCardSourceComponentView *weakSelf = self;
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.15 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        RNCMorphCardSourceComponentView *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_isExpanded) return;
        [UIView animateWithDuration:dur * 0.65
            animations:^{
              if (screenView) { screenView.alpha = 0; }
            }
            completion:nil];
      });
}

#pragma mark - Expand

- (void)expandToTarget:(UIView *)targetView
               resolve:(RCTPromiseResolveBlock)resolve {
  if (_isExpanded) {
    resolve(@(NO));
    return;
  }
  _isExpanded = YES;

  UIWindow *window = getKeyWindow();
  if (!window) {
    resolve(@(NO));
    return;
  }

  _targetView = targetView;

  // ── 1. Save card geometry ──
  _cardFrame = [self convertRect:self.bounds toView:nil];
  _cardCornerRadius = self.layer.cornerRadius;
  _hasWrapper = hasVisibleBackgroundColor(self);

  // ── 2. Snapshot the card ──
  UIImage *cardImage = [self captureSnapshot];

  // ── 3. Keep source screen visible during navigation transition ──
  UIView *sourceScreen = RNCMorphCardFindScreenContainer(self);
  _sourceScreenContainer = sourceScreen;
  _targetScreenContainer = RNCMorphCardFindScreenContainer(targetView);

  if (sourceScreen) {
    sourceScreen.alpha = 1;
  }

  // ── 4. Compute target frame and corner radius ──
  CGFloat targetCornerRadius = 0;
  CGRect targetFrame = [self targetFrameForView:targetView
                                   cornerRadius:&targetCornerRadius];

  NSTimeInterval dur = (_expandDuration > 0 ? _expandDuration : _duration) / 1000.0;

  if (_hasWrapper) {
    // ══ WRAPPER MODE ══
    // Wrapper view (with bg color, corner radius) expands.
    // Content snapshot stays at original size on top.
    UIView *wrapper = [[UIView alloc] initWithFrame:_cardFrame];
    wrapper.backgroundColor = self.backgroundColor;
    wrapper.layer.cornerRadius = _cardCornerRadius;
    wrapper.clipsToBounds = YES;

    UIImageView *content = [[UIImageView alloc] initWithImage:cardImage];
    content.contentMode = UIViewContentModeTopLeft;
    content.clipsToBounds = YES;
    content.frame = (CGRect){CGPointZero, _cardFrame.size};
    [wrapper addSubview:content];

    [window addSubview:wrapper];
    _wrapperView = wrapper;

    // Hide source AFTER overlay is on screen to avoid flicker
    self.alpha = 0;

    CGFloat contentOffsetY = self.pendingContentOffsetY;
    BOOL contentCentered = self.pendingContentCentered;
    CGSize contentSize = _cardFrame.size;

    CGFloat targetCx = contentCentered
        ? (targetFrame.size.width - contentSize.width) / 2.0
        : 0;
    CGFloat targetCy = contentCentered
        ? (targetFrame.size.height - contentSize.height) / 2.0
        : contentOffsetY;

    // Use bounds/center instead of frame so rotation transforms work correctly
    CGFloat totalAngleDeg = _rotations * 360.0 + _rotationEndAngle;
    CGFloat totalAngleRad = totalAngleDeg * M_PI / 180.0;
    wrapper.bounds = CGRectMake(0, 0, _cardFrame.size.width, _cardFrame.size.height);
    wrapper.center = CGPointMake(CGRectGetMidX(_cardFrame), CGRectGetMidY(_cardFrame));

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
    __weak RNCMorphCardSourceComponentView *weakSelf = self;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          RNCMorphCardSourceComponentView *strongSelf = weakSelf;
          if (!strongSelf || !strongSelf->_isExpanded) return;
          UIView *ts = strongSelf->_targetScreenContainer;
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
        UIView *content = wrapper.subviews.firstObject;
        if ([content isKindOfClass:[UIImageView class]]) {
          CGRect contentFrame = content.frame;
          [target showSnapshot:((UIImageView *)content).image
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
        CGFloat endAngleRad = self->_rotationEndAngle * M_PI / 180.0;
        if (endAngleRad != 0) {
          targetView.transform = CGAffineTransformMakeRotation(endAngleRad);
        }
      }
      self.alpha = 1;
      UIView *ts = self->_targetScreenContainer;
      if (ts) { ts.alpha = 1; }
      [wrapper removeFromSuperview];
      self->_wrapperView = nil;
      resolve(@(YES));
    }];

    [animator startAnimation];

  } else {
    // ══ NO-WRAPPER MODE ══
    // Container clips, image view inside respects scaleMode.
    // We compute image frames ourselves so scaleMode works during animation.
    UIViewContentMode scaleMode = _scaleMode;
    CGSize imageSize = cardImage.size;

    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.bounds = CGRectMake(0, 0, _cardFrame.size.width, _cardFrame.size.height);
    container.center = CGPointMake(CGRectGetMidX(_cardFrame), CGRectGetMidY(_cardFrame));
    container.clipsToBounds = YES;
    container.layer.cornerRadius = _cardCornerRadius;

    UIImageView *snapshot = [[UIImageView alloc] initWithImage:cardImage];
    snapshot.clipsToBounds = YES;
    // Start: image fills container exactly (matches source card)
    snapshot.frame = (CGRect){CGPointZero, _cardFrame.size};
    [container addSubview:snapshot];

    [window addSubview:container];
    _snapshot = snapshot;
    _wrapperView = container;

    // Hide source AFTER overlay is on screen to avoid flicker
    self.alpha = 0;

    if (targetView) {
      targetView.hidden = YES;
    }

    // Compute final image frame based on scaleMode
    CGRect targetImageFrame = imageFrameForScaleMode(
        scaleMode, imageSize, targetFrame.size);

    CGFloat totalAngleDegNoWrap = _rotations * 360.0 + _rotationEndAngle;
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
    __weak RNCMorphCardSourceComponentView *weakSelf2 = self;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          RNCMorphCardSourceComponentView *strongSelf2 = weakSelf2;
          if (!strongSelf2 || !strongSelf2->_isExpanded) return;
          UIView *ts = strongSelf2->_targetScreenContainer;
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
        CGFloat endAngleRad = self->_rotationEndAngle * M_PI / 180.0;
        if (endAngleRad != 0) {
          targetView.transform = CGAffineTransformMakeRotation(endAngleRad);
        }
      }
      self.alpha = 1;
      UIView *ts = self->_targetScreenContainer;
      if (ts) { ts.alpha = 1; }
      [container removeFromSuperview];
      self->_wrapperView = nil;
      self->_snapshot = nil;
      resolve(@(YES));
    }];

    [animator startAnimation];
  }
}

#pragma mark - Collapse

- (void)collapseFromTarget:(UIView *)targetView
                   resolve:(RCTPromiseResolveBlock)resolve {
  if (!_isExpanded) {
    resolve(@(NO));
    return;
  }

  UIWindow *window = getKeyWindow();
  if (!window) {
    resolve(@(NO));
    return;
  }

  UIView *targetScreen = _targetScreenContainer;
  UIView *sourceScreen = _sourceScreenContainer;

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
  NSTimeInterval dur = (collapseDur > 0 ? collapseDur : _duration) / 1000.0;

  if (_hasWrapper) {
    // ══ WRAPPER MODE COLLAPSE ══
    UIView *wrapper = _wrapperView;
    if (!wrapper) {
      self.alpha = 1;
      UIImage *cardImage = [self captureSnapshot];
      self.alpha = 0;

      CGFloat targetCornerRadius = 0;
      CGRect targetFrame = [self targetFrameForView:targetView
                                       cornerRadius:&targetCornerRadius];

      CGFloat contentOffsetY = self.pendingContentOffsetY;
      BOOL contentCentered = self.pendingContentCentered;
      CGSize contentSize = _cardFrame.size;
      CGFloat cx = contentCentered
          ? (targetFrame.size.width - contentSize.width) / 2.0 : 0;
      CGFloat cy = contentCentered
          ? (targetFrame.size.height - contentSize.height) / 2.0
          : contentOffsetY;

      wrapper = [[UIView alloc] initWithFrame:CGRectZero];
      wrapper.bounds = CGRectMake(0, 0, targetFrame.size.width, targetFrame.size.height);
      wrapper.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
      wrapper.backgroundColor = self.backgroundColor;
      wrapper.layer.cornerRadius = targetCornerRadius;
      wrapper.clipsToBounds = YES;

      UIImageView *content = [[UIImageView alloc] initWithImage:cardImage];
      content.contentMode = UIViewContentModeTopLeft;
      content.clipsToBounds = YES;
      content.frame = CGRectMake(cx, cy, contentSize.width, contentSize.height);
      [wrapper addSubview:content];

      [window addSubview:wrapper];
      _wrapperView = wrapper;
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
      wrapper.bounds = CGRectMake(0, 0, self->_cardFrame.size.width, self->_cardFrame.size.height);
      wrapper.center = CGPointMake(CGRectGetMidX(self->_cardFrame), CGRectGetMidY(self->_cardFrame));
      wrapper.layer.cornerRadius = self->_cardCornerRadius;
      if (content) {
        content.frame = (CGRect){CGPointZero, content.frame.size};
      }
    }];

    // Animate rotation back to 0
    CGFloat collapseStartAngle = _rotationEndAngle * M_PI / 180.0;
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
      [self scheduleScreenFadeOut:targetScreen duration:dur];
    }

    [animator addCompletion:^(UIViewAnimatingPosition pos) {
      [self collapseCleanupWithContainer:wrapper resolve:resolve];
    }];

    [animator startAnimation];

  } else {
    // ══ NO-WRAPPER MODE COLLAPSE ══
    UIView *container = _wrapperView;
    UIImageView *snapshot = _snapshot;

    if (!container) {
      self.alpha = 1;
      UIImage *cardImage = [self captureSnapshot];
      self.alpha = 0;

      CGFloat targetCornerRadius = 0;
      CGRect targetFrame = [self targetFrameForView:targetView
                                       cornerRadius:&targetCornerRadius];

      CGSize imageSize = cardImage.size;
      CGRect imageFrame = imageFrameForScaleMode(
          _scaleMode, imageSize, targetFrame.size);

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
      _wrapperView = container;
      _snapshot = snapshot;
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
      container.bounds = CGRectMake(0, 0, self->_cardFrame.size.width, self->_cardFrame.size.height);
      container.center = CGPointMake(CGRectGetMidX(self->_cardFrame), CGRectGetMidY(self->_cardFrame));
      container.layer.cornerRadius = self->_cardCornerRadius;
      snapshot.frame = (CGRect){CGPointZero, self->_cardFrame.size};
    }];

    // Animate rotation back to 0
    CGFloat collapseStartAngleNW = _rotationEndAngle * M_PI / 180.0;
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
      [self scheduleScreenFadeOut:targetScreen duration:dur];
    }

    [animator addCompletion:^(UIViewAnimatingPosition pos) {
      [self collapseCleanupWithContainer:container resolve:resolve];
    }];

    [animator startAnimation];
  }
}

- (void)collapseWithResolve:(RCTPromiseResolveBlock)resolve {
  [self collapseFromTarget:_targetView resolve:resolve];
}

Class<RCTComponentViewProtocol> RNCMorphCardSourceCls(void) {
  return RNCMorphCardSourceComponentView.class;
}

@end
