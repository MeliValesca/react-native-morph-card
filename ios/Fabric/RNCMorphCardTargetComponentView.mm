#import "RNCMorphCardTargetComponentView.h"
#import "RNCMorphCardViewRegistry.h"

#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/morphcard/ComponentDescriptors.h>
#import <react/renderer/components/morphcard/Props.h>

using namespace facebook::react;

@implementation RNCMorphCardTargetComponentView

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      RNCMorphCardTargetComponentDescriptor>();
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps =
      *std::static_pointer_cast<const RNCMorphCardTargetProps>(props);
  _targetWidth = newProps.targetWidth;
  _targetHeight = newProps.targetHeight;
  _targetBorderRadius = newProps.targetBorderRadius;
  [super updateProps:props oldProps:oldProps];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [[RNCMorphCardViewRegistry shared] registerView:self withTag:self.tag];

    // Immediately hide the detail screen container to prevent flicker.
    // The expand animation will fade it back in.
    UIWindow *window = self.window;
    CGRect windowBounds = window.bounds;
    UIView *current = self.superview;
    UIView *screenContainer = nil;
    while (current && current != window) {
      CGRect frameInWindow = [current convertRect:current.bounds toView:nil];
      if (CGRectEqualToRect(frameInWindow, windowBounds)) {
        screenContainer = current;
      }
      current = current.superview;
    }
    if (screenContainer) {
      screenContainer.alpha = 0;
    }
  } else {
    [[RNCMorphCardViewRegistry shared] unregisterViewWithTag:self.tag];
  }
}

Class<RCTComponentViewProtocol> RNCMorphCardTargetCls(void) {
  return RNCMorphCardTargetComponentView.class;
}

@end
