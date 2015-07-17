use utf8;
package XTracker::Schema::Result::SOS::WmsPriority;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Interval");
__PACKAGE__->table("sos.wms_priority");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.wms_priority_id_seq",
  },
  "shipment_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "shipment_class_attribute_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "wms_priority",
  { data_type => "integer", is_nullable => 0 },
  "wms_bumped_priority",
  { data_type => "integer", is_nullable => 1 },
  "bumped_interval",
  { data_type => "interval", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("wms_priority_country_id_key", ["country_id"]);
__PACKAGE__->add_unique_constraint("wms_priority_region_id_key", ["region_id"]);
__PACKAGE__->add_unique_constraint(
  "wms_priority_shipment_class_attribute_id_key",
  ["shipment_class_attribute_id"],
);
__PACKAGE__->add_unique_constraint("wms_priority_shipment_class_id_key", ["shipment_class_id"]);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::SOS::Country",
  { id => "country_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "region",
  "XTracker::Schema::Result::SOS::Region",
  { id => "region_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipment_class",
  "XTracker::Schema::Result::SOS::ShipmentClass",
  { id => "shipment_class_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipment_class_attribute",
  "XTracker::Schema::Result::SOS::ShipmentClassAttribute",
  { id => "shipment_class_attribute_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:e93orv1pk+Pa/WXFML89OA

__PACKAGE__->load_components('AuditLog');
__PACKAGE__->add_audit_recents_rel;
__PACKAGE__->audit_columns(qw/wms_priority wms_bumped_priority bumped_interval/);

use DateTime::Format::Duration;

=head2 type

Returns the type of object to which this rule applies
(shimpent_class, country, etc.). Names are the name of
the relationship as it applies to the result object

=cut

sub type {
    my ( $self ) = @_;

    my @outgoing_rels = qw(shipment_class country region shipment_class_attribute channel);
    for(@outgoing_rels){
        if(defined $self->$_) {
            return $_;
        }
    }
    # Should never reach here. If it has, there's
    # something wrong with the record in the DB.
    die "WMS priority has no related type";
}

=head2 name

Returns the name of the object to which this rule applies
(Standard, Bahrain, etc.)

=cut

sub name {
    my ($self) = @_;
    my $type = $self->type;
    return $self->$type->name;
}

=head2 get_audit_value_for_bumped_interval

returns a stringified value based on bumped_interval for audit purposes

=cut

sub get_audit_value_for_bumped_interval {
    my ($self) = @_;
    my $formatter = DateTime::Format::Duration->new(
        pattern     => '%H:%M',
        normalize   => 1,
    );

    # bumped_interval can be null
    if(defined($self->bumped_interval)) {
        return $formatter->format_duration($self->bumped_interval);
    } else {
        return undef;
    }
}

1;
