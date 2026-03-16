import * as React from 'react';
import { Text, View, Pressable, Dimensions } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

const SCREEN_WIDTH = Dimensions.get('window').width;

type Props = NativeStackScreenProps<RootStackParamList, 'ScaleModesDetail'>;

export default function ScaleModesDetailScreen({ route, navigation }: Props) {
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

      <View style={{ padding: 24, marginTop: 20 }}>
        <Text style={{ fontSize: 22, fontWeight: '700', color: '#fff' }}>
          Scale Mode: {route.params.mode}
        </Text>
        <Text style={{ fontSize: 15, color: '#888', marginTop: 8, lineHeight: 22 }}>
          This image was expanded using the "{route.params.mode}" scale mode.
          Compare how the image fills the target area differently with each mode.
        </Text>
      </View>

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
