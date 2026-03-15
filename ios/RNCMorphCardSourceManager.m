#import "RNCMorphCardSourceManager.h"
#import "RNCMorphCardSource.h"

@implementation RNCMorphCardSourceManager

RCT_EXPORT_MODULE()

- (UIView *)view {
  return [[RNCMorphCardSource alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(onMorphStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMorphComplete, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDismissComplete, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(duration, CGFloat)

@end
