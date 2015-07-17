package XT::Order::Role::Parser::Common::CustomerData;

use Moose::Role;
use XT::Data::CustomerName;

sub _get_name {
    my ( $self, $data ) = @_;

    die 'Requires a hash reference containing customer or delivery data'
        unless $data and ref( $data ) eq 'HASH';

    my $name = XT::Data::CustomerName->new({
        title       => $data->{'title'},
        first_name  => $data->{'first_name'},
        last_name   => $data->{'last_name'},
    });

    return $name;
}

1;
