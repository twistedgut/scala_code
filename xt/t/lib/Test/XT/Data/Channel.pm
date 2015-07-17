package Test::XT::Data::Channel;

use NAP::policy "tt",     qw( test role );

requires 'schema';

#
# Provide a Sales Channel
#
use XTracker::Config::Local;
use Test::XTracker::Data;


use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });

has channel => (
    is          => 'rw',
    lazy        => 1,
    builder     => '_set_channel',
);

# Get a Sales Channel
#
sub _set_channel{
    my $self    = shift;

    # default to NaP Channel
    return Test::XTracker::Data->channel_for_nap();
}

1;
