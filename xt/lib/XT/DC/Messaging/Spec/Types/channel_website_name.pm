package XT::DC::Messaging::Spec::Types::channel_website_name;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

# This is a _ridiculous_ state of affairs. This is the same as
# RxType::channel, but with a _ instead of - , and always force
# uppercase like it needs to be, and the short OUT name instead of
# OUTNET.
#
# Hopefully we can unify these two and have "channel" work like this
# one, because that's the format it looks like the website consumers
# want.

sub type_uri {
    sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'channel_website_name' };

my @brands  = qw( NAP MRP OUT JC );
my @markets = qw( AM INTL APAC );

my %valid_names=( );

foreach my $brand ( @brands ) {
    foreach my $market ( @markets ) {
        $valid_names{ "${brand}_${market}" } = 1;
    }
}

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_names{$value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid channel website name',
        value   => $value,
    });
}

1;
