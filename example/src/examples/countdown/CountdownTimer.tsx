import * as React from 'react';
import { Text, View } from 'react-native';
import { useCountdown } from './CountdownContext';

export default function CountdownTimer() {
  const count = useCountdown();

  return (
    <View
      style={{
        width: '100%',
        height: '100%',
        backgroundColor: '#1a1a2e',
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      <Text style={{ fontSize: 48, fontWeight: 'bold', color: '#e94560' }}>
        {count}
      </Text>
      <Text style={{ fontSize: 14, color: '#aaa', marginTop: 4 }}>
        seconds remaining
      </Text>
    </View>
  );
}
