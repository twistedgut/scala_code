package XT::DC::Messaging::Producer::PRL::PrepareStockFile;
use NAP::policy "tt", 'class';

use XT::DC::Messaging::Spec::PRL;

use XTracker::Constants qw/:prl_type/;
use MooseX::Params::Validate;
use XT::Domain::PRLs;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithPRLs';

=head1 NAME

XT::DC::Messaging::Producer::PRL::PrepareStockFile;

=head1 DESCRIPTION

Sends C<PrepareStockFile> message to PRL.

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::PrepareStockFile' => {
            request_id => $SomeID,
            prl_name   => 'Dematic'
        }
    );

=head1 METHODS

=cut

has '+type' => ( default => 'prepare_stock_file' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->prepare_stock_file();
}

=head2 transform

Accepts the AMQ header from the message producer

=cut

sub transform {
    my ( $self, $header, $args ) = @_;

    my $message = {
        request_id => $self->clean_id( $args->{request_id} ),
    };

    # Pack in AMQ cruft
    my @message_parts = $self->amq_cruft({
        header       => $header,
        payload      => $message,
        destinations => [
            XT::Domain::PRLs::get_amq_queue_from_prl_name({
                prl_name => $args->{prl_name},
            }),
        ],
    });
    return @message_parts;
}

=head2 clean_id($id) : $cleaned_id

Return the value of $id, but without any invalid chars (chars invalid
for a Windows file name, but keep known valid ones instead for
resilience).

=cut

sub clean_id {
    my ($self, $id) = @_;
    return $id =~ s{[^\w.-]}{}gsmr;
}

