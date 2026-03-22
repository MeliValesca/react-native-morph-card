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
    const presentation = entry?.presentation || 'push';

    if (presentation === 'push') {
      // For push: start collapse first (hides target, sets up overlay),
      // then goBack instantly, collapse continues over source screen.
      const collapsePromise = NativeMorphCardModule.collapse(sourceTag);
      // Wait one frame for collapse to create overlay and hide target
      await new Promise<void>(r => requestAnimationFrame(() => r()));
      navigation.setOptions({ animation: 'none' });
      navigation.goBack();
      await collapsePromise;
    } else {
      // For transparentModal: collapse first, then navigate back
      await NativeMorphCardModule.collapse(sourceTag);
      navigation.goBack();
    }
  }, [sourceTag, navigation]);

  return { dismiss };
}
