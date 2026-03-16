import * as React from 'react';
import { Text, View, Pressable } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

type Props = NativeStackScreenProps<RootStackParamList, 'MixedDetail'>;

export default function MixedDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  const { card } = route.params;

  return (
    <View style={{ flex: 1, backgroundColor: card.bg ?? '#000' }}>
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={'100%'}
        height={360}
        borderRadius={0}
        contentCentered
      />

      <View style={{ padding: 24, marginTop: 16 }}>
        <Text style={{ fontSize: 13, fontWeight: '600', color: 'rgba(255,255,255,0.5)' }}>
          {card.type === 'wrapper' ? 'WRAPPER MODE' : 'NO-WRAPPER MODE'}
        </Text>
        <Text style={{ fontSize: 24, fontWeight: '700', color: '#fff', marginTop: 8 }}>
          {card.title}
        </Text>
        <Text style={{ fontSize: 15, color: 'rgba(255,255,255,0.7)', marginTop: 8, lineHeight: 22 }}>
          {card.subtitle}. This card uses {card.type === 'wrapper' ? 'wrapper' : 'no-wrapper'} mode
          because it {card.type === 'wrapper' ? 'has' : 'does not have'} a backgroundColor prop.
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
