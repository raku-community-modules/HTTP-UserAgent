use Test;

use HTTP::Header;

plan 23;

# new
my $h = HTTP::Header.new(a => "A", b => "B");

is ~$h.field('b'), 'B', 'new';

# field
is ~$h.field('a'), 'A', 'field 1/4';

$h.field(a => ['a', 'a1']);
is ~$h.field('a'), 'a, a1', 'field 2/4';

$h.field(a => 'a');
is ~$h.field('a'), 'a', 'field 3/4';

# case insensitive
is ~$h.field('A'), 'a', 'field 4/4';

# init-field
$h.init-field(b => 'b');
is ~$h.field('b'), 'B', 'init-field 1/1';

# push-field
$h.push-field(a => ['a2', 'a3']);
is ~$h.field('a'), 'a, a2, a3', 'push-field 1/1';

# header-field-names
is $h.header-field-names.elems, 2, 'header-field-names 1/3';
is any($h.header-field-names), 'a', 'header-field-names 2/3';
is any($h.header-field-names), 'b', 'header-field-names 3/3';

# Str
is-deeply $h.Str, "a: a, a2, a3\nb: B\n", 'Str 1/2';
is-deeply $h.Str('|'), 'a: a, a2, a3|b: B|', 'Str 2/2';

# remove-field
$h.remove-field('a');
ok not $h.field('a'), 'remove-field 1/1';

# clear
$h.clear;
ok not $h.field('b'), 'clear 1/1';

$h = HTTP::Header.new(One => "one", Two => "two");

is $h.hash<One>, "one", "Got one (hash 1/2)";
is $h.hash<Two>, "two", "Got two (hash 2/2)";

$h = HTTP::Header.new();

lives-ok { $h.parse('ETag: W/"1201-51b0ce7ad3900"') }, "parses ETag";
is ~$h.field('ETag'), "1201-51b0ce7ad3900", "got the value we expected";

lives-ok { $h.parse('expires: Wed, 27 Jan 2016 17:44:43 GMT') }, "parses date on a Wed";
ok $h.field('expires') ~~ /^^Wed/, "Does not trip start of field value starting with 'W'";

# ugexe++ -- See http://irclog.perlgeek.de/perl6/2017-09-27#i_15227591
lives-ok { $h.parse('Custom-Auth-Header: W/7fhEfhkjafeHF') }, "parses ETag like";
is ~$h.field('Custom-Auth-Header'), 'W/7fhEfhkjafeHF', 'got the non truncated value';

subtest {
   my $htest = q:to/EOH/;
Cache-Control: max-age=21600
Connection: close
Date: Mon, 25 Jan 2016 17:44:43 GMT
Accept-Ranges: bytes
ETag: "276-422ea2b4cfcc0"
Server: Apache/2
Vary: upgrade-insecure-requests
Content-Length: 630
Content-Type: text/html
Expires: Mon, 25 Jan 2016 23:44:43 GMT
Last-Modified: Thu, 23 Nov 2006 13:37:31 GMT
Client-Date: Mon, 25 Jan 2016 17:44:43 GMT
Client-Peer: 128.30.52.100:80
Client-Response-Num: 1
Link: </StyleSheets/public>; rel="stylesheet"
P3P: policyref="http://www.w3.org/2014/08/p3p.xml"
Title: Test of a utf8 page served as text/html with UTF8 BOM
EOH
   my $h = HTTP::Header.new;
   $h.parse($htest);
   is $h.fields.elems,17, "got the number of fields we expected";
}, "test full parse of problematic header";
