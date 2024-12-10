#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw( $Bin );

use File::Path qw( mkpath );

sub main {
    my $target = shift || "$Bin/..";

    my @translators = qw ( lowdown pandoc );
    my $translator;
    foreach my $p (@translators) {
        if ( _which($p) ) {
            $translator = $p;
            last;
        }
    }
    unless ( defined $translator ) {
        die "\n  You must install one of "
            . join( ', ', @translators )
            . " in order to generate the man pages.\n\n";
    }

    _make_man( $translator, $target, 'libmaxminddb', 3 );
    _make_lib_man_links($target);

    _make_man( $translator, $target, 'mmdblookup', 1 );
}

sub _which {
    my $program = shift;
    for my $path ( split /:/, $ENV{PATH} ) {
        return 1 if -x "$path/$program";
    }
    return 0;
}

sub _make_man {
    my $translator = shift;
    my $target     = shift;
    my $name       = shift;
    my $section    = shift;

    my $input   = "$Bin/../doc/$name.md";
    my $man_dir = "$target/man/man$section";
    mkpath($man_dir);
    my $output = "$man_dir/$name.$section";

    if ( $translator eq 'pandoc' ) {
        system(
            'pandoc',
            '-s',
            '-f', 'markdown_mmd+backtick_code_blocks',
            '-t', 'man',
            '-M', "title:$name",
            '-M', "section:$section",
            $input,
            '-o', $output,
        ) == 0 or die "Failed to run pandoc: $!";
        _pandoc_postprocess($output);
    }
    elsif ( $translator eq 'lowdown' ) {
        system(
            'lowdown',
            '-s',
            '--out-no-smarty',
            '-Tman',
            '-M', "title:$name",
            '-M', "section:$section",
            $input,
            '-o', $output,
        ) == 0 or die "Failed to run lowdown: $!";
    }
}

sub _make_lib_man_links {
    my $target = shift;

    open my $header_fh, '<', "$Bin/../include/maxminddb.h"
        or die "Failed to open header file: $!";
    my $header = do { local $/; <$header_fh> };
    close $header_fh or die "Failed to close header file: $!";

    for my $proto ( $header =~ /^ *extern.+?(MMDB_\w+)\(/gsm ) {
        open my $fh, '>', "$target/man/man3/$proto.3"
            or die "Failed to open file: $!";
        print {$fh} ".so man3/libmaxminddb.3\n"
            or die "Failed to write to file: $!";
        close $fh or die "Failed to close file: $!";
    }
}

# AFAICT there's no way to control the indentation depth for code blocks with
# Pandoc.
sub _pandoc_postprocess {
    my $file = shift;

    open my $fh, '<', $file or die "Failed to open man file for reading: $!";
    my @lines = <$fh>;
    close $fh or die "Failed to close file: $!";

    for my $line (@lines) {
        $line =~ s/^\.IP\n\.nf/.IP "" 4\n.nf/gm;
        $line =~ s/(Automatically generated by Pandoc)(.+)$/$1/m;
    }

    open $fh, '>', $file or die "Failed to open file for writing: $!";
    print $fh @lines or die "Failed to write to file: $!";
    close $fh        or die "Failed to close file: $!";
}

main(shift);
