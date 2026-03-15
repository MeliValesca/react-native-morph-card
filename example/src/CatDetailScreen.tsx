import * as React from 'react';
import { Text, View, ScrollView } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from './App';

type Props = NativeStackScreenProps<RootStackParamList, 'CatDetail'>;

export default function CatDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View style={{ flex: 1, backgroundColor: '#fff' }}>
      <ScrollView style={{ flex: 1 }}>
        <View style={{ padding: 24, paddingTop: 80 }}>
          <Text
            style={{
              fontSize: 24,
              fontWeight: '700',
              color: '#1a1a1a',
              marginBottom: 20,
            }}
          >
            Mr. Whiskers
          </Text>

          <View style={{ flexDirection: 'row', marginBottom: 24 }}>
            {/* Just a position/size marker — source card snapshot animates here */}
            <MorphCardTarget
              sourceTag={route.params.sourceTag}
              width={160}
              height={120}
              borderRadius={16}
              shadowColor="#000"
              shadowOffset={{ width: 0, height: 4 }}
              shadowOpacity={0.2}
              shadowRadius={12}
              elevation={6}
            />

            <View style={{ flex: 1, marginLeft: 16, justifyContent: 'center' }}>
              <Text
                style={{
                  fontSize: 14,
                  fontWeight: '600',
                  color: '#007AFF',
                  marginBottom: 4,
                }}
              >
                Domestic Shorthair
              </Text>
              <Text style={{ fontSize: 13, color: '#666', lineHeight: 20 }}>
                Age: 3 years{'\n'}
                Weight: 4.5 kg{'\n'}
                Temperament: Playful, curious
              </Text>
            </View>
          </View>

          <Text
            style={{
              fontSize: 16,
              color: '#333',
              lineHeight: 24,
              marginBottom: 16,
            }}
          >
            Mr. Whiskers is a friendly domestic shorthair who loves chasing
            laser pointers and napping in sunbeams. He's been with his family
            since he was a kitten and rules the household with a velvet paw.
          </Text>
          <Text
            style={{
              fontSize: 16,
              color: '#333',
              lineHeight: 24,
              marginBottom: 24,
            }}
          >
            His favorite spot is the windowsill where he can watch birds. He's
            also an accomplished cardboard box inspector and paper bag explorer.
          </Text>

          <Text
            onPress={dismiss}
            style={{
              fontSize: 16,
              fontWeight: '600',
              color: '#007AFF',
            }}
          >
            ← Back
          </Text>
        </View>
      </ScrollView>
    </View>
  );
}
