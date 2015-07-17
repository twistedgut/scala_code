package XTracker::WebContent::Roles::StockManagerWithMessages;
use NAP::policy "tt", 'role';
with 'XTracker::Role::WithAMQMessageFactory';
use XTracker::Logfile 'xt_logger';

has message_type => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);

has _messages => (
    is          => 'ro',
    isa         => 'ArrayRef[HashRef]',
    init_arg    => undef, # not settable in constructor
    default     => sub {[]},
    traits      => ['Array'],
    handles     => {
        _add_to_messages    => 'push',
        _get_next_message   => 'shift',
        _clear_messages     => 'clear',
    },
);

sub commit {
    my ($self) = @_;

    $self->_send_messages;
    return;
}

sub rollback {
    my $self = shift;

    $self->_clear_messages;
    return;
}

sub _send_messages {
    my ( $self )    = shift;

    my $amq = $self->msg_factory;

    while (my $message = $self->_get_next_message) {
        try {
            my $msg_type = delete $message->{type} || $self->message_type;

            $amq->transform_and_send( $msg_type, $message);
        }
        catch {
            xt_logger()->warn($_);
        };
    }

    return;
}
