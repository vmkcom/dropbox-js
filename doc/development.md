# dropbox.js Development

Read this document if you want to modify the source of dropbox.js itself. If
you want to write applications using dropbox.js, check out the
[Getting Started](getting_started.md).

The library is written using [CoffeeScript](http://coffeescript.org/), built
using [cake](http://coffeescript.org/documentation/docs/cake.html), minified
using [uglify.js](https://github.com/mishoo/UglifyJS/), tested using
[mocha](http://visionmedia.github.com/mocha/) and
[chai.js](http://chaijs.com/), and packaged using [npm](https://npmjs.org/).


## Dev Environment Setup

Install [node.js](http://nodejs.org/#download) to get `npm` (the node
package manager), then use it to install the libraries required by the test
suite.

```bash
git clone https://github.com/dropbox/dropbox-sdk.git
cd dropbox-sdk
npm install -g coffee-script mocha uglify-js  # Prefix with sudo if necessary.
npm install
```

## Build

Run `npm pack` and ignore the deprecation warnings.

```bash
npm pack
```

The build output is in the `lib/` directory. `dropbox.js` is the compiled
library that ships in the npm package, and `dropbox.min.js` is a minified
version, optimized for browser apps.

## Test

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

The tests store all their data in folders named along the lines of
`js tests.0.ac1n6lgs0e3lerk9`. If tests fail, you might have to clean up these
folders yourself.

