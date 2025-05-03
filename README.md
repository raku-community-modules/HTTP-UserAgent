[![Actions Status](https://github.com/raku-community-modules/HTTP-UserAgent/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/HTTP-UserAgent/actions) [![Actions Status](https://github.com/raku-community-modules/HTTP-UserAgent/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/HTTP-UserAgent/actions) [![Actions Status](https://github.com/raku-community-modules/HTTP-UserAgent/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/HTTP-UserAgent/actions)

NAME
====

HTTP::UserAgent - Web user agent class

SYNOPSIS
========

```raku
use HTTP::UserAgent;

my $ua = HTTP::UserAgent.new;
$ua.timeout = 10;

my $response = $ua.get("URL");

if $response.is-success {
    say $response.content;
}
else {
    die $response.status-line;
}
```

DESCRIPTION
===========

This module provides functionality to crawling the web witha handling cookies and correct User-Agent value.

It has TLS/SSL support.

METHODS
=======

method new
----------

```raku
method new(HTTP::UserAgent:U: :$!useragent, Bool :$!throw-exceptions, :$!max-redirects = 5, :$!debug)
```

Default constructor.

There are four optional named arguments:

  * useragent

A string that specifies what will be provided in the `User-Agent` header in the request. A number of standard user agents are described in [HTTP::UserAgent::Common](HTTP::UserAgent::Common), but a string that is not specified there will be used verbatim.

  * throw-exceptions

By default the `request` method will not throw an exception if the response from the server indicates that the request was unsuccesful, in this case you should check `is-success` to determine the status of the [HTTP::Response](HTTP::Response) returned. If this is specified then an exception will be thrown if the request was not a success, however you can still retrieve the response from the `response` attribute of the exception object.

  * max-redirects

This is the maximum number of redirects allowed for a single request, if this is exceeded then an exception will be thrown (this is not covered by `no-exceptions` above and will always be throw,) the default value is 5.

  * debug

It can etheir be a Bool like simply `:debug` or you can pass it a IO::Handle or a file name. Eg `:debug($*ERR)` will ouput on stderr `:debug("mylog.txt")` will ouput on the file.

method auth
-----------

```raku
method auth(HTTP::UserAgent:, Str $login, Str $password)
```

Sets username and password needed to HTTP Auth.

method get
----------

```raku
multi method get(Str $url is copy, :bin?, *%headers)
multi method get(URI $uri, :bin?, *%headers)
```

Requests the $url site, returns HTTP::Response, except if throw-exceptions is set as described above whereby an exception will be thrown if the response indicates that the request wasn't successfull.

If the Content-Type of the response indicates that the content is text the `content` of the Response will be a decoded string, otherwise it will be left as a [Blob](Blob).

If the ':bin' adverb is supplied this will force the response `content` to always be an undecoded [Blob](Blob)

Any additional named arguments will be applied as headers in the request.

method post
-----------

```raku
multi method post(URI $uri, %form, *%header ) -> HTTP::Response
multi method post(Str $uri, %form, *%header ) -> HTTP::Response
```

Make a POST request to the specified uri, with the provided Hash of %form data in the body encoded as "application/x-www-form-urlencoded" content. Any additional named style arguments will be applied as headers in the request.

An [HTTP::Response](HTTP::Response) will be returned, except if throw-exceptions has been set and the response indicates the request was not successfull.

If the Content-Type of the response indicates that the content is text the `content` of the Response will be a decoded string, otherwise it will be left as a [Blob](Blob).

If the ':bin' adverb is supplied this will force the response `content` to always be an undecoded [Blob](Blob)

If greater control over the content of the request is required you should create an [HTTP::Request](HTTP::Request) directly and populate it as needed,

method request
--------------

```raku
method request(HTTP::Request $request, :bin?)
```

Performs the request described by the supplied [HTTP::Request](HTTP::Request), returns a [HTTP::Response](HTTP::Response), except if throw-exceptions is set as described above whereby an exception will be thrown if the response indicates that the request wasn't successful.

If the response has a 'Content-Encoding' header that indicates that the content was compressed, then it will attempt to inflate the data using [Compress::Zlib](Compress::Zlib), if the module is not installed then an exception will be thrown. If you do not have or do not want to install [Compress::Zlib](Compress::Zlib) then you should be able to send an 'Accept-Encoding' header with a value of 'identity' which should cause a well behaved server to send the content verbatim if it is able to.

If the Content-Type of the response indicates that the content is text the `content` of the Response will be a decoded string, otherwise it will be left as a [Blob](Blob). The content-types that are always considered to be binary (and thus left as a [Blob](Blob) ) are those with the major-types of 'image','audio' and 'video', certain 'application' types are considered to be 'text' (e.g. 'xml', 'javascript', 'json').

If the ':bin' adverb is supplied this will force the response `content` to always be an undecoded [Blob](Blob)

You can use the helper subroutines defined in [HTTP::Request::Common](HTTP::Request::Common) to create the [HTTP::Request](HTTP::Request) for you or create it yourself if you have more complex requirements.

routine get :simple
-------------------

```raku
sub get(Str $url) returns Str is export(:simple)
```

Like method get, but returns decoded content of the response.

routine head :simple
--------------------

```raku
sub head(Str $url) returns Parcel is export(:simple)
```

Returns values of following header fields:

  * Content-Type

  * Content-Length

  * Last-Modified

  * Expires

  * Server

routine getstore :simple
------------------------

```raku
sub getstore(Str $url, Str $file) is export(:simple)
```

Like routine get but writes the content to a file.

routine getprint :simple
------------------------

```raku
sub getprint(Str $url) is export(:simple)
```

Like routine get but prints the content and returns the response code.

SUPPORT MODULES
===============

HTTP::Cookie - HTTP cookie class
--------------------------------

This module encapsulates single HTTP Cookie.

```raku
use HTTP::Cookie;

my $cookie = HTTP::Cookie.new(:name<test_name>, :value<test_value>);
say ~$cookie;
```

The following methods are provided:

### method new

```raku
my $c = HTTP::Cookie.new(:name<a_cookie>, :value<a_value>, :secure, fields => (a => b));
```

A constructor, it takes these named arguments:

<table class="pod-table">
<thead><tr>
<th>key</th> <th>description</th>
</tr></thead>
<tbody>
<tr> <td>name</td> <td>name of a cookie</td> </tr> <tr> <td>value</td> <td>value of a cookie</td> </tr> <tr> <td>secure</td> <td>Secure param</td> </tr> <tr> <td>httponly</td> <td>HttpOnly param</td> </tr> <tr> <td>fields</td> <td>list of field Pairs (field =&gt; value)</td> </tr>
</tbody>
</table>

### method Str

Returns a cookie as a string in readable (RFC2109) form.

HTTP::Cookies - HTTP cookie jars
--------------------------------

This module provides a bunch of methods to manage HTTP cookies.

```raku
use HTTP::Cookies;
my $cookies = HTTP::Cookies.new(
  :file<./cookies>,
  :autosave
);
$cookies.load;
```

### method new

```raku
my $cookies = HTTP::Cookies.new(
  :file<./cookies.here>
  :autosave,
);

Constructor, takes named arguments:
```

<table class="pod-table">
<thead><tr>
<th>key</th> <th>description</th>
</tr></thead>
<tbody>
<tr> <td>file</td> <td>where to write cookies</td> </tr> <tr> <td>autosave</td> <td>save automatically after every operation on cookies or not</td> </tr>
</tbody>
</table>

### method set-cookie

```raku
my $cookies = HTTP::Cookies.new;
$cookies.set-cookie('Set-Cookie: name1=value1; HttpOnly');
```

Adds a cookie (passed as an argument $str of type Str) to the list of cookies.

### method save

```raku
my $cookies = HTTP::Cookies.new;
$cookies.set-cookie('Set-Cookie: name1=value1; HttpOnly');
$cookies.save;
```

Saves cookies to the file ($.file).

### method load

```raku
my $cookies = HTTP::Cookies.new;
$cookies.load;
```

Loads cookies from file specified at instantiation ($.file).

### method extract-cookies

```raku
my $cookies = HTTP::Cookies.new;
my $response = HTTP::Response.new(Set-Cookie => "name1=value; Secure");
$cookies.extract-cookies($response);
```

Gets cookies ('Set-Cookie: ' lines) from the HTTP Response and adds it to the list of cookies.

### method add-cookie-header

```raku
my $cookies = HTTP::Cookies.new;
my $request = HTTP::Request.new;
$cookies.load;
$cookies.add-cookie-header($request);
```

Adds cookies fields ('Cookie: ' lines) to the HTTP Request.

### method clear-expired

```raku
my $cookies = HTTP::Cookies.new;
$cookies.set-cookie('Set-Cookie: name1=value1; Secure');
$cookies.set-cookie('Set-Cookie: name2=value2; Expires=Wed, 09 Jun 2021 10:18:14 GMT');
$cookies.clear-expired; # contains 'name1' cookie only
```

Removes expired cookies.

### method clear

```raku
my $cookies = HTTP::Cookies.new;
$cookies.load;   # contains something
$cookies.clear;  # will be empty after this action
```

Removes all cookies.

### method push-cookie

```raku
my $c = HTTP::Cookie.new(:name<a>, :value<b>, :httponly);
my $cookies = HTTP::Cookies.new;
$cookies.push-cookie: $c;
```

Pushes cookies (passed as an argument $c of type HTTP::Cookie) to the list of cookies.

### method Str

Returns all cookies in human (and server) readable form.

HTTP::UserAgent::Common - the most commonly used User-Agents
------------------------------------------------------------

This module provides a list of the most commonly used User-Agents.

```raku
use HTTP::UserAgent::Common;
say get-ua('chrome_linux');
```

### routine get-ua

```raku
say get-ua('chrome_linux');
```

Returns correct UserAgent or unchaged passed argument if UserAgent could not be found.

Available UserAgents:

    chrome_w7_64 firefox_w7_64 ie_w7_64 chrome_w81_64 firefox_w81_64 mob_safari_osx
    safari_osx chrome_osx firefox_linux chrome_linux

HTTP::Header - class encapsulating HTTP message header
------------------------------------------------------

This module provides a class with a set of methods making us able to easily handle HTTP message headers.

```raku
use HTTP::Header;
my $h = HTTP::Header.new;
$h.field(Accept => 'text/plain');
say $h.field('Accept');
$h.remove-field('Accept');
```

### method new

```raku
my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
```

A constructor. Takes name => value pairs as arguments.

### method header

```raku
my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
say $head.header('h1');

my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
$head.header(:h3<v3>);
```

Gets/sets header field.

### method init-field

```raku
my $head = HTTP::Header.new;
$head.header(:h1<v1>);
$head.init-header(:h1<v2>, :h2<v2>); # it doesn't change the value of 'h1'
say ~$head;
```

Initializes a header field: adds a field only if it does not exist yet.

### method push-header

```raku
my $head = HTTP::Header.new;
$head.push-header( HTTP::Header::Field.new(:name<n1>, :value<v1>) );
say ~$head;
```

Pushes a new field. Does not check if exists.

### method remove-header

```raku
my $head = HTTP::Header.new;
$head.header(:h1<v1>);
$head.remove-header('h1');
```

Removes a field of name $field.

### method header-field-names

```raku
my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
my @names = $head.header-field-names;
say @names; # h1, h2
```

Returns a list of names of all fields.

### method clear

```raku
my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
$head.clear;
```

Removes all fields.

### method Str

Returns readable form of the whole header section.

### method parse

```raku
my $head = HTTP::Header.new.parse("h1: v1\r\nh2: v2\r\n");
say $head.raku;
```

Parses the whole header section.

HTTP::Header::Field
-------------------

This module provides a class encapsulating HTTP Message header field.

```raku
use HTTP::Header::Field;
my $header = HTTP::Header::Field.new(:name<Date>, values => (123, 456));
```

### method new

Constructor. Takes these named arguments:

<table class="pod-table">
<thead><tr>
<th>key</th> <th>description</th>
</tr></thead>
<tbody>
<tr> <td>name</td> <td>name of a header field</td> </tr> <tr> <td>values</td> <td>array of values of a header field</td> </tr>
</tbody>
</table>

### method Str

Stringifies an HTTP::Header::Field object. Returns a header field in a human (and server) readable form.

HTTP::Request - class encapsulating HTTP request message
--------------------------------------------------------

Module provides functionality to easily manage HTTP requests.

```raku
use HTTP::Request;
my $request = HTTP::Request.new(GET => 'http://www.example.com/');
```

### method new

A constructor, the first form takes parameters like:

  * method => URL, where method can be POST, GET ... etc.

  * field => values, header fields

```raku
my $req = HTTP::Request.new(:GET<example.com>, :h1<v1>);
```

The second form takes the key arguments as simple positional parameters and is designed for use in places where for example the request method may be calculated and the headers pre-populated.

### method set-method

```raku
my $req = HTTP::Request.new;
$req.set-method: 'POST';
```

Sets a method of the request.

### method uri

```raku
my $req = HTTP::Request.new;
$req.uri: 'example.com';
```

Sets URL to request.

### method add-cookies

```raku
method add-cookies(HTTP::Cookies $cookies)
```

This will cause the appropriate cookie headers to be added from the supplied HTTP::Cookies object.

### method add-form-data

```raku
multi method add-form-data(%data, :$multipart)
multi method add-form-data(:$multipart, *%data);
multi method add-form-data(Array $data, :$multipart)
```

Adds the form data, supplied either as a `Hash`, an `Array` of `Pair`s, or in a named parameter style, to the POST request (it doesn't make sense on most other request types).

The default is to use 'application/x-www-form-urlencoded' and 'multipart/form-data' can be used by providing the ':multipart' named argument. Alternatively a previously applied "content-type" header of either 'application/x-www-form-urlencoded' or 'multipart/form-data' will be respected and in the latter case any applied boundary marker will be retained.

As a special case for multipart data if the value for some key in the data is an `Array` of at least one item then it is taken to be a description of a file to be "uploaded" where the first item is the path to the file to be inserted, the second (optional) an alternative name to be used in the content disposition header and the third an optional `Array` of `Pair`s that will provide additional header lines for the part.

### method Str

Returns stringified object.

### method parse

```raku
method parse(Str $raw_request --> HTTP::Request:D)
```

Parses raw HTTP request. See `HTTP::Message`

HTTP::Request::Common - Construct common HTTP::Request objects
--------------------------------------------------------------

```raku
use HTTP::Request::Common;

my $ua       = HTTP::UserAgent.new;
my $response = $ua.request(GET 'http://google.com/');
```

This module provide functions that return newly created `HTTP::Request` objects. These functions are usually more convenient to use than the standard `HTTP::Request` constructor for the most common requests. The following functions are provided:

### GET $url, Header => Value...

The `GET` function returns an `HTTP::Request` object initialized with the "GET" method and the specified URL.

### HEAD $url, Header => Value,...

Like `GET` but the method in the request is "HEAD".

### DELETE $url, Header => Value,...

Like `GET` but the method in the request is "DELETE".

### `PUT $url, Header =` Value,..., content => $content>

Like `GET` but the method in the request is "PUT".

HTTP::Response - class encapsulating HTTP response message
----------------------------------------------------------

```raku
use HTTP::Response;
my $response = HTTP::Response.new(200);
say $response.is-success; # it is
```

Module provides functionality to easily manage HTTP responses.

Response object is returned by the .get() method of [HTTP::UserAgent](HTTP::UserAgent).

### method new

```raku
my $response = HTTP::Response.new(200, :h1<v1>);
```

A constructor, takes named arguments:

<table class="pod-table">
<thead><tr>
<th>key</th> <th>description</th>
</tr></thead>
<tbody>
<tr> <td>code</td> <td>code of the response</td> </tr> <tr> <td>fields</td> <td>header fields (field_name =&gt; values)</td> </tr>
</tbody>
</table>

### method is-success

```raku
my $response = HTTP::Response.new(200);
say 'YAY' if $response.is-success;
```

Returns True if response is successful (status == 2xx), False otherwise.

method set-code
---------------

```raku
my $response = HTTP::Response.new;
$response.set-code: 200;
```

Sets code of the response.

### method Str

Returns stringified object.

### method parse

See `HTTP::Message`.

HTTP::Message - class encapsulating HTTP message
------------------------------------------------

```raku
use HTTP::Message;
my $raw_msg = "GET / HTTP/1.1\r\nHost: somehost\r\n\r\n";
my $mess = HTTP::Message.new.parse($raw_msg);
say $mess;
```

This module provides a bunch of methods to easily manage HTTP message.

### method new

```raku
my $msg = HTTP::Message.new('content', :field<value>);
```

A constructor, takes these named arguments:

<table class="pod-table">
<thead><tr>
<th>key</th> <th>description</th>
</tr></thead>
<tbody>
<tr> <td>content</td> <td>content of the message (optional)</td> </tr> <tr> <td>fields</td> <td>fields of the header section</td> </tr>
</tbody>
</table>

### method add-content

```raku
my $msg = HTTP::Message.new('content', :field<value>);
$msg.add-content: 's';
say $msg.content; # says 'contents'
```

Adds HTTP message content. It does not remove the existing value, it concats to the existing content.

### method decoded-content

```raku
my $msg = HTTP::Message.new();
say $msg.decoded-content;
```

Returns decoded content of the message (using [Encode](Encode) module to decode).

### method field

See `HTTP::Header`.

### method init-field

See `HTTP::Header`.

### method push-field

See `HTTP::Header`.

### method remove-field

See `HTTP::Header`.

### method clear

```raku
my $msg = HTTP::Message.new('content', :field<value>);
$msg.clear;
say ~$msg; # says nothing
```

Removes the whole message, both header and content section.

### method parse

```raku
my $msg = HTTP::Message.new.parse("GET / HTTP/1.1\r\nHost: example\r\ncontent\r\n");
say $msg.raku;
```

Parses the whole HTTP message.

It takes the HTTP message (with \r\n as a line separator) and obtains the header and content sections, creates a `HTTP::Header` object.

### method Str

Returns HTTP message in a readable form.

AUTHOR
======

  * Filip Sergot

Source can be located at: https://github.com/raku-community-modules/HTTP-UserAgent . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2014 - 2022 Filip Sergot

Copyright 2023 - 2025 The Raku Community

This library is free software; you can redistribute it and/or modify it under the MIT License.

