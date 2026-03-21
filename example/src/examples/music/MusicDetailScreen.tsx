import * as React from 'react';
import { Text, View, Pressable } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

type Props = NativeStackScreenProps<RootStackParamList, 'MusicDetail'>;

export default function MusicDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  const { album } = route.params;

  return (
    <View style={{ flex: 1, backgroundColor: '#000' }}>
      <View
        style={{ alignItems: 'center', paddingTop: 100, paddingHorizontal: 40 }}
      >
        <MorphCardTarget
          sourceTag={route.params.sourceTag}
          width={300}
          height={300}
          collapseDuration={2400}
          borderRadius={16}
        />

        <Text
          style={{
            fontSize: 24,
            fontWeight: '700',
            color: '#fff',
            marginTop: 32,
            textAlign: 'center',
          }}
        >
          {album.title}
        </Text>
        <Text style={{ fontSize: 16, color: '#FF375F', marginTop: 4 }}>
          {album.artist}
        </Text>

        {/* Progress bar */}
        <View style={{ width: '100%', marginTop: 32 }}>
          <View style={{ height: 4, backgroundColor: '#333', borderRadius: 2 }}>
            <View
              style={{
                height: 4,
                width: '35%',
                backgroundColor: '#fff',
                borderRadius: 2,
              }}
            />
          </View>
          <View
            style={{
              flexDirection: 'row',
              justifyContent: 'space-between',
              marginTop: 8,
            }}
          >
            <Text style={{ fontSize: 11, color: '#666' }}>1:24</Text>
            <Text style={{ fontSize: 11, color: '#666' }}>-2:38</Text>
          </View>
        </View>

        {/* Controls */}
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'center',
            marginTop: 24,
            gap: 48,
          }}
        >
          <Text style={{ fontSize: 32, color: '#fff' }}>⏮</Text>
          <View
            style={{
              width: 72,
              height: 72,
              borderRadius: 36,
              backgroundColor: '#fff',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Text style={{ fontSize: 28, color: '#000', marginLeft: 4 }}>
              ▶
            </Text>
          </View>
          <Text style={{ fontSize: 32, color: '#fff' }}>⏭</Text>
        </View>

        {/* Volume */}
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            width: '100%',
            marginTop: 32,
            gap: 12,
          }}
        >
          <Text style={{ fontSize: 12, color: '#666' }}>🔈</Text>
          <View
            style={{
              flex: 1,
              height: 4,
              backgroundColor: '#333',
              borderRadius: 2,
            }}
          >
            <View
              style={{
                height: 4,
                width: '60%',
                backgroundColor: '#666',
                borderRadius: 2,
              }}
            />
          </View>
          <Text style={{ fontSize: 12, color: '#666' }}>🔊</Text>
        </View>
      </View>

      <Pressable
        onPress={dismiss}
        style={{
          position: 'absolute',
          top: 54,
          left: 20,
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
