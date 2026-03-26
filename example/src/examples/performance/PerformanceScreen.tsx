import * as React from 'react';
import { Image, FlatList, Text, View, Dimensions } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { landscapes } from '../../assets';

type Nav = NativeStackNavigationProp<RootStackParamList, 'Performance'>;

const SCREEN_WIDTH = Dimensions.get('window').width;
const COLUMNS = 3;
const ITEM_SIZE = (SCREEN_WIDTH - 4) / COLUMNS;

const data = Array.from({ length: 200 }, (_, i) => ({
  id: String(i),
  image: landscapes[i % landscapes.length],
}));

export default function PerformanceScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <FlatList
      data={data}
      numColumns={COLUMNS}
      style={{ flex: 1, backgroundColor: '#000' }}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => (
        <View style={{ width: ITEM_SIZE, height: ITEM_SIZE, padding: 1 }}>
          <MorphCardSource
            onPress={(sourceTag: number) =>
              navigation.navigate('PerformanceDetail', { sourceTag })
            }
          >
            <Image
              source={item.image}
              resizeMode="cover"
              style={{ width: '100%', height: '100%' }}
            />
          </MorphCardSource>
        </View>
      )}
      ListHeaderComponent={
        <View style={{ padding: 16, paddingBottom: 8 }}>
          <Text style={{ fontSize: 13, fontWeight: '600', color: '#888' }}>
            200 MORPHABLE CARDS IN A FLATLIST
          </Text>
        </View>
      }
    />
  );
}
