import * as React from 'react';
import {
  type ViewStyle,
  type DimensionValue,
  View,
  findNodeHandle,
  type LayoutChangeEvent,
} from 'react-native';
import NativeMorphCardModule from './specs/NativeMorphCardModule';
import NativeTargetViewSpec from './specs/NativeMorphCardTarget';
import { getSourceEntry } from './MorphChildrenRegistry';

const NativeTargetView = NativeTargetViewSpec ?? View;

export interface MorphCardTargetProps {
  /** The sourceTag from route params — triggers expand on mount. */
  sourceTag: number;
  /** Duration of the collapse animation in ms. Falls back to source's duration. */
  collapseDuration?: number;
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
}

export const MorphCardTarget = ({
  sourceTag,
  collapseDuration,
  width,
  height,
  borderRadius,
  contentOffsetY,
  contentCentered,
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
        contentCentered ?? false,
      );
      NativeMorphCardModule.expand(sourceTag, targetTag);
    },
    [sourceTag, borderRadius, contentOffsetY, contentCentered],
  );

  const sourceEntry = getSourceEntry(sourceTag);

  const containerStyle: ViewStyle = {
    overflow: 'hidden',
  };
  if (sourceEntry?.backgroundColor) {
    containerStyle.backgroundColor = sourceEntry.backgroundColor;
  }
  if (contentCentered) {
    containerStyle.justifyContent = 'center';
    containerStyle.alignItems = 'center';
  }
  if (contentOffsetY) {
    containerStyle.paddingTop = contentOffsetY;
  }

  if (width != null) {
    containerStyle.width = width;
  } else if (sourceSize) {
    containerStyle.width = sourceSize.width;
  }
  if (height != null) {
    containerStyle.height = height;
  } else if (sourceSize) {
    containerStyle.height = sourceSize.height;
  }

  if (borderRadius) {
    containerStyle.borderRadius = borderRadius;
  }

  return (
    <NativeTargetView
      ref={nativeRef}
      sourceTag={sourceTag}
      collapseDuration={collapseDuration}
      targetWidth={0}
      targetHeight={0}
      targetBorderRadius={borderRadius != null ? borderRadius : -1}
      style={containerStyle}
      onLayout={handleLayout}
    >
      {sourceEntry &&
        !sourceEntry.scaleMode &&
        (sourceEntry.backgroundColor && sourceEntry.layoutWidth ? (
          <View
            style={{
              width: sourceEntry.layoutWidth,
              height: sourceEntry.layoutHeight,
            }}
          >
            {sourceEntry.children}
          </View>
        ) : (
          sourceEntry.children
        ))}
    </NativeTargetView>
  );
};
