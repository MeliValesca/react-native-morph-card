import * as React from 'react';
import { Text, View, Pressable, Dimensions } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

const SCREEN_WIDTH = Dimensions.get('window').width;

type Props = NativeStackScreenProps<RootStackParamList, 'PerformanceDetail'>;

export default function PerformanceDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View style={{ flex: 1, backgroundColor: '#000', justifyContent: 'center' }}>
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={SCREEN_WIDTH}
        height={SCREEN_WIDTH}
        borderRadius={0}
      />

      <Pressable
        onPress={dismiss}
        style={{
          position: 'absolute',
          top: 54,
          right: 20,
          backgroundColor: 'rgba(255,255,255,0.15)',
          borderRadius: 16,
          width: 32,
          height: 32,
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 10,
        }}
      >
        <Text style={{ fontSize: 16, color: '#fff', fontWeight: '600' }}>
          ✕
        </Text>
      </Pressable>
    </View>
  );
}
