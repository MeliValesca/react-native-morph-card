import type { ReactNode } from 'react';

export interface SourceEntry {
  children: ReactNode;
  backgroundColor?: string;
  scaleMode?: string;
  presentation?: string;
  layoutWidth?: number;
  layoutHeight?: number;
}

export interface TargetConfig {
  width?: number | string;
  height?: number | string;
  borderRadius?: number;
  contentCentered?: boolean;
  contentOffsetY?: number;
}

const targetConfigs = new Map<number, TargetConfig>();

export function setTargetConfig(sourceTag: number, config: TargetConfig) {
  targetConfigs.set(sourceTag, config);
}

export function getTargetConfig(sourceTag: number): TargetConfig | undefined {
  return targetConfigs.get(sourceTag);
}

export function clearTargetConfig(sourceTag: number) {
  targetConfigs.delete(sourceTag);
}

const registry = new Map<number, SourceEntry>();

export function setSourceEntry(
  tag: number,
  children: ReactNode,
  backgroundColor?: string,
  scaleMode?: string,
  presentation?: string
) {
  const existing = registry.get(tag);
  registry.set(tag, {
    children,
    backgroundColor,
    scaleMode,
    presentation,
    layoutWidth: existing?.layoutWidth,
    layoutHeight: existing?.layoutHeight,
  });
}

export function setSourceLayout(tag: number, width: number, height: number) {
  const existing = registry.get(tag);
  if (existing) {
    existing.layoutWidth = width;
    existing.layoutHeight = height;
  }
}

export function getSourceEntry(tag: number): SourceEntry | undefined {
  return registry.get(tag);
}

export function clearSourceEntry(tag: number) {
  registry.delete(tag);
}
