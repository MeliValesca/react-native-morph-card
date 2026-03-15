#import <UIKit/UIKit.h>

// ──────────────────────────────────────────────────────
// VIEW REGISTRY
//
// On Paper (old arch), we could use self.bridge.uiManager to
// look up any view by its React tag. On Fabric (new arch),
// there's no bridge — TurboModules are standalone objects.
//
// Our solution: a simple singleton registry. When a MorphCardSource
// or MorphCardTarget mounts, it registers itself here with its
// React tag. When the module needs to find a view, it looks it up
// in this registry instead of going through the bridge.
//
// NSMapTable with weak values means: if the view gets deallocated
// (e.g., the screen is removed), the entry automatically becomes nil.
// No manual cleanup needed — no risk of retain cycles or stale refs.
// ──────────────────────────────────────────────────────

@interface RNCMorphCardViewRegistry : NSObject

+ (instancetype)shared;

/// Register a view with its React tag. Uses weak references
/// so views are not retained by the registry.
- (void)registerView:(UIView *)view withTag:(NSInteger)tag;

/// Remove a view from the registry (called on unmount).
- (void)unregisterViewWithTag:(NSInteger)tag;

/// Look up a view by its React tag. Returns nil if the view
/// has been deallocated or was never registered.
- (UIView *)viewForTag:(NSInteger)tag;

@end
