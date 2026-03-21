#import "RNCMorphCardTargetComponentView.h"
#import "RNCMorphCardSourceComponentView.h"
#import "RNCMorphCardViewRegistry.h"

#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/morphcard/ComponentDescriptors.h>
#import <react/renderer/components/morphcard/Props.h>

using namespace facebook::react;

// Declared in RNCMorphCardSourceComponentView.mm
extern UIView *RNCMorphCardFindScreenContainer(UIView *view);

@implementation RNCMorphCardTargetComponentView {
  UIView *_snapshotContainer; // our own view — Fabric can't reset its styles
  NSInteger _sourceTag;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      RNCMorphCardTargetComponentDescriptor>();
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps =
      *std::static_pointer_cast<const RNCMorphCardTargetProps>(props);
  _sourceTag = newProps.sourceTag;
  _targetWidth = newProps.targetWidth;
  _targetHeight = newProps.targetHeight;
  _targetBorderRadius = newProps.targetBorderRadius;
  _collapseDuration = newProps.collapseDuration;
  [super updateProps:props oldProps:oldProps];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [[RNCMorphCardViewRegistry shared] registerView:self withTag:self.tag];

    // Immediately hide the detail screen container to prevent flicker.
    // The expand animation will fade it back in.
    // Only hide if source is in a DIFFERENT screen container (i.e. navigation).
    // If source and target share the same screen (no navigation), don't hide.
    // For push presentation, don't hide — the target screen is already visible.
    UIView *sourceView = [[RNCMorphCardViewRegistry shared] viewForTag:_sourceTag];
    BOOL sourceIsPush = NO;
    if (sourceView && [sourceView isKindOfClass:[RNCMorphCardSourceComponentView class]]) {
      sourceIsPush = ((RNCMorphCardSourceComponentView *)sourceView).isPush;
    }
    if (sourceIsPush) {
      // Push mode: hide just the target card (not the screen) until expand completes.
      // The expand overlay covers it; showChildren restores it.
      self.alpha = 0;
    } else {
      UIView *targetScreen = RNCMorphCardFindScreenContainer(self);
      if (targetScreen) {
        UIView *sourceScreen = sourceView ? RNCMorphCardFindScreenContainer(sourceView) : nil;
        if (sourceScreen != targetScreen) {
          targetScreen.alpha = 0;
        }
      }
    }
  } else {
    [[RNCMorphCardViewRegistry shared] unregisterViewWithTag:self.tag];
    // Reset source state when target is removed (e.g. back navigation without morphCollapse)
    if (_sourceTag > 0) {
      UIView *sv = [[RNCMorphCardViewRegistry shared] viewForTag:_sourceTag];
      if (sv && [sv isKindOfClass:[RNCMorphCardSourceComponentView class]]) {
        RNCMorphCardSourceComponentView *source = (RNCMorphCardSourceComponentView *)sv;
        if (source.isExpanded && !source.isCollapsing) {
          source.isExpanded = NO;
          source.alpha = 1;
          if (source.wrapperView) {
            [source.wrapperView removeFromSuperview];
            source.wrapperView = nil;
          }
          source.snapshotView = nil;
        }
      }
    }
  }
}

- (void)showSnapshot:(UIImage *)image
         contentMode:(UIViewContentMode)mode
               frame:(CGRect)frame
        cornerRadius:(CGFloat)cornerRadius
     backgroundColor:(UIColor *)bgColor {
  [self clearSnapshot];
  // Use a dedicated container subview for all snapshot styling.
  // Fabric manages self's properties and can reset them at any time,
  // but it cannot touch our own subview's properties.
  UIView *container = [[UIView alloc] initWithFrame:self.bounds];
  container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  container.clipsToBounds = YES;
  container.layer.cornerRadius = cornerRadius;
  if (bgColor) { container.backgroundColor = bgColor; }

  UIImageView *iv = [[UIImageView alloc] initWithImage:image];
  iv.contentMode = mode;
  iv.clipsToBounds = YES;
  iv.frame = frame;
  [container addSubview:iv];

  [self addSubview:container];
  _snapshotContainer = container;
}

- (void)fadeOutSnapshot {
  UIView *snap = _snapshotContainer;
  if (!snap) return;
  // Only fade out if there are React children underneath to reveal.
  // If no children (scaleMode bitmap-only), keep the snapshot.
  BOOL hasReactChildren = NO;
  for (UIView *child in self.subviews) {
    if (child != _snapshotContainer) { hasReactChildren = YES; break; }
  }
  if (!hasReactChildren) return;

  [UIView animateWithDuration:0.15
      animations:^{ snap.alpha = 0; }
      completion:^(BOOL finished) {
        [snap removeFromSuperview];
        if (self->_snapshotContainer == snap) {
          self->_snapshotContainer = nil;
        }
      }];
}

- (void)clearSnapshot {
  if (_snapshotContainer) {
    [_snapshotContainer removeFromSuperview];
    _snapshotContainer = nil;
  }
}

- (void)showChildren {
  // For push mode: ensure all React subviews are visible
  for (UIView *child in self.subviews) {
    if (child != _snapshotContainer) {
      child.hidden = NO;
      child.alpha = 1;
    }
  }
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  [self clearSnapshot];
}

Class<RCTComponentViewProtocol> RNCMorphCardTargetCls(void) {
  return RNCMorphCardTargetComponentView.class;
}

@end
