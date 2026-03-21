import * as React from 'react';
import { Text, View } from 'react-native';
import { useCountdown } from './CountdownContext';

export default function CountdownTimer() {
  const { seconds, phase, round } = useCountdown();

  const isRest = phase === 'rest';
  const accent = isRest ? '#34C759' : '#FF3B30';
  const label = isRest ? 'REST' : 'WORK';

  const exercises = ['Burpees', 'Mountain Climbers', 'Jump Squats', 'High Knees'];
  const currentExercise = isRest ? 'Rest' : exercises[(round - 1) % exercises.length];
  const nextExercise = exercises[round % exercises.length];

  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  const display = `${mins}:${secs.toString().padStart(2, '0')}`;

  const total = isRest ? 10 : 30;
  const progress = ((total - seconds) / total) * 100;

  return (
    <View
      style={{
        width: '100%',
        height: 160,
        backgroundColor: '#fff',
        flexDirection: 'row',
        padding: 20,
      }}
    >
      <View style={{ flex: 1, justifyContent: 'center' }}>
        <View
          style={{
            backgroundColor: isRest ? '#E8F8ED' : '#FFEBEE',
            paddingHorizontal: 10,
            paddingVertical: 3,
            borderRadius: 8,
            alignSelf: 'flex-start',
            marginBottom: 6,
          }}
        >
          <Text style={{ fontSize: 11, fontWeight: '700', color: accent, letterSpacing: 1 }}>
            {label}
          </Text>
        </View>
        <Text style={{ fontSize: 38, fontWeight: '200', color: '#1a1a1a', fontVariant: ['tabular-nums'] }}>
          {display}
        </Text>
        <Text style={{ fontSize: 14, fontWeight: '600', color: '#1a1a1a', marginTop: 4 }}>
          {currentExercise}
        </Text>
        <Text style={{ fontSize: 11, color: '#8E8E93', marginTop: 2 }}>
          Round {round}/4 · Next: {nextExercise}
        </Text>
      </View>
      <View style={{ width: 80, justifyContent: 'center', alignItems: 'center' }}>
        <View
          style={{
            width: 64,
            height: 64,
            borderRadius: 32,
            borderWidth: 4,
            borderColor: '#E5E5EA',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <View
            style={{
              position: 'absolute',
              width: 64,
              height: 64,
              borderRadius: 32,
              borderWidth: 4,
              borderColor: accent,
              borderTopColor: progress > 25 ? accent : 'transparent',
              borderRightColor: progress > 50 ? accent : 'transparent',
              borderBottomColor: progress > 75 ? accent : 'transparent',
              borderLeftColor: 'transparent',
              transform: [{ rotate: '-90deg' }],
            }}
          />
          <Text style={{ fontSize: 16, fontWeight: '700', color: '#1a1a1a' }}>
            {seconds}
          </Text>
          <Text style={{ fontSize: 9, color: '#8E8E93' }}>sec</Text>
        </View>
        <View style={{ flexDirection: 'row', marginTop: 10, gap: 3 }}>
          {[1, 2, 3, 4].map((r) => (
            <View
              key={r}
              style={{
                width: 12,
                height: 3,
                borderRadius: 2,
                backgroundColor: r <= round ? accent : '#E5E5EA',
              }}
            />
          ))}
        </View>
      </View>
    </View>
  );
}
