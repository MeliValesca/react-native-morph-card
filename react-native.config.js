module.exports = {
  dependency: {
    platforms: {
      android: {
        libraryName: 'morphcard',
        componentDescriptors: [
          'RNCMorphCardSourceComponentDescriptor',
          'RNCMorphCardTargetComponentDescriptor',
        ],
      },
    },
  },
};
