# Client Library for the Dropbox API

This is a JavaScript client for the Dropbox API, suitable for use in both
modern browsers and in server-side code running under
[node.js](http://nodejs.org/).


## Supported Platforms

This library is tested against the following JavaScript platforms

* node.js 0.8
* Chrome 20+
* Firefox 12+
* Internet Explorer 8+


## Installation

The library can be included in client-side applications using the following
HTML snippet.

```html
<script type="text/javascript" src="http://TODO">
</script>
```

The library is also available as an [npm](http://npmjs.org/) package, and can
be installed using the following command.

```bash
npm install dropbox-4real
```


## Usage

TBD


## Development

The library is written using [CoffeeScript](http://coffeescript.org/), built
using [cake](http://coffeescript.org/documentation/docs/cake.html), minified
using [uglify.js](https://github.com/mishoo/UglifyJS/), tested using
[mocha](http://visionmedia.github.com/mocha/) and
[chai.js](http://chaijs.com/), and packaged using [npm](https://npmjs.org/).

### Dev Environment Setup

Install [node.js](http://nodejs.org/#download) to get `npm` (the node
package manager), then use it to install the libraries required by the test
suite.

```bash
git clone https://github.com/dropbox/dropbox-sdk.git
cd dropbox-sdk
npm install -g coffee-script mocha uglify-js  # Prefix with sudo if necessary.
npm install
```

### Build

Run `npm pack` and ignore the deprecation warnings.

```bash
npm pack
```

The build output is in the `lib/` directory. `dropbox.js` is the compiled
library that ships in the npm package, and `dropbox.min.js` is a minified
version, optimized for browser apps.

### Test

First, you will need to obtain a couple of Dropbox tokens that will be used by
the automated tests.

```bash
cake tokens
```

Re-run the command above if the tests fail due to authentication errors.

Once you have Dropbox tokens, you can run the test suite in node.js or in your
default browser.

```bash
cake test
cake webtest
```

The library is automatically re-built when running tests, so you don't need to
run `npm pack`. Please run the tests in both node.js and a browser before
submitting pull requests.


## Copyright and License

The library is Copyright (c) 2012 Dropbox Inc., and distributed under the MIT
License.

