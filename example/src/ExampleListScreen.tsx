import * as React from 'react';
import { Text, View, Pressable, ScrollView } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from './App';

type Nav = NativeStackNavigationProp<RootStackParamList, 'ExampleList'>;

const examples = [
  {
    key: 'AppStore' as const,
    title: 'App Store Today',
    subtitle: 'Featured article card expanding into a full story',
    color: '#007AFF',
  },
  {
    key: 'Music' as const,
    title: 'Music Player',
    subtitle: 'Album art morphing into a now-playing screen',
    color: '#AF52DE',
  },
  {
    key: 'Gallery' as const,
    title: 'Photo Gallery',
    subtitle: 'Grid photos expanding to fullscreen viewer',
    color: '#FF9500',
  },
  {
    key: 'Profile' as const,
    title: 'Profile Cards',
    subtitle: 'User cards expanding into full profiles',
    color: '#34C759',
  },
];

export default function ExampleListScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#f2f2f7' }}
      contentContainerStyle={{ padding: 20, paddingTop: 16 }}
      contentInsetAdjustmentBehavior="automatic"
    >
      {examples.map((ex) => (
        <Pressable
          key={ex.key}
          onPress={() => navigation.navigate(ex.key)}
          style={({ pressed }) => ({
            backgroundColor: pressed ? '#e5e5ea' : '#fff',
            borderRadius: 16,
            padding: 20,
            marginBottom: 12,
            shadowColor: '#000',
            shadowOffset: { width: 0, height: 2 },
            shadowOpacity: 0.06,
            shadowRadius: 8,
            elevation: 2,
          })}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <View
              style={{
                width: 44,
                height: 44,
                borderRadius: 12,
                backgroundColor: ex.color,
                marginRight: 16,
              }}
            />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 17, fontWeight: '600', color: '#1a1a1a' }}>
                {ex.title}
              </Text>
              <Text
                style={{
                  fontSize: 13,
                  color: '#8e8e93',
                  marginTop: 2,
                  lineHeight: 18,
                }}
              >
                {ex.subtitle}
              </Text>
            </View>
            <Text style={{ fontSize: 20, color: '#c7c7cc' }}>›</Text>
          </View>
        </Pressable>
      ))}
    </ScrollView>
  );
}
