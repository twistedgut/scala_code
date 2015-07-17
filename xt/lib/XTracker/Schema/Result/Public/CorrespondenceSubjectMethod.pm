use utf8;
package XTracker::Schema::Result::Public::CorrespondenceSubjectMethod;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.correspondence_subject_method");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "correspondence_subject_method_id_seq",
  },
  "correspondence_subject_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "correspondence_method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "can_opt_out",
  { data_type => "boolean", is_nullable => 0 },
  "default_can_use",
  { data_type => "boolean", is_nullable => 0 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "send_from",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "copy_to_crm",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "notify_on_failure",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "correspondence_subject_method_correspondence_method_id_corr_key",
  ["correspondence_method_id", "correspondence_subject_id"],
);
__PACKAGE__->belongs_to(
  "correspondence_method",
  "XTracker::Schema::Result::Public::CorrespondenceMethod",
  { id => "correspondence_method_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "correspondence_subject",
  "XTracker::Schema::Result::Public::CorrespondenceSubject",
  { id => "correspondence_subject_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "csm_exclusion_calendars",
  "XTracker::Schema::Result::Public::CsmExclusionCalendar",
  { "foreign.csm_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_csm_preferences",
  "XTracker::Schema::Result::Public::CustomerCsmPreference",
  { "foreign.csm_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders_csm_preferences",
  "XTracker::Schema::Result::Public::OrdersCsmPreference",
  { "foreign.csm_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sms_correspondences",
  "XTracker::Schema::Result::Public::SmsCorrespondence",
  { "foreign.csm_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lSAOz9vf1Ki+2cURF+IFlg


use Carp;
use DateTime;
use DateTime::Format::DateParse;

use XTracker::Utilities             qw( is_date_in_range );
use XTracker::Config::Local         qw( email_address_for_setting );


=head2 channel

    $channel_obj    = $self->channel;

Returns the Sales Channel DBIC Record associated with the Subject for this record.

=cut

sub channel {
    my $self    = shift;
    return $self->correspondence_subject->channel;
}

=head2 email_for_failure_notification

    $string = $self->email_for_failure_notification;

This will return the Email Address for the Config Setting that has been set in the 'notify_on_failure' column
for the record. If the field is empty or no Config Setting could be found then an Empty String will be returned.

=cut

sub email_for_failure_notification {
    my $self    = shift;

    # return an Empty String if field is empty
    return ""       if ( !$self->notify_on_failure );

    # get the Email Address for the Setting for the Sales Channel
    return email_address_for_setting( $self->notify_on_failure, $self->channel );
}

=head2 window_open_to_send

    $boolean    = $self->window_open_to_send( $datetime_obj );

This will return TRUE or FALSE based on whether it is ok to send Correspondence using a particular Method.

It will use the 'csm_exclusion_calendar' to check if 'now' is in a exlusion window and so will return FALSE
meaning that Correspondence can't be sent, otherwise it will return TRUE meaning it can.

=cut

sub window_open_to_send {
    my ( $self, $date ) = @_;

    if ( !$date || ref( $date ) ne 'DateTime' ) {
        croak "No DateTime parameter or NOT a DateTime object passed to '" . __PACKAGE__ . "::window_open_to_send'";
    }

    my @calendar= $self->csm_exclusion_calendars
                            ->search( {}, { order_by => 'id' } )
                                ->all;
    if ( !@calendar ) {
        # no exclusions then fine to send
        return 1;
    }

    # clone the date as it might need to be changed
    my $date_clone  = $date->clone;

    # assume it's ok to send
    my $result  = 1;

    # go through each Exclusion record and see if
    # $date_clone is a match, if it is then CAN'T SEND
    CALENDAR_REC:
    foreach my $cal ( @calendar ) {
        # flags which will determin what to check against
        my $chk_time    = 0;
        my $chk_date    = 0;
        my $chk_day     = 0;

        # Work Out Time
        my $time1   = ( $cal->start_time ? $cal->start_time : undef );
        my $time2   = ( $cal->end_time ? $cal->end_time : undef );
        $time2      = '23:59:59'    if ( $time1 && !$time2 );
        $time1      = '00:00:00'    if ( $time2 && !$time1 );
        $chk_time   = 1             if ( $time1 || $time2 );

        # Work Out Date
        my $date1   = ( $cal->start_date ? $cal->start_date : undef );
        my $date2   = ( $cal->end_date ? $cal->end_date : undef );
        $date1      = $date2        if ( !$date1 );
        $date2      = $date1        if ( !$date2 );

        # both dates need to be in a consistent form either 'DD/MM'
        # or 'DD/MM/YYYY' not a mix or reject whole calendar rec
        next CALENDAR_REC           if ( length( $date1 // '' ) != length( $date2 // '' ) );

        # if an Exact Date is used the length will be 10 - DD/MM/YYYY, these dates
        # shouldn't be swapped around if they are in the wrong order, they're just bad data
        my $date_type   = ( length( $date1 // '' ) == 10 ? 'exact_date' : 'date' );

        my $date_str1   = $self->_format_date( $date1, $date_clone );
        my $date_str2   = $self->_format_date( $date2, $date_clone );
        $chk_date   = 1             if ( $date_str1 || $date_str2 );

        # work Out Day of Week
        my @days            = grep { $_ && /^[1-7]$/ } split( /,/, ( $cal->day_of_week // '' ) );
        $chk_day    = 1     if ( @days );

        # if there is anything to check against
        if ( my $chk_total = ( $chk_time + $chk_date + $chk_day ) ) {
            # use $date_clone's own Date & Time part to make up
            # the DateTime's to compare against
            my $cmp_base    = {
                        date    => $date_clone->ymd(':'),
                        time    => $date_clone->hms(':'),
                        tzone   => $date_clone->time_zone->name,
                    };

            # check $date_clone against each individual element and then if they all are
            # "in range" and equal $chk_total then it's within the Window and return FALSE
            my $chk_count   = 0;

            if ( $chk_time ) {
                my $date1_cmp   = $self->_create_date_obj( { %{ $cmp_base }, time => $time1 } );
                my $date2_cmp   = $self->_create_date_obj( { %{ $cmp_base }, time => $time2 } );
                $chk_count      += $self->_is_date_in_range( 'time', $date_clone, $date1_cmp, $date2_cmp );
            }
            if ( $chk_date ) {
                my $date1_cmp   = $self->_create_date_obj( { %{ $cmp_base }, date => $date_str1 } );
                my $date2_cmp   = $self->_create_date_obj( { %{ $cmp_base }, date => $date_str2 } );
                $chk_count      += $self->_is_date_in_range( $date_type, $date_clone, $date1_cmp, $date2_cmp );
            }
            if ( $chk_day ) {
                if ( grep { $date_clone->day_of_week == $_ } @days ) {
                    $chk_count++;
                }
            }

            # if the checks match the expected checks
            # then in an exclusion window and can't send
            $result = 0     if ( $chk_total == $chk_count );
        }

        # if it's not ok then bail out now
        # no point checking any more
        last CALENDAR_REC       if ( !$result );
    }

    return $result;
}

# looks to see if a $date is in the range of two others inclusive pass in a
# type (time or date), target date, along with 2 dates represent start and end,
# will also adjust the comparison dates & times if they cross day or year boundaries
sub _is_date_in_range {
    my ( $self, $type, $target, $cmp_date1, $cmp_date2 )    = @_;

    # if one or both of the dates couldn't be created then return FALSE
    return 0        if ( !$cmp_date1 || !$cmp_date2 );

    # check for either Times crossing Day Boundaries or
    # Dates crossing Year Boundaries, then adjust the $cmp_*
    # dates accordingly

    # based on the $type work out what to adjust if $cmp_date1 > $cmp_date2
    my %to_adjust   = (
                time    => 'days',
                date    => 'years',
            );

    # this makes ranges like '25/12 to '01/02' and '21:00:00 to 09:00:00' work
    # if an Exact date has been used then don't adjust anything
    if ( $type ne 'exact_date' && DateTime->compare( $cmp_date1, $cmp_date2 ) > 0 ) {
        (
            DateTime->compare( $cmp_date1, $target ) > 0
            ? $cmp_date1->subtract( $to_adjust{ $type } => 1 )
            : $cmp_date2->add( $to_adjust{ $type } => 1 )
        );
    }

    return is_date_in_range( $target, $cmp_date1, $cmp_date2 );
}

# just use a Date Parser to create a date from
# a hash which has date & time keys
sub _create_date_obj {
    my ( $self, $date_hash )    = @_;

    # if it can't parse then fine, return 'undef'
    my $datetime;
    eval {
        $datetime   = DateTime::Format::DateParse->parse_datetime( "$date_hash->{date}T$date_hash->{time}", $date_hash->{tzone} );
    };
    return $datetime;
}

# formats a date into a string: 'YYYY:MM:DD', date
# being split should either be 'DD/MM' or 'DD/MM/YYYY',
# $date is used to make up the year
sub _format_date {
    my ( $self, $date_to_parse, $date_obj ) = @_;

    return      if ( !$date_to_parse );

    # parse the date either: 'DD/MM' or 'DD/MM/YYYY'
    if ( $date_to_parse =~ m{(?<day>\d\d)/(?<month>\d\d)(/(?<year>\d{4}))?} ) {
        return sprintf( "%0.4d:%0.2d:%0.2d",
                                    ( $+{year} ? $+{year} : $date_obj->year ),
                                    $+{month},
                                    $+{day},
                                );
    }
    return;
}

1;
