unit class HTTP::Cookies;

use HTTP::Cookie;
use HTTP::Response:auth<github:sergot>;
use HTTP::Request:auth<github:sergot>;
use DateTime::Parse;

has @.cookies;
has $.file;
has $.autosave is rw = 0;

my grammar HTTP::Cookies::Grammar {
    token TOP {
        'Set-Cookie:' [\s* <cookie> ','?]*
    }

    token cookie   {
        <name> '=' <value> ';'? \s* [<arg> \s*]* <secure>? ';'? \s* <httponly>? ';'?
    }
    token separator { <[()<>@,;:\"/\[\]?={}\s\t]> }
    token name     { <[\S] - [()<>@,;:\"/\[\]?={}]>+ }
    token value    { <-[;]>+ }
    token arg      { <name> '=' <value> ';'? }
    token secure   { Secure }
    token httponly { :i HttpOnly }
}

my class HTTP::Cookies::Actions {
    method cookie($/) {
        my $h = HTTP::Cookie.new;
        $h.name     = ~$<name>;
        $h.value    = ~$<value>;
        $h.secure   = $<secure>.defined ?? ~$<secure> !! False;;
        $h.httponly = $<httponly>.defined ?? ~$<httponly> !! False;

        for $<arg>.list -> $a {
            if <version expires path domain>.grep($a<name>.lc) {
              $h."{$a<name>.lc}"() = ~$a<value>;
            } else {
              $h.fields.push: $a<name> => ~$a<value>;
            }
        }
        $*OBJ.push-cookie($h);
    }
}

method extract-cookies(HTTP::Response $response) {
    self.set-cookie($_) for $response.field('Set-Cookie').grep({ $_.defined }).map({ "Set-Cookie: $_"  }).flat;
    self.save if $.autosave;
}

method add-cookie-header(HTTP::Request $request) {
    for @.cookies -> $cookie {
        # TODO this check sucks, eq is not the right (should probably use uri)
        #next if $cookie.domain.defined
        #        && $cookie.domain ne $request.field('Host');
        # TODO : path/domain restrictions
        my $cookiestr = "{$cookie.name}={$cookie.value}; { ($cookie.fields.map( *.fmt("%s=%s") )).flat.join('; ') }";
        if $cookie.version.defined and $cookie.version >= 1 {
            $cookiestr ~= ',$Version='~ $cookie.version;
        } else {
            $request.field(Cookie2 => '$Version="1"');
        }
        if $request.field('Cookie').defined {
            $request.field( Cookie => $request.field("Cookie") ~ $cookiestr );
        } else {
            $request.field( Cookie => $cookiestr );
        }
    }
}

method save {
    my $fh = open $.file, :w;

    # TODO : add versioning
    $fh.say: "#LWP6-Cookies-0.1";
    $fh.say: self.Str;

    $fh.close;
}

method load {
    for $.file.IO.lines -> $l {
        # we don't need #LWP6-Cookies-$VER
        self.set-cookie($l) unless $l.starts-with('#');
    }
}

method clear-expired {
    @.cookies .= grep({
        ! .expires.defined || .expires !~~ /\d\d/ ||
        # we need more precision
        DateTime::Parse.new( .expires ).Date > Date.today
    });
    self.save if $.autosave;
}

method clear {
    @.cookies = ();
    self.save if $.autosave;
}

method set-cookie($str) {
    my $*OBJ = self;
    HTTP::Cookies::Grammar.parse($str, :actions(HTTP::Cookies::Actions));

    self.save if $.autosave;
}

method push-cookie(HTTP::Cookie $c) {
    @.cookies .= grep({ .name ne $c.name });
    @.cookies.push: $c;

    self.save if $.autosave;
}

method Str {
    @.cookies.map({ "Set-Cookie: $_" }).join("\n");
}

# vim: expandtab shiftwidth=4
