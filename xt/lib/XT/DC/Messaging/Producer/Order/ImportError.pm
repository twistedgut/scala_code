package XT::DC::Messaging::Producer::Order::ImportError;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'OrderImportError' );
has '+destination' => ( default => 'overwritten_later' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my ($self, $header, $data )   = @_;

    return (
        { %$header,
            destination => _queue_name($data->{original_message}),
        },
        $data
    );
}

sub _queue_name {
    my $message = shift;

    my $channel = $message->{channel};

    confess "no channel found in message data"
        unless defined $channel;

    # we chould have a channel in the message; use that to work out where to
    # send back to
    my $webname = lc($channel);
    $webname =~ s{\A(\w+)-(\w+)\z}{$2/$1};

    return
        sprintf(
            '/queue/DLQ.%s/order',
            $webname
        );
}
