package DBIx::Class::Row::Delta;
use Moose;
use List::MoreUtils qw( uniq );
=head1 NAME

DBIx::Class::Row::Delta - Keep track of and report on changes to a
DBIC row object.

=head1 DESCRIPTION

Record an initial set of values for a DBIC row, and later on get a
string of the changed values.

=head1 SYNOPSIS

  use DBIx::Class::Row::Delta;

  my $shipment = $shipment_rs->find(321);
  my $shipment_notes_delta = NAP::DBIC::Row::Delta->new({
      dbic_row => $shipment,
      changes_sub => sub {
          my ($row) = @_;
          return {
              "Shipment Type"           => $row->shipment_type->type,
              "Shipping Charge"         => $row->shipping_charge->description // "",
              "Shipping SKU"            => $row->shipping_charge->sku,
              "Nominated Delivery Date" => $row->nominated_delivery_date->ymd,
          };
      },
  });

  # ...
  # Do stuff to $shipment, ->update(), etc.
  # ...

  # Note: this will discard_changes on $shipment.
  my $changes_string = $shipment_notes_delta->changes;
  # e.g.
  # Shipment id(321) changed: Shipping Charge(Premier Evening - Zone 1 => Premier Daytime - Zone 1) Shipping SKU (9000021-002 => 9000023-001)

=cut

has dbic_row           => (is => "rw", required => 1);

has changes_sub        => (is => "ro", isa => "CodeRef", required => 1);

has _initial_key_value => (is => "rw", isa => "HashRef", default => sub { +{} });

no Moose;

sub BUILD {
    my ($self, $args) = @_;
    $self->_initial_key_value(
        $self->changes_sub->( $self->dbic_row ),
    );
}

sub changes {
    my $self = shift;
    my $delta_key_value = $self->delta_key_value();
    keys %$delta_key_value or return undef;
    return $self->changes_from_delta($delta_key_value);
}

sub delta_key_value {
    my $self = shift;

    my $dbic_row = $self->dbic_row;
    $dbic_row->discard_changes();
    my $current_key_value = $self->changes_sub->( $dbic_row );

    return $self->diff( $self->_initial_key_value, $current_key_value );
}

sub diff {
    my ($self, $before_key_value, $after_key_value) = @_;
    my %all_keys = ();
    return {
        map { $_ => $after_key_value->{$_} }
        grep { ($after_key_value->{$_} // "") ne ($before_key_value->{$_} // "") }
        uniq(keys %$after_key_value, keys %$before_key_value)
    };
}

sub changes_from_delta {
    my ($self, $delta_key_value) = @_;
    my $initial_key_value = $self->_initial_key_value;
    return join(
        ", ",
        (
            map {
                "$_(" . empty($initial_key_value->{$_}) . " => "
                      . empty($delta_key_value->{$_}) . ")";
            }
            sort keys %$delta_key_value
        ),
    );
}

sub empty {
    my ($value) = @_;
    defined $value or return "''";
    return $value;
}

__PACKAGE__->meta->make_immutable;

1;
