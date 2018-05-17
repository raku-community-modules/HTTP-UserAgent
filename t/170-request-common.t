use v6.c;
use Test;

use URI;

use HTTP::Request::Common;

subtest {
    subtest {
        my $req = POST(
            'http://127.0.0.1/',
            {
                foo => "b&r",
                x   => ['t/dat/foo.txt'],
            },
            content-type => 'multipart/form-data; boundary=XxYyZ'
        );
        todo("issue with line endings on travis");
        is-deeply $req.Str.encode, slurp("t/dat/multipart-1.dat", :bin);
    }, 'uri';
}, 'POST(multi-part)';

subtest {
    subtest {
        my $req = POST(URI.new('http://127.0.0.1/'), {
            foo => "b&r\x1F42B",
        });
        is $req.method, 'POST';
        is $req.header.field('content-type'), 'application/x-www-form-urlencoded';
        is $req.header.field('content-length'), '21';
        is $req.content.decode, 'foo=b%26r%F0%9F%90%AB';
    }, 'uri';
    subtest {
        my $req = POST(
            'http://127.0.0.1/',
            content => [
                foo => "b&r\x1F42B",
            ],
            X-Foo => 'Bar');
        is $req.method, 'POST';
        is $req.header.field('content-type'), 'application/x-www-form-urlencoded';
        is $req.header.field('content-length'), '21';
        is $req.header.field('X-Foo'), 'Bar';
        is $req.content.decode, 'foo=b%26r%F0%9F%90%AB';
    }, 'content by array';
    subtest {
       my $req = POST('http://127.0.0.1/',
                 content => "bumble",
                 Content-Type => "text/plain");
       is $req.content.encode, "bumble";
       is $req.header.field('content-length'), 6;
       is $req.header.field('Content-Type'), "text/plain";
    }
}, 'POST';

subtest {
    subtest {
        my $req = GET URI.new('http://127.0.0.1/');
        is $req.method, 'GET';
    }, 'URI';
    subtest {
        my $req = GET 'http://127.0.0.1/';
        is $req.method, 'GET';
    }, 'Str';
    subtest {
        my $req = GET 'http://127.0.0.1/',
            X-Foo => 'Bar';
        is $req.method, 'GET';
        is $req.header.field('X-Foo'), 'Bar';
    }, 'header';
}, 'GET';

subtest {
    subtest {
        my $req = PUT 'http://127.0.0.1/',
            X-Foo => 'Bar',
            content => 'Yeah!';
        is $req.method, 'PUT';
        is $req.header.field('X-Foo'), 'Bar';
        is $req.content, 'Yeah!';
    }, 'header';
}, 'PUT';

subtest {
    subtest {
        my $req = DELETE 'http://127.0.0.1/',
            X-Foo => 'Bar';
        is $req.method, 'DELETE';
        is $req.header.field('X-Foo'), 'Bar';
    }, 'header';
}, 'DELETE';

subtest {
    subtest {
        my $req = HEAD 'http://127.0.0.1/',
            X-Foo => 'Bar';
        is $req.method, 'HEAD';
        is $req.header.field('X-Foo'), 'Bar';
    }, 'header';
}, 'HEAD';

subtest {
    subtest {
        my $req = PATCH 'http://127.0.0.1/',
            X-Foo => 'Bar',
            content => 'Yeah!';
        is $req.method, 'PATCH';
        is $req.header.field('X-Foo'), 'Bar';
        is $req.content, 'Yeah!';
    }, 'header';
}, 'PATCH';

done-testing;
