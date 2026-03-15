module.exports = {
  root: true,
  extends: ['@react-native'],
  plugins: ['@react-native/eslint-plugin-specs'],
  overrides: [
    {
      files: ['src/specs/**/*.ts'],
      rules: {
        '@react-native/specs/react-native-modules': 'error',
      },
    },
  ],
};
