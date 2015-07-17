package XT::DC::Messaging::Producer::Return::RequestError;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

=head1 NAME

XT::DC::Messaging::Producer::Return::RequestError

=head1 DESCRIPTION

This is the base class used for sending messages back when a Return Request
fails.

It should be extended for specific Brands:

XT::DC::Messaging::Producer::Return::RequestError::*

Thereby allowing for different Queue names to be used in the Config and not
being changed dynamically in this Class.

=cut

use XTracker::Config::Local     qw( config_var );

has '+type' => ( default => 'return_request_ack' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my ($self, $header, $data )   = @_;

    confess "No error in passed args hashref" unless $data->{errors};

    my $error = $data->{errors};

    # The error will be an array ref or a string. Ensure we remove any
    # code paths from exception strings.
    if ( ref $error && ref $error eq 'ARRAY' ) {
        my $new_error = [];
        foreach my $str ( @{ $error } ) {
            push @{ $new_error }, $self->_truncate_exception_string( $str );
        }
        $error = $new_error;
    }
    else {
        $error = $self->_truncate_exception_string( $error );
    }

    my $response = {
        status              => "failure",
        returnRequestDate   => $data->{original_message}->{returnRequestDate},
        orderNumber         => $data->{original_message}->{orderNumber},
        channel             => $data->{original_message}->{channel},
        error               => $error,
    };

    return ( $header, $response );
}

sub _truncate_exception_string {
    my ( $self, $data ) = @_;

    return unless $data;

    my $xtdc_base_path = config_var( 'SystemPaths', 'xtdc_base_dir' );

    if ( ref $data && ref $data eq 'ARRAY' ) {
    }
    else {
        if ( $data =~ /(?<truncated_error>.*) at $xtdc_base_path/ ) {
            $data = $+{truncated_error};
        }
    }

    return $data;
}
