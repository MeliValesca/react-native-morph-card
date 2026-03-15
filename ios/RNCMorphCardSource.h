#import <React/RCTView.h>

@interface RNCMorphCardSource : RCTView

/// Event fired when the morph animation begins.
@property (nonatomic, copy) RCTDirectEventBlock onMorphStart;

/// Event fired when the morph animation completes (expand finished).
@property (nonatomic, copy) RCTDirectEventBlock onMorphComplete;

/// Event fired when the dismiss animation completes.
@property (nonatomic, copy) RCTDirectEventBlock onDismissComplete;

/// Duration of the morph animation in milliseconds. Defaults to 500.
@property (nonatomic, assign) CGFloat duration;

/// Programmatically trigger the expand.
- (void)expand;

/// Programmatically trigger the dismiss.
- (void)collapse;

@end
