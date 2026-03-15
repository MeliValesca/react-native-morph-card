#import "RNCMorphCardTarget.h"
#import "RNCMorphCardViewRegistry.h"

@implementation RNCMorphCardTarget

- (instancetype)init {
  if (self = [super init]) {
    _duration = 350.0;
  }
  return self;
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [[RNCMorphCardViewRegistry shared] registerView:self
                                            withTag:self.tag];
  } else {
    [[RNCMorphCardViewRegistry shared] unregisterViewWithTag:self.tag];
  }
}

- (CGRect)frameInWindow {
  return [self convertRect:self.bounds toView:nil];
}

@end
