use utf8;
package XTracker::Schema::Result::SOS::ProcessingTime;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Interval");
__PACKAGE__->table("sos.processing_time");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.processing_time_id_seq",
  },
  "class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "class_attribute_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "processing_time",
  { data_type => "interval", is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("processing_time_channel_id_key", ["channel_id"]);
__PACKAGE__->add_unique_constraint(
  "processing_time_class_attribute_id_key",
  ["class_attribute_id"],
);
__PACKAGE__->add_unique_constraint("processing_time_class_id_key", ["class_id"]);
__PACKAGE__->add_unique_constraint("processing_time_country_id_key", ["country_id"]);
__PACKAGE__->add_unique_constraint("processing_time_region_id_key", ["region_id"]);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::SOS::Channel",
  { id => "channel_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "class",
  "XTracker::Schema::Result::SOS::ShipmentClass",
  { id => "class_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "class_attribute",
  "XTracker::Schema::Result::SOS::ShipmentClassAttribute",
  { id => "class_attribute_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);
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
__PACKAGE__->has_many(
  "processing_time_override_major_ids",
  "XTracker::Schema::Result::SOS::ProcessingTimeOverride",
  { "foreign.major_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "processing_time_override_minor_ids",
  "XTracker::Schema::Result::SOS::ProcessingTimeOverride",
  { "foreign.minor_id" => "self.id" },
  undef,
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


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UbbtPt/TDWX13uIHXYM/TA

__PACKAGE__->load_components('AuditLog');
__PACKAGE__->add_audit_recents_rel;
__PACKAGE__->audit_columns(qw/processing_time/);

use DateTime::Format::Duration;

use XTracker::Constants::FromDB qw(
    :sos_shipment_class
    :sos_shipment_class_attribute
);
use vars qw/
    $SOS_SHIPMENT_CLASS__PREMIER_DAYTIME
    $SOS_SHIPMENT_CLASS__PREMIER_EVENING
    $SOS_SHIPMENT_CLASS__PREMIER_ALL_DAY
    $SOS_SHIPMENT_CLASS__NOMINATED_DAY
    $SOS_SHIPMENT_CLASS__PREMIER_EVENING_HAMPTONS
/;


=head2 is_country

=head2 is_premier

=head2 is_nominated_day

=cut

sub is_country {
    my ($self) = @_;
    return ($self->country_id() ? 1 : 0);
}

sub is_premier {
    my ($self) = @_;
    return (($self->class_id()
        && grep { $self->class_id() == $_ } (
            $SOS_SHIPMENT_CLASS__PREMIER_DAYTIME,
            $SOS_SHIPMENT_CLASS__PREMIER_EVENING,
            $SOS_SHIPMENT_CLASS__PREMIER_ALL_DAY,
            $SOS_SHIPMENT_CLASS__PREMIER_EVENING_HAMPTONS//(),
        ) )
        ? 1 : 0);
}

sub is_nominated_day {
    my ($self) = @_;
    return (($self->class_id() && $self->class_id() == $SOS_SHIPMENT_CLASS__NOMINATED_DAY)
        ? 1 : 0);
}

=head2 type

Returns the type of object to which this rule applies, (class, country, etc.)

=cut

sub type {
    my($self) = @_;
    my @outgoing_rels = qw(class country region class_attribute channel);
    for(@outgoing_rels){
        if(defined $self->$_) {
            return $_;
        }
    }
    # Should never reach here. If it does, there's
    # something wrong with the record in the DB.
    die "processing time record has no related type";
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

=head2 overrides_all

Returns a boolean dependant on whether this record has a "blanket"
override, ignoring all other processing times

=cut

sub overrides_all {
    my ($self) = @_;

    my $overrides_all;
    my $type = $self->type;
    if ($self->$type->can('does_ignore_other_processing_times')) {
        $overrides_all = $self->$type->does_ignore_other_processing_times;
    } else {
        $overrides_all = 0;
    }

    return $overrides_all;
}
=head2 get_audit_value_for_processing_time

Return a stringified duration based on processing_time for audit purposes

=cut

sub get_audit_value_for_processing_time {
    my ($self) = @_;
    my $formatter = DateTime::Format::Duration->new(
        pattern     => '%H:%M',
        normalize   => 1,
    );

    return $formatter->format_duration($self->processing_time);
}

1;
