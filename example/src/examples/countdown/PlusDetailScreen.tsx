import * as React from 'react';
import { View, Pressable, Text, ScrollView } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';

type Props = NativeStackScreenProps<RootStackParamList, 'PlusDetail'>;

const actions = [
  { icon: '🏃', label: 'Start Workout', desc: 'Begin a new HIIT session' },
  { icon: '📊', label: 'View Stats', desc: 'Check your weekly progress' },
  { icon: '🎯', label: 'Set Goals', desc: 'Update your fitness targets' },
  { icon: '📅', label: 'Schedule', desc: 'Plan upcoming workouts' },
  { icon: '👥', label: 'Friends', desc: 'See what your friends are doing' },
  { icon: '⚙️', label: 'Settings', desc: 'Customize your experience' },
];

export default function PlusDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View style={{ flex: 1, backgroundColor: '#F2F2F7' }}>
      <View
        style={{
          paddingTop: 60,
          paddingHorizontal: 20,
          paddingBottom: 16,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 14,
        }}
      >
        <Pressable onPress={dismiss}>
          <MorphCardTarget
            sourceTag={route.params.sourceTag}
            width={48}
            height={48}
            borderRadius={24}
          />
        </Pressable>
        <Text style={{ fontSize: 28, fontWeight: '700', color: '#1a1a1a' }}>
          Quick Actions
        </Text>
      </View>
      <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 8 }}>
        {actions.map((a, i) => (
          <Pressable
            key={i}
            style={{
              backgroundColor: '#fff',
              borderRadius: 16,
              padding: 18,
              marginBottom: 10,
              flexDirection: 'row',
              alignItems: 'center',
              shadowColor: '#000',
              shadowOffset: { width: 0, height: 1 },
              shadowOpacity: 0.04,
              shadowRadius: 4,
              elevation: 1,
            }}
          >
            <View
              style={{
                width: 44,
                height: 44,
                borderRadius: 12,
                backgroundColor: '#F2F2F7',
                justifyContent: 'center',
                alignItems: 'center',
                marginRight: 14,
              }}
            >
              <Text style={{ fontSize: 20 }}>{a.icon}</Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text
                style={{ fontSize: 16, fontWeight: '600', color: '#1a1a1a' }}
              >
                {a.label}
              </Text>
              <Text style={{ fontSize: 13, color: '#8E8E93', marginTop: 2 }}>
                {a.desc}
              </Text>
            </View>
            <Text style={{ fontSize: 18, color: '#C7C7CC' }}>›</Text>
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
}
