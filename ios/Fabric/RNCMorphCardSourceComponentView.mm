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

static UIView *findScreenContainer(UIView *view) {
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

@implementation RNCMorphCardSourceComponentView {
  CGFloat _duration;
  UIViewContentMode _scaleMode;
  BOOL _isExpanded;
  BOOL _hasWrapper;
  CGRect _cardFrame;
  CGFloat _cardCornerRadius;
  __weak UIView *_targetView;
  __weak UIView *_sourceScreenContainer;
  __weak UIView *_targetScreenContainer;
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
  auto sm = newProps.scaleMode;
  if (sm == RNCMorphCardSourceScaleMode::AspectFit) {
    _scaleMode = UIViewContentModeScaleAspectFit;
  } else if (sm == RNCMorphCardSourceScaleMode::Stretch) {
    _scaleMode = UIViewContentModeScaleToFill;
  } else {
    _scaleMode = UIViewContentModeScaleAspectFill;
  }
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
  UIGraphicsImageRendererFormat *format =
      [UIGraphicsImageRendererFormat defaultFormat];
  format.opaque = NO;
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:self.bounds.size
                                             format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
  }];
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
  UIView *sourceScreen = findScreenContainer(self);
  _sourceScreenContainer = sourceScreen;
  _targetScreenContainer = findScreenContainer(targetView);

  if (sourceScreen) {
    sourceScreen.alpha = 1;
  }

  // ── 4. Compute target frame and corner radius ──
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

  CGFloat targetCornerRadius = tbr >= 0 ? tbr : _cardCornerRadius;

  NSTimeInterval dur = _duration / 1000.0;

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

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:dur
            dampingRatio:0.85
              animations:^{
                wrapper.frame = targetFrame;
                wrapper.layer.cornerRadius = targetCornerRadius;
                content.frame = CGRectMake(targetCx, targetCy,
                                           contentSize.width,
                                           contentSize.height);
              }];

    // Hide the target view itself so it doesn't double-render over the morph overlay.
    if (targetView) {
      targetView.hidden = YES;
    }

    // Start fading in screen content early (at 15% of the animation).
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          UIView *ts = self->_targetScreenContainer;
          if (ts) {
            [UIView animateWithDuration:dur * 0.5
                animations:^{
                  ts.alpha = 1;
                }
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
      }
      if (targetView) { targetView.hidden = NO; }
      self.alpha = 1;
      UIView *ts = self->_targetScreenContainer;
      if (ts) { ts.alpha = 1; }
      [UIView animateWithDuration:0.2
          animations:^{
            wrapper.alpha = 0;
          }
          completion:^(BOOL finished) {
            [wrapper removeFromSuperview];
            self->_wrapperView = nil;
          }];
      resolve(@(YES));
    }];

    [animator startAnimation];

  } else {
    // ══ NO-WRAPPER MODE ══
    // Container clips, image view inside respects scaleMode.
    // We compute image frames ourselves so scaleMode works during animation.
    UIViewContentMode scaleMode = _scaleMode;
    CGSize imageSize = cardImage.size;

    UIView *container = [[UIView alloc] initWithFrame:_cardFrame];
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

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:dur
            dampingRatio:0.85
              animations:^{
                container.frame = targetFrame;
                container.layer.cornerRadius = targetCornerRadius;
                snapshot.frame = targetImageFrame;
              }];

    // Start fading in screen content early (at 15% of the animation).
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          UIView *ts = self->_targetScreenContainer;
          if (ts) {
            [UIView animateWithDuration:dur * 0.5
                animations:^{
                  ts.alpha = 1;
                }
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
      }
      if (targetView) { targetView.hidden = NO; }
      self.alpha = 1;
      UIView *ts = self->_targetScreenContainer;
      if (ts) { ts.alpha = 1; }
      [UIView animateWithDuration:0.2
          animations:^{
            container.alpha = 0;
          }
          completion:^(BOOL finished) {
            [container removeFromSuperview];
            self->_wrapperView = nil;
            self->_snapshot = nil;
          }];
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

  // Clear the snapshot from the target view before re-creating the overlay
  if (targetView && [targetView isKindOfClass:[RNCMorphCardTargetComponentView class]]) {
    [(RNCMorphCardTargetComponentView *)targetView clearSnapshot];
  }

  NSTimeInterval dur = _duration / 1000.0;

  if (_hasWrapper) {
    // ══ WRAPPER MODE COLLAPSE ══
    UIView *wrapper = _wrapperView;
    if (!wrapper) {
      self.alpha = 1;
      UIImage *cardImage = [self captureSnapshot];
      self.alpha = 0;

      CGPoint targetOrigin = targetView
          ? [targetView convertPoint:CGPointZero toView:nil]
          : _cardFrame.origin;
      CGFloat tw = self.pendingTargetWidth;
      CGFloat th = self.pendingTargetHeight;
      CGFloat tbr = self.pendingTargetBorderRadius;
      CGRect targetFrame = CGRectMake(
          targetOrigin.x, targetOrigin.y,
          tw > 0 ? tw : _cardFrame.size.width,
          th > 0 ? th : _cardFrame.size.height);
      CGFloat targetCornerRadius = tbr >= 0 ? tbr : _cardCornerRadius;

      CGFloat contentOffsetY = self.pendingContentOffsetY;
      BOOL contentCentered = self.pendingContentCentered;
      CGSize contentSize = _cardFrame.size;
      CGFloat cx = contentCentered
          ? (targetFrame.size.width - contentSize.width) / 2.0 : 0;
      CGFloat cy = contentCentered
          ? (targetFrame.size.height - contentSize.height) / 2.0
          : contentOffsetY;

      wrapper = [[UIView alloc] initWithFrame:targetFrame];
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

    [UIView animateWithDuration:dur * 0.3
        animations:^{
          if (targetScreen) {
            targetScreen.alpha = 0;
          }
        }
        completion:^(BOOL finished) {
          if (sourceScreen) {
            sourceScreen.alpha = 1;
          }

          UIView *content = wrapper.subviews.firstObject;

          UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
              initWithDuration:dur
                  dampingRatio:0.85
                    animations:^{
                      wrapper.frame = self->_cardFrame;
                      wrapper.layer.cornerRadius = self->_cardCornerRadius;
                      if (content) {
                        content.frame = (CGRect){CGPointZero, content.frame.size};
                      }
                    }];

          [animator addCompletion:^(UIViewAnimatingPosition pos) {
            [wrapper removeFromSuperview];
            self->_wrapperView = nil;
            self.alpha = 1;
            self->_isExpanded = NO;
            self->_sourceScreenContainer = nil;
            self->_targetScreenContainer = nil;
            resolve(@(YES));
          }];

          [animator startAnimation];
        }];

  } else {
    // ══ NO-WRAPPER MODE COLLAPSE ══
    UIView *container = _wrapperView;
    UIImageView *snapshot = _snapshot;

    if (!container) {
      self.alpha = 1;
      UIImage *cardImage = [self captureSnapshot];
      self.alpha = 0;

      CGPoint targetOrigin = targetView
          ? [targetView convertPoint:CGPointZero toView:nil]
          : _cardFrame.origin;
      CGFloat tw = self.pendingTargetWidth;
      CGFloat th = self.pendingTargetHeight;
      CGFloat tbr = self.pendingTargetBorderRadius;
      CGRect targetFrame = CGRectMake(
          targetOrigin.x, targetOrigin.y,
          tw > 0 ? tw : _cardFrame.size.width,
          th > 0 ? th : _cardFrame.size.height);
      CGFloat targetCornerRadius = tbr >= 0 ? tbr : _cardCornerRadius;

      CGSize imageSize = cardImage.size;
      CGRect imageFrame = imageFrameForScaleMode(
          _scaleMode, imageSize, targetFrame.size);

      container = [[UIView alloc] initWithFrame:targetFrame];
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

    [UIView animateWithDuration:dur * 0.3
        animations:^{
          if (targetScreen) {
            targetScreen.alpha = 0;
          }
        }
        completion:^(BOOL finished) {
          if (sourceScreen) {
            sourceScreen.alpha = 1;
          }

          UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
              initWithDuration:dur
                  dampingRatio:0.85
                    animations:^{
                      container.frame = self->_cardFrame;
                      container.layer.cornerRadius = self->_cardCornerRadius;
                      snapshot.frame = (CGRect){CGPointZero, self->_cardFrame.size};
                    }];

          [animator addCompletion:^(UIViewAnimatingPosition pos) {
            [container removeFromSuperview];
            self->_wrapperView = nil;
            self->_snapshot = nil;
            self.alpha = 1;
            self->_isExpanded = NO;
            self->_sourceScreenContainer = nil;
            self->_targetScreenContainer = nil;
            resolve(@(YES));
          }];

          [animator startAnimation];
        }];
  }
}

- (void)collapseWithResolve:(RCTPromiseResolveBlock)resolve {
  [self collapseFromTarget:_targetView resolve:resolve];
}

Class<RCTComponentViewProtocol> RNCMorphCardSourceCls(void) {
  return RNCMorphCardSourceComponentView.class;
}

@end
