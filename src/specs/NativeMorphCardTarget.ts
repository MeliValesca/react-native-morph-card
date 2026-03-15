import type { ViewProps } from 'react-native';
import type {
  DirectEventHandler,
  Double,
  Int32,
} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

interface MorphCompleteEvent {
  finished: boolean;
}

export interface NativeMorphCardTargetProps extends ViewProps {
  /**
   * Duration of the morph animation in milliseconds.
   */
  duration?: Double;

  /**
   * The react tag of the source card to morph from.
   */
  sourceTag?: Int32;

  onMorphComplete?: DirectEventHandler<MorphCompleteEvent>;

  /** Explicit target width. 0 = use source width. */
  targetWidth?: Double;

  /** Explicit target height. 0 = use source height. */
  targetHeight?: Double;

  /** Target border radius. -1 = use source border radius. */
  targetBorderRadius?: Double;
}

export default codegenNativeComponent<NativeMorphCardTargetProps>(
  'RNCMorphCardTarget',
);
