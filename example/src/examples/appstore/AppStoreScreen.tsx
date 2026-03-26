import * as React from 'react';
import { Image, ScrollView, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

type Nav = NativeStackNavigationProp<RootStackParamList, 'AppStore'>;

const CARD_IMAGE = require('../../assets/landscape1.jpg');

export default function AppStoreScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#f2f2f7' }}
      contentContainerStyle={{ padding: 20, paddingTop: 16 }}
    >
      <Text
        style={{
          fontSize: 13,
          fontWeight: '600',
          color: '#8e8e93',
          textTransform: 'uppercase',
          marginBottom: 6,
        }}
      >
        TODAY
      </Text>

      <MorphCardSource
        onPress={(sourceTag) =>
          navigation.navigate('AppStoreDetail', { sourceTag })
        }
        backgroundColor="#1c1c1e"
        borderRadius={20}
        height={400}
      >
        <View style={{ flex: 1 }}>
          <Image
            source={CARD_IMAGE}
            style={{
              width: '100%',
              height: 260,
              borderTopLeftRadius: 20,
              borderTopRightRadius: 20,
            }}
          />
          <View style={{ padding: 20, flex: 1, justifyContent: 'flex-end' }}>
            <Text
              style={{
                fontSize: 12,
                fontWeight: '700',
                color: '#8e8e93',
                textTransform: 'uppercase',
                letterSpacing: 0.5,
              }}
            >
              FEATURED
            </Text>
            <Text
              style={{
                fontSize: 24,
                fontWeight: '800',
                color: '#fff',
                marginTop: 4,
              }}
            >
              The Art of Landscape Photography
            </Text>
            <Text style={{ fontSize: 14, color: '#aeaeb2', marginTop: 6 }}>
              Discover breathtaking vistas and learn the techniques behind
              stunning nature shots.
            </Text>
          </View>
        </View>
      </MorphCardSource>

      <View style={{ marginTop: 24 }}>
        <Text
          style={{
            fontSize: 13,
            fontWeight: '600',
            color: '#8e8e93',
            textTransform: 'uppercase',
            marginBottom: 12,
          }}
        >
          MORE TO EXPLORE
        </Text>
        {[
          'Mindfulness for Developers',
          'Hidden Gems: Indie Games',
          'Cooking with AI',
        ].map((title) => (
          <View
            key={title}
            style={{
              backgroundColor: '#fff',
              borderRadius: 12,
              padding: 16,
              marginBottom: 8,
              flexDirection: 'row',
              alignItems: 'center',
            }}
          >
            <View
              style={{
                width: 48,
                height: 48,
                borderRadius: 12,
                backgroundColor: '#e5e5ea',
                marginRight: 14,
              }}
            />
            <Text style={{ fontSize: 15, fontWeight: '500', color: '#1a1a1a' }}>
              {title}
            </Text>
          </View>
        ))}
      </View>
    </ScrollView>
  );
}
