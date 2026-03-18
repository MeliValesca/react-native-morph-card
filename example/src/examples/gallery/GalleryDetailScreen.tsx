import * as React from 'react';
import { View, Pressable, Text, Dimensions } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

type Props = NativeStackScreenProps<RootStackParamList, 'GalleryDetail'>;

const { width: SCREEN_WIDTH } = Dimensions.get('window');

export default function GalleryDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View
      style={{ flex: 1, backgroundColor: '#000', justifyContent: 'center' }}
    >
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={SCREEN_WIDTH}
        height={SCREEN_WIDTH}
        borderRadius={0}
        collapseDuration={200}
      />

      {/* Close button */}
      <Pressable
        onPress={dismiss}
        style={{
          position: 'absolute',
          top: 60,
          right: 20,
          backgroundColor: 'rgba(255,255,255,0.2)',
          borderRadius: 20,
          width: 40,
          height: 40,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Text style={{ fontSize: 18, color: '#fff', fontWeight: '600' }}>
          ✕
        </Text>
      </Pressable>

      {/* Bottom actions */}
      <View
        style={{
          position: 'absolute',
          bottom: 48,
          left: 0,
          right: 0,
          flexDirection: 'row',
          justifyContent: 'center',
          gap: 40,
        }}
      >
        {['Share', 'Favorite', 'Delete'].map((label) => (
          <View key={label} style={{ alignItems: 'center' }}>
            <View
              style={{
                width: 48,
                height: 48,
                borderRadius: 24,
                backgroundColor: 'rgba(255,255,255,0.12)',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Text style={{ fontSize: 20, color: '#fff' }}>
                {label === 'Share' ? '↗' : label === 'Favorite' ? '♡' : '🗑'}
              </Text>
            </View>
            <Text style={{ fontSize: 11, color: '#888', marginTop: 6 }}>
              {label}
            </Text>
          </View>
        ))}
      </View>
    </View>
  );
}
