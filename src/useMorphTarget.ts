import * as React from 'react';
import NativeMorphCardModule from './specs/NativeMorphCardModule';

interface UseMorphTargetOptions {
  sourceTag: number;
  navigation: { goBack: () => void };
}

/**
 * Hook for detail screens using MorphCardTarget.
 *
 * Returns a `dismiss()` that collapses the morph and navigates back.
 *
 * Usage:
 * ```tsx
 * const { dismiss } = useMorphTarget({ sourceTag, navigation });
 * return (
 *   <MorphCardTarget sourceTag={sourceTag} style={...}>
 *     ...
 *   </MorphCardTarget>
 *   <Pressable onPress={dismiss}><Text>Back</Text></Pressable>
 * );
 * ```
 */
export function useMorphTarget({ sourceTag, navigation }: UseMorphTargetOptions) {
  const dismiss = React.useCallback(async () => {
    await NativeMorphCardModule.collapse(sourceTag);
    navigation.goBack();
  }, [sourceTag, navigation]);

  return { dismiss };
}
