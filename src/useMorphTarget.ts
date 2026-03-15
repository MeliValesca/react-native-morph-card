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
 */
export function useMorphTarget({ sourceTag, navigation }: UseMorphTargetOptions) {
  const dismiss = React.useCallback(async () => {
    await NativeMorphCardModule.collapse(sourceTag);
    navigation.goBack();
  }, [sourceTag, navigation]);

  return { dismiss };
}
