import type { ViewProps } from 'react-native';
import type {
  DirectEventHandler,
  Double,
} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

export interface NativeMorphCardSourceProps extends ViewProps {
  onMorphStart?: DirectEventHandler<{}>;
  onMorphComplete?: DirectEventHandler<{}>;
  onDismissComplete?: DirectEventHandler<{}>;
  duration?: Double;
}

export default codegenNativeComponent<NativeMorphCardSourceProps>(
  'RNCMorphCardSource',
);