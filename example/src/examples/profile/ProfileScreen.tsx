import * as React from 'react';
import { Image, ScrollView, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MorphCardSource } from 'react-native-morph-card';
import type { RootStackParamList } from '../../App';
import { avatars } from '../../assets';

type Nav = NativeStackNavigationProp<RootStackParamList, 'Profile'>;

const users = [
  {
    name: 'Emma Rodriguez',
    handle: '@emmarodz',
    avatarIndex: 0,
    bio: 'Product designer at Figma. Passionate about accessible design systems and motion design. Previously at Stripe and Google.',
    followers: '12.4k',
    following: '847',
    posts: '234',
    color: '#FF6B6B',
  },
  {
    name: 'James Chen',
    handle: '@jameschen',
    avatarIndex: 1,
    bio: 'iOS engineer & open source contributor. Building tools that make developers happier. Coffee enthusiast.',
    followers: '8.2k',
    following: '512',
    posts: '167',
    color: '#4ECDC4',
  },
  {
    name: 'Sofia Andersson',
    handle: '@sofiaand',
    avatarIndex: 2,
    bio: 'Photographer & travel blogger. Capturing stories one frame at a time. Based in Stockholm.',
    followers: '45.1k',
    following: '1.2k',
    posts: '892',
    color: '#A78BFA',
  },
  {
    name: 'Marcus Williams',
    handle: '@marcusw',
    avatarIndex: 3,
    bio: 'Startup founder & angel investor. Building the future of remote work. Runner, reader, dad of 2.',
    followers: '22.7k',
    following: '934',
    posts: '445',
    color: '#F59E0B',
  },
];

export default function ProfileScreen() {
  const navigation = useNavigation<Nav>();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: '#f2f2f7' }}
      contentContainerStyle={{ padding: 20, paddingTop: 16 }}
    >
      {users.map((user) => (
        <View key={user.handle} style={{ marginBottom: 12 }}>
          <MorphCardSource
            backgroundColor="#fff"
            borderRadius={20}
            expandDuration={400}
            presentation="push"
            onPress={(sourceTag) =>
              navigation.navigate('ProfileDetail', { sourceTag, user })
            }
          >
            <View
              style={{
                padding: 20,
                flexDirection: 'row',
                alignItems: 'center',
              }}
            >
              <Image
                source={avatars[user.avatarIndex]}
                style={{
                  width: 56,
                  height: 56,
                  borderRadius: 28,
                  marginRight: 16,
                }}
              />
              <View style={{ flex: 1 }}>
                <Text
                  style={{ fontSize: 17, fontWeight: '600', color: '#1a1a1a' }}
                >
                  {user.name}
                </Text>
                <Text style={{ fontSize: 14, color: '#8e8e93', marginTop: 2 }}>
                  {user.handle}
                </Text>
                <Text
                  style={{
                    fontSize: 13,
                    color: '#636366',
                    marginTop: 6,
                    lineHeight: 18,
                  }}
                  numberOfLines={2}
                >
                  {user.bio}
                </Text>
              </View>
            </View>
          </MorphCardSource>
        </View>
      ))}
    </ScrollView>
  );
}
