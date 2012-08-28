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

## Installation

The library can be included in client-side applications using the following
HTML snippet.

```html
<script type="text/javascript" src="http://TODO">
</script>
```

The library is available as an [npm](http://npmjs.org/) package, and can be
installed using the following command.

```bash
npm install dropbox
```

If you want to build dropbox.js on your own, read the
[development guide](https://github.com/dropbox/dropbox-js/tree/master/doc/development.md).

## Usage

Read the source code of the
[sample apps](https://github.com/dropbox/dropbox-js/tree/master/samples),
and borrow as much as you need.

## Development

The
[development guide](https://github.com/dropbox/dropbox-js/tree/master/doc/development.md)
will make your life easier if you need to change the source code.


## Platform-Specific Issues

### node.js

Reading and writing binary files is currently broken.

### Firefox

Writing binary files is currently broken due to
[this bug](https://bugzilla.mozilla.org/show_bug.cgi?id=649150).

### Internet Explorer

The library is currently non-functional.


## Copyright and License

The library is Copyright (c) 2012 Dropbox Inc., and distributed under the MIT
License.

