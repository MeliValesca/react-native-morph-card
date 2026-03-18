#import <React/RCTViewComponentView.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNCMorphCardTargetComponentView : RCTViewComponentView

@property (nonatomic, assign) CGFloat targetWidth;
@property (nonatomic, assign) CGFloat targetHeight;
@property (nonatomic, assign) CGFloat targetBorderRadius;
@property (nonatomic, assign) CGFloat collapseDuration;

- (void)showSnapshot:(UIImage *)image
         contentMode:(UIViewContentMode)mode
               frame:(CGRect)frame
        cornerRadius:(CGFloat)cornerRadius
     backgroundColor:(nullable UIColor *)bgColor;
- (void)clearSnapshot;

@end

NS_ASSUME_NONNULL_END
