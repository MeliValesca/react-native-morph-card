import * as React from 'react';
import NativeMorphCardModule from './specs/NativeMorphCardModule';
import { getSourceEntry } from './MorphChildrenRegistry';

interface UseMorphTargetOptions {
  sourceTag: number;
  navigation: { goBack: () => void; setOptions: (opts: any) => void };
}

/**
 * Hook for detail screens using MorphCardTarget.
 *
 * Returns a `dismiss()` that collapses the morph and navigates back.
 * Automatically detects the source's presentation mode.
 */
export function useMorphTarget({ sourceTag, navigation }: UseMorphTargetOptions) {
  const dismiss = React.useCallback(async () => {
    const entry = getSourceEntry(sourceTag);
    const presentation = entry?.presentation || 'transparentModal';

    if (presentation === 'push') {
      // For push: goBack instantly first (reveals source screen),
      // then collapse reuses the expand overlay (already above source screen).
      navigation.setOptions({ animation: 'none' });
      navigation.goBack();
      // Wait one frame for goBack to process before collapsing
      await new Promise<void>(r => requestAnimationFrame(() => r()));
      await NativeMorphCardModule.collapse(sourceTag);
    } else {
      // For transparentModal: collapse first, then navigate back
      await NativeMorphCardModule.collapse(sourceTag);
      navigation.goBack();
    }
  }, [sourceTag, navigation]);

  return { dismiss };
}
