  export default [
    {
      match: {},
      callback: {
        url: 'http://search/update',
        method: 'POST'
      },
      options: {
        resourceFormat: 'v0.0.1',
        gracePeriod: 2000,
        ignoreFromSelf: true
      }
    }
  ];
