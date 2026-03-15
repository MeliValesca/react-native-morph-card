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
      result = current; // keep traversing to find the outermost one
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

@implementation RNCMorphCardSourceComponentView {
  CGFloat _duration;
  BOOL _isExpanded;
  BOOL _hasWrapper;
  CGRect _cardFrame;
  CGFloat _cardCornerRadius;
  CGFloat _cardShadowOpacity;
  __weak UIView *_targetView;
  __weak UIView *_sourceScreenContainer;
  __weak UIView *_targetScreenContainer;
  // Wrapper mode: wrapper view + content snapshot inside
  UIView *_wrapperView;
  // No-wrapper mode: single snapshot that scales
  UIImageView *_snapshot;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      RNCMorphCardSourceComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _duration = 500.0;
    _pendingTargetBorderRadius = -1;
  }
  return self;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps =
      *std::static_pointer_cast<const RNCMorphCardSourceProps>(props);
  _duration = newProps.duration > 0 ? newProps.duration : 500.0;
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
  _cardShadowOpacity = self.layer.shadowOpacity;
  _hasWrapper = hasVisibleBackgroundColor(self);

  // ── 2. Snapshot the card ──
  UIImage *cardImage = [self captureSnapshot];

  // ── 3. Keep source screen visible, hide detail screen ──
  UIView *sourceScreen = findScreenContainer(self);
  UIView *targetScreen = findScreenContainer(targetView);
  _sourceScreenContainer = sourceScreen;
  _targetScreenContainer = targetScreen;

  // Hide detail screen so it doesn't flash
  if (targetScreen) {
    targetScreen.alpha = 0;
  }
  // Force source screen to stay visible during navigation transition
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
    // Wrapper view (with bg color, shadow, corner radius) expands.
    // Content snapshot stays at original size on top.
    UIView *wrapper = [[UIView alloc] initWithFrame:_cardFrame];
    wrapper.backgroundColor = self.backgroundColor;
    wrapper.layer.cornerRadius = _cardCornerRadius;
    wrapper.clipsToBounds = YES;
    wrapper.layer.shadowColor = self.layer.shadowColor;
    wrapper.layer.shadowOpacity = _cardShadowOpacity;
    wrapper.layer.shadowOffset = self.layer.shadowOffset;
    wrapper.layer.shadowRadius = self.layer.shadowRadius;

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
                wrapper.layer.shadowOpacity = 0;
                content.frame = CGRectMake(targetCx, targetCy,
                                           contentSize.width,
                                           contentSize.height);
              }];

    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
      [UIView animateWithDuration:0.2
          animations:^{
            if (targetScreen) {
              targetScreen.alpha = 1;
            }
          }
          completion:^(BOOL finished) {
            resolve(@(YES));
          }];
    }];

    [animator startAnimation];

  } else {
    // ══ NO-WRAPPER MODE ══
    // Single snapshot scales with aspect-fill.
    UIImageView *snapshot = [[UIImageView alloc] initWithImage:cardImage];
    snapshot.contentMode = UIViewContentModeScaleAspectFill;
    snapshot.clipsToBounds = YES;
    snapshot.layer.cornerRadius = _cardCornerRadius;
    snapshot.layer.shadowColor = self.layer.shadowColor;
    snapshot.layer.shadowOpacity = _cardShadowOpacity;
    snapshot.layer.shadowOffset = self.layer.shadowOffset;
    snapshot.layer.shadowRadius = self.layer.shadowRadius;
    snapshot.frame = _cardFrame;
    [window addSubview:snapshot];
    _snapshot = snapshot;

    // Hide source AFTER overlay is on screen to avoid flicker
    self.alpha = 0;

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:dur
            dampingRatio:0.85
              animations:^{
                snapshot.frame = targetFrame;
                snapshot.layer.cornerRadius = targetCornerRadius;
                snapshot.layer.shadowOpacity = 0;
              }];

    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
      [UIView animateWithDuration:0.2
          animations:^{
            if (targetScreen) {
              targetScreen.alpha = 1;
            }
          }
          completion:^(BOOL finished) {
            resolve(@(YES));
          }];
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

  if (_hasWrapper && _wrapperView) {
    // ══ WRAPPER MODE COLLAPSE ══
    UIView *wrapper = _wrapperView;

    [UIView animateWithDuration:0.2
        animations:^{
          if (targetScreen) {
            targetScreen.alpha = 0;
          }
        }
        completion:^(BOOL finished) {
          // Show source screen again for collapse animation
          if (sourceScreen) {
            sourceScreen.alpha = 1;
          }

          NSTimeInterval dur = self->_duration / 1000.0;

          UIView *content = wrapper.subviews.firstObject;

          UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
              initWithDuration:dur
                  dampingRatio:0.85
                    animations:^{
                      wrapper.frame = self->_cardFrame;
                      wrapper.layer.cornerRadius = self->_cardCornerRadius;
                      wrapper.layer.shadowOpacity = self->_cardShadowOpacity;
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
    UIImageView *snapshot = _snapshot;

    if (!snapshot) {
      // Fallback: re-snapshot
      self.alpha = 1;
      UIImage *cardImage = [self captureSnapshot];
      self.alpha = 0;

      snapshot = [[UIImageView alloc] initWithImage:cardImage];
      snapshot.contentMode = UIViewContentModeScaleAspectFill;
      snapshot.clipsToBounds = YES;
      snapshot.frame = _cardFrame;
      [window addSubview:snapshot];
    }

    [UIView animateWithDuration:0.2
        animations:^{
          if (targetScreen) {
            targetScreen.alpha = 0;
          }
        }
        completion:^(BOOL finished) {
          // Show source screen again for collapse animation
          if (sourceScreen) {
            sourceScreen.alpha = 1;
          }

          NSTimeInterval dur = self->_duration / 1000.0;

          UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
              initWithDuration:dur
                  dampingRatio:0.85
                    animations:^{
                      snapshot.frame = self->_cardFrame;
                      snapshot.layer.cornerRadius = self->_cardCornerRadius;
                      snapshot.layer.shadowOpacity = self->_cardShadowOpacity;
                    }];

          [animator addCompletion:^(UIViewAnimatingPosition pos) {
            [snapshot removeFromSuperview];
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
