use utf8;
package XTracker::Schema::Result::Public::SmsCorrespondence;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.sms_correspondence");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sms_correspondence_id_seq",
  },
  "csm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "mobile_number",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "message",
  { data_type => "varchar", is_nullable => 1, size => 160 },
  "date_sent",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "sms_correspondence_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "failure_code",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "csm",
  "XTracker::Schema::Result::Public::CorrespondenceSubjectMethod",
  { id => "csm_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_sms_correspondence__returns",
  "XTracker::Schema::Result::Public::LinkSmsCorrespondenceReturn",
  { "foreign.sms_correspondence_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_sms_correspondence__shipments",
  "XTracker::Schema::Result::Public::LinkSmsCorrespondenceShipment",
  { "foreign.sms_correspondence_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "sms_correspondence_status",
  "XTracker::Schema::Result::Public::SmsCorrespondenceStatus",
  { id => "sms_correspondence_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:19j3T7mwGFYGGLZsWjtq1A


use Carp;

use XTracker::Config::Local         qw( config_var );
use XTracker::EmailFunctions        qw( send_email );
use XTracker::XTemplate;
use XTracker::Constants::FromDB     qw(
                                        :sms_correspondence_status
                                    );


=head2 Status Methods

Various Methods that will return TRUE or FALSE based on the Status of the Record:

    $boolean    = $self->is_pending;
    $boolean    = $self->is_success;
    $boolean    = $self->is_fail;
    $boolean    = $self->is_not_sent;

    $boolean    = $self->is_failed;     # if 'is_fail' or 'is_not_sent' return TRUE

=cut

sub is_pending  { return shift->_is_status( $SMS_CORRESPONDENCE_STATUS__PENDING ); }
sub is_success  { return shift->_is_status( $SMS_CORRESPONDENCE_STATUS__SUCCESS ); }
sub is_fail     { return shift->_is_status( $SMS_CORRESPONDENCE_STATUS__FAIL ); }
sub is_not_sent { return shift->_is_status( $SMS_CORRESPONDENCE_STATUS__NOT_SENT_TO_PROXY ); }
sub is_failed   {
    my $self    = shift;
    return $self->is_fail || $self->is_not_sent;
}

=head2 update_status

    $self->update_status( $status_id );

Updates the Status of the Record.

=cut

sub update_status {
    my ( $self, $status_id )    = @_;

    if ( !$status_id ) {
        croak "No Status Id passed in to '" . __PACKAGE__ . "::update_status' method";
    }

    $self->update( { sms_correspondence_status_id => $status_id } );

    return;
}

=head2 send_failure_alert

    $boolean    = $self->send_failure_alert;

This will send out a Failure Alert Email for the Record using the Email Address found for the CSM Record
associated with it.

=cut

sub send_failure_alert {
    my $self    = shift;

    # if the status isn't correct then don't send
    return 0    if ( !$self->is_failed );

    my $result  = 0;
    if ( my $email_to = $self->csm->email_for_failure_notification ) {
        # if there is a To Address then send a Notification
        my $from_addr   = config_var( 'Email', 'xtracker_email' );
        my $subject     = $self->csm->correspondence_method->description . " Failed for " .
                            $self->csm->correspondence_subject->description;

        if ( my $link_rec = $self->get_linked_record ) {
            if ( my $order = $link_rec->next_in_hierarchy_from_class('Orders', { stop_if_me => 1 } ) ) {
                my %message_data    = (
                            template_type   => 'email',
                            subject         => $subject,
                            order_nr        => $order->order_nr,
                            first_name      => $order->customer->first_name,
                            last_name       => $order->customer->last_name,
                            mobile_number   => $self->mobile_number,
                            failure_code    => $self->failure_code,
                            message         => $self->message,
                            link_record     => $link_rec,
                        );
                my $message;
                my $template    = XTracker::XTemplate->template;
                $template->process( 'email/internal/premier_routing_alert_failure.tt', \%message_data, \$message );

                $result = send_email(
                                        $from_addr,         # From
                                        $from_addr,         # ReplyTo
                                        $email_to,          # To
                                        $subject,           # Subject
                                        $message,           # Body
                                    );
            }
        }
    }

    return $result;
}

=head2 get_linked_record

    $dbic_obj   = $self->get_linked_record;

This will return a DBIC Record that is linked to this SMS Correspondence record or 'undef' if none is found.

It finds the record by looping round all relationships that start with 'link_sms_correspondence__' until it finds something.

=cut

sub get_linked_record {
    my $self    = shift;

    # expect standard naming convention for link tables
    my $link_prefix = 'link_sms_correspondence';
    # the Class prefix should be CamelCase version of the above
    my $class_prefix= join( '', map { ucfirst( $_ ) } split( /_/, $link_prefix ) );

    my @links   = grep { m/^${link_prefix}__\w+/ } $self->result_source->relationships;

    my $rec;
    LINK:
    foreach my $link ( @links ) {
        my $link_rec    = $self->$link->first;
        # if we get a link record, then get what it's linked to
        if ( $link_rec ) {
            # the relationship for the linked record should be
            # the same as the end of the class name lower cased
            my $link_class  = ref( $link_rec );
            $link_class     =~ s/.*::${class_prefix}//g;
            $link_class     = lc( $link_class );

            # check that $link_class exists as a method for $link_rec
            if ( $link_rec->can( $link_class ) ) {
                $rec        = $link_rec->$link_class;
                last LINK   if ( $rec );
            }
        }
    }

    return $rec;
}


# helper method to return TRUE or FALSE if the status is X
sub _is_status {
    my ( $self, $status )   = @_;
    return ( $self->sms_correspondence_status_id == $status ? 1 : 0 );
}


1;
