# Client Library for the Dropbox API

This is a JavaScript client for the Dropbox API, suitable for use in both
modern browsers and in server-side code running under
[node.js](http://nodejs.org/).


## Supported Platforms

This library is tested against the following JavaScript platforms

* node.js 0.8
* Chrome 21
* Firefox 15
* Internet Explorer 9

## Installation and Usage

The
[getting started guide](https://github.com/dropbox/dropbox-js/blob/master/doc/getting_started.md),
will help you get your first dropbox.js application up and running.

Peruse the source code of the
[sample apps](https://github.com/dropbox/dropbox-js/tree/master/samples),
and borrow as much as you need.

## Development

The
[development guide](https://github.com/dropbox/dropbox-js/blob/master/doc/development.md)
will make your life easier if you need to change the source code.


## Platform-Specific Issues

### node.js

Reading and writing binary files is currently broken.

### Internet Explorer 9

The library only works when used from `https://` pages, due to
[these issues](http://blogs.msdn.com/b/ieinternals/archive/2010/05/13/xdomainrequest-restrictions-limitations-and-workarounds.aspx).

Reading and writing binary files is unsupported.


## Copyright and License

The library is Copyright (c) 2012 Dropbox Inc., and distributed under the MIT
License.

