import * as React from 'react';
import { Image, Text, View, ScrollView, Pressable } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MorphCardTarget, useMorphTarget } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { avatars } from '../../assets';

type Props = NativeStackScreenProps<RootStackParamList, 'ProfileDetail'>;

export default function ProfileDetailScreen({ route, navigation }: Props) {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  const { user } = route.params;

  return (
    <View style={{ flex: 1, backgroundColor: '#f2f2f7' }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 40 }}>
        {/* Card target — expands from the profile card */}
        <MorphCardTarget
          sourceTag={route.params.sourceTag}
          width={'100%'}
          height={280}
          borderRadius={0}
          contentCentered
        />

        {/* Profile content overlaid on expanded card area */}
        <View style={{ alignItems: 'center' }}>
          <Text
            style={{
              fontSize: 26,
              fontWeight: '700',
              color: '#1a1a1a',
              marginTop: 12,
            }}
          >
            {user.name}
          </Text>
          <Text style={{ fontSize: 16, color: '#8e8e93', marginTop: 2 }}>
            {user.handle}
          </Text>
        </View>

        {/* Stats */}
        <View
          style={{
            flexDirection: 'row',
            justifyContent: 'center',
            marginTop: 24,
            gap: 40,
          }}
        >
          {[
            { label: 'Posts', value: user.posts },
            { label: 'Followers', value: user.followers },
            { label: 'Following', value: user.following },
          ].map((stat) => (
            <View key={stat.label} style={{ alignItems: 'center' }}>
              <Text
                style={{ fontSize: 20, fontWeight: '700', color: '#1a1a1a' }}
              >
                {stat.value}
              </Text>
              <Text style={{ fontSize: 13, color: '#8e8e93', marginTop: 2 }}>
                {stat.label}
              </Text>
            </View>
          ))}
        </View>

        {/* Bio */}
        <View style={{ paddingHorizontal: 24, marginTop: 24 }}>
          <Text
            style={{
              fontSize: 16,
              color: '#333',
              lineHeight: 24,
              textAlign: 'center',
            }}
          >
            {user.bio}
          </Text>
        </View>

        {/* Actions */}
        <View
          style={{
            flexDirection: 'row',
            paddingHorizontal: 24,
            marginTop: 24,
            gap: 12,
          }}
        >
          <Pressable
            style={{
              flex: 1,
              backgroundColor: '#007AFF',
              borderRadius: 14,
              paddingVertical: 14,
              alignItems: 'center',
            }}
          >
            <Text style={{ fontSize: 16, fontWeight: '600', color: '#fff' }}>
              Follow
            </Text>
          </Pressable>
          <Pressable
            style={{
              flex: 1,
              backgroundColor: '#e5e5ea',
              borderRadius: 14,
              paddingVertical: 14,
              alignItems: 'center',
            }}
          >
            <Text style={{ fontSize: 16, fontWeight: '600', color: '#1a1a1a' }}>
              Message
            </Text>
          </Pressable>
        </View>

        {/* Recent posts placeholder */}
        <View style={{ paddingHorizontal: 24, marginTop: 32 }}>
          <Text
            style={{
              fontSize: 18,
              fontWeight: '700',
              color: '#1a1a1a',
              marginBottom: 16,
            }}
          >
            Recent Posts
          </Text>
          {[1, 2, 3].map((i) => (
            <View
              key={i}
              style={{
                backgroundColor: '#fff',
                borderRadius: 16,
                padding: 16,
                marginBottom: 12,
              }}
            >
              <View
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  marginBottom: 12,
                }}
              >
                <Image
                  source={avatars[user.avatarIndex]}
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: 16,
                    marginRight: 10,
                  }}
                />
                <View>
                  <Text
                    style={{
                      fontSize: 14,
                      fontWeight: '600',
                      color: '#1a1a1a',
                    }}
                  >
                    {user.name}
                  </Text>
                  <Text style={{ fontSize: 11, color: '#8e8e93' }}>
                    {i}h ago
                  </Text>
                </View>
              </View>
              <View
                style={{
                  height: 120,
                  backgroundColor: '#f2f2f7',
                  borderRadius: 12,
                }}
              />
            </View>
          ))}
        </View>

        <Pressable
          onPress={dismiss}
          style={{
            backgroundColor: '#e5e5ea',
            borderRadius: 14,
            paddingVertical: 16,
            alignItems: 'center',
            marginHorizontal: 24,
            marginTop: 24,
          }}
        >
          <Text style={{ fontSize: 17, fontWeight: '600', color: '#1a1a1a' }}>
            Close
          </Text>
        </Pressable>
        <Pressable
          onPress={dismiss}
          style={{
            position: 'absolute',
            top: 60,
            right: 20,
            backgroundColor: 'rgba(255,255,255,0.2)',
            borderRadius: 20,
            width: 40,
            height: 40,
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 10,
          }}
        >
          <Text style={{ fontSize: 18, color: '#000', fontWeight: '600' }}>
            ✕
          </Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}
