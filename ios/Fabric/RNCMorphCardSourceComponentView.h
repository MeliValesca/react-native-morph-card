#import <React/RCTBridgeModule.h>
#import <React/RCTViewComponentView.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNCMorphCardSourceComponentView : RCTViewComponentView

// ── Pending target props (set by JS before expand) ──
@property (nonatomic, assign) CGFloat pendingTargetWidth;
@property (nonatomic, assign) CGFloat pendingTargetHeight;
@property (nonatomic, assign) CGFloat pendingTargetBorderRadius;
@property (nonatomic, assign) CGFloat pendingContentOffsetY;
@property (nonatomic, assign) BOOL pendingContentCentered;

// ── Animation configuration (readonly, set from props) ──
@property (nonatomic, assign, readonly) CGFloat duration;
@property (nonatomic, assign, readonly) CGFloat expandDuration;
@property (nonatomic, assign, readonly) UIViewContentMode scaleMode;
@property (nonatomic, assign, readonly) CGFloat rotations;
@property (nonatomic, assign, readonly) CGFloat rotationEndAngle;
@property (nonatomic, assign, readonly) BOOL isPush;

// ── Expand/collapse state (strategies read/write these) ──
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL isCollapsing;
@property (nonatomic, assign, readonly) BOOL hasWrapper;
@property (nonatomic, assign) CGRect cardFrame;
@property (nonatomic, assign) CGFloat cardCornerRadius;

// ── View references (strategies read/write these) ──
@property (nonatomic, weak, nullable) UIView *targetView;
@property (nonatomic, weak, nullable) UIView *sourceScreenContainer;
@property (nonatomic, weak, nullable) UIView *targetScreenContainer;
@property (nonatomic, strong, nullable) UIView *wrapperView;
@property (nonatomic, strong, nullable) UIImageView *snapshotView;

// ── Public API ──
/// Called before navigation to capture source position (push mode only).
- (void)prepareExpand;

- (void)expandToTarget:(nullable UIView *)targetView
               resolve:(RCTPromiseResolveBlock)resolve;

/// Collapse using the stored target from the last expand call.
- (void)collapseWithResolve:(RCTPromiseResolveBlock)resolve;

// ── Helpers (called by strategies) ──
- (UIImage *)captureSnapshot;
- (UIImage *)captureSnapshotAfterUpdates;
- (CGRect)targetFrameForView:(nullable UIView *)targetView
                cornerRadius:(nullable CGFloat *)outCornerRadius;
- (void)collapseCleanupWithContainer:(UIView *)container
                             resolve:(RCTPromiseResolveBlock)resolve;
- (void)scheduleScreenFadeOut:(UIView *)screenView
                     duration:(NSTimeInterval)dur;

@end

NS_ASSUME_NONNULL_END
