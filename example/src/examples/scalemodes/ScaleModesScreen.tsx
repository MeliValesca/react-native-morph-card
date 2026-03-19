import * as React from 'react';
import { Image, ScrollView, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { ResizeMode } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { landscapes } from '../../assets';

type Nav = NativeStackNavigationProp<RootStackParamList, 'ScaleModes'>;

const modes: { mode: ResizeMode; label: string; description: string }[] = [
  { mode: 'cover', label: 'Cover', description: 'Fills target, crops excess' },
  { mode: 'contain', label: 'Contain', description: 'Fits inside target, may letterbox' },
  { mode: 'stretch', label: 'Stretch', description: 'Stretches to fill exactly' },
];

export default function ScaleModesScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#1a1a1a' }}
      contentContainerStyle={{ padding: 20 }}
    >
      {modes.map((item, index) => (
        <View key={item.mode} style={{ marginBottom: 32 }}>
          <Text style={{ fontSize: 18, fontWeight: '700', color: '#fff', marginBottom: 4 }}>
            {item.label}
          </Text>
          <Text style={{ fontSize: 13, color: '#888', marginBottom: 12 }}>
            {item.description}
          </Text>
          <MorphCardSource
            expandDuration={350}
            resizeMode={item.mode}
            borderRadius={16}
            height={180}
            onPress={(sourceTag: number) =>
              navigation.navigate('ScaleModesDetail', { sourceTag, mode: item.mode })
            }
          >
            <Image
              source={landscapes[index % landscapes.length]}
              resizeMode="cover"
              style={{ width: '100%', height: '100%' }}
            />
          </MorphCardSource>
        </View>
      ))}
    </ScrollView>
  );
}
