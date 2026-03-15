import * as React from 'react';
import { Image, Pressable, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource, getViewTag } from 'react-native-morph-card';
import type { RootStackParamList } from './App';

type Nav = NativeStackNavigationProp<RootStackParamList, 'Home'>;

export default function HomeScreen() {
  const navigation = useNavigation<Nav>();
  const blueCardRef = React.useRef<any>(null);
  const catCardRef = React.useRef<any>(null);

  return (
    <View
      style={{
        flex: 1,
        padding: 24,
        paddingTop: 120,
        backgroundColor: '#f5f5f5',
      }}
    >
      <Text
        style={{
          fontSize: 28,
          fontWeight: '700',
          marginBottom: 8,
          color: '#1a1a1a',
        }}
      >
        Morph Card
      </Text>
      <Text
        style={{
          fontSize: 15,
          color: '#888',
          marginBottom: 32,
        }}
      >
        Tap a card to see it morph into a detail screen.
      </Text>

      {/* Blue card — will morph into a full-width header */}
      <Pressable
        onPress={() => {
          const tag = getViewTag(blueCardRef);
          if (tag != null)
            navigation.navigate('BlueDetail', { sourceTag: tag });
        }}
      >
        <MorphCardSource
          ref={blueCardRef}
          duration={500}
          backgroundColor="#007AFF"
          borderRadius={16}
          shadowColor="#000"
          shadowOffset={{ width: 0, height: 4 }}
          shadowOpacity={0.2}
          shadowRadius={12}
          elevation={6}
          height={80}
        >
          <View
            style={{
              justifyContent: 'flex-end',
              padding: 16,
              height: 80,
            }}
          >
            <Text
              style={{
                fontSize: 13,
                fontWeight: '500',
                color: 'rgba(255,255,255,0.7)',
              }}
            >
              FEATURED
            </Text>
            <Text
              style={{
                fontSize: 22,
                fontWeight: '700',
                color: '#fff',
                marginTop: 4,
              }}
            >
              Today's Highlight
            </Text>
          </View>
        </MorphCardSource>
      </Pressable>

      {/* Cat card — will morph into an inline image beside text */}
      <Pressable
        onPress={() => {
          const tag = getViewTag(catCardRef);
          if (tag != null) navigation.navigate('CatDetail', { sourceTag: tag });
        }}
        style={{ marginTop: 20 }}
      >
        <View
          style={{
            width: 140,
            borderRadius: 16,
            backgroundColor: 'blue',
            shadowColor: '#000',
            shadowOffset: { width: 0, height: 4 },
            shadowOpacity: 0.15,
            shadowRadius: 10,
            elevation: 4,
          }}
        >
          {/* Only the image morphs — not the whole card */}
          <MorphCardSource
            ref={catCardRef}
            duration={500}
            width={140}
            height={100}
            borderRadius={10}
          >
            <Image
              source={{
                uri: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Cat03.jpg/400px-Cat03.jpg',
              }}
              style={{ width: '100%', height: '100%' }}
            />
          </MorphCardSource>
          <Text
            style={{
              fontSize: 13,
              fontWeight: '600',
              color: '#1a1a1a',
              textAlign: 'center',
              paddingVertical: 8,
            }}
          >
            Mr. Whiskers
          </Text>
        </View>
      </Pressable>
    </View>
  );
}
