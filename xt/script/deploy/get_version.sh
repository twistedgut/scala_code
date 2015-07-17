#!/opt/xt/xt-perl/bin/perl

# This script is to overcome the fact that git describe --dirty --tags --abbrev --always
# doesn't return a very correct "version"
# I moved this here since having this inside back ticks in a BEGIN block was overkill not to mention next to impossible
# Ultimately it's ash's fault for having suggested git describe --dirty --tags --abbrev --always 
# and finally dakkar's for coming up with this monster
# I can only be blamed if you use git ;)
use strict;
use warnings;

exit unless -d '.git';

my @lines = qx(git log --decorate=full --topo-order --pretty='format:%h %d' -1000); ## no critic(ProhibitBacktickOperators)

my ($tag,$commits,$hash)=(undef,-1,undef);
for my $l (@lines) {
    ++$commits;
    $l =~ s{\bxt-}{}g; # clean old-style tags
    if ($l =~ m{\brefs/tags/([0-9]{4}\..*?)(?:, |\))}) {
        $tag = $1;
        last;
    }
}
($hash) = qx(git rev-parse --short HEAD);$hash =~ s{\s+}{}g; ## no critic(ProhibitBacktickOperators)

my $ret='';
if ($tag) {
    $ret=$tag;
    if ($commits) {
        $ret .= ".$commits.g$hash";
    }
    open my $fh, '>', 'VERSION';
    print $fh $ret;
}
