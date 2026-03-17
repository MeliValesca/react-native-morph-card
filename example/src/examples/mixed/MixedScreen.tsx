import * as React from 'react';
import { Image, ScrollView, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { landscapes, avatars } from '../../assets';

type Nav = NativeStackNavigationProp<RootStackParamList, 'Mixed'>;

const cards = [
  {
    id: 'wrapper-1',
    type: 'wrapper' as const,
    title: 'Wrapper Card',
    subtitle: 'Has backgroundColor — background expands',
    bg: '#1e3a5f',
  },
  {
    id: 'nowrap-1',
    type: 'nowrap' as const,
    title: 'No-Wrapper Image',
    subtitle: 'No backgroundColor — image scales directly',
  },
  {
    id: 'wrapper-2',
    type: 'wrapper' as const,
    title: 'Another Wrapper',
    subtitle: 'Different background color, same mode',
    bg: '#4a1942',
  },
  {
    id: 'nowrap-2',
    type: 'nowrap' as const,
    title: 'Circular Image',
    subtitle: 'No backgroundColor + large borderRadius',
  },
];

export default function MixedScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#f2f2f7' }}
      contentContainerStyle={{ padding: 20 }}
    >
      <Text
        style={{
          fontSize: 13,
          fontWeight: '600',
          color: '#888',
          marginBottom: 16,
        }}
      >
        WRAPPER AND NO-WRAPPER CARDS IN THE SAME LIST
      </Text>

      {cards.map((card, index) => (
        <View key={card.id} style={{ marginBottom: 20 }}>
          <MorphCardSource
            backgroundColor={card.type === 'wrapper' ? card.bg : undefined}
            borderRadius={card.id === 'nowrap-2' ? 100 : 16}
            height={card.id === 'nowrap-2' ? 200 : 180}
            duration={1000}
            onPress={(sourceTag: number) =>
              navigation.navigate('MixedDetail', { sourceTag, card })
            }
          >
            <Image
              source={
                card.type === 'wrapper'
                  ? landscapes[index]
                  : avatars[index % avatars.length]
              }
              resizeMode="cover"
              style={{ width: '100%', height: '100%' }}
            />
            {card.type === 'wrapper' && (
              <View
                style={{
                  position: 'absolute',
                  bottom: 16,
                  left: 16,
                  right: 16,
                }}
              >
                <Text
                  style={{ fontSize: 18, fontWeight: '700', color: '#fff' }}
                >
                  {card.title}
                </Text>
                <Text
                  style={{
                    fontSize: 13,
                    color: 'rgba(255,255,255,0.7)',
                    marginTop: 2,
                  }}
                >
                  {card.subtitle}
                </Text>
              </View>
            )}
          </MorphCardSource>
          {card.type === 'nowrap' && (
            <View style={{ marginTop: 8 }}>
              <Text
                style={{ fontSize: 15, fontWeight: '600', color: '#1a1a1a' }}
              >
                {card.title}
              </Text>
              <Text style={{ fontSize: 12, color: '#888', marginTop: 2 }}>
                {card.subtitle}
              </Text>
            </View>
          )}
        </View>
      ))}
    </ScrollView>
  );
}
