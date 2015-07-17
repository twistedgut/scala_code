use utf8;
package XTracker::Schema::Result::Public::ShipmentBox;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_box");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "varchar",
    is_auto_increment => 1,
    is_nullable => 0,
    sequence => "shipment_box_id_seq",
    size => 32,
  },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "box_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tracking_number",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "inner_box_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "outward_box_label_image",
  { data_type => "text", is_nullable => 1 },
  "return_box_label_image",
  { data_type => "text", is_nullable => 1 },
  "tote_id",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "hide_from_iws",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "box",
  "XTracker::Schema::Result::Public::Box",
  { id => "box_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "inner_box",
  "XTracker::Schema::Result::Public::InnerBox",
  { id => "inner_box_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.shipment_box_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PyUxEPkd2g/+m3RRgUJg8A
use Carp qw<cluck confess croak>;
use Data::Dump qw<pp>;
use Math::Round qw<nearest>;
use MooseX::Params::Validate qw/validated_hash pos_validated_list/;
use XTracker::Constants::FromDB qw( :carrier );
use XTracker::Order::Printing::ShipmentDocuments 'print_shipment_documents';
use XTracker::Order::Printing::PremierShipmentDocuments 'print_premier_shipment_documents';

__PACKAGE__->has_many(
  "shipment_box_logs",
  "XTracker::Schema::Result::Public::ShipmentBoxLog",
  { "foreign.shipment_box_id" => "self.id" },
  {},
);

# for clarity in UPS Carrier work
sub outer_box { return shift->box; }

# Need to get weight of all items in the shipment_box (from the
# shipping_attribute table) and then add the weight of the outer box used,
# then using the 'carrier_box_weight' table compare the total weight against
# the threshold for the relevant channel & service for the outer box being
# used and see if the weight is above or below - take the higher weight. If
# there is no record in the carrier_box_weight table for the
# channel/servie/box being used then just use the weight you have calculated.
# Currently this method of working out the weight is done in
# 'DHL/Manaifest.pm' within the functions 'get_manifest_shipment_data',
# 'generate_manifest_files' and '_get_carrier_box_weights' look for
# '$args->{carrier_id} == $CARRIER__UPS' or similar to see this beign worked
# out. This method of working out the weight with thresholds is UPS SPECIFIC.
sub package_weight {
    my $self = shift;
    my $total_weight = 0;
    my @shipment_items = $self->shipment_items->all;
    # the weight if the items
    map {
        $total_weight += nearest(
            .001,
            $_->product->shipping_attribute->weight
        )
    } @shipment_items;
    # and the weight of the box itself
    $total_weight += $self->box->weight;

    return sprintf("%.3f", $total_weight);
}

sub threshold_package_weight {
    my $self = shift;
    my $attr = shift;

    # if we're NOT UPS we shouldn't even be using this method
    if ($self->shipment->shipping_account->carrier_id != $CARRIER__UPS) {
        cluck
              __PACKAGE__
            . "::threshold_package_weight()"
            . "is a UPS only method; using package_weight()"

        ;
        return $self->package_weight;
    }

    my $schema = $self->result_source->schema;
    my $package_weight = $self->package_weight;
    my $service_name;

    # we steal the deduction of the service from XTracker::DHL::Manifest
    if ( $self->shipment->shipping_charge_table->shipping_charge_class->class eq 'Air' ) {
        $service_name = 'Next Day Air Saver';
    }
    else {
        $service_name = 'Ground';
    }

    # get all carrier/box matches
    my $search_terms = {
        carrier_id      => $self->shipment->shipping_account->carrier_id,
        channel_id      => $self->shipment->shipping_account->channel_id,
        service_name    => $service_name,
        box_id          => $self->box_id,
    };
    my @carrier_box_weights = $schema->resultset('Public::CarrierBoxWeight')
        ->search(
            $search_terms,
            # this is so that *if* something goes wrong and we get too many
            # results we don't cause the customer problems by picking a box
            # weight/limit that's too small
            { 'order_by' => 'weight DESC', }
        )
        ->all
    ;

    # if we didn't get any matches - use the package weight
    if (not @carrier_box_weights) {
        return $package_weight;
    }

    # if we got more than one result - something isn't right
    # emit a warning
    # use the largest weight box; so the order can continue and the customer
    # doesn't get screwed
    if (@carrier_box_weights > 1) {
        cluck
              "multiple results in call to "
            . __PACKAGE__
            . "::threshold_package_weight() - using the largest weight";
        warn
              __PACKAGE__
            . "::threshold_package_weight() search terms: "
            . pp($search_terms);
        warn
              __PACKAGE__
            . "::threshold_package_weight() largest matching record: "
            . pp($carrier_box_weights[0]->data_as_hash);
    }

    # return the larger of the package-weight or carrier-box-weight
    return
          ($carrier_box_weights[0]->weight > $package_weight)
        ? $carrier_box_weights[0]->weight
        : $package_weight
    ;
}

=head2 label(\%args) : $shipment_box

Labels the shipment box. Currently this means printing documents and logging an
action against the shipment_box_log table.

You always have to pass the following two parameters:

=over

=item operator_id

=back

If the shipment is premier, you can pass values for:

=over

=item premier_printer

=item card_printer

=back

Otherwise, you can pass values for:

=over

=item document_printer

=item label_printer

=back

=cut

sub label {
    my ( $self, %args ) = validated_hash(\@_,
        operator_id => { isa => 'Int', },
        map {
            $_ => { isa => 'Str', optional => 1 }
        } qw/premier_printer card_printer document_printer label_printer/,
    );

    my $schema = $self->result_source->schema;
    my $shipment = $self->shipment;
    $schema->txn_do(sub{
        # We log *before* the printouts as we want to be able to roll back
        # before printing the documents
        $self->log_action( 'Labelled', $args{operator_id} );
        if ($shipment->is_premier) {
            print_premier_shipment_documents(
                $schema, $shipment, @args{qw/premier_printer card_printer/}
            );
        }
        else {
            print_shipment_documents( $schema->storage->dbh,
                $self->id, @args{qw/document_printer label_printer/}
            );
        }
    });

    return $self;
}

=head2 log_action( $action, $operator_id ): $shipment_box_log

Log the given action.

=cut

sub log_action {
    my ( $self ) = shift;
    my ( $action, $operator_id ) = pos_validated_list(\@_,
        { isa => 'Str' }, { isa => 'Int' },
    );
    return $self->create_related('shipment_box_logs', {
        action => $action,
        operator_id => $operator_id,
        skus => [
            map { $_->get_true_variant->sku }
            # The order_by clause is just here to provide a predictable order.
            # If you change it make sure you update the unit test for
            # log_action too.
            $self->search_related('shipment_items', {}, { order_by => 'id' })->all
        ],
    });
}

=head2 is_labelled()

Returns boolean to determine whether this shipment box is labelled

=cut

sub is_labelled {
    my ($self) = shift;
    return !!$self->shipment_box_logs->search({action => 'Labelled'},{rows => 1})->single;
}

1;
