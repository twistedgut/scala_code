package XTracker::Admin::UserProfile;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Barcode;
use XTracker::PrintFunctions;
use Data::Dump                  qw( pp );
use XTracker::Logfile           qw( xt_logger );
use XTracker::Error;
use XTracker::Utilities         qw( url_encode );

# Maintain User's profile and what functions available to them and at what
# level
sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $operator_id = $handler->{data}{'operator_id'};
    my $effecting_user = $handler->{data}{'username'} // '';
    my $auth_level  = $handler->{data}{'auth_level'};

    my $schema      = $handler->{schema};

    # Get User ID out of the URI Path
    my @levels    = split /\//, $handler->{data}{uri};
    my $user_id   = $levels[4] || $handler->{param_of}{'operator_id_selected'};

    $handler->{data}{content}       = 'shared/admin/userprofile.tt';
    $handler->{data}{section}       = 'User Admin';
    $handler->{data}{subsection}    = 'User Profile';
    $handler->{data}{subsubsection} = q{};
    $handler->{data}{sidenav}       = [{ 'None' => [ { 'title' => 'Back to User List', 'url' => '/Admin/UserAdmin' } ] }];

    $handler->{data}{js}            = [ '/javascript/yui_autocomplete.js' ];

    if ( !$user_id ) {
        xt_warn("You can no longer create users using xTracker, this must be done using Fulcrum");
        return $handler->redirect_to( "/Admin/UserAdmin" );
    }
    my $operator = $schema->resultset('Public::Operator')->find($user_id);
    unless ( $operator ) {
        xt_warn("Could not find operator with id $user_id");
        return $handler->redirect_to( '/Admin/UserAdmin' );
    }

    $handler->{data}{form_submit} = "/Admin/UserAdmin/Profile/$user_id";

    ### profile form submitted
    if ( $handler->{param_of}{'submit'} ) {
        # deal with permission modifications
        eval {
            if ( $handler->{param_of}{department_id} ) {
                $schema->txn_do( sub {
                    _update_profile($operator, $handler->{param_of}, $effecting_user);
                    xt_success( 'User updated' );
                });
            }
            # Not sure why we don't die here (maybe something to do with
            # barcode users not having a department?)... but this is the
            # original behaviour so we're keeping it for now
            else {
                xt_warn( "No department specified\n" );
            }
            # deal with barcode printing - only if there were no error
            # modifying permissions (we don't want to lose error messages from
            # that)
            if ( defined $handler->{param_of}{'print_barcode'} and $handler->{param_of}{'print_barcode'} == 1 ) {
                _print_operator_barcode( $user_id, $handler->{param_of} );
                xt_success( 'Operator barcode printer' );
            }
        };
        if ( my $error = $@ ) {
            xt_warn( $error );
            xt_logger->warn( $error );
            $handler->{form_override}   = 1;        # Allow FORM params to stay so as to avoid user re-filling in form
        }
        else {
            # re-direct so the permissions that have been set will be applied
            # immediately to the Operator if they are updating themselves
            return $handler->redirect_to( $handler->{data}{form_submit} );
        }
    }

    $handler->{data}{'user_info'}   = $operator;
    $handler->{data}{'user_pref'}   = $operator->operator_preference;
    $handler->{data}{'user_auth'}   = _get_user_authorisation($operator, $handler->{param_of}, $handler->{form_override});

    $handler->{data}{departments}   = get_departments($schema);
    $handler->{data}{channels}      = $schema->resultset('Public::Channel')->get_channels();
    $handler->{data}{user_id}       = $user_id;

    return $handler->process_template;
}

# Gets the user's current authorisations
sub _get_user_authorisation {
    my ( $operator, $param_of, $form_override ) = @_;

    my %auth;
    for my $row ( $operator->operator_authorisations->all ) {
        $auth{ $row->authorisation_sub_section_id } = $row->authorisation_level_id;
    }

    my $schema = $operator->result_source->schema;
    my $authsect_rs = $schema->resultset('Public::AuthorisationSubSection')->search( undef, { prefetch => 'section' });

    my %user_auth;
    while ( my $row = $authsect_rs->next ) {
        $user_auth{ $row->section->section }{ $row->sub_section }{'id'} = $row->id;
        # pass to the TT whether or not this Option is under
        # ACL Control and so NOT useable on this page
        $user_auth{ $row->section->section }{ $row->sub_section }{'acl_controlled'} = $row->acl_controlled;

        $user_auth{ $row->section->section }{ $row->sub_section }{'auth'}   = 0;
        if ( $form_override ) {
            $user_auth{ $row->section->section }{ $row->sub_section }{'auth'}   = $param_of->{"level_".$row->id}    if ($param_of->{"auth_".$row->id});
        }
        else {
            $user_auth{ $row->section->section }{ $row->sub_section }{'auth'}   = $auth{ $row->id }     if ($auth{ $row->id });
        }
    }

    return \%user_auth;
}

# Used to get all the required parameters from a form to populate the account
# details section in case of an error, so details aren't lost
sub _get_user_info_params {
    my $param_of    = shift;
    my %user_info;
    # put list of required params in array
    my @params_to_get = (qw/
        name
        department_id
        auto_login
        disabled
        use_ldap
        username
        email_address
        phone_ddi
        use_acl_for_main_nav
    /);

    # get required params and populate hash only if they have been submitted
    foreach my $param (@params_to_get) {
        $user_info{$param}  = $param_of->{$param}       if ( exists $param_of->{$param} );
    }

    return \%user_info;
}

# Used to get all the preference parameters from a form to populate the
# operator preferences, in case of an error, so details aren't lost
sub _get_user_pref_params {
    my ( $schema, $param_of ) = @_;

    # put list of params in array
    my @columns = $schema->resultset('Public::OperatorPreference')->result_source->columns;

    # get params and populate hash only if they have been submitted
    my %user_info = map { $_ => $param_of->{$_} }
        grep { $_ ne 'operator_id' && exists $param_of->{$_} } @columns;

    return \%user_info;
}

# Gets all of the sections and sub_sections that user's can access
sub get_authorisation_sections {
    my ( $schema, $param_of, $form_override ) = @_;

    my %user_auth   = ();

    my $authsect_rs = $schema->resultset('Public::AuthorisationSubSection')->search( undef, { prefetch => 'section' });

    while ( my $row = $authsect_rs->next ) {
        $user_auth{ $row->section->section }{ $row->sub_section }{'id'}   = $row->id;
        if ( exists $param_of->{"auth_".$row->id} && $form_override )
        {
            $user_auth{ $row->section->section }{ $row->sub_section }{'auth'} = $param_of->{"level_".$row->id};
        }
        else
        {
            $user_auth{ $row->section->section }{ $row->sub_section }{'auth'} = 0;
        }
    }
    return \%user_auth;
}

# Gets all of the departments
sub get_departments {
    my $schema      = shift;
    my $dept_rs     = $schema->resultset("Public::Department")->search();
    my %dept = ();

    while ( my $row = $dept_rs->next ) {
        $dept{ $row->id } = $row->department;
    }

    return \%dept;
}

# Calls functions to update a user's profile
sub _update_profile {
    my ( $operator, $postref, $effecting_user ) = @_;

    # CANDO-881 -- auto_login is now always off, use_ldap is always on
    $postref->{'auto_login'} = 0;
    $postref->{'use_ldap'}  = 1;

    # cope with checkboxes where their keys will be
    # absent to signify they have been unchecked
    if ( !$postref->{'disabled'} ) {
        $postref->{'disabled'} = 0;
    }
    if ( !$postref->{'use_acl_for_main_nav'} ) {
        $postref->{'use_acl_for_main_nav'} = 0;
    }

    # Update non-authorisation part of profile
    _update_account( $operator, $postref, $effecting_user );

    # Get the user's new authorisations from FORM
    my $new_auth_ref= _get_auth_levels($postref);

    # if you haven't got access to a section then it can't be your default home page
    if ( exists $postref->{default_home_page} ) {
        $postref->{default_home_page}   = 0         if ( !exists $new_auth_ref->{ $postref->{default_home_page} } );
    }

    # Update the User's authorisations
    _update_authorisations( $operator, $new_auth_ref, $effecting_user );

    # Update the User's Preferences
    $operator->update_or_create_preferences( $postref );

    return;
}

# Given a reference to parameters submitted from a webpage, this method
# identifies the auth fields and returns an array, using them as a key for the
# values, which are authentication level fields
sub _get_auth_levels {
    my ( $form_input_ref ) = @_;
    my %auth_input_ref;

    # Loop through form fields
    foreach my $authorised ( keys %{$form_input_ref} ) {

        # If 'Authorised' field
        if ( $authorised =~ /^auth_(\d+)$/ ) {

            # Set subsection id to key and authorisation level to value
            $auth_input_ref{$1} = $form_input_ref->{"level_$1"};
        }
    }

    return \%auth_input_ref;
}

# Updates the operator table for the user with the new details the operator
# table
sub _update_account {
    my ($operator, $postref, $effecting_user)   = @_;

    # if no Old Department set then use an Empty String
    my $old_dept = ( $operator->department_id ? $operator->department->department : '' );

    my $rows = $operator->update ( {
            name            => $postref->{'name'},
            department_id   => $postref->{'department_id'},
            auto_login      => $postref->{'auto_login'},
            disabled        => $postref->{'disabled'},
            email_address   => $postref->{'email_address'},
            phone_ddi       => $postref->{'phone_ddi'},
            use_ldap        => $postref->{'use_ldap'},
            use_acl_for_main_nav => $postref->{'use_acl_for_main_nav'},
        }
    );

    # get the New Department
    my $new_dept = ( $operator->discard_changes->department_id ? $operator->department->department : '' );

    if ( $new_dept ne $old_dept ) {
        xt_logger( qw(UserProfile) )->info( "USER=" . $effecting_user
                                            . " CHANGED_USER=" . $operator->username
                                            . " OLD_DEPT=\"$old_dept\" NEW_DEPT=\"".$new_dept.'"' );
    }

    return $rows;
}

# Updates the operator_authorisation table changes the auth level, adds
# sections and deletes sections as appropriate
sub _update_authorisations {
    my ( $operator, $new_auth_ref, $effecting_user )    = @_;

    # loop round current auth's for user from DB
    for my $rec ( $operator->operator_authorisations->all ) {

        # If User already authorised
        if ( exists $new_auth_ref->{$rec->authorisation_sub_section_id} ) {

            # Authorisation changed - update database
            if ( !( $rec->authorisation_level_id == $new_auth_ref->{$rec->authorisation_sub_section_id} ) ) {
                $rec->update( { authorisation_level_id => $new_auth_ref->{$rec->authorisation_sub_section_id} } );
                xt_logger->info( "USER=$effecting_user"
                                 . "CHANGED_USER=" . $rec->operator->username
                                 . ' TYPE=UPDATE SECTION="'.$rec->auth_sub_section->section->section
                                 . '" SUB_SECTION="'.$rec->auth_sub_section->sub_section.'"' );
            }

            # Remove entry from new auth's hash
            delete $new_auth_ref->{$rec->authorisation_sub_section_id};
        }
        else {
            xt_logger->info( "USER=$effecting_user"
                             . "CHANGED_USER=" . $rec->operator->username
                             . ' TYPE=DELETE SECTION="'.$rec->auth_sub_section->section->section
                             . '" SUB_SECTION="'.$rec->auth_sub_section->sub_section.'"' );
            $rec->delete();
        }
    }

    # Authorisation add - for each entry still in the new auth's hash create in DB
    foreach my $subsec_id( keys % {$new_auth_ref} ) {
        $operator->create_related('operator_authorisations', {
            authorisation_sub_section_id    => $subsec_id,
            authorisation_level_id          => $new_auth_ref->{$subsec_id}
        });
    }

    return;
}

# Prints barcode for operators
sub _print_operator_barcode {
    my ($user_id, $postref) = @_;

    $postref->{'user_id'} = $user_id;

    my $barcode
        = create_barcode( 'login-'.$user_id, lc($postref->{'username'}), 'small', 2, 0, 60 );

    my $html
        = create_document( 'login-' . $user_id . q{}, 'print/operator_barcode.tt', $postref );

    my $result
        = print_document( 'login-' . $user_id . q{}, 'picking-regular', 1 );

    return;

}

1;
