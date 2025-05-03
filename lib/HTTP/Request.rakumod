use HTTP::Message;
use URI;
use URI::Escape;
use HTTP::MediaType;
use MIME::Base64;

unit class HTTP::Request is HTTP::Message;

subset RequestMethod of Str where any(<GET POST HEAD PUT DELETE PATCH>);

has RequestMethod $.method is rw;
has $.url is rw;
has $.file is rw;
has $.uri is rw;

has Str $.host is rw;
has Int $.port is rw;
has Str $.scheme is rw;

my $CRLF = "\r\n";

my $HRC_DEBUG = %*ENV<HRC_DEBUG>.Bool;

proto method new(|) {*}

multi method new(Bool :$bin, *%args) {

    if %args {
        my ($method, $url, $file, %fields, $uri);
        for %args.kv -> $key, $value {
            if $key.lc ~~ any(<get post head put delete patch>) {
                $uri = $value.isa(URI) ?? $value !! URI.new($value);
                $method = $key.uc;
            }
            else {
                %fields{$key} = $value;
            }
        }

        my $header = HTTP::Header.new(|%fields);
        self.new($method // 'GET', $uri, $header, :$bin);
    }
    else {
        self.bless
    }
}

multi method new() { self.bless }

multi method new(RequestMethod $method, URI $uri, HTTP::Header $header, Bool :$bin) {
    my $url = $uri.grammar.parse_result.orig;
    my $file = $uri.path_query || '/';

    $header.field(Host => get-host-value($uri)) without $header.field('Host');

    self.bless(:$method, :$url, :$header, :$file, :$uri, binary => $bin)
}

sub get-host-value(URI $uri --> Str) {
    my Str $host = $uri.host;

    if $host {
        if ( $uri.port != $uri.default_port ) {
            $host ~= ':' ~ $uri.port;
        }
    }
    $host;
}

method set-method($method) { $.method = $method.uc }

proto method uri(|) {*}

multi method uri($uri is copy where URI|Str) {
    $!uri = $uri.isa(Str) ?? URI.new($uri) !! $uri ;
    $!url = $!uri.grammar.parse_result.orig;
    $!file = $!uri.path_query || '/';
    self.field(Host => get-host-value($!uri));
    $!uri
}

multi method uri() is rw { $!uri }

proto method host(|) {*}

multi method host(--> Str:D) is rw {
    $!host = ~self.field('Host').values without $!host;
    $!host
}

proto method port(|) {*}

multi method port(--> Int) is rw {
    if not $!port.defined {
        # if there isn't a scheme the no default port
        if try self.uri.scheme {
            $!port = self.uri.port;
        }
    }
    $!port
}

proto method scheme(|) {*}

multi method scheme(--> Str:D) is rw {
    without $!scheme {
        CATCH {
            default { $!scheme = 'http' }
        }
        $!scheme = self.uri.scheme;
    }
    $!scheme
}

method add-cookies($cookies) {
    $cookies.add-cookie-header(self) if $cookies.cookies;
}

proto method add-content(|) {*}

multi method add-content(Str:D $content) {
    self.content ~= $content;
    self.header.field(Content-Length => self.content.encode.bytes.Str);
}

proto method add-form-data(|) {*}

multi method add-form-data(:$multipart, *%data) {
    self.add-form-data(%data.sort.Array, :$multipart);
}

multi method add-form-data(%data, :$multipart) {
    self.add-form-data(%data.sort.Array, :$multipart);
}

multi method add-form-data(Array $data, :$multipart) {
    my $ct = do {
        my $f = self.header.field('Content-Type');
        if $f {
            $f.values[0];
        } else {
            if $multipart {
                'multipart/form-data';
            }
            else {
                'application/x-www-form-urlencoded';
            }
        }
    };
    sub form-escape($s) {
        uri-escape($s).subst(:g, '%20', '+').subst(:g, '%2A', '*');
    }
    given $ct {
        when 'application/x-www-form-urlencoded' {
            my @parts;
            for @$data {
                @parts.push: form-escape(.key) ~ "=" ~ form-escape(.value);
            }
            self.content = @parts.join("&").encode;
            self.header.field(Content-Length => self.content.bytes.Str);

        }
        when m:i,^ "multipart/form-data" \s* ( ";" | $ ), {
            say 'generating form-data' if $HRC_DEBUG;

            my $mt = HTTP::MediaType.parse($ct);
            my Str $boundary = $mt.param('boundary') // self.make-boundary(10);
            (my $generated-content, $boundary) = self.form-data($data, $boundary);
            $mt.param('boundary', $boundary);
            $ct = $mt.Str;
            my Str $encoded-content = $generated-content;
            self.content = $encoded-content;
            self.header.field(Content-Length => $encoded-content.encode('ascii').bytes.Str);
        }
    }
    self.header.field(Content-Type => $ct)
}


method form-data(Array:D $content, Str:D $boundary) {
    my @parts;
    for @$content {
        my ($k, $v) = $_.key, $_.value;
        given $v {
            when Str {
                $k ~~ s:g/(<[\\ \"]>)/\\$1/;  # escape quotes and backslashes
                @parts.push: qq!Content-Disposition: form-data; name="$k"$CRLF$CRLF$v!;
            }
            when Array {
                my ($file, $usename, @headers) = @$v;
                unless defined $usename {
                    $usename = $file;
                    $usename ~~ s!.* "/"!! if defined($usename);
                }
                $k ~~ s:g/(<[\\ \"]>)/\\$1/;
                my $disp = qq!form-data; name="$k"!;
                if (defined($usename) and $usename.elems > 0) {
                    $usename ~~ s:g/(<[\\ \"]>)/\\$1/;
                    $disp ~= qq!; filename="$usename"!;
                }
                my $content;
                my $headers = HTTP::Header.new(|@headers);
                if $file {
                    # TODO: dynamic file upload support
                    $content = $file.IO.slurp;
                    unless $headers.field('Content-Type') {
                        # TODO: LWP::MediaTypes
                        $headers.field(Content-Type => 'application/octet-stream');
                    }
                }
                if $headers.field('Content-Disposition') {
                    $disp = $headers.field('Content-Disposition');
                    $headers.remove-field('Content-Disposition');
                }
                if $headers.field('Content') {
                    $content = $headers.field('Content');
                    $headers.remove-field('Content');
                }
                my $head = ["Content-Disposition: $disp",
                            $headers.Str($CRLF),
                            ""].join($CRLF);
                given $content {
                    when Str {
                        @parts.push: $head ~ $content;
                    }
                    default {
                        die "NYI"
                    }
                }
            }
            default {
                die "unsupported type: $v.WHAT.gist()($content.raku())";
            }
        }
    }

    say $content if $HRC_DEBUG;
    say @parts if $HRC_DEBUG;
    return "", "none" unless @parts;

    my $contents;
    # TODO: dynamic upload support
    my $bno = 10;
    CHECK_BOUNDARY: {
        for @parts {
            if $_.index($boundary).defined {
                # must have a better boundary
                $boundary = self.make-boundary(++$bno);
                redo CHECK_BOUNDARY;
            }
        }
    }
    my $generated-content = "--$boundary$CRLF"
                ~ @parts.join("$CRLF--$boundary$CRLF")
                ~ "$CRLF--$boundary--$CRLF";

    $generated-content, $boundary
}


method make-boundary(int $size=10) {
    my $str = (1..$size*3).map({(^256).pick.chr}).join('');
    my $b = MIME::Base64.new.encode_base64($str, :oneline);
    $b ~~ s:g/\W/X/;  # ensure alnum only
    $b
}


method Str (:$debug, Bool :$bin) {
    $.file = '/' ~ $.file unless $.file.starts-with: '/';
    my $s = "$.method $.file $.protocol";
    $s ~= $CRLF ~ callwith($CRLF, :$debug, :$bin);
}

method parse($raw_request) {
    my @lines = $raw_request.split($CRLF);
    ($.method, $.file) = @lines.shift.split(' ');

    $.url = 'http://';

    for @lines -> $line {
        if $line ~~ m:i/host:/ {
            $.url ~= $line.split(/\:\s*/)[1];
        }
    }

    $.url ~= $.file;

    self.uri = URI.new($.url) ;

    nextsame;
}

# vim: expandtab shiftwidth=4
