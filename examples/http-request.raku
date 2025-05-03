#!/usr/bin/env raku
use HTTP::UserAgent :simple;

sub MAIN($url) {
    getprint($url);
}

# vim: expandtab shiftwidth=4
