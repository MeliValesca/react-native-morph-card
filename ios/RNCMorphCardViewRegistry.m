#import "RNCMorphCardViewRegistry.h"

@implementation RNCMorphCardViewRegistry {
  // NSMapTable lets us use NSNumber keys with weak object values.
  // "weak" means: if the UIView is deallocated, the entry automatically
  // becomes nil — no manual cleanup needed.
  NSMapTable<NSNumber *, UIView *> *_views;
}

+ (instancetype)shared {
  static RNCMorphCardViewRegistry *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[RNCMorphCardViewRegistry alloc] init];
  });
  return instance;
}

- (instancetype)init {
  if (self = [super init]) {
    // strongToWeakObjects: keys are strong (NSNumber stays alive),
    // values are weak (UIView can be deallocated freely).
    _views = [NSMapTable strongToWeakObjectsMapTable];
  }
  return self;
}

- (void)registerView:(UIView *)view withTag:(NSInteger)tag {
  [_views setObject:view forKey:@(tag)];
}

- (void)unregisterViewWithTag:(NSInteger)tag {
  [_views removeObjectForKey:@(tag)];
}

- (UIView *)viewForTag:(NSInteger)tag {
  return [_views objectForKey:@(tag)];
}

@end
