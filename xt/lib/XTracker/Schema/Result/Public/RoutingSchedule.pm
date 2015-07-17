use utf8;
package XTracker::Schema::Result::Public::RoutingSchedule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.routing_schedule");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "routing_schedule_id_seq",
  },
  "routing_schedule_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "routing_schedule_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "external_id",
  { data_type => "integer", is_nullable => 0 },
  "date_imported",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "task_window_date",
  { data_type => "date", is_nullable => 1 },
  "task_window",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "driver",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "run_number",
  { data_type => "integer", is_nullable => 1 },
  "run_order_number",
  { data_type => "integer", is_nullable => 1 },
  "signatory",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "signature_time",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "undelivered_notes",
  { data_type => "varchar", is_nullable => 1, size => 1000 },
  "notified",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->might_have(
  "link_routing_schedule__return",
  "XTracker::Schema::Result::Public::LinkRoutingScheduleReturn",
  { "foreign.routing_schedule_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "link_routing_schedule__shipment",
  "XTracker::Schema::Result::Public::LinkRoutingScheduleShipment",
  { "foreign.routing_schedule_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "routing_schedule_status",
  "XTracker::Schema::Result::Public::RoutingScheduleStatus",
  { id => "routing_schedule_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "routing_schedule_type",
  "XTracker::Schema::Result::Public::RoutingScheduleType",
  { id => "routing_schedule_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:a8J8xnfCddywaNPcBcrKRw

__PACKAGE__->load_components('+XTracker::Utilities::DBIC::DateTimeFormat');

__PACKAGE__->many_to_many(
    shipments => 'link_routing_schedule__shipment' => 'shipment'
);

__PACKAGE__->many_to_many(
    returns => 'link_routing_schedule__return' => 'return'
);


use XTracker::Constants::FromDB         qw( :routing_schedule_status );
use XTracker::Utilities                 qw( twelve_hour_time_format );


=head2 shipment_rec

    $shipment_rec   = $self->shipment_rec;

Returns the Shipment record associated with the Routing Schedule record.

=cut

sub shipment_rec {
    my $self        = shift;

    my $shipments   = $self->shipments;

    if ( $shipments ) {
        return $shipments->first;
    }
    else {
        return;
    }
}

=head2 return_rec

    $return_rec = $self->return_rec;

Returns the Return record associated with the Routing Schedule record.

=cut

sub return_rec {
    my $self    = shift;

    my $returns = $self->returns;

    if ( $returns ) {
        return $returns->first;
    }
    else {
        return;
    }
}

=head2 format_task_window

    $string = $self->format_task_window();

This formats the 'task_window' time from 24hrs to a more natural 12hr style, so:

    '15:00 to 18:00' becomes '3pm to 6pm'
    '16:30 to 17:00' becomes '4:30pm to 5pm'
    '10:00 to 12:00' becomes '10am to 12pm'
    undef or empty   becomes 'TBC'              if Status is 'Re-Scheduled'

If the task window is not in the expected 24hr format then it just returns whatever the 'task_window' contains, unchanged.

=cut

sub format_task_window {
    my ( $self )    = @_;

    my $window      = $self->task_window;
    my $formatted   = '';

    # regardless of what the 'task_window' might be according to Route-Monkey
    # 'Re-Scehdules' don't have Task Windows and so no Alerts should be sent out
    if ( $self->routing_schedule_status_id == $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED ) {
        return 'TBC';
    }

    return $window  if ( !$window );        # if it's 'undef' or empty give it back

    if ( $window !~ m/(\d{2}):(\d{2}) .* (\d{2}):(\d{2})/ ) {
        # not in the expected format then just give it back
        return $window;
    }
    ## no critic(ProhibitCaptureWithoutTest)
    my ( $from_hr, $from_mn, $to_hr, $to_mn )   = ( $1, $2, $3, $4 );

    eval {
        my $from    = DateTime->new( year => 2001, day => 1, month => 1, hour => $from_hr, minute => $from_mn );
        my $to      = DateTime->new( year => 2001, day => 1, month => 1, hour => $to_hr, minute => $to_mn );

        $formatted  = twelve_hour_time_format( $from ) . '-' . twelve_hour_time_format( $to );
    };
    if ( $@ ) {
        # couldn't create proper DateTime's just give the window back
        return $window;
    }

    return lc( $formatted );
}

1;
