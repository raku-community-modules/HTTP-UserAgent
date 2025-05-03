#!/usr/bin/env raku
use HTTP::UserAgent :simple;

sub MAIN(Str $url, Str $filename?) {
    my $file = $filename.defined ?? $filename !! get-filename($url);

    say "Saving to '$file'...";

    getstore($url, $file);

    say "{($file.path.s / 1024).fmt("%.1f")} KB received";
}

sub get-filename($url is copy) {
    my $filename;

    $filename = $url.substr($url.chars - 1, 1) eq '/' ??
        'index.html' !! $url.substr($url.rindex('/') + 1);

}

# vim: expandtab shiftwidth=4
