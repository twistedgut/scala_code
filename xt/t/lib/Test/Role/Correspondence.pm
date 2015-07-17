package Test::Role::Correspondence;
use NAP::policy "tt", qw( role test);

requires 'get_schema';

use XTracker::Utilities     qw( time_now );


=head1 NAME

Test::Role::Correspondence - a Moose role to do Correspondence related stuff for tests.

=head1 SYNOPSIS

    package Test::Foo;

    with 'Test::Role::Correspondence';

=cut

=head1 METHODS

=head2 create_csm_subject

    $csm_subject_rec    = $class->create_csm_subject( $channel, $name );

Will create a Correspondence Subject for a given Channel, if $name is omitted a default will be used.

=cut

sub create_csm_subject {
    my ( $self, $channel, $name )   = @_;

    if ( !$channel ) {
        die "No DBIC Channel Object passed";
    }

    my $subject_rs  = $self->get_schema->resultset('Public::CorrespondenceSubject');

    $name   ||= "Test Subject " . $$ . " " . ( $subject_rs->get_column('id')->max + 1 );

    my $subject = $subject_rs->create( {
                    subject     => $name,
                    description => $name . " Description",
                    channel_id  => $channel->id,
                } )->discard_changes;
    note "Created Subject: " . $subject->subject;

    return $subject;
}

=head2 assign_csm_methods

    $array_ref  = $class->assign_csm_methods( $subject_rec, [ 'SMS', 'Email' ... ] );
                    or
    @array      = $class->assign_csm_methods( $subject_rec, [ 'SMS', 'Email' ... ] );

Will assign Correspondence Subject Methods to a Correspondence Subject and set the fields: enabled, can_opt_out and default_can_use to TRUE.

Returns an Array Ref or an Array of Correspondence Subject Method records that have been created.

=cut

sub assign_csm_methods {
    my ( $self, $subject, $methods )    = @_;

    my $method_rs   = $self->get_schema->resultset('Public::CorrespondenceMethod');

    # make sure the $methods are an Array Ref
    $methods    = ( ref( $methods ) ? $methods : [ $methods ] );

    my @recs;
    foreach my $method ( @{ $methods } ) {
        my $meth_rec    = $method_rs->find( { method => $method } );
        push @recs, $subject->create_related( 'correspondence_subject_methods', {
                                                correspondence_method_id    => $meth_rec->id,
                                                can_opt_out                 => 1,
                                                default_can_use             => 1,
                                        } )->discard_changes;
        note "Assigned Method: " . $meth_rec->method;
    }

    return ( wantarray ? @recs : [ @recs ] );
}

=head2 is_method_enabled_for_subject

    $boolean    = is_method_enabled_for_subject( $channel, $subject_name, $method_name );

This will return TRUE or FALSE based on whether various fields are enabled for the Method
and the Subject and whether the Method is enabled in general. Will also take into account
the 'csm_exlusion_calendar' table for the Correspondence Subject Method.

=cut

sub is_method_enabled_for_subject {
    my ( $self, $channel, $subject_name, $method_name ) = @_;

    my $schema  = $self->get_schema;

    my $method  = $schema->resultset('Public::CorrespondenceMethod')
                                ->find( { method => $method_name } );
    if ( !$method ) {
        croak "Couldn't find a Correspondence Method for '$method_name' in '" . __PACKAGE__ . "::is_method_enabled_for_subject'";
    }
    my $subject = $schema->resultset('Public::CorrespondenceSubject')
                                ->find( { subject => $subject_name, channel_id => $channel->id } );
    if ( !$subject ) {
        croak "Couldn't find a Correspondence Subject for '$subject_name' and Channel '".$channel->name."' in '" . __PACKAGE__ . "::is_method_enabled_for_subject'";
    }

    my $csm_rec = $subject->correspondence_subject_methods
                            ->search( { correspondence_method_id => $method->id, enabled => 1 } )
                                ->first;

    my $result  = 1;
    if ( !$method->enabled ) {
        # if it's turned off on the Method's record
        $result = 0;
    }
    elsif ( !$channel->can_premier_send_alert_by( $method_name ) ) {
        # if it's turned off from a System point of view
        $result = 0;
    }
    elsif ( !$subject->enabled ) {
        # Subject is turned off
        $result = 0;
    }
    elsif ( !$csm_rec ) {
        # if it's turned off for the subject & method
        $result = 0;
    }
    elsif ( !$csm_rec->window_open_to_send( time_now ) ) {
        # can't send it at this moment in time
        $result = 0;
    }

    return $result;
}

1;
