#import "RNCMorphCardModule.h"
#import "RNCMorphCardViewRegistry.h"

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNCMorphCardSourceComponentView.h"
#endif

@implementation RNCMorphCardModule {
  NSMutableDictionary<NSNumber *, RNCMorphCardSourceComponentView *> *_cachedSources;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(prepareExpand : (double)sourceTag) {
  dispatch_async(dispatch_get_main_queue(), ^{
#ifdef RCT_NEW_ARCH_ENABLED
    UIView *sourceView =
        [[RNCMorphCardViewRegistry shared] viewForTag:(NSInteger)sourceTag];
    if ([sourceView isKindOfClass:[RNCMorphCardSourceComponentView class]]) {
      RNCMorphCardSourceComponentView *src =
          (RNCMorphCardSourceComponentView *)sourceView;
      // For push mode: capture source position before navigation
      if (!self->_cachedSources) self->_cachedSources = [NSMutableDictionary new];
      self->_cachedSources[@((NSInteger)sourceTag)] = src;
      if (src.isPush) {
        [src prepareExpand];
      }
    }
#endif
  });
}

RCT_EXPORT_METHOD(setTargetConfig
                  : (double)sourceTag targetWidth
                  : (double)targetWidth targetHeight
                  : (double)targetHeight targetBorderRadius
                  : (double)targetBorderRadius contentOffsetY
                  : (double)contentOffsetY contentCentered
                  : (BOOL)contentCentered) {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIView *sourceView =
        [[RNCMorphCardViewRegistry shared] viewForTag:(NSInteger)sourceTag];
#ifdef RCT_NEW_ARCH_ENABLED
    if ([sourceView
            isKindOfClass:[RNCMorphCardSourceComponentView class]]) {
      RNCMorphCardSourceComponentView *src =
          (RNCMorphCardSourceComponentView *)sourceView;
      src.pendingTargetWidth = targetWidth;
      src.pendingTargetHeight = targetHeight;
      src.pendingTargetBorderRadius = targetBorderRadius;
      src.pendingContentOffsetY = contentOffsetY;
      src.pendingContentCentered = contentCentered;
    }
#endif
  });
}

RCT_EXPORT_METHOD(expand
                  : (double)sourceTag targetTag
                  : (double)targetTag resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject) {
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)),
      dispatch_get_main_queue(), ^{
        UIView *sourceView =
            [[RNCMorphCardViewRegistry shared]
                viewForTag:(NSInteger)sourceTag];

        UIView *targetView =
            [[RNCMorphCardViewRegistry shared]
                viewForTag:(NSInteger)targetTag];

#ifdef RCT_NEW_ARCH_ENABLED
        RNCMorphCardSourceComponentView *src = nil;
        if ([sourceView isKindOfClass:[RNCMorphCardSourceComponentView class]]) {
          src = (RNCMorphCardSourceComponentView *)sourceView;
        } else {
          src = self->_cachedSources[@((NSInteger)sourceTag)];
        }
        if (src) {
          [src expandToTarget:targetView resolve:resolve];
        } else {
          resolve(@(NO));
        }
#else
        resolve(@(NO));
#endif
      });
}

RCT_EXPORT_METHOD(getSourceSize
                  : (double)sourceTag resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIView *sourceView =
        [[RNCMorphCardViewRegistry shared] viewForTag:(NSInteger)sourceTag];
    if (sourceView) {
      resolve(@{
        @"width" : @(sourceView.bounds.size.width),
        @"height" : @(sourceView.bounds.size.height)
      });
    } else {
      resolve(@{@"width" : @(0), @"height" : @(0)});
    }
  });
}

RCT_EXPORT_METHOD(collapse
                  : (double)sourceTag resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIView *sourceView =
        [[RNCMorphCardViewRegistry shared] viewForTag:(NSInteger)sourceTag];

#ifdef RCT_NEW_ARCH_ENABLED
    RNCMorphCardSourceComponentView *src = nil;
    if ([sourceView isKindOfClass:[RNCMorphCardSourceComponentView class]]) {
      src = (RNCMorphCardSourceComponentView *)sourceView;
    } else {
      src = self->_cachedSources[@((NSInteger)sourceTag)];
    }
    NSLog(@"[MorphCard] collapse: src=%@ isExpanded=%d isCollapsing=%d wrapper=%@",
          src, src.isExpanded, src.isCollapsing, src.wrapperView);
    if (src) {
      [src collapseWithResolve:resolve];
      [self->_cachedSources removeObjectForKey:@((NSInteger)sourceTag)];
    } else {
      NSLog(@"[MorphCard] collapse: no source view found");
      resolve(@(NO));
    }
#else
    resolve(@(NO));
#endif
  });
}

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeMorphCardModuleSpecJSI>(
      params);
}
#endif

@end
