#!perl
package Test::Orphans;

use NAP::policy "tt",'test';

use File::Find::Rule;

my $d = $ENV{'XTDC_BASE_DIR'};

my $cssdir    = "$d/root/static/css/";
my $jsdir     = "$d/root/static/javascript/";

my @cssfiles = File::Find::Rule
    ->name('*.css')
    ->in($cssdir);

my @jsfiles = File::Find::Rule
    ->name('*.js')
    ->in($jsdir);

# Find reference(s) for each css file
for my $cssfile ( @cssfiles ) {
    $cssfile =~ s/$cssdir//;

    # Exclude jQuery plugins and Twitter Bootstrap files
    next if ($cssfile =~ m/^(jquery|bootstrap)/i);

    my @matches = (
        `git grep -l '$cssfile'` ## no critic(ProhibitBacktickOperators)
    );

    ok(@matches, "Found ".@matches." reference(s) for $cssfile");
}

# Find reference(s) for each javascript file
for my $jsfile ( @jsfiles ) {
    $jsfile =~ s/$jsdir//;

    # Exclude jQuery plugins and Twitter Bootstrap files
    next if ($jsfile =~ m/^(jquery|bootstrap)/i);

    my @matches = (
        `git grep -l '$jsfile'` ## no critic(ProhibitBacktickOperators)
    );

    ok(@matches, "Found ".@matches." reference(s) for $jsfile");
}

done_testing();
