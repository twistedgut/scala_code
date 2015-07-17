package XTracker::Schema::Role::CSMPreference;
use NAP::policy "tt", 'role';
requires qw( channel can_use_csm );

=head1 XTracker::Schema::Role::CSMPreference

A role for Getting/Changing CSM Preferences ans other CSM related activities.

Currently a Role for:
    * Public::Customer
    * Public::Orders

=cut

use Carp;


has _csm_relationship => (
    is          => 'ro',
    isa         => 'Object',
    lazy_build  => 1,
);


=head2 change_csm_preference

    $boolean    = $self->change_csm_preference( $subject_id, {
                                                    method_id => TRUE or FALSE
                                                    ...
                                                });

This will change the Preferences that a record has for a Correspondence Subject as to whether
different Correspondence Methods can be used to communicate with the Customer.

This method expects $self to have a relationship between itself and the 'correspondence_subject_method' table
via a table which is called 'something_csm_preferences' such as 'customer_csm_preferences' or 'orders_csm_preferences'
if there isn't one it will throw an exception.

Returns TRUE or FALSE depending on whether any of the Preferences had actually changed from what they were before.

=cut

sub change_csm_preference {
    my ( $self, $subject_id, $args )    = @_;

    if ( !$subject_id ) {
        croak "No Subject Id passed in to '" . __PACKAGE__ . "::change_csm_preference'";
    }
    if ( !$args || ref( $args ) ne 'HASH' ) {
        croak "No Arguments as a Hash Ref passed in to '" . __PACKAGE__ . "::change_csm_preference'";
    }

    my $csm = $self->result_source->schema
                        ->resultset('Public::CorrespondenceSubjectMethod')
                            ->search( { correspondence_subject_id => $subject_id } );
    if ( !$csm->first ) {
        croak "Couldn't find any 'correspondence_subject_method' records for Subject Id: $subject_id, in method '" . __PACKAGE__ . "::change_csm_preference'";
    }

    # get the Relationship between $self and the 'correspondence_subject_method'
    # table to store the Preferences on
    my $csm_link    = $self->_csm_relationship;

    # set-up a flag to decide if $self is a 'customer' record or not
    my $is_customer = ( ref( $self ) =~ m/Public::Customer$/ ? 1 : 0 );

    # get list of Methods allowed to change Preferences on, for the Subject
    my %subject_methods     = map { $_->correspondence_method_id => $_ }
                                    grep { $_->can_opt_out } $csm->reset->all;

    # get the current Method Preferences - if any
    my $existing_preferences    = $self->get_csm_preferences( $subject_id );

    # flag to set if any of the Preferences have actually changed
    my $any_changes = 0;

    CHANGE:
    foreach my $method ( keys %{ $args } ) {

        # if it's not one of the Allowable Methods for the Subject then don't do it
        next CHANGE     if ( !exists( $subject_methods{ $method } ) );

        my $pref        = $args->{ $method };
        my $csm_rec     = $subject_methods{ $method };
        my $exist_pref  = ( exists( $existing_preferences->{ $method } ) ? $existing_preferences->{ $method } : undef );

        if ( !$exist_pref || $exist_pref->{can_use} != $pref ) {
            (
                $exist_pref
                ? $exist_pref->{pref_rec}->update( { can_use => $pref } )
                : $csm_link->create( { csm_id => $csm_rec->id, can_use => $pref } )
            );
            $any_changes    = 1;
        }
    }

    # if $self is a Customer and there has been at least one
    # change then cascade down to all Un-Dispatched Orders
    if ( $is_customer && $any_changes ) {
        if ( my @orders = $self->orders_with_undispatched_shipments->all ) {

            # get the newly changed current Preferences for the Customer
            my $prefs   = $self->get_csm_preferences( $subject_id );
            my %ord_args= map { $_ => $prefs->{ $_ }{can_use} } keys %{ $prefs };

            foreach my $order ( @orders ) {
                $order->change_csm_preference( $subject_id, \%ord_args );
            }
        }
    }

    return $any_changes;
}

=head2 csm_preferences_rs

    $resultset  = $self->csm_preferences_rs( $subject_id );

This returns a Resultset for '$self->_csm_relationship' which is a link between $self
and the 'correspondence_subject_method' table for a given Correspondence Subject Id, it
will return a Resultset with a 'join' to the 'correspondence_subject_method' table.
Not Passing in the Subject Id returns all Subjects.

=cut

sub csm_preferences_rs {
    my ( $self, $subject_id )   = @_;

    my $args;
    if ( $subject_id ) {
        $args   = { 'csm.correspondence_subject_id' => $subject_id };
    }

    return $self->_csm_relationship
                    ->search( $args, { join => 'csm' } );
}

=head2 get_csm_preferences

    $hash_ref   = $self->get_csm_preferences( $subject_id );

This returns the Correspondence Method Preferences for a particular Correspondence Subject for
all Methods.

Returns a HASH Ref:
    {
        correspondence_method_id => {
                method  => ' ... ::Public::CorrespondenceMethod',
                pref_rec=> ' ... ::Public::*CsmPreference',
                can_use => TRUE or FALSE
            },
        ...
    }

=cut

sub get_csm_preferences {
    my ( $self, $subject_id )   = @_;

    if ( !$subject_id ) {
        croak "No Subject Id passed in to '" . __PACKAGE__ . "::get_csm_preferences'";
    }

    my %prefs   = map {
                        $_->csm->correspondence_method_id => {
                                                method  => $_->csm->correspondence_method,
                                                pref_rec=> $_,
                                                can_use => $_->can_use,
                                            }
                      } $self->csm_preferences_rs( $subject_id )->all;

    return ( %prefs ? \%prefs : undef );
}

=head2 get_csm_available_to_change

    $hash_ref   = $self->get_csm_available_to_change( $subject_id );

Returns back all of the Opt Out'able Methods for a Subject along with the $self's current Preferences.
If no Subject Id is passed then it will get all Subjects which have records in the 'correspondence_subject_method' table
and return an entry for each. The value of the 'can_use' key is got from calling '$self->can_use_csm' for the Subject &
Method, this method is in the Role 'XTracker::Schema::Role::CanUseCSM'.

Returns:

    When Passed with a Subject Id:
        {
            correspondence_method_id => {
                    method => ' ... ::Public::CorrespondenceMethod',
                    can_use => TRUE or FALSE
                    default_can_use => TRUE or FALSE
                },
            ...
        }

    When Passed without a Subject Id:
        {
            correspondence_subject_id => {
                subject => ' ... ::Public::CorrespondenceSubject',
                methods => {
                    correspondence_method_id => {
                            method => ' ... ::Public::CorrespondenceMethod',
                            can_use => TRUE or FALSE
                            default_can_use => TRUE or FALSE
                        },
                    ...
                }
            },
        }

=cut

sub get_csm_available_to_change {
    my ( $self, $subject_id )   = @_;

    my $search_args = {
            # don't use 'channel_id' field as $self may not
            # have it but should have method 'channel'
            'me.channel_id' => $self->channel->id,
            'me.enabled'    => 1,
        };
    if ( $subject_id ) {
        $search_args->{'me.id'}  = $subject_id;
    }

    my %prefs;

    my @subjects    = $self->result_source
                            ->schema->resultset('Public::CorrespondenceSubject')
                                ->search( $search_args )->all;
    SUBJECT:
    foreach my $subject ( @subjects ) {

        # only use Subjects which have Opt Out'able Methods
        my $methods     = $subject->get_enabled_methods( { opt_outable_only => 1 } );
        next SUBJECT    if ( !$methods );

        my $avail_methods;
        foreach my $method_id ( keys %{ $methods } ) {
            $avail_methods->{ $method_id }  = {
                                method => $methods->{ $method_id }{method},
                                can_use => $self->can_use_csm( $subject, $method_id ),
                                default_can_use => $methods->{ $method_id }{default_can_use},
                            };
        }

        $prefs{ $subject->id }  = {
                    subject => $subject,
                    methods => $avail_methods,
                }
    }

    if ( $subject_id && %prefs ) {
        # only want to return the 'Methods' as caller
        # presumably knows what the Subject is
        %prefs  = %{ $prefs{ $subject_id }{methods} };
    }
    return ( %prefs ? \%prefs : undef );
}

=head2 ui_change_csm_available_by_subject

    $boolean    = $self->ui_change_csm_available_by_subject( $subject_id, {
                                                                method_id => TRUE or FALSE,
                                                                ...
                                                            } );

This will update ALL the Opt-Outable Method Preferences available for a Subject. This is
to be used by functionality that comes from a UI where the absence of a Method Preference
is taken to mean setting that preference to be Off. This is required as using Checkboxes
in HTML Forms results in nothing being passed to the server when an option is un-checked.

It will create links between $self and the 'correspondece_subject_method' table for each
Opt-Outable Method assigned to the Subject using either the Method preference passed to it
or turning it Off if that preferences wasn't specified.

If no Method arguments are passed then it will just create Preferences for all available
Opt-Outable Methods turning them Off.

Returns TRUE or FALSE depending on whether any of the Preferences had actually changed from
what they were before.

=cut

sub ui_change_csm_available_by_subject {
    my ( $self, $subject_id, $args )    = @_;

    if ( !$subject_id ) {
        croak "No Subject Id passed in to '" . __PACKAGE__ . "::ui_change_csm_available_by_subject'";
    }
    if ( $args && ref( $args ) ne 'HASH' ) {
        croak "If Method Arguments passed in then they should be a Hash Ref, in '" . __PACKAGE__ . "::ui_change_csm_available_by_subject'";
    }

    my $avail_methods   = $self->get_csm_available_to_change( $subject_id );
    return 0            if ( !$avail_methods );     # nothing to do

    # loop round each Available Method and build up a list of Methods to
    # pass to 'change_csm_preference' using either the Preferences passed in
    # or if it wasn't passed set the Preference to Off.
    my %methods_to_update   = map { $_ => ( exists( $args->{ $_ } ) ? $args->{ $_ } : 0 ) }
                                    keys %{ $avail_methods };

    return $self->change_csm_preference( $subject_id, \%methods_to_update );
}


# helper function to return the relationship between
# $self and the 'correspondence_subject_method' table
sub _build__csm_relationship {
    my $self    = shift;

    my ( $csm_link )    = grep { m/\w+_csm_preferences$/ } $self->result_source->relationships;
    if ( !$csm_link ) {
        croak "Couldn't find a Relationship between '" . ref( $self ) . "' and 'correspondence_subject_method' in method '" . __PACKAGE__ . "::_build__csm_relationship'";
    }

    return $self->$csm_link;
}

1;
