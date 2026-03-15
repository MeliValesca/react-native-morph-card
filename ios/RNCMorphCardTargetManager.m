#import "RNCMorphCardTargetManager.h"
#import "RNCMorphCardTarget.h"

@implementation RNCMorphCardTargetManager

RCT_EXPORT_MODULE()

- (UIView *)view {
  return [[RNCMorphCardTarget alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(duration, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(sourceTag, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(onMorphComplete, RCTDirectEventBlock)

@end
