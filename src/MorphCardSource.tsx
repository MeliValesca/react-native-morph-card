import * as React from 'react';
import {
  Pressable,
  type ViewStyle,
  View,
  findNodeHandle,
} from 'react-native';
import NativeMorphCardModule from './specs/NativeMorphCardModule';
import NativeSourceViewSpec from './specs/NativeMorphCardSource';

const NativeSourceView = NativeSourceViewSpec ?? View;

export type ScaleMode = 'aspectFill' | 'aspectFit' | 'stretch';

export interface MorphCardSourceProps {
  ref?: React.Ref<any>;
  duration?: number;
  width?: number;
  height?: number;
  borderRadius?: number;
  backgroundColor?: string;
  /** How the snapshot scales in no-wrapper mode (no backgroundColor). Default: 'aspectFill' */
  scaleMode?: ScaleMode;
  onPress?: (sourceTag: number) => void;
  children: React.ReactNode;
}

export const MorphCardSource = ({
  children,
  duration = 300,
  width,
  height,
  borderRadius,
  backgroundColor,
  scaleMode,
  onPress,
  ref,
}: MorphCardSourceProps) => {
  const nativeRef = React.useRef<any>(null);
  React.useImperativeHandle(ref, () => nativeRef.current);

  const style: ViewStyle = {};
  if (width != null) style.width = width;
  if (height != null) style.height = height;
  if (borderRadius != null) style.borderRadius = borderRadius;
  if (backgroundColor != null) style.backgroundColor = backgroundColor;
  const handlePress = React.useCallback(() => {
    if (!onPress) return;
    const tag = findNodeHandle(nativeRef.current);
    if (tag != null) onPress(tag);
  }, [onPress]);

  const content = (
    <NativeSourceView ref={nativeRef} duration={duration} scaleMode={scaleMode} style={style}>
      {children}
    </NativeSourceView>
  );

  if (onPress) {
    return <Pressable onPress={handlePress}>{content}</Pressable>;
  }

  return content;
};

/**
 * Get the native view tag from a ref. Useful for passing sourceTag
 * to the detail screen via navigation params.
 */
export function getViewTag(viewRef: React.RefObject<any>): number | null {
  return findNodeHandle(viewRef.current);
}

/**
 * Expand: background grows from card bounds to fullscreen while
 * card snapshot moves to targetRef's position. Content fades in at the end.
 *
 * Call this AFTER navigating to the detail screen (so the target is mounted).
 */
export async function morphExpand(
  sourceRef: React.RefObject<any>,
  targetRef: React.RefObject<any>,
): Promise<boolean> {
  const sourceTag = findNodeHandle(sourceRef.current);
  const targetTag = findNodeHandle(targetRef.current);
  if (!sourceTag || !targetTag) return false;
  return NativeMorphCardModule.expand(sourceTag, targetTag);
}

/**
 * Collapse: content fades out, background shrinks from fullscreen back
 * to card bounds while card snapshot moves from target back to card position.
 * Uses the target stored from the last expand call.
 */
export async function morphCollapse(sourceTag: number): Promise<boolean> {
  return NativeMorphCardModule.collapse(sourceTag);
}
