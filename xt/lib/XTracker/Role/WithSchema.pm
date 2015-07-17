package XTracker::Role::WithSchema;

=head2 NAME

XTracker::Role::WithSchema

=head2 SYNOPSIS

    use NAP::policy "tt", 'class';
    with 'XTracker::Role::WithSchema';

=cut

use Moose::Role;
use Carp;
use Data::Dump qw/pp/;
use XT::Data::Types;

use XTracker::Database 'schema_handle';

has schema => (
    is          => 'rw',
    isa         => 'DBIx::Class::Schema|XT::DC::Messaging::Model::Schema',
    lazy        => 1,
    builder     => 'build_schema',
    clearer     => 'clear_schema',
    trigger     => sub { shift->clear_dbh },
);

has dbh => (
    is          => 'ro',
    isa         => 'DBI::db',
    lazy        => 1,
    clearer     => 'clear_dbh',
    builder     => '_build_dbh',
);

sub build_schema {
    return schema_handle();
}

sub _build_dbh {
    my $self = shift;

    return $self->schema->storage->dbh;
};

sub make_queue_name {
    my($self,$channel, $queue_name) = @_;

    my $row = $self->find_channel($channel);

    # /queue/nap-intl-orders
    return "/queue/". join('-', $row->lc_web_name, $queue_name);

}

sub find_channel {
    my($self,$channel) = @_;

    return $channel
      if blessed($channel) && $channel->isa(XTracker::Schema->class('Public::Channel'));

    my $row = $self->schema->resultset('Public::Channel')->find($channel);

    if (not defined $row) {
        die ref($self) ." - cannot find channel using " . pp($channel);
    }

    return $row;
}

=head2 find_shipping_charge_sku($sku) : ShippingCharge $row or die

Find the ShippingCharge with $sku

=cut

sub find_shipping_charge_sku {
    my ($self, $sku) = @_;
    my $shipping_charge = $self->schema->resultset(
        "Public::ShippingCharge",
    )->find_by_sku($sku) or die("Unknown Shipping Charge SKU ($sku)\n");
    return $shipping_charge;
}

1;
