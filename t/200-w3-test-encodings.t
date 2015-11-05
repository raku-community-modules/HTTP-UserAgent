# TODO probably should contain Bufs of data and test HTTP::Message
# directly rather than go over the wire.

use v6;
use HTTP::UserAgent;
use Test;

my @tests = 3..9; # TODO 1 and 2
plan @tests.elems;

unless %*ENV<NETWORK_TESTING> {
    diag "NETWORK_TESTING was not set";
    skip-rest("NETWORK_TESTING was not set");
    exit;
}

my $ua = HTTP::UserAgent.new;

for @tests -> $i {
    my $url = "http://www.w3.org/2006/11/mwbp-tests/test-encoding-{$i}.html";
    my $res =  $ua.get($url);
    ok $res.content ~~ / 'é' /, "got correctly encoded é {$i} from w3.org" or warn :$url.perl;
}

