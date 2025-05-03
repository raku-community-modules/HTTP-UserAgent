unit class HTTP::MediaType;

class X::MediaTypeParser::IllegalMediaType is Exception {
    has $.media-type;

    method message() { "Illegal media type: '$.media-type'" }
}

my grammar MediaTypeGrammar {
    token TOP { <media-type> }

    # https://tools.ietf.org/html/rfc7231#section-3.1.1.1
    token media-type { <type> "/" <subtype> [ <.OWS> ";" <.OWS> <parameter> ]* }
    token type { <._token> }
    token subtype { <._token> }

    token parameter { <parameter-key> "=" <parameter-value> }
    token parameter-key { <._token> }
    token parameter-value { <._token> || <.quoted-string> }

    # https://tools.ietf.org/html/rfc7230#section-3.2.3
    # optional white space
    token OWS { [ <.SP> || <.HTAB> ]* }

    # https://tools.ietf.org/html/rfc7230#section-3.2.6
    token _token { <.tchar>+ }
    token tchar {
        || < ! # $ % & ' * + - . ^ _ ` | ~ >
        || <.DIGIT>
        || <.ALPHA>
    }
    token quoted-string { <.DQUOTE> [<.qdtext> || <.quoted-pair>]* <.DQUOTE> }
    token qdtext { <.HTAB> || <.SP> || "\x21" || <[\x23 .. \x5B]> || <[\x5D .. \x7E]> || <.obs-text> }
    token obs-text { <[\x80..\xff]> }
    token quoted-pair { '\\' [ <.HTAB> || <.SP> || <.VCHAR> || <.obs-text> ] }

    # https://tools.ietf.org/html/rfc5234#appendix-B.1
    token DIGIT { <[ 0..9 ]> }
    token ALPHA { <[ A..Z a..z ]> }
    token SP { "\x20" }
    token HTAB { "\x09" }
    token DQUOTE { "\x22" }
    # visible (printing) characters
    token  VCHAR { <[\x21..\x7E]> }
}

my class MediaTypeAction {
    method TOP($/) { $/.make: $<media-type>.made() }
    method media-type($/) {
        $/.make: HTTP::MediaType.new(
            type => $<type>.made ~ "/" ~ $<subtype>.made,
            major-type => $<type>.made,
            sub-type   => $<subtype>.made,
            parameters => $<parameter>».made())
    }
    method type($/) { $/.make: ~$/ }
    method subtype($/) { $/.make: ~$/ }
    method parameter($/) { $/.make: $<parameter-key>.made() => $<parameter-value>.made }
    method parameter-key($/) { $/.make: ~$/ }
    method parameter-value($/) { $/.make: ~$/ }
}

has Str $.type;
has Str $.major-type;
has Str $.sub-type;
has %.parameters;

method charset(HTTP::MediaType:D:) returns Str {
    (%!parameters<charset> // '').lc;
}

method parse(Str $media-type) {
    my $result = MediaTypeGrammar.parse($media-type, :actions(MediaTypeAction));
    if $result {
        $result.made;
    }
    else {
        X::MediaTypeParser::IllegalMediaType.new(:$media-type).throw;
    }
}

proto method param(|) {*}

multi method param(Str:D $name) {
    %!parameters{$name};
}

multi method param(Str:D $name, Str:D $value) {
    %!parameters{$name} = $value
}

method Str(HTTP::MediaType:D:) {
    %!parameters
      ?? $.type ~ "; " ~ %!parameters.map({ .key ~ "=" ~ .value }).join(";")
      !! $.type
}

# vim: expandtab shiftwidth=4
