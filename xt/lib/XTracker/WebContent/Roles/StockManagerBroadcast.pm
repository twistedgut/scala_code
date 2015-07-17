package XTracker::WebContent::Roles::StockManagerBroadcast;
use NAP::policy "tt", 'role';
use XTracker::WebContent::StockManagement::Broadcast;

has _broadcast_delegate => (
    isa => 'XTracker::WebContent::StockManagement::Broadcast',
    is => 'ro',
    lazy_build => 1,
);
sub _build__broadcast_delegate {
    my ($self) = @_;
    XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $self->schema,
        channel_id => $self->channel_id,
        channel => $self->channel,
    });
}

after stock_update => sub {
    my ($self,@args) = @_;
    $self->_broadcast_delegate->stock_update(@args);
};

after commit => sub {
    my ($self,@args) = @_;
    $self->_broadcast_delegate->commit(@args);
};

after rollback => sub {
    my ($self,@args) = @_;
    $self->_broadcast_delegate->rollback(@args);
};

1;
