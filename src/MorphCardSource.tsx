import * as React from 'react';
import {
  requireNativeComponent,
  type ViewProps,
  type ViewStyle,
  View,
  findNodeHandle,
} from 'react-native';
import NativeMorphCardModule from './specs/NativeMorphCardModule';

let NativeSourceView: React.ComponentType<
  ViewProps & { duration?: number }
>;

try {
  NativeSourceView = requireNativeComponent('RNCMorphCardSource');
} catch {
  NativeSourceView = View;
}

export interface MorphCardSourceProps {
  ref?: React.Ref<any>;
  duration?: number;
  width?: number;
  height?: number;
  borderRadius?: number;
  backgroundColor?: string;
  shadowColor?: string;
  shadowOffset?: { width: number; height: number };
  shadowOpacity?: number;
  shadowRadius?: number;
  elevation?: number;
  children: React.ReactNode;
}

export const MorphCardSource = ({
  children,
  duration = 500,
  width,
  height,
  borderRadius,
  backgroundColor,
  shadowColor,
  shadowOffset,
  shadowOpacity,
  shadowRadius,
  elevation,
  ref,
}: MorphCardSourceProps) => {
  const nativeRef = React.useRef<any>(null);
  React.useImperativeHandle(ref, () => nativeRef.current);

  const style: ViewStyle = {};
  if (width != null) style.width = width;
  if (height != null) style.height = height;
  if (borderRadius != null) style.borderRadius = borderRadius;
  if (backgroundColor != null) style.backgroundColor = backgroundColor;
  if (shadowColor != null) style.shadowColor = shadowColor;
  if (shadowOffset != null) style.shadowOffset = shadowOffset;
  if (shadowOpacity != null) style.shadowOpacity = shadowOpacity;
  if (shadowRadius != null) style.shadowRadius = shadowRadius;
  if (elevation != null) style.elevation = elevation;

  return (
    <NativeSourceView
      ref={nativeRef}
      duration={duration}
      style={style}
    >
      {children}
    </NativeSourceView>
  );
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
