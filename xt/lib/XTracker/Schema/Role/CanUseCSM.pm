package XTracker::Schema::Role::CanUseCSM;
use NAP::policy "tt", 'role';
requires 'next_in_hierarchy_with_method';

=head1 XTracker::Schema::Role::CanUseCSM

A role for checking whether or not something can send Correspondence using a particular Correspondence Method for
a particular Correspondence Subject, according to what the Customer's CSM Preferences are set to.

Currently a Role for:
    * Public::Customer
    * Public::Orders
    * Public::Shipment
    * Public::Return

=cut

=head2 can_use_csm

    $boolean    = $self->can_use_csm( $subject, $method_id, $channel_id # optional );

This will check that for a given Subject that the supplied Method Id 'Can Be Used' to send Correspondence
for the Customer. If no Preferences can be found (undef) this is taken to mean as yet no Preference specified
so the Method CAN be used.

$subject can be one of the following:
    * Subject Id.
    * Correspondence Subject Record.
    * Subject Name (value of 'corresepondence_subject's 'subject' field), if
      this is passed then a Channel Id also needs to be passed in.

=cut

sub can_use_csm {
    my ( $self, $subject, $method_id, $channel_id ) = @_;

    if ( !$subject ) {
        croak "No Subject passed in to '" . __PACKAGE__ . "::can_use_csm'";
    }
    if ( !$method_id ) {
        croak "No Method Id passed in to '" . __PACKAGE__ . "::can_use_csm'";
    }

    my $subject_rec;

    # decide what $subject is and get the Subject Record
    if ( ref( $subject ) =~ m/Public::CorrespondenceSubject$/ ) {
        # Subject Record itself passed in
        $subject_rec    = $subject;
    }
    elsif ( $subject =~ m/^\d+$/ ) {
        # Subject Id passed in
        $subject_rec    = $self->result_source
                                    ->schema->resultset('Public::CorrespondenceSubject')
                                        ->find( $subject );
        if ( !$subject_rec ) {
            croak "Couldn't find a Subject for Id: '$subject' in '" . __PACKAGE__ . "::can_use_csm'";
        }
    }
    elsif ( !ref( $subject ) ) {
        # Subject Name passed in, check for Channel Id
        if ( !$channel_id ) {
            croak "No Channel Id passed in with Subject Name in '" . __PACKAGE__ . "::can_use_csm'";
        }
        $subject_rec    = $self->result_source
                                    ->schema->resultset('Public::CorrespondenceSubject')
                                        ->find( { subject => $subject, channel_id => $channel_id } );
        if ( !$subject_rec ) {
            croak "Couldn't find a Subject under Name: '$subject' for Channel Id: '$channel_id' in '" . __PACKAGE__ . "::can_use_csm'";
        }
    }
    else {
        croak "Subject was passed in but of an Incorrect Type, should be a Record, Id or Subject Name in '" . __PACKAGE__ . "::can_use_csm'";
    }

    # if Subject has been Disabled then can't use anything
    return 0            if ( !$subject_rec->enabled );

    my $avail_methods   = $subject_rec->get_enabled_methods;

    # if a Method has been supplied that IS NOT
    # assigned to the Subject then return FALSE
    return 0            if ( !exists( $avail_methods->{ $method_id } ) );

    # if a Method has been supplied which you can
    # NOT Opt Out of Receiving then return TRUE
    return 1            if ( !$avail_methods->{ $method_id }{can_opt_out} );


    # see if it's ok to use
    my $ok_to_use   = $self->csm_prefs_allow_method( $subject_rec, $avail_methods->{ $method_id }{method} );

    if ( !defined $ok_to_use ) {
        # if can't find a Preference
        # then use Default for Method
        $ok_to_use  = $avail_methods->{ $method_id }{default_can_use};
    }

    return $ok_to_use;
}


=head2 csm_prefs_allow_method

    $boolean    = $self->csm_prefs_allow_method( $subject_rec, $method_rec );

This will return either TRUE, FALSE or 'undef' as to whether $self's CSM Preferences allow the use of the
Correspondence Method for the Correspondence Subject.

It will check to see if $self has a method called 'get_csm_preferences' if so it will call it and check
to see if it finds any Preferences set if not it will go through the Customer Hierarchy of Records calling
this method (csm_prefs_allow_method) on each Record until it reaches Preferences or the End. If it gets to
the end without finding any Preferences then it will return 'undef'.

Neither Return nor Shipment have the method 'get_csm_preferences' and will immediately go up to the Order.

=cut

sub csm_prefs_allow_method {
    my ( $self, $subject, $method )     = @_;

    if ( !$subject || ref( $subject ) !~ m/::CorrespondenceSubject$/ ) {
        croak "No Subject DBIC Object passed to '" . __PACKAGE__ . "::csm_prefs_allow_method'";
    }
    if ( !$method || ref( $method ) !~ m/::CorrespondenceMethod$/ ) {
        croak "No Method DBIC Object passed to '" . __PACKAGE__ . "::csm_prefs_allow_method'";
    }

    my $is_customer = ( ref( $self ) =~ m/Public::Customer$/ ? 1 : 0 );
    my $can_use;

    if ( $self->can('get_csm_preferences') ) {
        my $prefs   = $self->get_csm_preferences( $subject->id );
        $can_use    = $prefs->{ $method->id }{can_use};
    }

    if ( !defined $can_use ) {
        if ( $is_customer ) {
            # if $self is a 'Customer' record
            # then use the Customer Defaults
            return $self->csm_default_prefs_allow_method( $method );
        }
        # no Preferences found? Then see if
        # the next record in the Hierarchy does
        my $next    = $self->next_in_hierarchy_with_method('get_csm_preferences');
        return ( $next ? $next->csm_prefs_allow_method( $subject, $method ) : undef );
    }

    return $can_use;
}


1;
