#import "RNCMorphCardSourceComponentView.h"
#import "RNCMorphCardTargetComponentView.h"
#import "RNCMorphCardViewRegistry.h"
#import "RNCMorphCardAnimationStrategy.h"
#import "RNCMorphCardTransparentModalStrategy.h"
#import "RNCMorphCardPushStrategy.h"

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

#pragma mark - Implementation

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
  BOOL _isPush;
  UIView *_wrapperView;
  UIImageView *_snapshot;
  id<RNCMorphCardAnimationStrategy> _strategy;
}

#pragma mark - Property synthesis

// Readonly props from JS
- (CGFloat)duration { return _duration; }
- (CGFloat)expandDuration { return _expandDuration; }
- (UIViewContentMode)scaleMode { return _scaleMode; }
- (CGFloat)rotations { return _rotations; }
- (CGFloat)rotationEndAngle { return _rotationEndAngle; }
- (BOOL)isPush { return _isPush; }

// Expand/collapse state
- (BOOL)isExpanded { return _isExpanded; }
- (void)setIsExpanded:(BOOL)isExpanded { _isExpanded = isExpanded; }
- (BOOL)hasWrapper { return _hasWrapper; }
- (CGRect)cardFrame { return _cardFrame; }
- (void)setCardFrame:(CGRect)cardFrame { _cardFrame = cardFrame; }
- (CGFloat)cardCornerRadius { return _cardCornerRadius; }
- (void)setCardCornerRadius:(CGFloat)cardCornerRadius { _cardCornerRadius = cardCornerRadius; }

// View references
- (UIView *)targetView { return _targetView; }
- (void)setTargetView:(UIView *)targetView { _targetView = targetView; }
- (UIView *)sourceScreenContainer { return _sourceScreenContainer; }
- (void)setSourceScreenContainer:(UIView *)sourceScreenContainer { _sourceScreenContainer = sourceScreenContainer; }
- (UIView *)targetScreenContainer { return _targetScreenContainer; }
- (void)setTargetScreenContainer:(UIView *)targetScreenContainer { _targetScreenContainer = targetScreenContainer; }
- (UIView *)wrapperView { return _wrapperView; }
- (void)setWrapperView:(UIView *)wrapperView { _wrapperView = wrapperView; }
- (UIImageView *)snapshotView { return _snapshot; }
- (void)setSnapshotView:(UIImageView *)snapshotView { _snapshot = snapshotView; }

#pragma mark - Fabric

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
  BOOL wasPush = _isPush;
  _isPush = (newProps.presentation == RNCMorphCardSourcePresentation::Push);
  if (!_strategy || _isPush != wasPush) {
    [self _updateStrategy];
  }
  [super updateProps:props oldProps:oldProps];
}

- (void)_updateStrategy {
  if (_isPush) {
    _strategy = [[RNCMorphCardPushStrategy alloc] init];
  } else {
    _strategy = [[RNCMorphCardTransparentModalStrategy alloc] init];
  }
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
  return [self _captureSnapshotAfterUpdates:NO];
}

- (UIImage *)captureSnapshotAfterUpdates {
  return [self _captureSnapshotAfterUpdates:YES];
}

- (UIImage *)_captureSnapshotAfterUpdates:(BOOL)afterUpdates {
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
                  afterScreenUpdates:afterUpdates];
      CGContextRestoreGState(ctx.CGContext);
    }
  }];
}

#pragma mark - Shared helpers

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

#pragma mark - Expand / Collapse (delegate to strategy)

- (void)prepareExpand {
  // For push mode: capture source position and create overlay BEFORE navigation.
  // This ensures the overlay is added to the window before the push transition,
  // so it renders above the pushed screen.
  _cardFrame = [self convertRect:self.bounds toView:nil];
  _cardCornerRadius = self.layer.cornerRadius;
  _hasWrapper = hasVisibleBackgroundColor(self);
  _sourceScreenContainer = RNCMorphCardFindScreenContainer(self);

  UIWindow *window = getKeyWindow();
  if (!window) return;

  UIImage *cardImage = [self captureSnapshot];

  // Hide source immediately — overlay covers it
  self.alpha = 0;

  UIView *wrapper;
  if (_hasWrapper) {
    wrapper = [[UIView alloc] initWithFrame:_cardFrame];
    wrapper.backgroundColor = self.backgroundColor;
    wrapper.layer.cornerRadius = _cardCornerRadius;
    wrapper.clipsToBounds = YES;

    UIImageView *content = [[UIImageView alloc] initWithImage:cardImage];
    content.contentMode = UIViewContentModeTopLeft;
    content.clipsToBounds = YES;
    content.frame = (CGRect){CGPointZero, _cardFrame.size};
    [wrapper addSubview:content];

    if (_isPush) {
      // Push wrapper mode: shadow below the card.
      // masksToBounds = NO for shadow, content clips itself with cornerRadius.
      wrapper.layer.masksToBounds = NO;
      wrapper.layer.shadowColor = [UIColor blackColor].CGColor;
      wrapper.layer.shadowOffset = CGSizeMake(0, 8);
      wrapper.layer.shadowOpacity = 0.12;
      wrapper.layer.shadowRadius = 5;
      // Content clips itself since wrapper can't (masksToBounds = NO)
      content.layer.cornerRadius = _cardCornerRadius;
    }
  } else {
    wrapper = [[UIView alloc] initWithFrame:CGRectZero];
    wrapper.bounds = CGRectMake(0, 0, _cardFrame.size.width, _cardFrame.size.height);
    wrapper.center = CGPointMake(CGRectGetMidX(_cardFrame), CGRectGetMidY(_cardFrame));
    wrapper.clipsToBounds = YES;
    wrapper.layer.cornerRadius = _cardCornerRadius;

    UIImageView *snapshot = [[UIImageView alloc] initWithImage:cardImage];
    snapshot.clipsToBounds = YES;
    snapshot.frame = (CGRect){CGPointZero, _cardFrame.size};
    [wrapper addSubview:snapshot];
    _snapshot = snapshot;

    // No-wrapper push: no shadow (clipsToBounds blocks it, and
    // masksToBounds=NO would show square corners of the snapshot)
  }

  [window addSubview:wrapper];
  _wrapperView = wrapper;

  // Start a subtle scale-up during the delay before expandToTarget fires.
  // Use bounds/center instead of transform to avoid cornerRadius distortion.
  CGRect startBounds = wrapper.bounds;
  CGPoint startCenter = wrapper.center;
  CGFloat scale = 1.05;
  [UIView animateWithDuration:0.15
                        delay:0
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     wrapper.bounds = CGRectMake(0, 0,
                       startBounds.size.width * scale,
                       startBounds.size.height * scale);
                     // Scale content with wrapper so edges don't show
                     UIView *content = wrapper.subviews.firstObject;
                     if (content) {
                       content.frame = CGRectMake(0, 0,
                         startBounds.size.width * scale,
                         startBounds.size.height * scale);
                     }
                   }
                   completion:nil];
}

- (void)expandToTarget:(UIView *)targetView
               resolve:(RCTPromiseResolveBlock)resolve {
  if (!_strategy) {
    [self _updateStrategy];
  }
  _hasWrapper = hasVisibleBackgroundColor(self);
  [_strategy expandToTarget:targetView sourceView:self resolve:resolve];
}

- (void)collapseWithResolve:(RCTPromiseResolveBlock)resolve {
  if (!_strategy) {
    [self _updateStrategy];
  }
  [_strategy collapseFromTarget:_targetView sourceView:self resolve:resolve];
}

Class<RCTComponentViewProtocol> RNCMorphCardSourceCls(void) {
  return RNCMorphCardSourceComponentView.class;
}

@end
