import * as React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import HomeScreen from './HomeScreen';
import BlueDetailScreen from './BlueDetailScreen';
import CatDetailScreen from './CatDetailScreen';

export type RootStackParamList = {
  Home: undefined;
  BlueDetail: { sourceTag: number };
  CatDetail: { sourceTag: number };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

const modalOptions = {
  presentation: 'transparentModal' as const,
  animation: 'none' as const,
  headerShown: false,
};

export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen
          name="Home"
          component={HomeScreen}
          options={{ title: 'Morph Card' }}
        />
        <Stack.Screen
          name="BlueDetail"
          component={BlueDetailScreen}
          options={modalOptions}
        />
        <Stack.Screen
          name="CatDetail"
          component={CatDetailScreen}
          options={modalOptions}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
