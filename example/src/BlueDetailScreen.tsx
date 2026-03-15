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
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        duration={200}
        width={'100%'}
        borderRadius={0}
        height={240}
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
