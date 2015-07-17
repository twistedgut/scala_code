package XT::DC::Messaging::Producer::Correspondence::SMS;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

use Carp                        qw( croak );

=head1 NAME

XT::DC::Messaging::Producer::Correspondence::SMS - for sending SMS Messages via the SMS Proxy on the Integration Service

=head1 METHODS

=head2 C<message_spec>

L<Data::Rx> spec for the ActiveMQ message.

=cut

has '+type' => ( default => 'SMSMessage' );

sub message_spec {
    return {
        type        => '//rec',
        required    => {
            id              => '//str',
            salesChannel    => '//str',
            message     => {
                    type        => '//rec',
                    required    => {
                        body        => '//str',
                        from        => '//str',
                        phoneNumber => '//str',
                    },
                },
            },
        };
}

=head2 C<transform>

    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Correspondence::SMS', {
                message_id  => 'Will be Sent back by the SMS Proxy in the Return Message',
                channel     => $channel_obj,
                message     => 'the message text to send',
                phone       => '+44567890123',
                from        => 'will appear as the Sender on the customer's phone',
        } );

Will send an SMS Text to a Phone Number by sending an AMQ Message to the SMS Proxy in the Integration Service.

Will send the AMQ message on the 'sms_broadcast' queue in the 'CORRESPONDENCE_Queues' config section.

=cut

sub transform {
    my ( $self, $header, $data )    = @_;

    if ( !$data || ref( $data ) ne 'HASH' ) {
        croak "Must pass Arguments to Producer '" . __PACKAGE__ . "'";
    }
    # make sure everything required has been passed in
    foreach my $field ( qw(
                            message_id
                            channel
                            message
                            phone
                            from
                    ) ) {
        # can't find the field or it's empty
        if ( !exists( $data->{ $field } ) || !$data->{ $field } ) {
            croak "Missing or Empty '$field' in Arguments passed to Producer '" . __PACKAGE__ . "'";
        }
    }

    my $payload = {
            id      => $data->{message_id},
            message => {
                    body        => $data->{message},
                    from        => $data->{from},
                    phoneNumber => $data->{phone},
                },
        };

    $payload->{salesChannel} = $data->{channel}->website_name;

    return ( $header, $payload );
}

1;
