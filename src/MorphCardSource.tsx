import * as React from 'react';
import {
  Pressable,
  type ViewStyle,
  type DimensionValue,
  type LayoutChangeEvent,
  View,
  findNodeHandle,
} from 'react-native';
import NativeMorphCardModule from './specs/NativeMorphCardModule';
import NativeSourceViewSpec from './specs/NativeMorphCardSource';
import { setSourceEntry, setSourceLayout, clearSourceEntry } from './MorphChildrenRegistry';

const NativeSourceView = NativeSourceViewSpec ?? View;

export type ResizeMode = 'cover' | 'contain' | 'stretch';

export interface MorphCardSourceProps {
  ref?: React.Ref<any>;
  duration?: number;
  expandDuration?: number;
  width?: DimensionValue;
  height?: DimensionValue;
  borderRadius?: number;
  backgroundColor?: string;
  /** How the snapshot scales in no-wrapper mode (no backgroundColor). Default: 'cover' */
  resizeMode?: ResizeMode;
  onPress?: (sourceTag: number) => void;
  children: React.ReactNode;
}

export const MorphCardSource = ({
  children,
  duration = 300,
  expandDuration,
  width,
  height,
  borderRadius,
  backgroundColor,
  resizeMode,
  onPress,
  ref,
}: MorphCardSourceProps) => {
  const nativeRef = React.useRef<any>(null);
  React.useImperativeHandle(ref, () => nativeRef.current);

  // Store children in shared registry so MorphCardTarget can clone them
  React.useEffect(() => {
    const tag = findNodeHandle(nativeRef.current);
    if (tag != null) {
      setSourceEntry(tag, children, backgroundColor, resizeMode);
    }
    return () => {
      if (tag != null) clearSourceEntry(tag);
    };
  }, [children, backgroundColor, resizeMode]);

  const style: ViewStyle = {};
  if (width != null) style.width = width as ViewStyle['width'];
  if (height != null) style.height = height as ViewStyle['height'];
  if (borderRadius != null) {
    style.borderRadius = borderRadius;
    style.overflow = 'hidden';
  }
  if (backgroundColor != null) style.backgroundColor = backgroundColor;

  const handleLayout = React.useCallback((e: LayoutChangeEvent) => {
    const tag = findNodeHandle(nativeRef.current);
    if (tag != null) {
      const { width: lw, height: lh } = e.nativeEvent.layout;
      setSourceLayout(tag, lw, lh);
    }
  }, []);

  const handlePress = React.useCallback(() => {
    if (!onPress) return;
    const tag = findNodeHandle(nativeRef.current);
    if (tag != null) {
      // Create overlay immediately BEFORE navigation to prevent target screen flash.
      // Delay navigation by one frame so the overlay is drawn before the modal screen
      // is added — prevents the target screen from flashing on Android.
      NativeMorphCardModule.prepareExpand(tag);
      requestAnimationFrame(() => onPress(tag));
    }
  }, [onPress]);

  const content = (
    <NativeSourceView ref={nativeRef} duration={duration} expandDuration={expandDuration} scaleMode={resizeMode === 'contain' ? 'aspectFit' : resizeMode === 'stretch' ? 'stretch' : 'aspectFill'} cardBorderRadius={borderRadius} style={style} onLayout={handleLayout}>
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
