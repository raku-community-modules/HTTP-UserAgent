unit class HTTP::Message;

use HTTP::Header;
use HTTP::MediaType;
use Encode;

has HTTP::Header $.header = HTTP::Header.new;
has $.content is rw;

has $.protocol is rw = 'HTTP/1.1';

has Bool $.binary = False;
has Str  @.text-types;

my $CRLF = "\r\n";

method new($content?, *%fields) {
    my $header = HTTP::Header.new(|%fields);

    self.bless(:$header, :$content);
}

method add-content($content) {
    $.content ~= $content;
}

class X::Decoding is Exception {
    has HTTP::Message $.response;
    has Blob $.content;
    method message() {
        "Problem decoding content";
    }
}

method content-type(--> Str:D) {
    $!header.field('Content-Type').values[0] || '';
}

has HTTP::MediaType $!media-type;

method media-type(--> HTTP::MediaType) {
    without $!media-type { 
        if self.content-type() -> $ct {
            $!media-type = HTTP::MediaType.parse($ct);
        }
    }
    $!media-type
}

# Don't want to put the heuristic in the HTTP::MediaType
# Also moving this here makes it much more easy to test

method charset(--> Str:D) {
    if self.media-type -> $mt {
        $mt.charset || ( $mt.major-type eq 'text' ?? $mt.sub-type eq 'html' ?? 'utf-8' !! 'iso-8859-1' !! 'utf-8');
    }
    else {
        # At this point we're probably screwed anyway
        'iso-8859-1'
    }
}

# This is already a candidate for refactoring
# Just want to get it working
method is-text(--> Bool:D) {
    if $!binary {
        False
    }
    elsif self.media-type -> $mt {
        if $mt.type ~~ any(@!text-types) {
            True
        }
        else {
            given $mt.major-type {
                when 'text' {
                    True
                }
                when any(<image audio video>) {
                    False
                }
                when 'application' {
                    given $mt.sub-type {
                        when /xml|javascript|json/ {
                            True
                        }
                        default {
                            False
                        }
                    }
                }
                default {
                    # Not sure about this
                    True
                }
            }
        }
    }
    else {
        # No content type, try and blow up
        True
    }
}

method is-binary(--> Bool:D) { !self.is-text }

method content-encoding() {
    $!header.field('Content-Encoding');
}

class X::Deflate is Exception {
    has Str $.message;
}

method inflate-content(--> Blob:D) {
    if self.content-encoding -> $v is copy {
        # This is a guess
        $v = 'zlib' if $v eq 'compress' ;
        $v = 'zlib' if $v eq 'deflate';
        try require ::('Compress::Zlib');
        if ::('Compress::Zlib::Stream') ~~ Failure {
            X::Deflate.new(message => "Please install 'Compress::Zlib' to uncompress '$v' encoded content").throw;
        }
        else {
            my $z = ::('Compress::Zlib::Stream').new( |{ $v => True });
            $z.inflate($!content);
        }
    }
    else {
        $!content;
    }
}

method decoded-content(:$bin) {
    return $!content if $!content ~~ Str || $!content.bytes == 0;

    my $content = self.inflate-content;
    # [todo]
    # If charset is missing from Content-Type, then before defaulting
    # to anything it should attempt to extract it from $.content like (for HTML):
    # <meta charset="UTF-8"> 
    # <meta http-equiv="content-type" content="text/html; charset=UTF-8">
    
    my $decoded_content;

    if !$bin && self.is-text {
        my $charset = self.charset;
        $decoded_content = try {
            Encode::decode($charset, $content);
        } || try {
            $content.decode('iso-8859-1');
        } || try { 
            $content.unpack("A*") 
        } || X::Decoding.new(content => $content, response => self).throw;
    }
    else {
        $decoded_content = $content;
    }

    $decoded_content
}

multi method field(Str $f) {
    $.header.field($f)
}

multi method field(*%fields) {
    $.header.field(|%fields)
}

method push-field(*%fields) {
    $.header.push-field(|%fields)
}

method remove-field(Str $field) {
    $.header.remove-field($field)
}

method clear {
    $.header.clear;
    $.content = ''
}

method parse($raw_message) {
    my @lines = $raw_message.split(/$CRLF/);

    my ($first, $second, $third) = @lines.shift.split(/\s+/);

    if $third.index('/') { # is a request
        $.protocol = $third;
    }
    else {               # is a response
        $.protocol = $first;
    }

    loop {
        last until @lines;

        my $line = @lines.shift;
        if $line {
            my ($k, $v) = $line.split(/\:\s*/, 2);
            if $k and $v {
                if $.header.field($k) {
                    $.header.push-field: |($k => $v.split(',')>>.trim);
                } else {
                    $.header.field: |($k => $v.split(',')>>.trim);
                }
            }
        } else {
            $.content = @lines.grep({ $_ }).join("\n");
            last;
        }
    }

    self
}

method Str($eol = "\n", :$debug, Bool :$bin) {
    my constant $max_size = 300;
    my $s = $.header.Str($eol);
    $s ~= $eol if $.content;
    
    # The :bin will be passed from the H::UA
    if not $bin {
        $s ~=  $.content ~ $eol if $.content and !$debug;
    }
    if $.content and $debug {
        if $bin || self.is-binary {
            $s ~= $eol ~ "=Content size : " ~ $.content.elems ~ " bytes ";
            $s ~= "$eol ** Not showing binary content ** $eol";
        }
        else {
            $s ~= $eol ~ "=Content size: "~$.content.Str.chars~" chars";
            $s ~= "- Displaying only $max_size" if $.content.Str.chars > $max_size;
            $s ~= $eol ~ $.content.Str.substr(0, $max_size) ~ $eol;
        }
    }

    $s
}

# vim: expandtab shiftwidth=4
