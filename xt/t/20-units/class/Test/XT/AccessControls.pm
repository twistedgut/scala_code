package Test::XT::AccessControls;
use NAP::policy "tt",     'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::AccessControls

=head1 DESCRIPTION

Tests the 'XT::AccessControls' Class and assoicated Classes/Modules, such as:

    XT::AccessControls::InsecurePaths

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition    export => qw( $distribution_centre );
use Test::XTracker::Data::AccessControls;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :department
                                    );
use XTracker::Utilities::ACL        qw( main_nav_option_to_url_path );
use XTracker::Config::Local;

use XT::AccessControls::InsecurePaths   qw( permitted_insecure_path );

use XT::AccessControls;


# to be done first before ALL the tests start
sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup;
}

# to be done BEFORE each test runs
sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

    # get an Operator
    $self->{operator}   = $self->rs('Public::Operator')
                                ->search( { id => { '!=' => $APPLICATION_OPERATOR_ID } } )
                                    ->first;

    $self->{session}    = $self->_basic_session;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_access_controls_class

Test instantiating the Class.

=cut

sub test_access_controls_class : Tests() {
    my $self    = shift;

    my $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => $self->{session},
    } );
    isa_ok( $acl, 'XT::AccessControls', "can Instantiate Class" );

    note "test Required Arguments for the Class";
    my %tests   = (
        "with No 'operator' passed should die" => {
            args    => {
                session     => $self->{session},
            },
        },
        "with No 'session' passed should die" => {
            args    => {
                operator    => $self->{operator},
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        dies_ok {
            $acl = XT::AccessControls->new( $test->{args} );
        } "died on Instantiation";
    }
}

=head2 test_can_call_methods_and_attributes

Tests that all Expected Methods and Attributes can be called without dieing.

=cut

sub test_can_call_methods_and_attributes : Tests() {
    my $self    = shift;

    my $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => $self->{session},
    } );

    my %methods = (
        logger                      => [],
        operator                    => [],
        schema                      => [],
        dbh                         => [],
        session                     => [],
        operator_roles              => [],
        operator_has_the_role       => [ 'role' ],
        operator_has_role_in        => [],
        number_of_roles_for_operator=> [],
        list_of_roles_for_operator  => [],
        can_build_main_nav_using_acl=> [],
        url_restrictions            => [],
    );

    while ( my ( $method, $params ) = each %methods ) {
        ok( $acl->can( $method ), "can call '${method}'" );
        lives_ok {
            $acl->$method( @{ $params } );
        } "and when called, '${method}' doesn't DIE";
    }
}

=head2 test_roles_get_filtered

This tests that only the Roles we want get pulled into
the 'operator_roles' Attribute.

=cut

sub test_roles_get_filtered : Tests() {
    my $self    = shift;

    my $this_dc = $distribution_centre;
    my $that_dc = $self->rs('Public::DistribCentre')
                        ->search( { name => { '!=' => $this_dc } } )
                            ->first->name;

    my @roles = (
        "app_canPick",
        "app_can-fly~APP.XT${this_dc}",
        "app_can-fly~APP.XT${that_dc}",
        "email_canPack",
        "app_canPack~APP.XT${that_dc}",
        "app_has_RTV~APP.XT${this_dc}&BRAND.NAP",
        "app_can_do_GI~BRAND.NAP&APP.XT${this_dc}",
        "app_can_do_Returns~BRAND.NAP&APP.XT${that_dc}",
        "app_makes_sense~BRAND.NAP",
        "APP_cando",
        "aPp_can_talk~",
        "aapp_rolename",
    );

    my $acl_obj = $self->_get_acl_object( \@roles );
    my @got = $acl_obj->list_of_roles_for_operator;
    cmp_deeply(
        \@got,
        bag( qw(
            app_canpick
            app_can-fly
            app_has_rtv
            app_can_do_gi
            app_makes_sense
            app_cando
            app_can_talk
        ) ),
        "got ALL the expected Roles after they've been filtered they are all Lowercased"
    );

    # now give a set of Roles where none of them match
    @roles = qw(
        app_can-fly~APP.XT${that_dc}
        email_canPack
        app_canPack~APP.XT${that_dc}
        aapp_rolename
    );

    $acl_obj = $self->_get_acl_object( \@roles );
    @got = $acl_obj->list_of_roles_for_operator;
    is_deeply( \@got, [], "when NO Roles Match then none are found" );

    # check when NO Roles are given at all
    $acl_obj = $self->_get_acl_object( [] );
    @got = $acl_obj->list_of_roles_for_operator;
    is_deeply( \@got, [], "when NO Roles Given then none are found" );
}


=head2 test_populating_operator_roles

This tests that the 'operator_roles' Attribute gets populated correctly
based on what is in the Session.

=cut

sub test_populating_operator_roles : Tests() {
    my $self    = shift;

    my $roles   = $self->_get_some_roles();

    # what '$acl->operator_roles' should look like
    my %expected_roles  = map { $_ => 1 } @{ $roles };

    # the Session will have an ArrayRef of Roles
    # so use the keys from the above Hash
    my $session = $self->_session_with_roles( $roles );

    my $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => $session,
    } );

    is_deeply( $acl->operator_roles, \%expected_roles,
                    "'operator_roles' Attribute is as Expected" );

    note "testing 'operator_has_the_role'";
    cmp_ok( $acl->operator_has_the_role('app_can_make_tea'), '==', 1,
                    "returns TRUE when asking for a Role the Operator DOES have" );
    cmp_ok( $acl->operator_has_the_role('app_can_make_coffee'), '==', 0,
                    "returns FALSE when asking for a Role the Operator does NOT have" );

    note "testing when an Operator doesn't have Roles and when NO Roles were in the Session";

    # an Operator who doesn't have Roles
    $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => $self->_basic_session,
    } );
    is_deeply( $acl->operator_roles, {},
                    "when an Operator doesn't have any Roles then an empty Hash is found" );

    # a Session without Roles
    $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => { acl => {} },
    } );
    throws_ok {
        $acl->operator_roles;
    } qr/Session.*can't find Operator Roles/i,
                    "when a Session doesn't have any Roles then use of 'operator_roles' should die";
}

=head2 test_operator_has_role_in

Tests the 'operator_has_role_in' method.

=cut

sub test_operator_has_role_in : Tests() {
    my $self    = shift;

    my $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => $self->{session},
    } );

    throws_ok {
        my $got = $acl->operator_has_role_in( { role => 1 } );
    } qr/must.*Scalar.*Array/i,
                "when past a NON Array Ref, it dies with the correct error";

    my %tests   = (
        "Passing 'undef' as the Roles" => {
            roles   => undef,
            expect  => 0,
        },
        "Passing an Empty String as the Roles" => {
            roles   => '',
            expect  => 0,
        },
        "Passing an Empty Array Ref as the Roles" => {
            roles   => [ ],
            expect  => 0,
        },
        "Passing one Role as a Scalar that the Operator Has" => {
            roles   => 'app_can_make_tea',
            expect  => 1,
        },
        "Passing one Role as a Scalar that the Operator Does Not Have" => {
            roles   => 'app_can_make_coffee',
            expect  => 0,
        },
        "Passing an Array Ref of Roles all of which the Operator Has" => {
            roles   => [ qw( app_can_make_tea app_can_fly app_can_pack ) ],
            expect  => 1,
        },
        "Passing an Array Ref of Roles all of which the Operator Does Not Have" => {
            roles   => [ qw( app_can_make_coffee app_can_jump app_can_pick ) ],
            expect  => 0,
        },
        "Passing Several Roles of which the Operator has only One of" => {
            roles   => [ qw( app_can_back_flip app_can_look_sincere app_can_see_dead_people app_has_human_rights app_can_levitate ) ],
            expect  => 1,
        },
        "Passing Several Roles when the Operator has NO Roles" => {
            operator_roles => [],
            roles   => [ qw( app_can_make_tea app_can_fly app_can_pack ) ],
            expect  => 0,
        },
        "Passing mixed Cased Roles makes no difference and ALL are found" => {
            roles   => [ qw( aPp_cAn_mAKe_tea aPp_cAn_flY aPP_CAN_PAck ) ],
            expect  => 1,
        },
    );


    my $roles   = $self->_get_some_roles;

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        $acl = XT::AccessControls->new( {
            operator    => $self->{operator},
            session     => $self->_session_with_roles( $test->{operator_roles} // $roles ),
        } );

        my $got = $acl->operator_has_role_in( $test->{roles} );
        cmp_ok( $got, '==', $test->{expect},
                        "'operator_has_role_in' returns " . ( $test->{expect} ? 'TRUE' : 'FALSE' ) );
    }
}

=head2 test_operator_has_all_roles

Tests the 'operator_has_all_roles' method.

=cut

sub test_operator_has_all_roles : Tests() {
    my $self    = shift;

    my $roles   = $self->_get_some_roles;

    my $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => $self->{session},
    } );

    throws_ok {
        my $got = $acl->operator_has_all_roles( { role => 1 } );
    } qr/must.*Scalar.*Array/i,
                "when past a NON Array Ref, it dies with the correct error";

    my %tests   = (
        "Passing 'undef' as the Roles" => {
            roles   => undef,
            expect  => 0,
        },
        "Passing an Empty String as the Roles" => {
            roles   => '',
            expect  => 0,
        },
        "Passing an Empty Array Ref as the Roles" => {
            roles   => [ ],
            expect  => 0,
        },
        "Passing one Role as a Scalar that the Operator Has" => {
            roles   => 'app_can_make_tea',
            expect  => 1,
        },
        "Passing one Role as a Scalar that the Operator Does Not Have" => {
            roles   => 'app_can_make_coffee',
            expect  => 0,
        },
        "Passing an Array Ref of Roles all of which the Operator Has" => {
            roles   => [ qw( app_can_make_tea app_can_fly app_can_pack ) ],
            expect  => 1,
        },
        "Passing an Array Ref of Roles all of which the Operator Does Not Have" => {
            roles   => [ qw( app_can_make_coffee app_can_jump app_can_pick ) ],
            expect  => 0,
        },
        "Passing Several Roles of which the Operator has only One of" => {
            roles   => [ qw( app_can_back_flip app_can_look_sincere app_can_see_dead_people app_has_human_rights app_can_levitate ) ],
            expect  => 0,
        },
        "Passing Several Roles when the Operator has NO Roles" => {
            operator_roles => [],
            roles   => [ qw( app_can_make_tea app_can_fly app_can_pack ) ],
            expect  => 0,
        },
        "Passing an Array Ref of Mixed Cased Roles all of which the Operator Has" => {
            roles   => [ qw( APp_CAn_make_tea APP_CAN_fly APp_CAn_pACk ) ],
            expect  => 1,
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        $acl = XT::AccessControls->new( {
            operator    => $self->{operator},
            session     => $self->_session_with_roles( $test->{operator_roles} // $roles ),
        } );

        my $got = $acl->operator_has_all_roles( $test->{roles} );
        cmp_ok( $got, '==', $test->{expect},
                        "'test_operator_has_all_roles' returns " . ( $test->{expect} ? 'TRUE' : 'FALSE' ) );
    }
}

=head2 test_build_and_checking_main_nav_options

Test the 'build_main_nav' method which gets the Options used for
the Main Navigation. Then also checks the 'has_permission' method
with the 'can_use_fallback' argument passed which checks that the
Main Nav Option that was chosen can actually be accessed by the
Operator using the Role to Authorisation Sub Section functionality
or the 'operator_authorisation' table.

=cut

sub test_build_and_checking_main_nav_options : Tests() {
    my $self    = shift;

    # re-define RAVNI & PRL functions so as to
    # make sure certain menu options are excluded

    # first store the Original functions
    my $orig_ravni_func = \&XTracker::RAVNI_transient::is_ravni_disabled_section;
    my $orig_prl_func   = \&XTracker::PRLPages::is_prl_disabled_section;

    no warnings 'redefine';
    *XTracker::Schema::ResultSet::ACL::AuthorisationRole::is_ravni_disabled_section = $self->_redefined_is_ravni_disabled_section;
    *XTracker::Schema::ResultSet::ACL::AuthorisationRole::is_prl_disabled_section   = $self->_redefined_is_prl_disabled_section;
    use warnings 'redefine';

    my $al_read_only    = $AUTHORISATION_LEVEL__READ_ONLY;
    my $al_operator     = $AUTHORISATION_LEVEL__OPERATOR;
    my $al_manager      = $AUTHORISATION_LEVEL__MANAGER;

    Test::XTracker::Data::AccessControls->clearout_link_role_to_url_path();
    Test::XTracker::Data::AccessControls->set_main_nav_options( {
        # setup for the ACL way of building the main Nav
        acl => {
            app_has_admin_rights    => [
                'Admin/User Admin',
            ],
            app_can_pack            => [
                'Fulfilment/Packing Exception',
                'Fulfilment/Packing',
            ],
            app_can_make_tea        => [
                'Fulfilment/Packing',
            ],
            app_has_superpowers     => [
                'RTV/Pick RTV',
                'RTV/Pack RTV',
            ],
            app_can_fly             => [
                'Customer Care/Order Search',
                'Customer Care/Customer Search',
            ],
            app_can_see_dead_people => [
                'Finance/Fraud Rules',
                'Goods In/Returns In',
            ],
        },
        # setup for the old way of building the Main Nav
        non_acl => {
            department => 'Customer Care',
            operator   => $self->{operator},
            $al_operator => [
                'Goods In/Returns In',
            ],
            $al_manager => [
                'Admin/Email Templates',
                'Fulfilment/Dispatch',
                'Fulfilment/Picking',
            ],
        },
        delete_existing_acl_options => 1,
    } );

    # get all the Nav Options specified above either
    # using ACL Roles or 'operator_authorisation'
    my $all_nav_options = $self->_get_all_nav_options();

    # get the 'ord' value on the 'authorisation_sub_section'
    # table for every Sub Section, this govens the order in
    # which the options are displayed and returned by the methods
    my $sub_section_ord = $self->_get_sub_section_ord_values;

    # create a Role which doesn't have any Main Nav options associated with it
    $self->rs('ACL::AuthorisationRole')->update_or_create( { authorisation_role => 'app_not_for_main_nav' } );

    my %tests   = (
        "When the Main Switch is turned Off the Old way is used" => {
            setup => {
                main_switch => 'off',
            },
            expect => {
                'Admin'      => [ 'Email Templates' ],
                'Fulfilment' => [ 'Dispatch', 'Picking' ],
                'Goods In'   => [ 'Returns In' ],
            },
        },
        "When the Operator's 'use_acl_for_main_nav' flag is FALSE the Old way is used" => {
            setup => {
                operator_flag => 0,
            },
            expect => {
                'Admin'      => [ 'Email Templates' ],
                'Fulfilment' => [ 'Dispatch', 'Picking' ],
                'Goods In'   => [ 'Returns In' ],
            },
        },
        "When the Operator has NO Roles the Old way is used" => {
            setup => {
                roles => [],
            },
            expect => {
                'Admin'      => [ 'Email Templates' ],
                'Fulfilment' => [ 'Dispatch', 'Picking' ],
                'Goods In'   => [ 'Returns In' ],
            },
        },
        "The Operator has Roles and Switches/Flags are TRUE the New way is used" => {
            setup  => { },
            expect => {
                'Admin'         => [ 'User Admin' ],
                'Fulfilment'    => [ 'Packing Exception', 'Packing' ],
                'RTV'           => [ 'Pick RTV', 'Pack RTV' ],
                'Customer Care' => [ 'Order Search', 'Customer Search' ],
                'Finance'       => [ 'Fraud Rules' ],
                'Goods In'      => [ 'Returns In' ],
            },
        },
        "The Operator only has some of the Roles, only some of the Options are Returned" => {
            setup => {
                roles => [ qw(
                    app_can_make_tea
                    app_can_fly
                ) ],
            },
            expect => {
                'Fulfilment'    => [ 'Packing' ],
                'Customer Care' => [ 'Order Search', 'Customer Search' ],
            },
        },
        "The Operator only has some but not all of the Roles, only some of the Options are Returned" => {
            setup => {
                roles => [ qw(
                    app_has_admin_rights
                    app_can_see_dead_people
                ) ],
            },
            expect => {
                'Admin'         => [ 'User Admin' ],
                'Finance'       => [ 'Fraud Rules' ],
                'Goods In'      => [ 'Returns In' ],
            },
        },
        "The Operator has Roles but NONE have any Options assigned, then the Old way is used" => {
            setup => {
                roles => [ qw(
                    app_have_made_up_role
                    app_can_stare_at_goats
                ) ],
            },
            expect => {
                'Admin'      => [ 'Email Templates' ],
                'Fulfilment' => [ 'Dispatch', 'Picking' ],
                'Goods In'   => [ 'Returns In' ],
            },
        },
        "Check when the Section is a RAVNI Section and it has been Disabled, the RAVNI Option isn't returned" => {
            setup => {
                ravni => { section => 'Admin', sub_section => 'User Admin' },
            },
            expect => {
                'Fulfilment'    => [ 'Packing Exception', 'Packing' ],
                'RTV'           => [ 'Pick RTV', 'Pack RTV' ],
                'Customer Care' => [ 'Order Search', 'Customer Search' ],
                'Finance'       => [ 'Fraud Rules' ],
                'Goods In'      => [ 'Returns In' ],
            },
        },
        "Check when the Section is a PRL Section and it has been Disabled, the PRL Option isn't returned" => {
            setup => {
                prl => { section => 'RTV', sub_section => 'Pack RTV' },
            },
            expect => {
                'Admin'         => [ 'User Admin' ],
                'Fulfilment'    => [ 'Packing Exception', 'Packing' ],
                'RTV'           => [ 'Pick RTV' ],
                'Customer Care' => [ 'Order Search', 'Customer Search' ],
                'Finance'       => [ 'Fraud Rules' ],
                'Goods In'      => [ 'Returns In' ],
            },
        },
        "Check when there are both PRL & RAVNI Sections Disabled, that neither Options are returned" => {
            setup => {
                ravni   => { section => 'Admin', sub_section => 'User Admin' },
                prl     => { section => 'RTV',   sub_section => 'Pack RTV' },
            },
            expect => {
                'Fulfilment'    => [ 'Packing Exception', 'Packing' ],
                'RTV'           => [ 'Pick RTV' ],
                'Customer Care' => [ 'Order Search', 'Customer Search' ],
                'Finance'       => [ 'Fraud Rules' ],
                'Goods In'      => [ 'Returns In' ],
            },
        },
        "Operator has some Main Nav Roles & Some other Role NOT associated to a Main Nav option, only the expected options should still appear" => {
            setup => {
                roles => [ qw(
                    app_has_admin_rights
                    app_can_see_dead_people
                    app_not_for_main_nav
                ) ],
            },
            expect => {
                'Admin'         => [ 'User Admin' ],
                'Finance'       => [ 'Fraud Rules' ],
                'Goods In'      => [ 'Returns In' ],
            },
        },
        "The Operator Roles are of a different 'case' than in the DB, expected Main Nav options should still be found" => {
            setup => {
                roles => [ qw(
                    aPp_has_ADMin_rights
                    App_can_sEE_DEAd_people
                ) ],
            },
            expect => {
                'Admin'         => [ 'User Admin' ],
                'Finance'       => [ 'Fraud Rules' ],
                'Goods In'      => [ 'Returns In' ],
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # define the defaults for setup and then
        # override them for each specific test
        my %setup   = (
            main_switch     => 'on',
            operator_flag   => 1,
            roles           => $self->_get_some_roles,
            prl             => { section => '', sub_section => '' },
            ravni           => { section => '', sub_section => '' },
            %{ $test->{setup} },
        );

        $self->_change_global_main_nav_switch( $setup{main_switch} );
        $self->{operator}->update( { use_acl_for_main_nav => $setup{operator_flag} } );

        # to control the re-defined functions
        $self->{prl_control}    = $setup{prl};
        $self->{ravni_control}  = $setup{ravni};

        # sort out what to expect
        my %granted_access;
        my %expect;
        foreach my $section ( keys %{ $test->{expect} } ) {
            $expect{ $section } = {
                map {
                    $sub_section_ord->{ "${section}/${_}" } => superhashof( {
                        section     => $section,
                        sub_section => $_,
                        ord         => $sub_section_ord->{ "${section}/${_}" },
                    } )
                } @{ $test->{expect}{ $section } }
            };

            # get all the Sections & Sub-Sections that should be
            # granted Access for testing the 'has_permission' method
            $granted_access{ $section }{ $_ } = 1   foreach ( @{ $test->{expect}{ $section } } );
        }

        my $acl_obj = $self->_get_acl_object( $setup{roles} );
        my $got     = $acl_obj->build_main_nav;

        cmp_deeply( $got, \%expect, "calling 'build_main_nav' returned the Expected Main Nav Options" );


        note "testing 'has_permission' method to see if the relevant Nav Options are Granted or Denied Access";

        # include any RAVNI or PRL Options in 'granted_access'
        # as they won't be excluded when calling 'has_permission'
        $granted_access{ $setup{prl}{section} }{ $setup{prl}{sub_section} }     = 1     if ( $setup{prl}{section} );
        $granted_access{ $setup{ravni}{section} }{ $setup{ravni}{sub_section} } = 1     if ( $setup{ravni}{section} );

        foreach my $section ( keys %{ $all_nav_options } ) {
            while (  my ( $sub_section, $auth_level_id ) = each %{ $all_nav_options->{ $section } } ) {

                # clear these out from the Session
                delete $acl_obj->session->{auth_level};
                delete $acl_obj->session->{department_id};

                # if Section & Sub-Section are in Granted Access then
                # check access is granted else expected access to be denied
                my $expect          = ( exists( $granted_access{ $section }{ $sub_section } ) ? 1 : 0 );
                my $expect_label    = ( $expect ? 'granted' : 'denied' );
                my $got             = $acl_obj->has_permission( _make_url( $section, $sub_section ), { can_use_fallback => 1 } );

                cmp_ok( $got, '==', $expect, "Access '${expect_label}' for '${section}/${sub_section}'" );
                ok( !exists( $acl_obj->session->{auth_level} ), "No 'auth_level' set in Session when 'update_session' not passed" );
                ok( !exists( $acl_obj->session->{department_id} ), "No 'department_id' set in Session when 'update_session' not passed" );

                $got = $acl_obj->has_permission( _make_url( $section, $sub_section ), {
                    update_session   => 1,
                    can_use_fallback => 1,
                } );
                cmp_ok( $got, '==', $expect, "Access '${expect_label}' for '${section}/${sub_section}' with 'update_session' passed" );

                if ( $expect ) {
                    cmp_ok( $acl_obj->session->{auth_level}, '==', $all_nav_options->{ $section }{ $sub_section },
                                                "'auth_level' set in Session and with the correct value" );
                    cmp_ok( $acl_obj->session->{department_id}, '==', $DEPARTMENT__CUSTOMER_CARE,
                                                "'department_id' set in Session and with the correct value" );
                }
                else {
                    # if access is denied then the Session should still NOT have been updated
                    ok( !exists( $acl_obj->session->{auth_level} ), "Still No 'auth_level' set in Session when 'update_session' passed" );
                    ok( !exists( $acl_obj->session->{department_id} ), "Still No 'department_id' set in Session when 'update_session' passed" );
                }
            }
        }
    }


    # restore Original functions
    no warnings 'redefine';
    *XTracker::Schema::ResultSet::ACL::AuthorisationRole::is_prl_disabled_section   = $orig_prl_func;
    *XTracker::Schema::ResultSet::ACL::AuthorisationRole::is_ravni_disabled_section = $orig_ravni_func;
    use warnings 'redefine';
}

=head2 test_authorised_access_to_url

This tests the 'has_permission' method when calling with a URL
but without the 'can_use_fallback' argument being passed in.

=cut

sub test_authorised_access_to_url : Tests() {
    my $self    = shift;

    # set-up what Roles should have
    # access to which URL Paths
    my %roles_for_paths = (
        app_can_do_something => [
            # this Role won't be assigned to the Operator
            # so none of these URLs should be authorised
            '/SomeURL',
            '/SomeURL/Stage1',
            '/SomeURL/Stage1/PartB',
            '/Fulfilment/Packing',
            '/Fly',
        ],
        app_can_fly => [
            '/Fly/Up',
            '/Fly/Down',
            '/Fly/Onwards',
        ],
        app_has_superpowers => [
            '/Fly/Up',
            '/XRay/On/Full',
            '/XRay/Off',
            '/Fulfilment/OnHold',
        ],
    );
    Test::XTracker::Data::AccessControls->set_url_path_roles( \%roles_for_paths );

    # create a Main Nav Option that isn't any of the above
    # and because the 'fallback' option won't be being used
    # these shouldn't result in access being authorised
    my %main_nav_options = (
        # set-up the options for both ACL & NON-ACL so that it
        # doesn't matter how the rest of the system is set-up
        acl => {
            app_can_fly => [
                'Fulfilment/Packing',
            ],
            app_can_do_something => [
                'Fulfilment/DDU',
            ],
        },
        non_acl => {
            department => 'Customer Care',
            operator   => $self->{operator},
            $AUTHORISATION_LEVEL__MANAGER => [
                'Fulfilment/Packing',
                'Fulfilment/DDU',
            ],
        },
        delete_existing_acl_options => 1,
    );
    Test::XTracker::Data::AccessControls->set_main_nav_options( \%main_nav_options );

    my %tests = (
        "Using 'undef' as a URL" => {
            url     => undef,
            expect  => 0,
        },
        "Using an Empty String as a URL" => {
            url     => '',
            expect  => 0,
        },
        "Using an Unknown URL" => {
            url     => '/Some/Unknown/URL',
            expect  => 0,
        },
        "Using a URL that the Operator doesn't have a Role for" => {
            url     => '/SomeURL/Stage1',
            expect  => 0,
        },
        "Using an ALL Lowercased URL that shouldn't match a different cased version" => {
            url     => '/fly/onwards',
            expect  => 0,
        },
        "Using a URL which the Operator has a Main Nav option for but with no Fallback should fail" => {
            url     => '/Fulfilment/Packing',
            expect  => 0,
        },
        "Using an Unknown URL for 'url_path' but one that does exist as a Main Nav Option, with no Fallback should fail" => {
            url     => '/Fulfilment/DDU',
            expect  => 0,
        },
        "Using a URL that is in 'url_path' and matches the start of a URL that the Operator does have access to, should fail" => {
            url     => '/Fly',
            expect  => 0,
        },
        "Using a URL that the Operator does have a Role for" => {
            url     => '/XRay/On/Full',
            expect  => 1,
        },
        "Using a URL that the Operator has more than one Role for" => {
            url     => '/Fly/Up',
            expect  => 1,
        },
        "Using another URL that the Operator has a Role for" => {
            url     => '/XRay/Off',
            expect  => 1,
        },
        "Using URL without leading slash" => {
            url     => 'XRay/On/Full',
            expect  => 1,
        }
    );

    my $acl_obj = $self->_get_acl_object;

    # make sure these two keys are NOT in the Session
    delete $acl_obj->session->{auth_level};
    delete $acl_obj->session->{department_id};

    foreach my $label ( keys %tests ) {
        note "Testing: '${label}'";
        my $test = $tests{ $label };

        my $result_label = ( $test->{expect} ? 'Authorised' : 'NOT Authorised' );

        note "using URL: '" . ( $test->{url} // 'undef' ) . "'";
        my $got = $acl_obj->has_permission( $test->{url} );
        ok( defined $got, "'check_authorised_access' returned a defined result" );
        cmp_ok( $got, '==', $test->{expect}, "and was as expected: '${result_label}'" );
    }

    note "make sure the Session hasn't been Updated when authorising the URL Paths";
    ok( !exists( $acl_obj->session->{auth_level} ), "'auth_level' key does NOT exist in the Session" );
    ok( !exists( $acl_obj->session->{department_id} ), "'department_id' key does NOT exist in the Session" );

    note "Use a URL from the URL Path table that is assigned to the Operator's Roles as a";
    note "Main Nav option but NOT as a URL Path, use the 'can_use_fallback' argument and the";
    note "URL should NOT be Authorised as being linked to in the URL Path table takes precedence";
    my $got = $acl_obj->has_permission( '/Fulfilment/Packing', {
        can_use_fallback => 1,
    } );
    ok( defined $got, "'check_authorised_access' returned a defined result" );
    cmp_ok( $got, '==', 0, "and was as expected: 'NOT Authorised'" );

    # add a Main Nav option that is also defined as a
    # URL Path and associate it to a Role the Operator has
    push @{ $main_nav_options{acl}{app_has_superpowers} }, 'Fulfilment/On Hold';
    push @{ $main_nav_options{non_acl}{ $AUTHORISATION_LEVEL__MANAGER } }, 'Fulfilment/On Hold';
    Test::XTracker::Data::AccessControls->set_main_nav_options( \%main_nav_options );

    note "now use a URL Path that has ALSO been assigned as a Main Nav option which the Fallback method would use";

    note "check that when passing 'update_session' but not using Fallback, the Session is still NOT updated";
    $got = $acl_obj->has_permission( '/Fulfilment/OnHold', {
        update_session => 1,
    } );
    cmp_ok( $got, '==', 1, "'/Fulfilment/OnHold' was 'Authorised'" );
    ok( !exists( $acl_obj->session->{auth_level} ), "'auth_level' key STILL does NOT exist in the Session" );
    ok( !exists( $acl_obj->session->{department_id} ), "'department_id' key STILL does NOT exist in the Session" );

    note "check that when passing 'update_session' & 'can_use_fallback', the Session is still NOT updated";
    $got = $acl_obj->has_permission( '/Fulfilment/OnHold', {
        update_session   => 1,
        can_use_fallback => 1,
    } );
    cmp_ok( $got, '==', 1, "'/Fulfilment/OnHold' was 'Authorised'" );
    ok( !exists( $acl_obj->session->{auth_level} ), "'auth_level' key STILL does NOT exist in the Session" );
    ok( !exists( $acl_obj->session->{department_id} ), "'department_id' key STILL does NOT exist in the Session" );
}

=head2 test_url_restrictions

Tests the 'url_restrictions' attribute which contains all of the
URLs in the 'acl.url_path' table and the Roles associated with them.

=cut

sub test_url_restrictions : Tests() {
    my $self    = shift;

    my $acl = XT::AccessControls->new( {
        operator    => $self->{operator},
        session     => $self->{session},
    } );

    # Create data
    Test::XTracker::Data::AccessControls->set_url_path_roles( {
        XT_test_role => [ qw( /Test/Path ) ],
    } );
    my $no_roles_url = $self->rs('ACL::URLPath')->create( { url_path => '/No/Roles' });

    # Grab URL/role restrictions
    my $restrictions = $acl->url_restrictions;

    # Test, test, test
    ok(@{$restrictions->{'/Test/Path'}}, 'Some restrictions on defined and restricted URL');
    ok( ! defined $restrictions->{'/Non/Existent'}, 'No restrictions on undefined URL');
    ok( !@{$restrictions->{'/No/Roles'}}, 'No restrictions on defined but unrestricted URL');
}

=head2 test_can_protect_sidenav

Tests the 'can_protect_sidenav' method that decides whether the sidenav
should use ACL Protection when it gets drawn.

=cut

sub test_can_protect_sidenav : Tests() {
    my $self = shift;

    my $config = \%XTracker::Config::Local::config;

    my $acl_obj = $self->_get_acl_object;

    # take a copy of the original config to restore later
    my %orig_config = %{ $config->{ACL_Protected_Sidenav} };


    note "Test using a Call Frame";

    #
    # This tests the method using a Call Frame to determine
    # the Class of the Caller. The tests will set the config
    # with Classes from the Call Frames of this test method
    # (test_can_protect_sidenav) and then pass in Call Frame
    # numbers that should either match or not match what's
    # in the Config.
    #
    # The Call Frame is used by NON-Catalyst Handlers.
    #

    delete $config->{ACL_Protected_Sidenav}{name};
    my $got = $acl_obj->can_protect_sidenav( { call_frame => 2 } );
    cmp_ok( $got, '==', 0, "returned FALSE when there are no Classes in the Config" );

    $config->{ACL_Protected_Sidenav}{name} = ( caller(2) )[0];
    $got = $acl_obj->can_protect_sidenav( { call_frame => 2 } );
    cmp_ok( $got, '==', 1, "returned TRUE when only one Class in the Config and using a Call Frame number to a Class in the Config" );
    $got = $acl_obj->can_protect_sidenav( { call_frame => 4 } );
    cmp_ok( $got, '==', 0, "returned FALSE when only one Class in the Config and NOT using a Call Frame number to a Class in the Config" );

    $config->{ACL_Protected_Sidenav}{name} = [
        ( caller(1) )[0],
        ( caller(3) )[0],
    ];
    $got = $acl_obj->can_protect_sidenav( { call_frame => 3 } );
    cmp_ok( $got, '==', 1, "returned TRUE when more than one Class in the Config and using a Call Frame number to a Class in the Config" );
    $got = $acl_obj->can_protect_sidenav( { call_frame => 6 } );
    cmp_ok( $got, '==', 0, "returned FALSE when more than one Class in the Config and NOT using a Call Frame number to a Class in the Config" );


    note "Test using a URL";

    #
    # This tests the method using a URL to see
    # if it matches what is in the Config. The
    # Tests will set the Config with some URLs
    # and then pass some in that either should
    # or should not match what's in the Config.
    #
    # URLs are used by Catalyst Handlers.
    #

    delete $config->{ACL_Protected_Sidenav}{url};
    $got = $acl_obj->can_protect_sidenav( { url => '/some/url' } );
    cmp_ok( $got, '==', 0, "returned FALSE when there are no URLs in the Config" );

    $config->{ACL_Protected_Sidenav}{url} = '/Some/Url';
    $got = $acl_obj->can_protect_sidenav( { url => '/Some/Url' } );
    cmp_ok( $got, '==', 1, "returned TRUE when only one URL in the Config" );
    $got = $acl_obj->can_protect_sidenav( { url => '/Another/Url' } );
    cmp_ok( $got, '==', 0, "returned FALSE when only one URL in the Config" );
    $got = $acl_obj->can_protect_sidenav( { url => 'Some/Url' } );
    cmp_ok( $got, '==', 1, "returned TRUE when passing a URL without leading '/'" );

    $config->{ACL_Protected_Sidenav}{url} = [ qw(
        /Some/Url
        /Another/Link
        /Pattern/Matching.*
    ) ];
    $got = $acl_obj->can_protect_sidenav( { url => '/Another/Link' } );
    cmp_ok( $got, '==', 1, "returned TRUE when more than one URL in the Config" );
    $got = $acl_obj->can_protect_sidenav( { url => '/Not/In/Config' } );
    cmp_ok( $got, '==', 0, "returned FALSE when more than one URL in the Config" );

    # test using pattern matching links
    # check '/Pattern/Matching/Link' matches against '/Pattern/Matching.*'
    $got = $acl_obj->can_protect_sidenav( { url => '/Pattern/Matching/Link' } );
    cmp_ok( $got, '==', 1, "returned TRUE when URL matching against a RegEx" );
    # check '/Pattern/Matching' matches against '/Pattern/Matching.*'
    $got = $acl_obj->can_protect_sidenav( { url => '/Pattern/Matching' } );
    cmp_ok( $got, '==', 1, "returned TRUE when URL matching exactly against a RegEx" );
    # check '/Pattern' does NOT match against '/Pattern/Matching.*'
    $got = $acl_obj->can_protect_sidenav( { url => '/Pattern' } );
    cmp_ok( $got, '==', 0, "returned FALSE when URL doesn't match entirely the RegEx" );
    # check '/Another/Link/Again' does NOT match against '/Another/Link'
    $got = $acl_obj->can_protect_sidenav( { url => '/Another/Link/Again' } );
    cmp_ok( $got, '==', 0, "returned FALSE when URL has part of a non-RegEx Config URL in it" );


    $config->{ACL_Protected_Sidenav} = \%orig_config;
}

=head2 test_permitted_insecure_path

Test the 'permitted_insecure_path' function in the 'XT::AccessControls::InsecurePaths' module
that it returns TRUE or FALSE based on whether a path matches whats in the config.

=cut

sub test_permitted_insecure_path : Tests() {
    my $self    = shift;

    my $config = \%XTracker::Config::Local::config;

    # take a copy of the original config to restore later
    my %orig_config;
    %orig_config = %{ $config->{ACL}{insecure_paths} }  if ( exists( $config->{ACL}{insecure_paths} ) );

    # set the new config for the 'ACL->insecure_paths' section
    my $insecure_paths = [ qw(
        test
        path/to/test
        should/match
    ) ];
    $config->{ACL}{insecure_paths}{path} = $insecure_paths;

    my %tests = (
        "Pass a Path that shouldn't match" => {
            path_to_use => 'qwerty',
            expect      => 0,
        },
        "Pass a Path that similar but not an exact match" => {
            path_to_use => 'tes',
            expect      => 0,
        },
        "Pass a simple Path that should match" => {
            path_to_use => 'test',
            expect      => 1,
        },
        "Pass a more complex Path that should match" => {
            path_to_use => 'path/to/test',
            expect      => 1,
        },
        "Pass a Path that contains one of the config paths in it ('test') and should still match" => {
            path_to_use => 'test/this',
            expect      => 1,
        },
        "Test that the Case a Path is in doesn't matter and still matches" => {
            path_to_use => 'SHOULD/Match',
            expect      => 1,
        },
    );

    note "Paths used to Test against: " . p( $insecure_paths );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test = $tests{ $label };
        my $path = $test->{path_to_use};

        my $got = permitted_insecure_path( $path );
        cmp_ok( $got, '==', $test->{expect},
                        "'permitted_insecure_path' returned the expected result for path: '${path}'" );
    }


    note "TEST when there is only one path in the Config that everything still works";
    $config->{ACL}{insecure_paths}{path} = 'some/path';
    my $got = permitted_insecure_path( 'some/path' );
    cmp_ok( $got, '==', 1, "'permitted_insecure_path' still returns TRUE when it matches" );

    $got = permitted_insecure_path( 'no/match' );
    cmp_ok( $got, '==', 0, "'permitted_insecure_path' still returns FALSE when it doesn't match" );


    # restore the Config
    $config->{ACL}{insecure_paths} = \%orig_config      if ( keys( %orig_config ) );
}

#----------------------------------------------------------------------

# build an XT::AccessControls object
# with a set of Roles, by default use
# those from '_get_some_roles'
sub _get_acl_object {
    my ( $self, $roles )    = @_;

    return XT::AccessControls->new( {
        operator    => $self->{operator}->discard_changes,
        session     => $self->_session_with_roles( $roles // $self->_get_some_roles ),
    } );
}

# some Roles to be used in the tests
sub _get_some_roles {
    my $self    = shift;

    return Test::XTracker::Data::AccessControls->roles_for_tests;
}

# create the minimum required in the Session
# that XT::AccessControls requires
sub _basic_session {
    my $self    = shift;

    return {
        acl => {
            operator_roles  => [],
        },
    };
}

# create a session with Operator Roles
sub _session_with_roles {
    my ( $self, $roles )    = @_;

    return {
        acl => {
            operator_roles => $roles,
        },
    };
}

# turn on/off the Main Switch to use ACL
# to build the Main Navigation
sub _change_global_main_nav_switch {
    my ( $self, $value )    = @_;

    Test::XTracker::Data->remove_config_group( 'ACL' );
    Test::XTracker::Data->create_config_group( 'ACL', {
        settings => [
            { setting => 'build_main_nav', value => $value },
        ],
    } );

    return;
}

# get all the Main Nav options specified
# for an Operator and Roles
sub _get_all_nav_options {
    my $self    = shift;

    my %nav_options;

    # get the options for Roles first
    my @options = $self->rs('ACL::LinkAuthorisationRoleAuthorisationSubSection')->all;
    foreach my $option ( @options ) {
        my $section     = $option->authorisation_sub_section->section->section;
        my $sub_section = $option->authorisation_sub_section->sub_section;
        # default all Authorisation Roles to have an Auth Level of Read-Only
        $nav_options{ $section }{ $sub_section }    = $AUTHORISATION_LEVEL__READ_ONLY;
    }

    # now get the options in the 'operator_authorisation' table
    @options    = $self->rs('Public::OperatorAuthorisation')
                        ->search( { operator_id => $self->{operator}->id } )->all;
    foreach my $option ( @options ) {
        my $section     = $option->auth_sub_section->section->section;
        my $sub_section = $option->auth_sub_section->sub_section;
        $nav_options{ $section }{ $sub_section }    = $option->authorisation_level_id;
    }

    return \%nav_options;
}

# get the 'ord' values for all sub sections
# in the 'authorisation_sub_section' table
sub _get_sub_section_ord_values {
    my $self    = shift;

    my @sub_sections = $self->rs('Public::AuthorisationSubSection')->all;

    return {
        map {
            $_->section->section . '/' . $_->sub_section => $_->ord,
        } @sub_sections
    };
}

# redefined 'is_ravni_disabled_section' function
sub _redefined_is_ravni_disabled_section {
    my $self    = shift;

    return sub {
        my ( $section, $sub_section )   = @_;

        note "================== IN RE-DEFINED 'is_ravni_disabled_section' function ==================";

        return 0    if ( !$section || !$sub_section );

        # just look out for one Main Nav Option
        if ( $section eq $self->{ravni_control}{section} && $sub_section eq $self->{ravni_control}{sub_section} ) {
            return 1;
        }
        return 0;
    };
}

# redefined 'is_prl_disabled_section' function
sub _redefined_is_prl_disabled_section {
    my $self    = shift;

    return sub {
        my ( $section, $sub_section )   = @_;

        note "================== IN RE-DEFINED 'is_prl_disabled_section' function ==================";

        return 0    if ( !$section || !$sub_section );

        # just look out for one Main Nav Option
        if ( $section eq $self->{prl_control}{section} && $sub_section eq $self->{prl_control}{sub_section} ) {
            return 1;
        }
        return 0;
    };
}

# given a Section & Sub-Section will
# join them together to form the URL
sub _make_url {
    return main_nav_option_to_url_path( @_ );
}

