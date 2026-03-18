#import <React/RCTBridgeModule.h>
#import <React/RCTViewComponentView.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNCMorphCardSourceComponentView : RCTViewComponentView

@property (nonatomic, assign) CGFloat pendingTargetWidth;
@property (nonatomic, assign) CGFloat pendingTargetHeight;
@property (nonatomic, assign) CGFloat pendingTargetBorderRadius;
@property (nonatomic, assign) CGFloat pendingContentOffsetY;
@property (nonatomic, assign) BOOL pendingContentCentered;

- (void)expandToTarget:(nullable UIView *)targetView
               resolve:(RCTPromiseResolveBlock)resolve;

/// Collapse using the stored target from the last expand call.
- (void)collapseWithResolve:(RCTPromiseResolveBlock)resolve;

@end

NS_ASSUME_NONNULL_END
