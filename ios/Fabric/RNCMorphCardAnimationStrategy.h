#import <UIKit/UIKit.h>
#import <React/RCTBridgeModule.h>

@class RNCMorphCardSourceComponentView;

NS_ASSUME_NONNULL_BEGIN

@protocol RNCMorphCardAnimationStrategy <NSObject>

- (void)expandToTarget:(nullable UIView *)targetView
            sourceView:(RNCMorphCardSourceComponentView *)sourceView
               resolve:(RCTPromiseResolveBlock)resolve;

- (void)collapseFromTarget:(nullable UIView *)targetView
                sourceView:(RNCMorphCardSourceComponentView *)sourceView
                   resolve:(RCTPromiseResolveBlock)resolve;

@end

NS_ASSUME_NONNULL_END
