# Getting Started

This is a guide to writing your first dropbox.js application.


## Library Setup

This section describes how to get the library hooked up into your application.

### Browser Applications

To get started right away, place this snippet in your page's `<head>`.

```html
<script src="//cdnjs.cloudflare.com/ajax/libs/dropbox.js/0.5.0/dropbox.min.js">
</script>
```

To get the latest development build of dropbox.js, follow the steps in the
[development guide](https://github.com/dropbox/dropbox-js/blob/master/doc/development.md).


### node.js Applications

First, install the `dropbox` [npm](https://npmjs.org/) package.

```bash
npm install dropbox
```

Once the npm package is installed, the following `require` statement lets you
access the same API as browser applications

```javascript
var Dropbox = require("dropbox");
```


## Initialization

[Register your application](https://www.dropbox.com/developers/apps) to obtain
an API key. Read the brief
[API core concepts intro](https://www.dropbox.com/developers/start/core).

Once you have an API key, use it to create a `Dropbox.Client`.

```javascript
var client = new Dropbox.Client({
    key: "your-key-here", secret: "your-secret-here", sandbox: true
});
```

If your application requires full Dropbox access, leave out the `sandbox: true`
parameter.


## Authentication

Before you can make any API calls, you need to authenticate your application's
user with Dropbox, and have them authorize your app's to access their Dropbox.

This process follows the [OAuth 1.0](http://tools.ietf.org/html/rfc5849)
protocol, which entails sending the user to a Web page on `www.dropbox.com`,
and then having them redirected back to your application. Each Web application
has its requirements, so `dropbox.js` lets you customize the authentication
process by implementing an
[OAuth driver](https://github.com/dropbox/dropbox-js/blob/master/src/drivers.coffee).

At the same time, dropbox.js ships with a couple of OAuth drivers, and you
should take advantage of them as you prototype your application.

### Browser Setup

The following snippet will set up the recommended driver.

```javascript
client.authDriver(new Dropbox.Driver.Redirect());
```

### node.js Setup

Single-process node.js applications should create one driver to authenticate
all the clients.

```javascript
var driver = new Dropbox.Driver.NodeServer(8191);  // 8191 is a TCP port
client.authDriver(driver);
```

### Shared Code

After setting up an OAuth driver, authenticating the user is one method call
away.

```javascript
client.authenticate(function(error, client) {
  if (error) {
    return showError(error);  // Something went wrong.
  }

  doSomethingCool(client);  // client is a Dropbox.Client instance
});
```


## The Fun Part

Authentication was the hard part. Now that it's behind us, you can interact
with the user's Dropbox and focus on coding up your application!

The following sections have some commonly used code snippets. To understand the
entire Dropbox API, read the JSDoc comments in the
[Dropbox.Client source](https://github.com/dropbox/dropbox-js/blob/master/src/client.coffee),
the examples in the
[Dropbox.Client tests](https://github.com/dropbox/dropbox-js/blob/master/test/src/client_test.coffee),
and the
[REST API reference](https://www.dropbox.com/developers/reference/api).


### User Info

```javascript
client.getUserInfo(function(error, userInfo) {
  if (error) {
    return showError(error);  // Something went wrong.
  }

  alert("Hello, " + userInfo.name + "!");
});
```

### Write a File

```javascript
client.writeFile("hello_world.txt", "Hello, world!\n", function(error, stat) {
  if (error) {
    return showError(error);  // Something went wrong.
  }

  alert("File saved as revision " + stat.revisionTag);
});
```

### Read a File

```javascript
client.readFile("hello_world.txt", function(error, data) {
  if (error) {
    return showError(error);  // Something went wrong.
  }

  alert(data);  // data has the file's contents
});
```

### List a Directory's Contents

```javascript
client.readdir("/", function(error, entries) {
  if (error) {
    return showError(error);  // Something went wrong.
  }

  alert("Your Dropbox contains " + entries.join(", ");
});
```

