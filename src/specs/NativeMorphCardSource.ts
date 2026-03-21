import type { ViewProps } from 'react-native';
import type {
  DirectEventHandler,
  Double,
  WithDefault,
} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

export interface NativeMorphCardSourceProps extends ViewProps {
  onMorphStart?: DirectEventHandler<{}>;
  onMorphComplete?: DirectEventHandler<{}>;
  onDismissComplete?: DirectEventHandler<{}>;
  duration?: Double;
  expandDuration?: Double;
  scaleMode?: WithDefault<'aspectFill' | 'aspectFit' | 'stretch', 'aspectFill'>;
  cardBorderRadius?: Double;
  rotations?: Double;
  rotationEndAngle?: Double;
  presentation?: WithDefault<'transparentModal' | 'push', 'transparentModal'>;
}

export default codegenNativeComponent<NativeMorphCardSourceProps>(
  'RNCMorphCardSource',
);