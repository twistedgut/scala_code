#!/usr/bin/env perl
use NAP::policy "tt",     qw( class test );

BEGIN {
    extends 'NAP::Test::Class';
}

=head1 DESCRIPTION

Tests drawing the Main Nav using Roles

=cut

use Test::XTracker::Data;
use Test::XT::Flow;
use Test::XTracker::Data::AccessControls;

use XTracker::Config::Local         qw( use_acl_to_build_main_nav );
use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :department
                                    );
use XTracker::Database::Session;

use XTracker::Utilities             qw( parse_url_path );


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits  => [
            'Test::XT::Flow::Admin',
            'Test::XT::Flow::CustomerCare',
        ],
    );

    $self->{operator} = $self->rs('Public::Operator')
                                ->find( { username => 'it.god' } );

    Test::XTracker::Data::AccessControls->set_build_main_nav_setting( 'on' );
    Test::XTracker::Data::AccessControls->save_role_to_sub_section_links;
}

sub shut_down : Test( shutdown => no_plan ) {
    my $self    = shift;

    $self->SUPER::shutdown;

    Test::XTracker::Data::AccessControls->restore_build_main_nav_setting;
    Test::XTracker::Data::AccessControls->restore_role_to_sub_section_links;
}


=head1 TESTS

=head2 test_main_nav_using_acl

Check that the the Main Nav Menu shown on the page has all the expected
options in it when building it using Roles or the Old way.

This tests the building of the menu when on Catalyst & Non-Catalyst pages.

=cut

sub test_main_nav_using_acl : Tests() {
    my $self    = shift;

    my $flow    = $self->{flow};

    # expected Main Nav Entries
    my %expected_nav = (
        non_acl => {
            Home => 1,
            Admin => {
                'User Admin' => 1,
            },
            'Stock Control' => {
                Reservation => 1,
            },
            'Finance' => {
                'Store Credits' => 1,
            },
        },
        acl => {
            Home => 1,
            Admin => {
                'Email Templates' => 1,
            },
            'Fulfilment' => {
                Packing => 1,
            },
            'Finance' => {
                'Store Credits' => 1,
            },
        },
    );

    my $perms = {
        $AUTHORISATION_LEVEL__READ_ONLY => [
            'Admin/User Admin',
            'Stock Control/Reservation',
            # Catalyst page
            'Finance/Store Credits',
        ],
    };

    Test::XTracker::Data::AccessControls->set_main_nav_options( {
        acl => {
            app_has_admin_rights    => [ 'Admin/Email Templates' ],
            app_has_superpowers     => [
                'Fulfilment/Packing',
                # Catalyst page
                'Finance/Store Credits',
            ],
        },
        delete_existing_acl_options => 1,
    } );

    # make sure the Operator is set to
    # not use ACL to draw the Main Nav
    $self->{operator}->update( { use_acl_for_main_nav => 0 } );

    $flow->login_with_permissions( {
        dept => 'Customer Care',
        perms => $perms,
    } );
    # Make a request so we load the new nav bar
    $flow->mech->get_ok('/Home');

    note "Check the Main Nav for the correct Options which shouldn't be using ACL";
    my $main_nav    = $flow->mech->parse_main_navigation;
    is_deeply( $main_nav, $expected_nav{non_acl},
                    "Main Nav has expected Options when NOT using ACL to build it" );

    note "go to a Catalyst page and check Main Nav";
    $flow->mech->get_ok( '/Finance/StoreCredits' );
    $main_nav   = $flow->mech->parse_main_navigation;
    is_deeply( $main_nav, $expected_nav{non_acl},
                    "Main Nav on a Catalyst page has expected Options when NOT using ACL to build it" );


    note "Check the Main Nav for the correct Options when using ACL to build it";
    $self->{operator}->discard_changes->update( { use_acl_for_main_nav => 1 } );

    my $session = $flow->mech->session->replace_acl_roles(
        Test::XTracker::Data::AccessControls->roles_for_tests,
    );

    $flow->mech->get_ok( '/Home', "go to the 'Home' page (which isn't a Catalyst page)" );
    $main_nav   = $flow->mech->parse_main_navigation;
    is_deeply( $main_nav, $expected_nav{acl},
                    "Main Nav has expected Options when USING ACL to build it" );

    note "go to a Catalyst page and check Main Nav";
    $flow->mech->get_ok( '/Finance/StoreCredits' );
    $main_nav   = $flow->mech->parse_main_navigation;
    is_deeply( $main_nav, $expected_nav{acl},
                    "Main Nav on a Catalyst page has expected Options when USING ACL to build it" );

    $flow->mech->get_ok( '/Logout', "Logout to get rid of the Session" );
}

=head2 test_authorising_main_nav_options

Check that all Options shown on the Main Nav when it has been built using
Roles or the Old way CAN be accessed and all Main Nav options that aren't
shown can NOT be accessed and the 'don't have permission' warning is shown.

This checks accessing both Catalyst and Non-Catalyst pages.

=cut

sub test_authorising_main_nav_options : Tests() {
    my $self    = shift;

    my $flow    = $self->{flow};

    # expected Main Nav Entries
    my %nav_options = (
        non_acl => {
            Home => 1,
            Admin => {
                'User Admin' => 1,
            },
            'Stock Control' => {
                Reservation => 1,
            },
        },
        acl => {
            Home => 1,
            Admin => {
                'User Admin' => 1,
            },
            'Fulfilment' => {
                Packing => 1,
            },
            'Finance' => {
                'Store Credits' => 1,
            },
        },
    );

    my $perms = {
        $AUTHORISATION_LEVEL__READ_ONLY => [
            'Stock Control/Reservation',
        ],
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Admin/User Admin',
        ],
    };

    Test::XTracker::Data::AccessControls->set_main_nav_options( {
        acl => {
            app_has_admin_rights    => [ 'Admin/User Admin' ],
            app_has_superpowers     => [
                'Fulfilment/Packing',
                # Catalyst page
                'Finance/Store Credits',
            ],
        },
        delete_existing_acl_options => 1,
    } );

    # make sure the Operator is set to not
    # use ACL to Draw & Authorise the Main Nav
    $self->{operator}->discard_changes->update( { use_acl_for_main_nav => 0 } );

    $flow->login_with_permissions( {
        dept => 'Marketing',
        perms => $perms,
    } );

    my $non_acl_options = $self->_get_flatten_main_nav_options( $nav_options{non_acl} );
    my $acl_options     = $self->_get_flatten_main_nav_options( $nav_options{acl} );
    my $all_nav_options = $self->_get_flatten_main_nav_options(
        Test::XTracker::Data::AccessControls->get_all_main_nav_options( $self->{operator}->discard_changes )
    );
    # Assign Roles to the Operator's Session
    $flow->mech->session->replace_acl_roles(
        Test::XTracker::Data::AccessControls->roles_for_tests(),
    );

    note "Testing where ACL is NOT being used to Authorise Access to Main Nav pages";
    $self->_check_main_nav_option_access( $non_acl_options, $acl_options, $all_nav_options );

    # make sure the Operator now uses ACL for Main Nav Options
    $self->{operator}->discard_changes->update( { use_acl_for_main_nav => 1 } );

    note "Testing with ACL being used to Authorise Access to Main Nav pages";
    $self->_check_main_nav_option_access( $acl_options, $non_acl_options, $all_nav_options );

    $flow->mech->get_ok( '/Logout', "Logout to get rid of the Session" );
}

#-------------------------------------------------------------

# given 2 sets of main nav options this will test to make sure
# that options the Operator doesn't have permission for can't
# be accessed and the options they do have permission are can be
sub _check_main_nav_option_access {
    my ( $self, $allowed_list, $not_allowed_list, $all_options )    = @_;

    my $flow    = $self->{flow};

    $self->{operator}->discard_changes;

    note "check pages that the Operator DOESN'T have Permission to Access";
    OPTION:
    foreach my $option ( keys %{ $not_allowed_list } ) {
        # don't want an option that is in both lists
        next OPTION     if ( exists( $allowed_list->{ $option } ) );

        $flow->mech->get_ok( $option );
        $flow->mech->has_feedback_error_ok( qr/don't have permission/i, "get 'No Permission' error message" );

        my $session = $flow->mech->session->get_session;
        ok( !exists( $session->{auth_level} ), "NO 'auth_level' is set in the Session" );
        cmp_ok( $session->{department_id}, '==', $self->{operator}->department_id,
                    "'department_id' IS set in the Session" );
    }

    note "check pages that the Operator DOES have Permission to Access";
    foreach my $option ( keys %{ $allowed_list } ) {
        $flow->mech->get_ok( $option );
        $flow->mech->no_feedback_error_ok();

        my $session = $flow->mech->session->get_session;
        cmp_ok( $session->{auth_level}, '==', $all_options->{ $option },
                    "'auth_level' IS set in the Session & for the correct value" )      if ( $option ne '/Home' );
        cmp_ok( $session->{department_id}, '==', $self->{operator}->department_id,
                    "'department_id' IS set in the Session" );

        if ( $option ne '/Home' ) {
            my $path_parts  = parse_url_path( $option );
            like( $session->{current_sub_section}, qr/$path_parts->{sub_section}.*$path_parts->{section}/,
                        "'current_sub_section' has been set correctly" );
        }
        else {
            ok( !exists( $session->{current_sub_section} ), "'current_sub_section' doesn't exist for '/Home'" );
        }
    }
}

# given a Hash Ref. of Sections & Sub-Sections
# it will flattern the list into 'Section/SubSection'
# and return them into a Hash Ref.
sub _get_flatten_main_nav_options {
    my ( $self, $options )  = @_;

    my %flattened_options;

    foreach my $section ( keys %{ $options } ) {
        if ( ref( $options->{ $section } ) ) {
            # there is a sub-section so go through all of them

            my $sub_sections = $options->{ $section };
            $section         =~ s/ //g;

            while ( my ( $sub_section, $value ) = each %{ $sub_sections } ) {
                $sub_section    =~ s/ //g;
                $flattened_options{ "/${section}/${sub_section}" } = $value;
            }
        }
        else {
            $section =~ s/ //g;
            $flattened_options{ "/${section}" } = $options->{ $section };
        }
    }

    return \%flattened_options;
}

Test::Class->runtests;
