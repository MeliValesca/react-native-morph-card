import * as React from 'react';
import { View, Text } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import CountdownTimer from './CountdownTimer';

type Props = NativeStackScreenProps<RootStackParamList, 'Countdown'>;

export default function CountdownScreen({ navigation }: Props) {
  return (
    <View
      style={{
        flex: 1,
        backgroundColor: '#0f0f23',
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      <Text style={{ color: '#fff', fontSize: 18, marginBottom: 20 }}>
        Tap the timer — it should keep ticking after expand
      </Text>
      <MorphCardSource
        width={200}
        height={200}
        borderRadius={16}
        backgroundColor="#1a1a2e"
        duration={350}
        onPress={(sourceTag: number) =>
          navigation.navigate('CountdownDetail', { sourceTag })
        }
      >
        <CountdownTimer />
      </MorphCardSource>
    </View>
  );
}
