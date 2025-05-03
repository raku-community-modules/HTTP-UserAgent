unit class HTTP::UserAgent;

use HTTP::Response:auth<github:sergot>;
use HTTP::Request:auth<github:sergot>;
use HTTP::Cookies;
use HTTP::UserAgent::Common;
use HTTP::UserAgent::Exception;

use Encode;
use URI;

use File::Temp;
use MIME::Base64;

constant CRLF = Buf.new(13, 10);

# placeholder role to make signatures nicer
# and enable greater abstraction
role Connection {
    method send-request(HTTP::Request $request ) {
        $request.field(Connection => 'close') unless $request.field('Connection');
        if $request.binary {
            self.print($request.Str(:bin));
            self.write($request.content);
        }
        else {
            self.print($request.Str ~ "\r\n");
        }
    }
}

has Int $.timeout is rw = 180;
has $.useragent;
has HTTP::Cookies $.cookies is rw = HTTP::Cookies.new(
    file     => tempfile[0],
    autosave => 1,
);
has $.auth_login;
has $.auth_password;
has Int $.max-redirects is rw;
has $.redirects-in-a-row;
has Bool $.throw-exceptions;
has $.debug;
has IO::Handle $.debug-handle;

my sub search-header-end(Blob $input) {
    my $i = 0;
    my $input-bytes = $input.bytes;
    while $i+2 <= $input-bytes {
        # CRLF
        if $i+4 <= $input-bytes && $input[$i] == 0x0d && $input[$i+1]==0x0a && $input[$i+2]==0x0d && $input[$i+3]==0x0a {
            return $i+4;
        }
        # LF
        if $input[$i] == 0x0a && $input[$i+1]==0x0a {
            return $i+2;
        }
        $i++;
    }
    Nil
}

my sub _index_buf(Blob $input, Blob $sub) {
    my $end-pos = 0;
    while $end-pos < $input.bytes {
        if $sub eq $input.subbuf($end-pos, $sub.bytes) {
            return $end-pos;
        }
        $end-pos++;
    }
    -1
}

submethod BUILD(:$!useragent, Bool :$!throw-exceptions, :$!max-redirects = 5, :$!debug, :$!redirects-in-a-row) {
    $!useragent = get-ua($!useragent) if $!useragent.defined;
    if $!debug.defined {
        if $!debug ~~ Bool and $!debug == True {
            $!debug-handle = $*OUT;
        }
        if $!debug ~~ Str {
            say $!debug;
            $!debug-handle = open($!debug, :w);
            $!debug = True;
        }
        if $!debug ~~ IO::Handle {
            $!debug-handle = $!debug;
            $!debug = True;
        }
    }
}

method auth(Str $login, Str $password) {
    $!auth_login    = $login;
    $!auth_password = $password;
}

proto method get(|) {*}

multi method get(URI $uri is copy, Bool :$bin,  *%header ) {
    my $request  = HTTP::Request.new(GET => $uri, |%header);
    self.request($request, :$bin)
}

multi method get(Str $uri is copy, Bool :$bin,  *%header ) {
    self.get(URI.new(_clear-url($uri)), :$bin, |%header)
}

proto method post(|) {*}

multi method post(URI $uri is copy, %form , Bool :$bin,  *%header) {
    my $request = HTTP::Request.new(POST => $uri, |%header);
    $request.add-form-data(%form);
    self.request($request, :$bin)
}

multi method post(Str $uri is copy, %form, Bool :$bin, *%header ) {
    self.post(URI.new(_clear-url($uri)), %form, |%header)
}

proto method put(|) {*}

multi method put(URI $uri is copy, %form , Bool :$bin,  *%header) {
    my $request = HTTP::Request.new(PUT => $uri, |%header);
    $request.add-form-data(%form);
    self.request($request, :$bin)
}

multi method put(Str $uri is copy, %form, Bool :$bin, *%header ) {
    self.put(URI.new(_clear-url($uri)), %form, |%header)
}

proto method delete(|) {*}

multi method delete(URI $uri is copy, Bool :$bin,  *%header ) {
    my $request  = HTTP::Request.new(DELETE => $uri, |%header);
    self.request($request, :$bin)
}

multi method delete(Str $uri is copy, Bool :$bin,  *%header ) {
    self.delete(URI.new(_clear-url($uri)), :$bin, |%header)
}

method request(HTTP::Request $request, Bool :$bin --> HTTP::Response:D) {
    my HTTP::Response $response;

    # add cookies to the request
    $request.add-cookies($.cookies);

    # set the useragent
    $request.field(User-Agent => $.useragent) if $.useragent.defined;

    # if auth has been provided add it to the request
    self.setup-auth($request);
    $.debug-handle.say("==>>Send\n" ~ $request.Str(:debug)) if $.debug;
    my Connection $conn = self.get-connection($request);

    if $conn.send-request($request) {
         $response = self.get-response($request, $conn, :$bin);
    }
    $conn.close;

    X::HTTP::Response.new(:rc('No response')).throw unless $response;

    $.debug-handle.say("<<==Recv\n" ~ $response.Str(:debug)) if $.debug;

    # save cookies
    $.cookies.extract-cookies($response);

    if $response.code ~~ /^30<[0123]>/ {
        $!redirects-in-a-row++;
        if $.max-redirects < $.redirects-in-a-row {
            X::HTTP::Response.new(:rc('Max redirects exceeded'), :response($response)).throw;
        }
        my $new-request = $response.next-request();
        return self.request($new-request);
    }
    else {
        $!redirects-in-a-row = 0;
    }
    if $!throw-exceptions {
        given $response.code {
            when /^4/ {
                X::HTTP::Response.new(:rc($response.status-line), :response($response)).throw;
            }
            when /^5/ {
                X::HTTP::Server.new(:rc($response.status-line), :response($response)).throw;
            }
        }
    }

    $response
}

proto method get-content(|) {*}

# When we have a content-length
multi method get-content(Connection $conn, Blob $content, $content-length --> Blob:D) {
    if $content.bytes == $content-length {
        $content
    }
    else {
        # Create a Buf with what we have now and append onto
        # it until we've read the right amount.
        my $buf = Buf.new($content);
        my int $total-bytes-read = $content.bytes;
        while $content-length > $total-bytes-read {
           my $read = $conn.recv($content-length - $total-bytes-read, :bin);
           $buf.append($read);
           $total-bytes-read += $read.bytes;
        }
        $buf
    }
}

# fallback when not chunked and no content length
multi method get-content(Connection $conn, Blob $content is rw --> Blob:D) {

    while my $new_content = $conn.recv(:bin) {
        $content ~= $new_content;
    }
    $content;
}

method get-chunked-content(Connection $conn, Blob $content is rw --> Blob:D) {
    my Buf $chunk = $content.clone;
    $content  = Buf.new;
    # We carry on as long as we receive something.
    PARSE_CHUNK: loop {
        my $end_pos = _index_buf($chunk, CRLF);
        if $end_pos >= 0 {
            my $size = $chunk.subbuf(0, $end_pos).decode;
            # remove optional chunk extensions
            $size = $size.subst(/';'.*$/, '');
            # www.yahoo.com sends additional spaces(maybe invalid)
            $size = $size.subst(/' '*$/, '');
            $chunk = $chunk.subbuf($end_pos+2);
            my $chunk-size = :16($size);
            if $chunk-size == 0 {
                last PARSE_CHUNK;
            }
            while $chunk-size+2 > $chunk.bytes {
                $chunk ~= $conn.recv($chunk-size+2-$chunk.bytes, :bin);
            }
            $content ~= $chunk.subbuf(0, $chunk-size);
            $chunk = $chunk.subbuf($chunk-size+2);
        }
        else {
            # XXX Reading 1 byte is inefficient code.
            #
            # But IO::Socket#read/IO::Socket#recv reads from socket until
            # fill the requested size.
            #
            # It cause hang-up on socket reading.
            my $byte = $conn.recv(1, :bin);
            last PARSE_CHUNK unless $byte.elems;
            $chunk ~= $byte;
        }
    };

    $content
}

method get-response(HTTP::Request $request, Connection $conn, Bool :$bin --> HTTP::Response:D) {
    my Blob[uint8] $first-chunk = Blob[uint8].new;
    my $msg-body-pos;

    CATCH {
        when X::HTTP::NoResponse {
            X::HTTP::Internal.new(rc => 500, reason => "server returned no data").throw;
        }
        when /'Connection reset by peer'/ {
            X::HTTP::Internal.new(rc => 500, reason => "Connection reset by peer").throw;
        }
    }

    # Header can be longer than one chunk
    while my $t = $conn.recv( :bin ) {
        $first-chunk ~= $t;

        # Find the header/body separator in the chunk, which means
        # we can parse the header seperately and are  able to figure
        # out the correct encoding of the body.
        $msg-body-pos = search-header-end($first-chunk);
        last if $msg-body-pos.defined;
    }


    # If the header would indicate that there won't
    # be any content there may not be a \r\n\r\n at
    # the end of the header.
    my $header-chunk = do if $msg-body-pos.defined {
        $first-chunk.subbuf(0, $msg-body-pos);
    }
    else {
        # Assume we have the whole header because if the server
        # didn't send it we're stuffed anyway
        $first-chunk;
    }


    my HTTP::Response $response = HTTP::Response.new($header-chunk);
    $response.request = $request;

    if $response.has-content {
        if !$msg-body-pos.defined {
            X::HTTP::Internal.new(rc => 500, reason => "server returned no data").throw;
        }


        my $content = $first-chunk.subbuf($msg-body-pos);
        # Turn the inner exceptions to ours
        # This may really want to be outside
        CATCH {
            when X::HTTP::ContentLength {
                X::HTTP::Header.new( :rc($_.message), :response($response) ).throw
            }
        }
        # We also need to handle 'Transfer-Encoding: chunked', which means
        # that we request more chunks and assemble the response body.
        if $response.is-chunked {
            $content = self.get-chunked-content($conn, $content);
        }
        elsif $response.content-length -> $content-length is copy {
            $content = self.get-content($conn, $content, $content-length);
        }
        else {
            $content = self.get-content($conn, $content);
        }

        $response.content = $content andthen $response.content = $response.decoded-content(:$bin);
    }
    $response
}


proto method get-connection(|) {*}

multi method get-connection(HTTP::Request $request --> Connection:D) {
    my $host = $request.host;
    my $port = $request.port;


    if self.get-proxy($request) -> $http_proxy {
        $request.file = $request.url;
        my ($proxy_host, $proxy_auth) = $http_proxy.split('/').[2].split('@', 2).reverse;
        ($host, $port) = $proxy_host.split(':');
        $port.=Int;
        if $proxy_auth.defined {
            $request.field(Proxy-Authorization => basic-auth-token($proxy_auth));
        }
        $request.field(Connection => 'close');
    }
    self.get-connection($request, $host, $port)
}

my $https_lock = Lock.new;
multi method get-connection(HTTP::Request $request, Str $host, Int $port? --> Connection:D) {
    my $conn;
    if $request.scheme eq 'https' {
        $https_lock.lock;
        try require ::("IO::Socket::SSL");
        $https_lock.unlock;
        die "Please install IO::Socket::SSL in order to fetch https sites" if ::('IO::Socket::SSL') ~~ Failure;
        $conn = ::('IO::Socket::SSL').new(:$host, :port($port // 443), :timeout($.timeout))
    }
    else {
        $conn = IO::Socket::INET.new(:$host, :port($port // 80), :timeout($.timeout));
    }
    $conn does Connection;
    $conn
}

# heuristic to determine whether we are running in the CGI
# please adjust as required
method is-cgi() returns Bool {
    %*ENV<request_method>:exists or %*ENV<REQUEST_METHOD>:exists;
}

has $.http-proxy;
# want the request to possibly match scheme, no_proxy etc
method get-proxy(HTTP::Request $request) {
    $!http-proxy //= do if self.is-cgi {
        %*ENV<cgi_http_proxy> || %*ENV<CGI_HTTP_PROXY>;
    }
    else {
        %*ENV<http_proxy> || %*ENV<HTTP_PROXY>;
    }
    if self.use-proxy( $request ) {
        $!http-proxy;
    }
}

has @.no-proxy;

has Bool $!no-proxy-check = False;

method no-proxy() {
    if @!no-proxy.elems == 0 {
        if not $!no-proxy-check {
            if (%*ENV<no_proxy> || %*ENV<NO_PROXY> ) -> $no-proxy {
                @!no-proxy = $no-proxy.split: /\s*\,\s*/;
            }
            $!no-proxy-check = True;
        }
    }
    @!no-proxy;
}

proto method use-proxy(|) {*}

multi method use-proxy(HTTP::Request $request --> Bool:D) {
    self.use-proxy($request.host)
}

multi method use-proxy(Str $host) returns Bool {
    my $rc = True;

    for self.no-proxy -> $no-proxy {
        if $host ~~ /$no-proxy/ {
            $rc = False;
            last;
        }
    }
    $rc
}

multi sub basic-auth-token(Str $login, Str $passwd --> Str:D) {
    basic-auth-token("{$login}:{$passwd}");

}

multi sub basic-auth-token(Str $creds where * ~~ /':'/ --> Str:D) {
    "Basic " ~ MIME::Base64.encode-str($creds, :oneline);
}

method setup-auth(HTTP::Request $request) {
    # use HTTP Auth
    if self.use-auth($request) {
        $request.field(Authorization => basic-auth-token($!auth_login,$!auth_password));
    }
}

method use-auth(HTTP::Request $request) {
    $!auth_login.defined && $!auth_password.defined;
}

# :simple
our sub get($target where URI|Str) is export(:simple) {
    my $ua = HTTP::UserAgent.new(:throw-exceptions);
    my $response = $ua.get($target);

    $response.decoded-content
}

our sub head(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new(:throw-exceptions);
    $ua.get($url).header.hash<Content-Type Content-Length Last-Modified Expires Server>
}

our sub getprint(Str $url) is export(:simple) {
    my $response = HTTP::UserAgent.new(:throw-exceptions).get($url);
    print $response.decoded-content;
    $response.code
}

our sub getstore(Str $url, Str $file) is export(:simple) {
    $file.IO.spurt: get($url)
}

sub _clear-url(Str $url is copy) {
    $url.starts-with('http://' | 'https://')
      ?? $url
      !! "http://$url"
}

# vim: expandtab shiftwidth=4
