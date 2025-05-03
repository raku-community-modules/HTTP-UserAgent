use URI;
use URI::Escape;
use HTTP::Request:auth<zef:raku-community-modules>;
use HTTP::MediaType;
use MIME::Base64;
use HTTP::Header;

constant $CRLF = "\x0d\x0a";
my $HRC_DEBUG = %*ENV<HRC_DEBUG>.Bool;

#- private subs ----------------------------------------------------------------
my sub get-request(
  Str:D $meth, URI:D $uri, Bool :$bin, *%nameds
--> HTTP::Request:D) {
    my $request  = HTTP::Request.new(|($meth.uc => $uri), :$bin);
    $request.header.field(|%nameds);
    $request
}

my sub send-text-content(
  Str:D $meth, URI:D $uri, :$content, *%nameds
--> HTTP::Request:D) {
    my $request = get-request($meth, $uri, |%nameds);
    $request.add-content($_) with $content;
    $request
}

my sub send-binary-content(
  Str:D $meth, URI:D $uri, Blob :$content, *%nameds is copy
) {
    %nameds<Content-Length> = $content.elems;
    if %nameds<Content-Type>:!exists and %nameds<content-type>:!exists {
        %nameds<Content-Type> = 'application/octet-stream';
    }
    my $request = get-request($meth, $uri, |%nameds, :bin);
    $request.content = $content;
    $request
}

#- POST ------------------------------------------------------------------------
# TODO: multipart/form-data
proto sub POST(|) is export {*}
multi sub POST(URI $uri, %form, *%nameds) {
    POST($uri, content => %form, |%nameds);
}

multi sub POST(Str $uri, %form, *%nameds) {
    POST(URI.new($uri), content => %form, |%nameds)
}

multi sub POST(URI $uri, Array :$content, *%nameds) {
    my $request  = get-request('POST', $uri, |%nameds);
    $request.add-form-data($content);
    $request
}

multi sub POST(Str:D $uri, *%nameds) {
    POST(URI.new($uri), |%nameds)
}

multi sub POST(URI:D $uri, Hash :$content, *%nameds) {
    POST($uri, content => $content.Array, |%nameds)
}

multi sub POST(URI:D $uri, Str :$content, *%nameds) {
    send-text-content('POST', $uri, :$content, |%nameds)
}

multi sub POST(Str:D $uri, Blob :$content, *%nameds ) {
    POST(URI.new($uri), :$content, |%nameds)
}

multi sub POST(URI:D $uri, Blob :$content, *%nameds ) {
    send-binary-content('POST', $uri, :$content, |%nameds)
}

#- GET -------------------------------------------------------------------------
proto sub GET(|) is export {*}
multi sub GET(URI:D $uri, *%nameds) {
    get-request('GET', $uri, |%nameds);
}

multi sub GET(Str:D $uri, *%nameds) {
    GET(URI.new($uri), |%nameds)
}

#- HEAD ------------------------------------------------------------------------
proto sub HEAD(|) is export {*}
multi sub HEAD(URI:D $uri, *%nameds) {
    get-request('HEAD', $uri, |%nameds);
}

multi sub HEAD(Str:D $uri, *%nameds) {
    HEAD(URI.new($uri), |%nameds)
}

#- DELETE ----------------------------------------------------------------------
proto sub DELETE(|) is export {*}
multi sub DELETE(URI:D $uri, *%nameds) {
    get-request('DELETE', $uri, |%nameds);
}

multi sub DELETE(Str:D $uri, *%nameds) {
    DELETE(URI.new($uri), |%nameds)
}

#- PUT -------------------------------------------------------------------------
proto sub PUT(|) is export {*}
multi sub PUT(URI:D $uri, Str :$content, *%nameds) {
    send-text-content('PUT', $uri, :$content, |%nameds);
}

multi sub PUT(Str:D $uri, Str :$content, *%nameds) {
    PUT(URI.new($uri), :$content, |%nameds)
}

multi sub PUT(Str:D $uri, Blob :$content, *%nameds) {
    PUT(URI.new($uri), :$content, |%nameds);
}

multi sub PUT(URI:D $uri, Blob :$content, *%nameds ) {
    send-binary-content('PUT', $uri, :$content, |%nameds);
}

#- PATCH -----------------------------------------------------------------------
proto sub PATCH(|) is export {*}
multi sub PATCH(URI:D $uri, *%nameds) {
    send-text-content('PATCH', $uri, |%nameds);
}

multi sub PATCH(Str:D $uri, *%nameds) {
    PATCH(URI.new($uri), |%nameds)
}

# vim: expandtab shiftwidth=4
