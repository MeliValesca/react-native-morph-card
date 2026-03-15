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
  } else {
    [[RNCMorphCardViewRegistry shared] unregisterViewWithTag:self.tag];
  }
}

Class<RCTComponentViewProtocol> RNCMorphCardTargetCls(void) {
  return RNCMorphCardTargetComponentView.class;
}

@end
