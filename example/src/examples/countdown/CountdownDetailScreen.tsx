import * as React from 'react';
import { View, Pressable, Text } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

type Props = NativeStackScreenProps<RootStackParamList, 'CountdownDetail'>;

export default function CountdownDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View style={{ flex: 1, backgroundColor: '#0f0f23' }}>
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={'100%'}
        height={400}
        borderRadius={0}
        contentCentered
      />
      <Pressable
        onPress={dismiss}
        style={{ position: 'absolute', top: 50, right: 20 }}
      >
        <Text style={{ color: '#fff', fontSize: 24 }}>✕</Text>
      </Pressable>
      <View style={{ padding: 20 }}>
        <Text style={{ color: '#fff', fontSize: 16 }}>
          The timer above should still be counting down — it's a live React
          component, not a static bitmap.
        </Text>
      </View>
    </View>
  );
}
