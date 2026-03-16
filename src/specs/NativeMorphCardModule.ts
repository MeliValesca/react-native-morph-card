import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  prepareExpand(sourceTag: number): void;
  expand(sourceTag: number, targetTag: number): Promise<boolean>;
  setTargetConfig(
    sourceTag: number,
    targetWidth: number,
    targetHeight: number,
    targetBorderRadius: number,
    contentOffsetY: number,
    contentCentered: boolean
  ): void;
  collapse(sourceTag: number): Promise<boolean>;
  getSourceSize(
    sourceTag: number
  ): Promise<{ width: number; height: number }>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RNCMorphCardModule');
