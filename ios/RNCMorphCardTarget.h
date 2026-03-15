#import <React/RCTView.h>

@interface RNCMorphCardTarget : RCTView

/// Duration of the morph animation in milliseconds. Defaults to 350.
@property (nonatomic, assign) CGFloat duration;

/// The react tag of the source card this target morphs from.
/// Used by the module to look up the source view and snapshot it.
@property (nonatomic, assign) NSInteger sourceTag;

/// Event fired when the morph animation completes.
@property (nonatomic, copy) RCTDirectEventBlock onMorphComplete;

/// Returns this view's frame in window coordinates.
/// The animation needs this to know where the snapshot should land.
- (CGRect)frameInWindow;

@end
