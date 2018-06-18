use HTTP::Request;
use Test;

use URI;

plan 28;

my $url = 'http://testsite.ext/cat/f.h?q=1&q=2';
my $file = '/cat/f.h?q=1&q=2';
my $host = 'testsite.ext';

# new
my $r1 = HTTP::Request.new(POST => $url, test_field => 'this_is_field');

is $r1.method, 'post'.uc, 'new 1/8';
is $r1.url, $url, 'new 2/8';
is $r1.file, $file, 'new 3/8';
is $r1.field('Host'), $host, 'new 4/8';
is $r1.field('test_field'), 'this_is_field', 'new 5/8';
ok $r1.Str ~~ /^POST\s$file/, 'new 6/8';
isa-ok $r1, HTTP::Request, 'new 7/8';
isa-ok $r1, HTTP::Message, 'new 8/8';

# content
$r1.add-content('n1=v1&a');
is $r1.content, 'n1=v1&a', 'content 1/1';

# field
$r1.field(Accept => 'test');
is $r1.field('Accept'), 'test', 'field 1/2';
$r1.field(Accept => 'test2');
is $r1.field('Accept'), 'test2', 'field 2/2';

# uri
$file = '/cat/b.a?r=1&r=2';
$r1.uri('http://test.com' ~ $file);
is $r1.url, 'http://test.com' ~ $file, 'uri 1/4';
is $r1.field('Host'), 'test.com', 'uri 2/4';
is $r1.file, $file, 'uri 3/4';
ok $r1.Str ~~ /^POST\s$file/, 'uri 4/4';

# check construction of host header
$r1.uri('http://test.com:8080');
is $r1.url, 'http://test.com:8080', 'uri 3/4';
is $r1.field('Host'), 'test.com:8080', 'uri 4/4';

# set-method
throws-like({ $r1.set-method: 'TEST' }, /'expected HTTP::Request::RequestMethod but got Str'/, "rejects wrong method");
lives-ok { $r1.set-method: 'PUT' }, "set method";
is $r1.method, 'PUT', 'set-method 1/1';

# parse
my $req = "GET /index HTTP/1.1\r\nHost: somesite\r\nAccept: test\r\n\r\nname=value&a=b\r\n";
$r1 = HTTP::Request.new.parse($req);

is $r1.method, 'get'.uc, 'parse 1/6';
is $r1.file, '/index', 'parse 2/6';
is $r1.url, 'http://somesite/index', 'parse 3/6';
is $r1.field('Accept'), 'test', 'parse 4/6';
is $r1.content, 'name=value&a=b', 'parse 5/6';
is $r1.Str, $req, 'parse 6/6';

subtest {
   my $r;
   lives-ok { $r = HTTP::Request.new('GET', URI.new('http://foo.com/bar'), HTTP::Header.new(Foo => 'bar') ) }, "mew with positionals";
   is $r.method, 'GET', "right method";
   is $r.file, '/bar', "right file";
   is $r.field('Host'), 'foo.com', 'got right host';
}, "positional construcutor";

subtest {
    subtest {
        my $req = HTTP::Request.new(POST => URI.new('http://127.0.0.1/'));
        lives-ok { $req.add-form-data({ foo => "b&r\x1F42B", }) }, "add-form-data";
        is $req.method, 'POST';
        is $req.header.field('content-type'), 'application/x-www-form-urlencoded';
        is $req.header.field('content-length'), '21';
        is $req.content.decode, 'foo=b%26r%F0%9F%90%AB';
    }, 'add-form-data with positional Hash';
    subtest {
        my $req = HTTP::Request.new(POST => URI.new('http://127.0.0.1/'));
        lives-ok { $req.add-form-data( foo => "b&r\x1F42B", ) }, "add-form-data";
        is $req.method, 'POST';
        is $req.header.field('content-type'), 'application/x-www-form-urlencoded';
        is $req.header.field('content-length'), '21';
        is $req.content.decode, 'foo=b%26r%F0%9F%90%AB';
    }, 'add-form-data with slurpy hash';
    subtest {
        my $req = HTTP::Request.new(POST => 'http://127.0.0.1/', X-Foo => 'Bar');
        lives-ok { $req.add-form-data([foo => "b&r\x1F42B",]) }, "add-form-data with array of pairs";
        is $req.method, 'POST';
        is $req.header.field('content-type'), 'application/x-www-form-urlencoded';
        is $req.header.field('content-length'), '21';
        is $req.header.field('X-Foo'), 'Bar';
        is $req.content.decode, 'foo=b%26r%F0%9F%90%AB';
    }, 'content by array';
    subtest {
        # need to set the host up front so it compares with the data nicely
        my $req = HTTP::Request.new(POST => 'http://127.0.0.1/', Host => '127.0.0.1', content-type => 'multipart/form-data; boundary=XxYyZ');
        lives-ok { $req.add-form-data({ foo => "b&r", x   => ['t/dat/foo.txt'], }) }, "add-form-data";
        todo("issue seen on travis regarding line endings");
        is-deeply Buf[uint8].new($req.Str.encode), slurp("t/dat/multipart-1.dat", :bin);
    }, 'multipart implied by existing content-type';
    subtest {
        my $req = HTTP::Request.new(POST => 'http://127.0.0.1/');
        lives-ok { $req.add-form-data({ foo => "b&r", x   => ['t/dat/foo.txt'], }, :multipart) }, "add-form-data";
        like $req.header.field('content-type').Str, /"multipart\/form-data"/, "and got multipart data";
    }, 'multipart explicit';
    subtest {
        my $req = HTTP::Request.new(POST => 'http://127.0.0.1/');
        lives-ok { $req.add-form-data( foo => "b&r", x   => ['t/dat/foo.txt'], :multipart) }, "add-form-data";
        like $req.header.field('content-type').Str, /"multipart\/form-data"/, "and got multipart data";
    }, 'multipart explicit with slurpy hash (check no gobble adverb)';
}, 'add-form-data';
# vim: expandtab shiftwidth=4 ft=perl6
