import * as React from 'react';
import { Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from './App';

type Props = NativeStackScreenProps<RootStackParamList, 'BlueDetail'>;

export default function BlueDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View style={{ flex: 1, backgroundColor: '#fff' }}>
      {/* Just a position/size marker — the source card's content
          is snapshotted and animated here by the native side */}

      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={'100%'}
        height={240}
        // contentOffsetY={60}
        contentCentered
      />
      <Text
        style={{
          fontSize: 16,
          color: '#333',
          lineHeight: 24,
          marginBottom: 16,
        }}
      >
        This is the expanded detail view. The blue card from the home screen
        morphed into the header above — the background grew outward while the
        card slid into position.
      </Text>
      <Text
        style={{
          fontSize: 16,
          color: '#333',
          lineHeight: 24,
          marginBottom: 24,
        }}
      >
        Imagine articles, featured content, or app-store-style cards opening
        into their full detail view with this transition.
      </Text>
      <Text
        onPress={dismiss}
        style={{
          fontSize: 16,
          fontWeight: '600',
          color: '#007AFF',
        }}
      >
        ← Back
      </Text>
    </View>
  );
}
