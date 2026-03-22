import * as React from 'react';
import { Image, ScrollView, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { albums as albumImages } from '../../assets';

type Nav = NativeStackNavigationProp<RootStackParamList, 'Music'>;

const albums = [
  { title: 'After Hours', artist: 'The Weeknd', color: '#b91c1c' },
  { title: 'Midnight Rain', artist: 'Luna Eclipse', color: '#1e40af' },
  { title: 'Golden Hour', artist: 'Sunset Collective', color: '#b45309' },
  { title: 'Neon Dreams', artist: 'Synthwave FM', color: '#7c3aed' },
];

export default function MusicScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#000' }}
      contentContainerStyle={{ padding: 20, paddingTop: 16 }}
    >
      <Text
        style={{
          fontSize: 13,
          fontWeight: '600',
          color: '#666',
          textTransform: 'uppercase',
          marginBottom: 16,
        }}
      >
        RECENTLY PLAYED
      </Text>

      <View
        style={{
          flexDirection: 'row',
          flexWrap: 'wrap',
          justifyContent: 'space-between',
        }}
      >
        {albums.map((album, index) => (
          <View key={album.title} style={{ width: '48%', marginBottom: 24 }}>
            <View style={{ aspectRatio: 1 }}>
              <MorphCardSource
                borderRadius={150}
                width={'100%'}
                height={'100%'}
                duration={400}
                rotations={2}
                onPress={(sourceTag) =>
                  navigation.navigate('MusicDetail', { sourceTag, album })
                }
              >
                <Image
                  source={albumImages[index]}
                  resizeMode="cover"
                  style={{ width: '100%', height: '100%' }}
                />
              </MorphCardSource>
            </View>
            <Text
              style={{
                fontSize: 14,
                fontWeight: '600',
                color: '#fff',
                marginTop: 8,
              }}
              numberOfLines={1}
            >
              {album.title}
            </Text>
            <Text
              style={{ fontSize: 12, color: '#888', marginTop: 2 }}
              numberOfLines={1}
            >
              {album.artist}
            </Text>
          </View>
        ))}
      </View>
    </ScrollView>
  );
}
