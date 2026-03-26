import * as React from 'react';
import { View, Text, ScrollView } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import CountdownTimer from './CountdownTimer';

type Props = NativeStackScreenProps<RootStackParamList, 'Countdown'>;

const stats = [
  { label: 'Workouts', value: '12' },
  { label: 'Calories', value: '4,230' },
  { label: 'Minutes', value: '186' },
];

const upcomingWorkouts = [
  { name: 'Upper Body HIIT', duration: '25 min', day: 'Tomorrow' },
  { name: 'Core Blast', duration: '15 min', day: 'Wednesday' },
  { name: 'Full Body Burn', duration: '30 min', day: 'Friday' },
];

export default function CountdownScreen({ navigation }: Props) {
  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#F2F2F7' }}
      contentContainerStyle={{ padding: 20 }}
    >
      <Text
        style={{
          fontSize: 13,
          fontWeight: '600',
          color: '#8E8E93',
          letterSpacing: 0.5,
          marginBottom: 8,
        }}
      >
        THIS WEEK
      </Text>
      <View style={{ flexDirection: 'row', gap: 10, marginBottom: 24 }}>
        {stats.map((s) => (
          <View
            key={s.label}
            style={{
              flex: 1,
              backgroundColor: '#fff',
              borderRadius: 14,
              padding: 14,
              shadowColor: '#000',
              shadowOffset: { width: 0, height: 1 },
              shadowOpacity: 0.04,
              shadowRadius: 4,
              elevation: 1,
            }}
          >
            <Text style={{ fontSize: 22, fontWeight: '700', color: '#1a1a1a' }}>
              {s.value}
            </Text>
            <Text style={{ fontSize: 12, color: '#8E8E93', marginTop: 2 }}>
              {s.label}
            </Text>
          </View>
        ))}
      </View>

      <Text
        style={{
          fontSize: 13,
          fontWeight: '600',
          color: '#8E8E93',
          letterSpacing: 0.5,
          marginBottom: 8,
        }}
      >
        ACTIVE WORKOUT
      </Text>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
        <View
          style={{
            flex: 1,
            borderRadius: 18,
            borderWidth: 1,
            borderColor: '#E5E5EA',
            overflow: 'hidden',
          }}
        >
          <MorphCardSource
            backgroundColor="#fff"
            borderRadius={20}
            onPress={(sourceTag: number) =>
              navigation.navigate('CountdownDetail', { sourceTag })
            }
          >
            <CountdownTimer />
          </MorphCardSource>
        </View>
        <MorphCardSource
          width={48}
          height={48}
          borderRadius={24}
          backgroundColor="white"
          rotationEndAngle={45}
          duration={300}
          onPress={(sourceTag: number) =>
            navigation.navigate('PlusDetail', { sourceTag })
          }
        >
          <View
            style={{
              width: 48,
              height: 48,
              justifyContent: 'center',
              alignItems: 'center',
            }}
          >
            <Text
              style={{
                fontSize: 28,
                fontWeight: '300',
                color: '#000',
                marginTop: -2,
              }}
            >
              +
            </Text>
          </View>
        </MorphCardSource>
      </View>

      <Text
        style={{
          fontSize: 13,
          fontWeight: '600',
          color: '#8E8E93',
          letterSpacing: 0.5,
          marginTop: 24,
          marginBottom: 8,
        }}
      >
        UPCOMING
      </Text>
      {upcomingWorkouts.map((w, i) => (
        <View
          key={i}
          style={{
            backgroundColor: '#fff',
            borderRadius: 14,
            padding: 16,
            marginBottom: 8,
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
              width: 40,
              height: 40,
              borderRadius: 10,
              backgroundColor: '#F2F2F7',
              justifyContent: 'center',
              alignItems: 'center',
              marginRight: 12,
            }}
          >
            <Text style={{ fontSize: 18 }}>
              {i === 0 ? '💪' : i === 1 ? '🔥' : '⚡'}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 15, fontWeight: '600', color: '#1a1a1a' }}>
              {w.name}
            </Text>
            <Text style={{ fontSize: 12, color: '#8E8E93', marginTop: 2 }}>
              {w.day} · {w.duration}
            </Text>
          </View>
          <Text style={{ fontSize: 18, color: '#C7C7CC' }}>›</Text>
        </View>
      ))}
    </ScrollView>
  );
}
