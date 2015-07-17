package XT::DC::Messaging::Producer::Sync::HSCode;
use NAP::policy "tt", 'class';
    with 'XT::DC::Messaging::Role::Producer';

use XTracker::Config::Local qw/ config_var /;
use Data::Dump qw/ pp /;

sub message_spec {
    return {
        type => '//rec',

        required => {
            hs_code => '//int',
        },
    };
}

has '+type' => ( default => 'hs_create' );

=head2 transform

This is the payload for transfering new HS Codes from DC to FUL.

=cut

sub transform {
    my ( $self, $header, $data ) = @_;

    return ( $header, $data );
}

1;
