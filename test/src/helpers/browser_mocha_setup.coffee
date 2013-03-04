mocha.setup(
    ui: 'bdd', slow: 150, timeout: 15000, bail: false,
    ignoreLeaks: !!window.cordova)
