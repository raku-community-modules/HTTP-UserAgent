#!/usr/bin/env raku
use HTTP::UserAgent;

sub MAIN($url) {
    my $response = HTTP::UserAgent.new.get($url);
    say ~$response.header;
    my $content = $response.decoded-content;
    if $content.elems > 800 {
        say "{$content.substr(0, 800)}...";
        $content .= substr(800);
        say "(+ {$content.encode('utf8').bytes} bytes not shown)";
    }
    else {
        $content.say;
    }
}

# vim: expandtab shiftwidth=4
