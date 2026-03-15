module.exports = {
  dependency: {
    platforms: {
      android: {
        libraryName: 'morphcard',
        componentDescriptors: [
          'RNCMorphCardSourceComponentDescriptor',
          'RNCMorphCardTargetComponentDescriptor',
        ],
        cmakeListsPath: '../src/main/jni/CMakeLists.txt',
      },
    },
  },
};
