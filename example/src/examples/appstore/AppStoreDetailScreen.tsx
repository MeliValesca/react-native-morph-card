import * as React from 'react';
import { Text, View, ScrollView, Pressable } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

type Props = NativeStackScreenProps<RootStackParamList, 'AppStoreDetail'>;

export default function AppStoreDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View style={{ flex: 1, backgroundColor: '#1c1c1e' }}>
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={'100%'}
        height={420}
        borderRadius={0}
        contentCentered
      />

      <ScrollView
        style={{
          flex: 1,
          backgroundColor: '#fff',
          borderTopLeftRadius: 20,
          borderTopRightRadius: 20,
          marginTop: -5,
        }}
        contentContainerStyle={{ padding: 24, paddingTop: 32 }}
      >
        <Text
          style={{
            fontSize: 13,
            fontWeight: '700',
            color: '#007AFF',
            textTransform: 'uppercase',
            letterSpacing: 0.5,
          }}
        >
          PHOTOGRAPHY
        </Text>
        <Text
          style={{
            fontSize: 28,
            fontWeight: '800',
            color: '#1a1a1a',
            marginTop: 8,
          }}
        >
          The Art of Landscape Photography
        </Text>
        <Text style={{ fontSize: 14, color: '#8e8e93', marginTop: 8 }}>
          By Sarah Chen · 8 min read
        </Text>

        <Text
          style={{ fontSize: 17, color: '#333', lineHeight: 26, marginTop: 24 }}
        >
          Landscape photography is more than just pointing a camera at a pretty
          view. It's about capturing the mood, the light, and the feeling of
          being present in a moment that will never quite repeat itself.
        </Text>
        <Text
          style={{ fontSize: 17, color: '#333', lineHeight: 26, marginTop: 16 }}
        >
          The golden hour — that magical window just after sunrise and before
          sunset — transforms ordinary scenes into extraordinary compositions.
          Shadows lengthen, colors warm, and the world takes on a quality that
          feels almost painterly.
        </Text>
        <Text
          style={{ fontSize: 17, color: '#333', lineHeight: 26, marginTop: 16 }}
        >
          But great landscape photography doesn't require exotic locations. Some
          of the most compelling images come from familiar places seen with
          fresh eyes. A local park after rain, a city skyline at dusk, or
          morning fog rolling through a valley.
        </Text>

        <Pressable
          onPress={dismiss}
          style={{
            backgroundColor: '#007AFF',
            borderRadius: 14,
            paddingVertical: 16,
            alignItems: 'center',
            marginTop: 32,
            marginBottom: 40,
          }}
        >
          <Text style={{ fontSize: 17, fontWeight: '600', color: '#fff' }}>
            Close
          </Text>
        </Pressable>
      </ScrollView>

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
          zIndex: 110,
        }}
      >
        <Text style={{ fontSize: 16, color: '#fff', fontWeight: '600' }}>
          ✕
        </Text>
      </Pressable>
    </View>
  );
}
