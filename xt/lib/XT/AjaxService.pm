package XT::AjaxService;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use JSON;

use base qw/ XT::Service /;

#our @EXPORT_OK = ( qw/$OK $FAILED/ );
use Plack::App::FakeApache1::Constants qw(:common);

use Class::Std;
{

    my %response_of     :ATTR( get => 'response', set => 'response' );

    sub START {
        my($self) = @_;

        $self->set_response({});

        return;
    }

    sub toJson {
        my($self) = @_;

        return encode_json( $self->get_response );
    }

    sub return_response {
        my($self) = @_;
        my $handler = $self->get_handler;

        $handler->{request}->print( $self->toJson );

        xt_logger->debug( $self->toJson ) if ( $self->debug );

        return OK;
    }
}
1;

__END__

=pod

=head1 NAME

XT::Tier::Service;

=head1 AUTHOR

Jason Tang

=cut

