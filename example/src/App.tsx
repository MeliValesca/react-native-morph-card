import * as React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import ExampleListScreen from './ExampleListScreen';
import AppStoreScreen from './examples/appstore/AppStoreScreen';
import AppStoreDetailScreen from './examples/appstore/AppStoreDetailScreen';
import MusicScreen from './examples/music/MusicScreen';
import MusicDetailScreen from './examples/music/MusicDetailScreen';
import GalleryScreen from './examples/gallery/GalleryScreen';
import GalleryDetailScreen from './examples/gallery/GalleryDetailScreen';
import ProfileScreen from './examples/profile/ProfileScreen';
import ProfileDetailScreen from './examples/profile/ProfileDetailScreen';

export type RootStackParamList = {
  ExampleList: undefined;
  AppStore: undefined;
  AppStoreDetail: { sourceTag: number };
  Music: undefined;
  MusicDetail: { sourceTag: number; album: { title: string; artist: string } };
  Gallery: undefined;
  GalleryDetail: { sourceTag: number };
  Profile: undefined;
  ProfileDetail: { sourceTag: number; user: { name: string; handle: string; avatarIndex: number; bio: string; followers: string; following: string; posts: string } };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

const morphModal = {
  presentation: 'transparentModal' as const,
  animation: 'none' as const,
  headerShown: false,
};

export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen
          name="ExampleList"
          component={ExampleListScreen}
          options={{ title: 'Morph Card Examples', headerLargeTitle: true }}
        />
        <Stack.Screen
          name="AppStore"
          component={AppStoreScreen}
          options={{ title: 'App Store Today' }}
        />
        <Stack.Screen
          name="AppStoreDetail"
          component={AppStoreDetailScreen}
          options={morphModal}
        />
        <Stack.Screen
          name="Music"
          component={MusicScreen}
          options={{ title: 'Music Player' }}
        />
        <Stack.Screen
          name="MusicDetail"
          component={MusicDetailScreen}
          options={morphModal}
        />
        <Stack.Screen
          name="Gallery"
          component={GalleryScreen}
          options={{ title: 'Photo Gallery' }}
        />
        <Stack.Screen
          name="GalleryDetail"
          component={GalleryDetailScreen}
          options={morphModal}
        />
        <Stack.Screen
          name="Profile"
          component={ProfileScreen}
          options={{ title: 'Profiles' }}
        />
        <Stack.Screen
          name="ProfileDetail"
          component={ProfileDetailScreen}
          options={morphModal}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
