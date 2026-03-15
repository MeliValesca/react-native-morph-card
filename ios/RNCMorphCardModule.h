#ifdef RCT_NEW_ARCH_ENABLED
#import <morphcard/morphcard.h>
#else
#import <React/RCTBridgeModule.h>
#endif

@interface RNCMorphCardModule : NSObject
#ifdef RCT_NEW_ARCH_ENABLED
    <NativeMorphCardModuleSpec>
#else
    <RCTBridgeModule>
#endif

@end
