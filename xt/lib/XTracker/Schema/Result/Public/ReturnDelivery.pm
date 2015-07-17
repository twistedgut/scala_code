use utf8;
package XTracker::Schema::Result::Public::ReturnDelivery;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.return_delivery");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "return_delivery_id_seq",
  },
  "confirmed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "date_confirmed",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "date_created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "created_by",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "return_arrivals",
  "XTracker::Schema::Result::Public::ReturnArrival",
  { "foreign.return_delivery_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZWm9t5E+RV6O2cJlCCl4gA

use Carp;

=head2 add_arrival( $awb, $operator_id ) : $return_arrival_row

Create a return arrival for the given air waybill and add it to this delivery.

=cut

sub add_arrival {
    my ( $self, $awb, $operator_id ) = @_;

    my $schema = $self->result_source->schema;
    return $schema->txn_do(sub{
        # The AWB has already been entered
        croak "AWB: $awb already exists"
            if $schema->resultset('Public::ReturnArrival')
                      ->find({ return_airway_bill => $awb });

        # Create the new return arrival row
        my $return_arrival = $self->add_to_return_arrivals({
            return_airway_bill => $awb,
            operator_id        => $operator_id,
        });

        # Find all shipment associated with this return arrival and populate
        # link_return_arrival__shipment
        $return_arrival->create_related(
            link_return_arrival__shipments => { shipment_id => $_ }
        ) for $return_arrival->return_awb_shipments->get_column('id')->all;

        return $return_arrival;
    });
}

=head2 total_packages() : $package_count

Return the total number of packages for the arrivals in this delivery.

=cut

sub total_packages {
    return $_[0]->return_arrivals->get_column('packages')->sum//0;
}

=head2 confirm($operator_id) : $dbic_row

Confirm the return delivery.

=cut

sub confirm {
    my ( $self, $operator_id ) = @_;
    croak 'You must provide an operator_id' unless $operator_id;

    return $self->update({
        confirmed      => 1,
        date_confirmed => $self->result_source->schema->db_now,
        operator_id    => $operator_id,
    });
}

1;
