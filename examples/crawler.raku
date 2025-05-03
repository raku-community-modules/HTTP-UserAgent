#!/usr/bin/env raku
use HTTP::UserAgent;

sub MAIN(Str $start_url) {
    my $c = HTTP::UserAgent.new(:useragent<chrome_linux>);

    my $content = $c.get($start_url).content;

    my @urls = get-urls($content);

    while my $url = @urls.shift {
        print "trying: $url ... ";
        try {
            my $r = $c.get(~$url);
            CATCH {
                when X::HTTP {
                    say '[ALMOST OK - X::HTTP exception]';
                }

                say '[NOT OK]';
            }
            default {
                say '[OK]';

                $content = $r.content;
                if $content ~~ Str {
                    #say ~$r.header;
                    #say $content;
                    my @new_url = get-urls($content);
                    @urls.push($_) unless $_ ~~ any(@urls) for @new_url;
                }
            }
        }
    }
}

sub get-urls($content) {
    $content.match(/ \s 'href="' (<-["]>+) '"' /, :g).map({ $_[0] }).grep( rx:i/^http/ );
}

# vim: expandtab shiftwidth=4
