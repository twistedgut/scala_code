package XT::DC::Messaging::Producer::Order::ImportStatus;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'OrderImportStatus' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my ($self, $header, $data )   = @_;

    # we only use the message for working out where to send the response; the
    # webapp doesn't need this. In fact sending it makes their life much more
    # difficult, so we'll just nuke it in the transform
    my $message = delete $data->{message};

    return (
        { %$header,
            destination => _queue_name($message),
        },
        $data
    );
}

=for an explanation

I don't remember when this was agreed, but I assume I agreed to this before I
knew any better.

    On 2/7/12 9:53 AM, Lucelia Siqueira wrote:
    > i Chisel,
    >
    > We agreed before on:
    > intl/mrp/order-status
    > am/mrp/order-status
    >
    > Cheers
    > Lu
    >
    > Chisel wrote:
    >> I'm an idiot - can you remind me what queue(s) you're expecting
    >> success/fail responses on?

This explains why we're not (yet) using something nice like
lc($order->channel->web_name)

Chisel (2012-02-07)

=cut

sub _queue_name {
    my $message = shift;

    my $channel = $message->{channel};

    confess "no channel found in message data"
        unless defined $channel;

    return $channel;
}
