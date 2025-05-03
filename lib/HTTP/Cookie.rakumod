unit class HTTP::Cookie;

has $.name is rw;
has $.value is rw;
has $.secure is rw;
has $.httponly is rw;
has $.path is rw;
has $.domain is rw;
has $.version is rw;
has $.expires is rw;

has %.fields;

method Str {
    my $s = "$.name=$.value";
    $s ~= "; Domain=$.domain" if $.domain;
    $s ~= "; Version=$.version" if $.version;
    $s ~= "; Path=$.path" if $.path;
    $s ~= "; Expires=$.expires" if $.expires;
    $s ~= ';' ~ (%.fields.map( *.fmt("%s=%s") )).flat.join('; ') if %.fields.elems > 1;
    $s ~= "; $.secure" if $.secure;
    $s ~= "; $.httponly" if $.httponly;
    $s
}

# vim: expandtab shiftwidth=4
