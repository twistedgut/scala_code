package XT::DC::Messaging::Producer::ProductService::MassSetField;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer',
    # these are to appease XT's message queue "custom accessors"
    'XTracker::Role::WithIWSRolloutPhase',
    'XTracker::Role::WithPRLs',
    'XTracker::Role::WithSchema';

use XTracker::Config::Local 'config_var';
use XTracker::Logfile qw( xt_logger );

use JSON::XS;

sub message_spec {
    return {
        type => '//rec',
        required => {
            products => {
                type => '//arr',
                length => { min => 1 },
                contents => {
                    type => '//rec',
                    required => {
                        product_id => '//int',
                        channel_id => '//int',
                    },
                },
            },
            fields => {
                type => '//map',
                values => '//any',
            },
        },
        optional => {
            create_missing => '//bool',
            opts => {
                type => '//map',
                values => '//any',
            },
        },
    };
}

has '+type' => ( default => 'mass_set_field' );

sub transform {
    my ($self,$header,$data) = @_;

    croak "Products required" unless $data->{products};

    my $logger = xt_logger();

    $logger->debug('Sending a MassSetField message for '
        . scalar @{$data->{products}} . " product(s)");

    # Buld the payload
    my $payload;

    $payload->{products} = $data->{products};
    $payload->{fields} = $data->{fields};
    # Force creation of the document if it doesn't exist
    $payload->{create_missing} = JSON::XS::true;

    $header->{staging} = 1;
    $header->{live} = $data->{live};

    return ( $header, $payload );
}


