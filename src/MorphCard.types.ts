import type { ViewProps } from 'react-native';

export interface MorphCardProps extends ViewProps {
  /**
   * Duration of the morph animation in milliseconds. Defaults to 500.
   */
  duration?: number;
  /**
   * Called when the expand animation begins.
   */
  onMorphStart?: () => void;
  /**
   * Called when the expand animation completes.
   */
  onMorphComplete?: () => void;
  /**
   * Called when the collapse animation completes.
   */
  onDismissComplete?: () => void;
  /**
   * The collapsed card content.
   */
  renderCollapsed: () => React.ReactNode;
  /**
   * The expanded fullscreen content.
   */
  renderExpanded: (collapse: () => void) => React.ReactNode;
  ref?: React.Ref<any>;
}