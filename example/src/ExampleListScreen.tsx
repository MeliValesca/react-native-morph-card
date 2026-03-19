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
    tags: ['wrapper mode', 'backgroundColor', 'contentCentered', 'borderRadius 0 target', 'full-width expand'],
    color: '#007AFF',
  },
  {
    key: 'Music' as const,
    title: 'Music Player',
    subtitle: 'Circular album art morphing into a player screen',
    tags: ['no-wrapper mode', 'circular borderRadius', 'borderRadius morph', 'fixed target size'],
    color: '#AF52DE',
  },
  {
    key: 'Gallery' as const,
    title: 'Photo Gallery',
    subtitle: 'Grid photos expanding to fullscreen viewer',
    tags: ['no-wrapper mode', 'resizeMode', 'grid layout', 'variable card sizes', 'custom duration'],
    color: '#FF9500',
  },
  {
    key: 'Profile' as const,
    title: 'Profile Cards',
    subtitle: 'User cards expanding into full profiles',
    tags: ['wrapper mode', 'backgroundColor', 'contentCentered', 'target inside ScrollView', 'multiple cards'],
    color: '#34C759',
  },
  {
    key: 'ResizeModes' as const,
    title: 'Resize Modes',
    subtitle: 'Compare aspectFill, aspectFit, and stretch',
    tags: ['no-wrapper mode', 'resizeMode comparison', 'cover', 'contain', 'stretch'],
    color: '#FF2D55',
  },
  {
    key: 'Mixed' as const,
    title: 'Mixed Modes',
    subtitle: 'Wrapper and no-wrapper cards in the same list',
    tags: ['wrapper + no-wrapper', 'mixed backgroundColor', 'circular + rect', 'custom duration'],
    color: '#5856D6',
  },
  {
    key: 'Performance' as const,
    title: 'Performance',
    subtitle: '200 cards in a FlatList — stress test',
    tags: ['FlatList', '200 items', 'view recycling', 'scroll performance'],
    color: '#FF3B30',
  },
  {
    key: 'Countdown' as const,
    title: 'Live Countdown',
    subtitle: 'Timer keeps ticking after expand — proves live children',
    tags: ['live children', 'observable state', 'no bitmap'],
    color: '#E94560',
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
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 8, gap: 4 }}>
                {ex.tags.map((tag) => (
                  <View
                    key={tag}
                    style={{
                      backgroundColor: ex.color + '18',
                      borderRadius: 6,
                      paddingHorizontal: 8,
                      paddingVertical: 3,
                    }}
                  >
                    <Text style={{ fontSize: 11, color: ex.color, fontWeight: '500' }}>
                      {tag}
                    </Text>
                  </View>
                ))}
              </View>
            </View>
            <Text style={{ fontSize: 20, color: '#c7c7cc' }}>›</Text>
          </View>
        </Pressable>
      ))}
    </ScrollView>
  );
}
