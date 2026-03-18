import * as React from 'react';
import { Image, ScrollView, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { landscapes } from '../../assets';

type Nav = NativeStackNavigationProp<RootStackParamList, 'Gallery'>;

export default function GalleryScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#000' }}
      contentContainerStyle={{ flexDirection: 'row', flexWrap: 'wrap' }}
    >
      {landscapes.map((source, index) => {
        const isWide = index % 5 === 0;
        const width = isWide ? '100%' : '50%';
        const height = isWide ? 240 : 160;

        return (
          <View key={index} style={{ width, height, padding: 1 }}>
            <MorphCardSource
              scaleMode="aspectFit"
              borderRadius={0}
              expandDuration={350}
              onPress={(sourceTag: number) =>
                navigation.navigate('GalleryDetail', { sourceTag })
              }
            >
              <Image
                source={source}
                style={{ width: '100%', height: '100%' }}
              />
            </MorphCardSource>
          </View>
        );
      })}
    </ScrollView>
  );
}
