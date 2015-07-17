
package Test::NAP::Admin;

=head1 NAME

Test::NAP::Admin - Test some miscellaneous functions only Admins can do

=head1 DESCRIPTION

Test some miscellaneous functions only Admins can do

#TAGS xpath stickypage useradmin admin misc http toobig fraud finance candoandwhm

=head1 METHODS

=cut

use NAP::policy "tt",     'test';
use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;
use Test::XTracker::Data::AccessControls;
use XTracker::Utilities qw(:string);
use Test::XT::Flow;

use XTracker::Constants::FromDB     qw( :authorisation_level :department );
use XTracker::Config::Local         qw( use_acl_to_build_main_nav );
use JSON::XS;

sub startup : Test( startup => 1 ) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [qw/
            Test::XT::Flow::Admin
            Test::XT::Flow::PrintStation
        /],
    );

}

sub setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->{framework}->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Admin/Email Templates',
                'Admin/Sticky Pages',
                'Admin/Fraud Rules',
                'Admin/User Admin',
                'Admin/ACL Admin',
                'Admin/ACL Main Nav Info',
                'Goods In/Quality Control',
                'Goods In/Returns In',
                'Goods In/Returns QC',
            ],
        },
    } );


}

sub shutdown : Test( shutdown ) {
    my ( $self ) = @_;

    $self->delete_operators( $self->{operators} );
    $self->delete_acl_roles( $self->{acl_roles});
    $self->SUPER::shutdown;
}

# Delete any created operators and their sticky pages
sub delete_operators {
    my ( $self, $operators ) = @_;
    for my $operator (@$operators) {
        my $sp = $operator->sticky_page;
        $sp->delete if $sp;
        $operator->delete;
    }
}

# Delete  any acl aut roles created.
sub delete_acl_roles {
    my( $self, $roles ) = @_;
    for my $role (@$roles) {
        $role->link_authorisation_role__authorisation_sub_sections->delete_all;
        $role->delete;
    }
}

=head2 test_sticky_pages_permissions

Tests that only a user with I<Manager> authorisation for the
'/Admin/StickyPages' page can access the page.

=cut

sub test_sticky_pages_permissions : Tests {
    my ( $self ) = @_;
    my $mech = $self->{framework}->mech;
    for (
        [ q{}, 0, ],
        [ $AUTHORISATION_LEVEL__READ_ONLY, 0, ],
        [ $AUTHORISATION_LEVEL__OPERATOR, 0, ],
        [ $AUTHORISATION_LEVEL__MANAGER, 1, ],
    ) {
        my ( $level, $is_allowed ) = @$_;
        Test::XTracker::Data->grant_permissions('it.god', 'Admin', 'Sticky Pages', $level);
        $mech->get_ok( '/Admin/StickyPages' );
        if ( $is_allowed ) {
            is($mech->uri->path, '/Admin/StickyPages',
                "access granted for level '$level'" );
        }
        else {
            $mech->has_feedback_error_ok(qr{You don't have permission},
                "access denied for level '$level'" );
        }
    }
}

=head2 test_remove_sticky_pages

Create two sticky pages for two operators - one dated $now, the other dated
$now-1day.

Verify that both entries appear on the sticky pages admin page. Verify that the
old one has a I<warn> class.

Remove the sticky pages and verify that we get a sticky page deleted success
message.

=cut

sub test_remove_sticky_pages : Tests {
    my ( $self ) = @_;

    my @operators = map { $self->create_test_operator } 1..2;
    $self->{operators} = \@operators;

    my $now = DateTime->now(time_zone => 'UTC');
    my $yesterday = $now->clone->subtract(days => 1);
    $_->[0]->create_related('sticky_page', {
        signature => 'just a sig',
        html => 'html',
        sticky_class => 'Operator::StickyPage::Packing',
        sticky_id => 1,
        created => $_->[1],
    }) for ([$operators[0],$now], [$operators[1],$yesterday]);

    my $framework = $self->{framework};
    $framework->flow_mech__admin__sticky_pages;

    my $mech = $framework->mech;
    # Ensure operators appear in table
    for my $operator ( @operators ) {
        ok( (grep {
                $_->{Remove}{input_value} == $operator->id
            } @{$mech->as_data->{sticky_pages}}),
            sprintf 'operator %d found in sticky pages admin table', $operator->id
        );
    }
    like($mech->find_xpath( sprintf(
            q{//form[@id='remove_sticky_pages']//input[@value=%d]/..},
            $operators[1]->id)
        )->pop->attr('class'),
        qr{warn},
        q{old stickies have a 'warn' class}
    ) or diag sprintf(
        q{got '%s', expected '%s'},
        $operators[1]->sticky_page->created, $yesterday
    );
    # Test sticky page removal
    $framework->flow_mech__admin__remove_sticky_pages([map { $_->id } @operators]);
    $mech->has_feedback_success_ok(
        sprintf q{Deleted %d sticky pages}, scalar @operators);
    for my $operator ( @operators ) {
        ok( !(grep {
                $_->{Remove}{input_value} == $operator->id
            } @{$mech->as_data->{sticky_pages}}),
            sprintf 'operator %d deleted from sticky pages admin table', $operator->id
        );
    }
}

sub create_test_operator {
    my ( $self, $args ) = @_;

    my $id = Test::XTracker::Data->next_id('public.operator');
    return $self->{framework}->schema->resultset('Public::Operator')->create({
        id => $id,
        name => $args->{name} // "Test Operator $id",
        username => $args->{username} // "t.operator_$id",
        password => $args->{password} // 'new',
        auto_login => $args->{auto_login} // 0,
        disabled => $args->{disabled} // 0,
        department_id => $args->{department_id} // $DEPARTMENT__IT,
        email_address => $args->{email} // "test.operator_$id\@net-a-porter.com",
        use_ldap => $args->{use_ldap} // 1,
    })->discard_changes;
}

=head2 test_fraud_rules_admin

Tests the 'Admin->Fraud Rules' page which allows users to change the Switch for
the Fraud Rules Engine.

Test when no ACL roles are assigned /Admin/FraudRules throws permission denied error.

Verify when roles are assigned page is accessible.

Switch fraud rules off in all channels.

Verify that all radio buttons are off, and that the
switch change log is empty.

Turn NAP on, and verify it's set correctly. Set Outnet to on, MRP to
parallel, and verify the radio buttons are set correctly.

Turn NAP off, and verify that all changes were logged.

=cut

sub test_fraud_rules_admin : Tests() {
    my $self    = shift;

    my $flow    = $self->{framework};
    my $schema  = $flow->schema;
    my $mech    = $flow->mech;
    $mech->client_parse_cell_deeply( 1 );       # gets more information for cells containing 'INPUT' tags

    note "Accessing Admin/Fraud Rules page with no roles";

    $flow->login_with_permissions ({
        roles => {}
    });


    $flow->catch_error(
        qr/don't have permission to/i,
        q{Can't access the /Admin/FraudRules page},
        flow_mech__admin__fraud_rules => ()
    );

    note " Accessing Admin/FraudRules page With role";

    my %channels= map {
        $_->business->config_section => $_
    } $schema->resultset('Public::Channel')->all;

    $schema->resultset('Fraud::LogRuleEngineSwitchPosition')->delete;       # clear out all Logs

    Test::XTracker::Data::FraudRule->switch_all_channels_off;

    $flow->login_with_permissions({
        roles => {
            paths => [ '/Admin/FraudRules' ]
        },
    });
    $mech->no_feedback_error_ok;

    Test::XTracker::Data::FraudRule->switch_all_channels_off;

    $flow->flow_mech__admin__fraud_rules;

    my $switch_table = $mech->as_data()->{switches};

    cmp_ok( @{ $switch_table }, '==', scalar keys %channels, "Got All Sales Channels in Switch Table" );


    is_deeply(
        $self->_get_switch_positions,
        { map { $_->id => 'off' } values %channels },
        "and All Channels are Switched 'Off'"
    );

    my $log = $mech->as_data()->{switch_log};
    cmp_ok( @{ $log }, '==', 0, "Switch Change Log is Empty" );

    # turn 'On' for NAP
    $flow->flow_mech__admin__fraud_rules_flip_switch( {
        $channels{NAP}->id  => 'On',
    } );
    is_deeply(
        $self->_get_switch_positions,
        {
            ( map { $_->id => 'off' } values %channels ),
            $channels{NAP}->id => 'on',
        },
        "Switched 'NAP' to 'On'"
    );

    # turn 'On' OUTNET and 'Parallel' for MRP
    $flow->flow_mech__admin__fraud_rules_flip_switch( {
        $channels{OUTNET}->id   => 'on',
        $channels{MRP}->id      => 'parallel',
    } );
    is_deeply(
        $self->_get_switch_positions,
        {
            ( map { $_->id => 'off' } values %channels ),
            $channels{NAP}->id => 'on',
            $channels{OUTNET}->id => 'on',
            $channels{MRP}->id => 'parallel',
        },
        "Switched 'OUTNET' to 'On' and 'MRP' to 'Parallel'"
    );

    # turn 'Off' NAP
    $flow->flow_mech__admin__fraud_rules_flip_switch( {
        $channels{NAP}->id   => 'off',
    } );
    is_deeply(
        $self->_get_switch_positions,
        {
            ( map { $_->id => 'off' } values %channels ),
            $channels{OUTNET}->id => 'on',
            $channels{MRP}->id => 'parallel',
        },
        "Switched 'NAP' back to 'Off'"
    );

    $log    = $mech->as_data()->{switch_log};
    is_deeply(
        [
            map { { $_->{'Sales Channel'} => $_->{'Switched To'} } } @{ $log }
        ],
        [
            { $channels{NAP}->name => 'On' },
            { $channels{OUTNET}->name => 'On' },
            { $channels{MRP}->name => 'Parallel' },
            { $channels{NAP}->name => 'Off' },
        ],
        "Switch Log shows All the Changes that have happened"
    );

    cmp_ok( $channels{NAP}->is_fraud_rules_engine_off, '==', 1,
                "'is_fraud_rules_engine_off' returns TRUE for NAP" );
    cmp_ok( $channels{OUTNET}->is_fraud_rules_engine_on, '==', 1,
                "'is_fraud_rules_engine_on' returns TRUE for OUTNET" );
    cmp_ok( $channels{MRP}->is_fraud_rules_engine_in_parallel, '==', 1,
                "'is_fraud_rules_engine_in_parallel' returns TRUE for MRP" );

    $mech->client_parse_cell_deeply( 0 );
}


# return which position the Switch
# is on for each Sales Channel
sub _get_switch_positions {
    my $self    = shift;

    my $switch_table    = $self->{framework}->mech
                                ->as_data()->{switches};

    my %channels;
    foreach my $row ( @{ $switch_table } ) {
        my ( $position )= grep { ref( $_ ) && $_->{input_checked} }
                            values %{ $row };
        my $channel_id  = $position->{input_name};
        $channel_id     =~ s/[^\d]//g;
        $channels{ $channel_id } = $position->{input_value};
    }

    return \%channels;
}

=head2 test_select_printer_station

This test is probably overkill - but as we had a bug (WHM-2492) where we
weren't being redirected properly for just one entry in the dropdown, we now
test that selecting every entry produces the desired results

Get an operator and verify it has no preferred printer station name.

For GoodsIn's QualityControl, ReturnsIn and ReturnsQC pages, verify we redirect
to the select printer station page, select a printer, and verify we are
redirected to the page we were trying to access.

=cut

sub test_select_printer_station : Tests() {
    my $self = shift;

    my $flow = $self->{framework};
    my $mech = $flow->mech;
    my $operator = $mech->logged_in_as_object;

    # Let's make sure we start without a blank printer station if this operator
    # already has some preferences
    $self->_unset_printer_station_name( $operator );

    for my $uri (qw<
        /GoodsIn/QualityControl
        /GoodsIn/ReturnsIn
        /GoodsIn/ReturnsQC
    >) {
        # Get our URI so we can build our printer station list
        $mech->get_ok($uri);
        like($mech->uri, qr{SelectPrinterStation}, 'redirected to select printer station page');

        # Loop through all the pickable stations
        for my $station ( grep { $_ } map { $_->{value} } @{$mech->as_data->{stations}} ) {
            subtest "test set station $station on $uri" => sub {
                # Again, make sure there's no printer station if the operator
                # has some preferences
                $self->_unset_printer_station_name( $operator );

                # Put us on the select printer station page
                $mech->get_ok($uri);
                like($mech->uri, qr{SelectPrinterStation},
                    'redirected to select printer station page');

                # Submit a value and make sure the results are the ones we expect
                $flow->flow_mech__select_printer_station_submit($station);
                $mech->has_feedback_success_ok('Printer Station Selected');
                like($mech->uri, qr{$uri}, "redirected to $uri");
                # Selecting the printer station should've created an operator
                # preference row if there wasn't one before, so we should
                # definitely be able to check it now.
                is(
                    $operator->discard_changes->operator_preference->printer_station_name,
                    $station,
                    'operator preference has correct printer station name'
                );
            };
        }
    }
}

sub _unset_printer_station_name {
    my ( $self, $operator ) = @_;
    # Make sure we don't use a cached version of operator_preference
    my $operator_preference = $operator->discard_changes->operator_preference;
    $operator_preference->update({printer_station_name => undef})
        if $operator_preference;
}

=head2 test_admin_user_profile

Tests the 'User Profile' page which shows the Operator's details.

=cut

sub test_admin_user_profile : Tests() {
    my $self    = shift;

    my $flow            = $self->{framework};
    my $logged_in_user  = $flow->mech->logged_in_as_object;
    my $user_admin_auth = $logged_in_user->operator_authorisations->search(
        {
            'auth_sub_section.sub_section' => 'User Admin',
            'section.section'              => 'Admin',
        },
        {
            join => { auth_sub_section => 'section' },
        }
    )->first;
    $flow->mech->client_parse_cell_deeply(1);

    my $operator    = $self->create_test_operator();
    $operator->update( { department_id => $DEPARTMENT__DISTRIBUTION } );


    note "Testing the 'Account Details' section";

    note "check updating the 'Use LDAP to Build Nav' option";
    $operator->update( { use_acl_for_main_nav => 1 } );

    $flow->flow_mech__admin__user_profile( $operator->id );
    my $pg_details  = $flow->mech->as_data()->{account_details};
    cmp_ok( $pg_details->{'Use LDAP to build Main Nav'}{input_checked}, '==', 1,
                            "'Use LPAD to build Main Nav' option is checked on the page" );

    note "turn the option OFF";
    $flow->flow_mech__admin__user_profile_update( { use_acl_for_main_nav => 0 } );
    $pg_details = $flow->mech->as_data()->{account_details};
    cmp_ok( $pg_details->{'Use LDAP to build Main Nav'}{input_checked}, '==', 0,
                            "'Use LPAD to build Main Nav' option is un-checked on the page" );
    cmp_ok( $operator->discard_changes->use_acl_for_main_nav, '==', 0,
                            "and the 'use_acl_for_main_nav' field is FALSE on the 'operator' record" );

    note "turn the option back ON";
    $flow->flow_mech__admin__user_profile_update( { use_acl_for_main_nav => 1 } );
    $pg_details = $flow->mech->as_data()->{account_details};
    cmp_ok( $pg_details->{'Use LDAP to build Main Nav'}{input_checked}, '==', 1,
                            "'Use LPAD to build Main Nav' option is checked again on the page" );
    cmp_ok( $operator->discard_changes->use_acl_for_main_nav, '==', 1,
                            "and the 'use_acl_for_main_nav' field is TRUE on the 'operator' record" );


    note "Testing the 'Authorisation' section";

    # get any Sub-Section from either Fulfilment or Goods In as this page
    # works in 2 ways: if you have Manager Level Access you have can assign
    # all options, if you have Operator Level Access you can only assign
    # Fulfilment & Goods In options, this test will try both ways
    my $sub_section_rec = $self->rs('Public::AuthorisationSubSection')->search(
        {
            'section.section' => { IN => [ 'Fulfilment', 'Goods In' ] },
        },
        {
            join    => 'section',
        }
    )->first;

    # store the original 'acl_controlled' value for restoring later
    my $orig_acl_setting = $sub_section_rec->acl_controlled;

    note "loop round Operator & Manager Authorisation Level setting for the User Admin page";

    my @auth_levels = $self->rs('Public::AuthorisationLevel')->all;
    AUTH_LEVEL:
    foreach my $auth_level ( @auth_levels ) {
        next AUTH_LEVEL     if ( $auth_level->id == $AUTHORISATION_LEVEL__READ_ONLY );

        note "using 'Admin->User Admin' page under Authorisation Level: '" . $auth_level->description . "'";
        $user_admin_auth->discard_changes->update( { authorisation_level_id => $auth_level->id } );

        # now stop the Sub-Section being set by the User Profile page
        my $sub_section = $sub_section_rec->sub_section;
        my $section     = $sub_section_rec->section->section;

        note "putting '${section}->${sub_section}' under ACL Control";
        $sub_section_rec->discard_changes->update( { acl_controlled => 1 } );
        $flow->flow_mech__admin__user_profile( $operator->id );
        $pg_details = $flow->mech->as_data()->{authorisation}{ $section }{ $sub_section };
        cmp_ok( $pg_details->{'Authorised'}{input_readonly}, '==', 1,
                        "Authorised checkbox is Disabled" );
        cmp_ok( $pg_details->{'Authorisation Level'}{select_readonly}, '==', 1,
                        "Authorisation Level drop-down is Disabled as well" );

        note "try Assigning '${section}->${sub_section}' to the Operator, shouldn't work";
        $flow->flow_mech__admin__user_profile_update( {
            'auth_' . $sub_section_rec->id => 1,
            'level_' . $sub_section_rec->id => $AUTHORISATION_LEVEL__MANAGER,
        } );
        my $option_assigned = $operator->operator_authorisations->search( {
            authorisation_sub_section_id => $sub_section_rec->id
        } )->count;
        cmp_ok( $option_assigned, '==', 0, "'${section}->${sub_section}' NOT assigned to the Operator" );

        note "putting '${section}->${sub_section}' back under User Admin control";
        $sub_section_rec->discard_changes->update( { acl_controlled => 0 } );
        $flow->flow_mech__admin__user_profile( $operator->id );
        $pg_details = $flow->mech->as_data()->{authorisation}{ $section }{ $sub_section };
        cmp_ok( $pg_details->{'Authorised'}{input_readonly}, '==', 0,
                        "Authorised checkbox is once again useable" );
        cmp_ok( $pg_details->{'Authorisation Level'}{select_readonly}, '==', 0,
                        "Authorisation Level drop-down is useable as well" );

        note "try Assigning '${section}->${sub_section}' to the Operator, should work";
        $flow->flow_mech__admin__user_profile_update( {
            'auth_' . $sub_section_rec->id => 1,
            'level_' . $sub_section_rec->id => $AUTHORISATION_LEVEL__MANAGER,
        } );
        $option_assigned = $operator->operator_authorisations->search( {
            authorisation_sub_section_id => $sub_section_rec->id
        } )->count;
        cmp_ok( $option_assigned, '==', 1, "'${section}->${sub_section}' NOW assigned to the Operator" );
    }

    # restore the 'acl_controlled' setting for the Sub Section
    $sub_section_rec->discard_changes->update( { acl_controlled => $orig_acl_setting } );

    $flow->mech->client_parse_cell_deeply(0);
}

=head2 test_acl_admin_page

Tests the ACL Admin page where ACL system wide settings are maintained.

=cut

sub test_acl_admin_page : Tests() {
    my $self    = shift;

    my $flow    = $self->{framework};

    # turn On the Build Main Nav using ACL setting
    Test::XTracker::Data::AccessControls->set_build_main_nav_setting('On');

    $flow->flow_mech__admin__acl_admin;
    my $pg_data = $flow->mech->as_data()->{page_data};


    note "check 'Build Main Nav using LDAP' option";
    cmp_ok( $pg_data->{'Build Main Nav using LDAP'}, '==', 1, "option is 'On' on the page" );

    $flow->flow_mech__admin__acl_admin_update( {
        setting_build_main_nav => 0,
    } );
    like( $flow->mech->app_status_message, qr/updated/i, "got 'Updated' message" );
    $pg_data = $flow->mech->as_data()->{page_data};
    ok( !defined $pg_data->{'Build Main Nav using LDAP'}, "option is 'Off' on the page" );
    cmp_ok( use_acl_to_build_main_nav( $self->schema ), '==', 0, "and 'Off' in the DB" );

    $flow->flow_mech__admin__acl_admin_update( {
        setting_build_main_nav => 1,
    } );
    like( $flow->mech->app_status_message, qr/updated/i, "got 'Updated' message" );
    $pg_data = $flow->mech->as_data()->{page_data};
    cmp_ok( $pg_data->{'Build Main Nav using LDAP'}, '==', 1, "option is back 'On' on the page" );
    cmp_ok( use_acl_to_build_main_nav( $self->schema ), '==', 1, "and 'On' in the DB" );

    $flow->flow_mech__admin__acl_admin_update( {
        setting_build_main_nav => 1,
    } );
    ok( !$flow->mech->app_status_message, "NO 'Update' message when updating the setting with the existing value" );


    # restore the original state of the Build Main Nav setting
    Test::XTracker::Data::AccessControls->restore_build_main_nav_setting;
}


sub test_acl_main_nav_info :Tests() {
    my $self = shift;

    my $flow  =  $self->{framework};

    $flow->flow_mech__admin__acl_main_nav_info;
    my $pg_data = $flow->mech->as_data()->{page_data};


    # check when page loads, result data is empty
    cmp_ok($pg_data, 'eq', "\'\'", "Page data should be empty as expected");

    # Test for user roles
    # insert to table
    my @roles = map { $self->_create_acl_auth_role($_) } 1..2;
    $self->{acl_roles} = \@roles;

    $self->_create_link_role_to_subsection( {
        app_canTestRole1 => [
            'Admin/User Admin'
        ],
        app_canTestRole2 => [
            'Admin/Fraud Rules',
            'Goods In/Returns QC',
        ],
    });

    $flow->flow_mech__admin__acl_main_nav_info_role_submit({
        user_roles => 'app_canTestRole1'
    });

    $pg_data = $flow->mech->as_data()->{page_data};

    my $expected_data = [
    {
        label => 'Admin',
        children => [
            { label => 'User Admin' }
        ]
    }];

    my $got_data = JSON::XS->new->pretty->decode($pg_data);
    is_deeply($got_data, $expected_data, "User Roles: Navigation options are as expected");


    #get id for User Admin
    my $sub_section_rs = $self->{framework}->schema->resultset('Public::AuthorisationSubSection')->search({
        sub_section => 'User Admin'
    })->first;

    #check for navigation
    $flow->flow_mech__admin__acl_main_nav_info_role_submit({
        nav_options => $sub_section_rs->id,
    });

    $expected_data =
        {
          "children" => [
             {
                "children" => [
                   "User Admin"
                ],
                "label" => "Admin"
             }
          ],
          "label" => "app_canTestRole1",
        };

    $pg_data = $flow->mech->as_data()->{page_data};
    my $format_data = JSON::XS->new->pretty->decode($pg_data);

    #extracting hash from returned content
    my $got;
    foreach my $node (@{$format_data} ) {
        if (grep {$_ eq 'app_canTestRole1'} values %{$node}) {
           $got = $node;
           last;
        }
    }
    cmp_deeply($got, superhashof( $expected_data), "Navigation Options: User roles as expected")


}

=head2 test_admin_email_templates_page

Tests the Admin  Email Templates page

=cut

sub test_admin_email_templates_page : Tests() {
    my $self    = shift;

    my $flow    = $self->{framework};

    # delete all log entries
    my $log_rs = $self->{framework}->schema->resultset('Public::CorrespondenceTemplatesLog');
    $log_rs->delete_all;

    $flow->flow_mech__admin__email_templates
         ->flow_mech__admin__edit_email_templates('TEST');

    #Step:1 Update content of template
    $flow->flow_mech__admin__edit_email_template_submit({
        content => "_TEST CONTENT_"
    });

    #test content was updated
    my $page_data = $flow->mech->as_data();
    cmp_ok($page_data->{template_content} ,'eq', '_TEST CONTENT_',"Email Content is as expeced");


    $flow->errors_are_fatal(0);

    # test template parser error
    $flow->flow_mech__admin__edit_email_template_submit({
        content => "
            [% FOREACH user = userlist %]
                [% INCLUDE userinfo %]"
    });

    like( $flow->mech->app_error_message,
          qr/Error saving the template: line 3: unexpected end of input/i,
          "Template Parser Error"
     );

    $page_data = $flow->mech->as_data();
    my $log = $page_data->{template_log};
    # there is log entry due to Step 1
    cmp_ok( @{ $log }, '==', 1, "Template Change Log is not updated" );


    # Test correct template gets saved
    $flow->flow_mech__admin__edit_email_template_submit({
        content => "[% FOREACH user = userlist %][% INCLUDE userinfo %][% END %]"
    });

    $page_data  = $flow->mech->as_data();
    $log        = $page_data->{template_log};
    my $content    = $page_data->{template_content};


    like($flow->mech->app_status_message,
         qr/Template Updated/i,
         "Template Saved correctly"
    );
    cmp_ok( @{ $log }, '==', 2, "Template Change Log has an Entry" );
    cmp_ok( $content,
        'eq',
        "[% FOREACH user = userlist %][% INCLUDE userinfo %][% END %]",
        "Content was update succesfully"
    );

}

sub _create_acl_auth_role {
    my $self = shift;
    my $args = shift;

    return $self->{framework}->schema->resultset('ACL::AuthorisationRole')->create({
        authorisation_role => 'app_canTestRole'.$args,
    })->discard_changes;

}


sub _create_link_role_to_subsection {
    my $self = shift;
    my $args = shift;

    Test::XTracker::Data::AccessControls->link_role_to_sub_section( $args );

    return ;
}

