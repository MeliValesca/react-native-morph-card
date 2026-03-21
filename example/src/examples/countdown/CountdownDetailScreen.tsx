import * as React from 'react';
import { View, Pressable, Text } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { useCountdown } from './CountdownContext';

type Props = NativeStackScreenProps<RootStackParamList, 'CountdownDetail'>;

export default function CountdownDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });
  const { phase, round } = useCountdown();

  const exercises = [
    'Burpees',
    'Mountain Climbers',
    'Jump Squats',
    'High Knees',
  ];
  const currentExercise = exercises[(round - 1) % exercises.length];
  const nextExercise = exercises[round % exercises.length];

  return (
    <View style={{ flex: 1, backgroundColor: '#F2F2F7' }}>
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={'100%'}
        height={320}
        borderRadius={0}
        contentCentered
      />
      <Pressable
        onPress={dismiss}
        style={{
          position: 'absolute',
          top: 54,
          right: 20,
          backgroundColor: 'rgba(0,0,0,0.06)',
          borderRadius: 16,
          width: 32,
          height: 32,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Text style={{ fontSize: 16, color: '#333', fontWeight: '600' }}>
          ✕
        </Text>
      </Pressable>
      <View style={{ padding: 24 }}>
        <Text style={{ fontSize: 24, fontWeight: '700', color: '#1a1a1a' }}>
          {phase === 'work' ? currentExercise : 'Rest'}
        </Text>
        <Text
          style={{
            fontSize: 14,
            color: '#8E8E93',
            marginTop: 6,
            lineHeight: 20,
          }}
        >
          {phase === 'work'
            ? 'Give it everything — this timer is a live React component, not a static image.'
            : 'Breathe. Next up: ' + nextExercise}
        </Text>

        <View style={{ marginTop: 24 }}>
          <View
            style={{
              flexDirection: 'row',
              justifyContent: 'space-between',
              marginBottom: 6,
            }}
          >
            <Text style={{ fontSize: 12, fontWeight: '600', color: '#8E8E93' }}>
              PROGRESS
            </Text>
            <Text style={{ fontSize: 12, color: '#8E8E93' }}>
              Round {round} / 4
            </Text>
          </View>
          <View style={{ flexDirection: 'row', gap: 6 }}>
            {[1, 2, 3, 4].map((r) => (
              <View
                key={r}
                style={{
                  flex: 1,
                  height: 6,
                  borderRadius: 3,
                  backgroundColor:
                    r <= round
                      ? phase === 'rest'
                        ? '#34C759'
                        : '#FF3B30'
                      : '#E5E5EA',
                }}
              />
            ))}
          </View>
        </View>

        <View
          style={{
            backgroundColor: '#fff',
            borderRadius: 14,
            padding: 16,
            marginTop: 24,
            shadowColor: '#000',
            shadowOffset: { width: 0, height: 1 },
            shadowOpacity: 0.04,
            shadowRadius: 4,
            elevation: 1,
          }}
        >
          <Text
            style={{
              fontSize: 13,
              fontWeight: '600',
              color: '#8E8E93',
              marginBottom: 10,
            }}
          >
            WORKOUT PLAN
          </Text>
          {exercises.map((ex, i) => (
            <View
              key={ex}
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                paddingVertical: 8,
                borderTopWidth: i > 0 ? 1 : 0,
                borderTopColor: '#F2F2F7',
              }}
            >
              <View
                style={{
                  width: 24,
                  height: 24,
                  borderRadius: 12,
                  backgroundColor:
                    i + 1 === round
                      ? phase === 'rest'
                        ? '#34C759'
                        : '#FF3B30'
                      : '#E5E5EA',
                  justifyContent: 'center',
                  alignItems: 'center',
                  marginRight: 12,
                }}
              >
                <Text
                  style={{
                    fontSize: 11,
                    fontWeight: '700',
                    color: i + 1 === round ? '#fff' : '#8E8E93',
                  }}
                >
                  {i + 1}
                </Text>
              </View>
              <Text
                style={{
                  fontSize: 15,
                  color: i + 1 === round ? '#1a1a1a' : '#8E8E93',
                  fontWeight: i + 1 === round ? '600' : '400',
                }}
              >
                {ex}
              </Text>
              <Text
                style={{ fontSize: 12, color: '#C7C7CC', marginLeft: 'auto' }}
              >
                30s
              </Text>
            </View>
          ))}
        </View>
      </View>
    </View>
  );
}
