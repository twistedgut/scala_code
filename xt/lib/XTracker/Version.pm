package XTracker::Version;
use strict;
use warnings;
use Path::Class;

our $VERSION;

BEGIN {
    # we get something like ' (refs/tags/xt-2.12.01, refs/heads/pre-release/RB-2.12)'
    my $git_refs = '$Format:%d$';
    my ($refs)=($git_refs =~ m{\A\s* \( (.*) \) \s*\z}smx);

    my $basedir=file(__FILE__)
        ->parent # XTracker
        ->parent # lib
        ->parent; # xt root
    my $verfile=$basedir->file('VERSION');

    # Load from the VERSION file.
    if ( -e $verfile ) {
        $VERSION = $verfile->slurp(chomp => 1);
        $VERSION =~ s/-/\./g;
    }
    elsif ( defined $refs ) {
        my @refs=split /\s*,\s*/,$refs;

        my @tags=map { m{\A(?:refs/tags/)?([0-9].*)\z} ? $1 : () } @refs;
        my @branches=map { m{\A(?:refs/heads/)?pre-release/RB-(.*)\z} ? $1 : () } @refs;

        $VERSION = $tags[0] || $branches[0];
    }

    $VERSION ||= 'master';
}

1;
