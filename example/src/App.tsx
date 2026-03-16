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
import ScaleModesScreen from './examples/scalemodes/ScaleModesScreen';
import ScaleModesDetailScreen from './examples/scalemodes/ScaleModesDetailScreen';
import MixedScreen from './examples/mixed/MixedScreen';
import MixedDetailScreen from './examples/mixed/MixedDetailScreen';
import PerformanceScreen from './examples/performance/PerformanceScreen';
import PerformanceDetailScreen from './examples/performance/PerformanceDetailScreen';

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
  ScaleModes: undefined;
  ScaleModesDetail: { sourceTag: number; mode: string };
  Mixed: undefined;
  MixedDetail: { sourceTag: number; card: { id: string; type: string; title: string; subtitle: string; bg?: string } };
  Performance: undefined;
  PerformanceDetail: { sourceTag: number };
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
        <Stack.Screen
          name="ScaleModes"
          component={ScaleModesScreen}
          options={{ title: 'Scale Modes' }}
        />
        <Stack.Screen
          name="ScaleModesDetail"
          component={ScaleModesDetailScreen}
          options={morphModal}
        />
        <Stack.Screen
          name="Mixed"
          component={MixedScreen}
          options={{ title: 'Mixed Modes' }}
        />
        <Stack.Screen
          name="MixedDetail"
          component={MixedDetailScreen}
          options={morphModal}
        />
        <Stack.Screen
          name="Performance"
          component={PerformanceScreen}
          options={{ title: 'Performance' }}
        />
        <Stack.Screen
          name="PerformanceDetail"
          component={PerformanceDetailScreen}
          options={morphModal}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
