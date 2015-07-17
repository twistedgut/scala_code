package XT::DC::Messaging::Spec::Types::channel;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'channel' };

my @brands  = qw( nap mrp outnet out jc );
my @markets = qw( am intl apac );

my %valid_names=( );

foreach my $brand ( @brands ) {
    foreach my $market ( @markets ) {
        $valid_names{"$brand-$market"} = 1;
    }
}

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_names{lc $value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid channel',
        value   => $value,
    });
}

1;
