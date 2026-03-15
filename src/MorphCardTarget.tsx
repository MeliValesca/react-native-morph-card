import * as React from 'react';
import {
  requireNativeComponent,
  type ViewProps,
  type StyleProp,
  type ViewStyle,
  type DimensionValue,
  View,
  findNodeHandle,
  type LayoutChangeEvent,
} from 'react-native';
import NativeMorphCardModule from './specs/NativeMorphCardModule';

let NativeTargetView: React.ComponentType<
  ViewProps & {
    targetWidth?: number;
    targetHeight?: number;
    targetBorderRadius?: number;
  }
>;

try {
  NativeTargetView = requireNativeComponent('RNCMorphCardTarget');
} catch {
  NativeTargetView = View;
}

export interface MorphCardTargetProps {
  /** The sourceTag from route params — triggers expand on mount. */
  sourceTag: number;
  /** Optional width override (number or '100%'). If omitted, source width is used. */
  width?: DimensionValue;
  /** Optional height override (number or '100%'). If omitted, source height is used. */
  height?: DimensionValue;
  /** Optional border radius override. If omitted, source border radius is used. Set to 0 for no rounding. */
  borderRadius?: number;
  /** Vertical offset for the content snapshot inside the expanded wrapper (wrapper mode only). */
  contentOffsetY?: number;
  /** Center the content snapshot horizontally inside the expanded wrapper (wrapper mode only). */
  contentCentered?: boolean;
  /** Optional style for positioning (margin, position, etc). */
  style?: StyleProp<ViewStyle>;
}

export const MorphCardTarget = ({
  sourceTag,
  width,
  height,
  borderRadius,
  contentOffsetY,
  contentCentered,
  style,
  ...rest
}: MorphCardTargetProps) => {
  const nativeRef = React.useRef<any>(null);
  const expandedRef = React.useRef(false);
  const [sourceSize, setSourceSize] = React.useState<{
    width: number;
    height: number;
  } | null>(null);

  // Fetch source size for auto-sizing when width/height not provided
  React.useEffect(() => {
    let cancelled = false;
    if (sourceTag && (width == null || height == null)) {
      NativeMorphCardModule.getSourceSize(sourceTag)
        .then((size: { width: number; height: number }) => {
          if (!cancelled) setSourceSize(size);
        })
        .catch(() => {});
    }
    return () => {
      cancelled = true;
    };
  }, [sourceTag, width, height]);

  // Use onLayout to get resolved pixel dimensions, then trigger expand
  const handleLayout = React.useCallback(
    (e: LayoutChangeEvent) => {
      if (expandedRef.current) return;
      if (!sourceTag) return;

      const { width: lw, height: lh } = e.nativeEvent.layout;
      const targetTag = findNodeHandle(nativeRef.current);
      if (!targetTag) return;

      expandedRef.current = true;

      NativeMorphCardModule.setTargetConfig(
        sourceTag,
        lw,
        lh,
        borderRadius != null ? borderRadius : -1,
        contentOffsetY ?? 0,
        contentCentered ?? false
      );
      NativeMorphCardModule.expand(sourceTag, targetTag);
    },
    [sourceTag, borderRadius, contentOffsetY, contentCentered]
  );

  const sizeStyle: ViewStyle = {};
  if (width != null) {
    sizeStyle.width = width;
  } else if (sourceSize) {
    sizeStyle.width = sourceSize.width;
  }
  if (height != null) {
    sizeStyle.height = height;
  } else if (sourceSize) {
    sizeStyle.height = sourceSize.height;
  }

  return (
    <NativeTargetView
      ref={nativeRef}
      targetWidth={0}
      targetHeight={0}
      targetBorderRadius={borderRadius != null ? borderRadius : -1}
      style={[style, sizeStyle]}
      onLayout={handleLayout}
      {...rest}
    />
  );
};
