#!/usr/bin/env perl

=head1 NAME

userprofile.t - Test XTracker::Admin::UserProfile functions

=head1 DESCRIPTION

Tests XTracker::Admin::UserProfile functions - both public and private
functions in the class are tested

All functions except _print_operator_barcode are tested here.

#TAGS shouldbeunit

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;

use XTracker::Constants ':application';

my %test_hash_keys = (
    name            => 'Test User',
    department_id   => 10,
    auto_login      => 0,
    disabled        => 0,
    use_ldap        => 1,
    username        => 'testuser',
    email_address   => 'testuser@net-a-porter.com',
    phone_ddi       => '01234 567890',
    use_acl_for_main_nav => 0,
);
my %test_hash_keys_2i = (
    auth_80  => 1,
    auth_12  => 1,
    level_80 => 2,
    level_12 => 3,
);
my %test_hash_keys_2o  = (
    80 => 2,
    12 => 3,
);
my $channel_id = Test::XTracker::Data->channel_for_nap->id;
my %test_hash_keys_3   = (
    default_home_page => 80,
    pref_channel_id   => $channel_id,
);

use_ok( 'XTracker::Admin::UserProfile' );
can_ok("XTracker::Admin::UserProfile",qw(
    _get_auth_levels
    get_authorisation_sections
    get_departments
    _get_user_authorisation
    _print_operator_barcode
    _update_account
    _update_authorisations
    _update_profile
));

# get a schema to query
my $schema = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my $params = {
    name              => 'Test User',
    department_id     => 10,
    auto_login        => 0,
    disabled          => 0,
    use_ldap          => 1,
    username          => 'testuser',
    email_address     => 'testuser@net-a-porter.com',
    phone_ddi         => '01234 567890',
    pref_channel_id   => $channel_id,
    default_home_page => 80,
    use_acl_for_main_nav => 0,
};

# Tests the passive part of the module
subtest 'test_passive' => sub {
    my $user_info   = XTracker::Admin::UserProfile::_get_user_info_params($params);
    isa_ok($user_info,"HASH");
    foreach my $test_key (keys %test_hash_keys ) {
        is($user_info->{$test_key},$test_hash_keys{$test_key},"Test User Info - KEY: $test_key VALUE: $test_hash_keys{$test_key}");
    }
    my $user_pref   = XTracker::Admin::UserProfile::_get_user_pref_params($schema, $params);
    isa_ok($user_pref,"HASH");
    foreach my $test_key (keys %test_hash_keys_3 ) {
        is($user_pref->{$test_key},$test_hash_keys_3{$test_key},"Test User Info - KEY: $test_key VALUE: $test_hash_keys_3{$test_key}");
    }
    my $auth_sect   = XTracker::Admin::UserProfile::get_authorisation_sections($schema, $params);
    isa_ok($auth_sect,"HASH");
    my $depts       = XTracker::Admin::UserProfile::get_departments($schema);
    isa_ok($depts,"HASH");

    # When a User Id is passed (User Id set to 1 - Application)
    my $operator      = $schema->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID);
    isa_ok($operator,"XTracker::Schema::Result::Public::Operator");
    $auth_sect = XTracker::Admin::UserProfile::_get_user_authorisation($operator, $params);
    isa_ok($auth_sect,"HASH");
};

# Tests the Updating of a User's Details
subtest 'test_update' => sub {
    # Updating a User testing each sub routine
    $schema->txn_dont( sub {
        my $operator = $schema->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID);
        $params->{'use_ldap'} = 1;
        # Updating the Operator Table

        subtest 'update operator no dept' => sub {
            $operator->update( { department_id => undef } );
            my $upd_res = XTracker::Admin::UserProfile::_update_account($operator,$params);
            cmp_ok($upd_res,">=",1,"Operator WITHOUT a Department Record Updated");
        };

        subtest 'update operator table' => sub {
            my $upd_res  = XTracker::Admin::UserProfile::_update_account($operator,$params);
            cmp_ok($upd_res,">=",1,"Operator Record Updated");
            foreach my $test_key (keys %test_hash_keys ) {
                if ( $test_key ne "username" ) {
                    is($operator->$test_key,$test_hash_keys{$test_key},"Test User Info - KEY: $test_key VALUE: $test_hash_keys{$test_key}");
                }
                else {
                    isnt($operator->$test_key,$test_hash_keys{$test_key},"Test User Info - KEY: $test_key VALUE: $test_hash_keys{$test_key}");
                }
            }
        };

        # Updating the Operator Preferences Table
        subtest 'update operator preferences table' => sub {
            my $upd_res     = $operator->update_or_create_preferences($params);
            ok( $upd_res, "Operator Preference Record Updated" );
            my $user_pref   = $operator->operator_preference;
            isa_ok($user_pref,"XTracker::Schema::Result::Public::OperatorPreference");
            foreach my $test_key (keys %test_hash_keys_3 ) {
                is($user_pref->$test_key,$test_hash_keys_3{$test_key},"Test User Preferences - KEY: $test_key VALUE: $test_hash_keys_3{$test_key}");
            }
        };

        # Updating the Authorisations
        subtest 'update authorisations' => sub {
            my $auth_level  = XTracker::Admin::UserProfile::_get_auth_levels(\%test_hash_keys_2i);
            isa_ok($auth_level,"HASH");
            is_deeply($auth_level,\%test_hash_keys_2o,"Got Auth Levels");
            XTracker::Admin::UserProfile::_update_authorisations($operator,$auth_level);
            $auth_level = $operator->operator_authorisations;
            isa_ok($auth_level,"DBIx::Class::ResultSet");
            while (my $rec = $auth_level->next) {
                ok(exists $test_hash_keys_2o{$rec->authorisation_sub_section_id},"Auth Level: ".$rec->authorisation_sub_section_id." Exists");
                is($rec->authorisation_level_id,$test_hash_keys_2o{$rec->authorisation_sub_section_id},"Auth Level: ".$rec->authorisation_sub_section_id." is Correct");
            }
        };
    });

    # Updating a User testing _update_profile which calls the above 3 sub routines
    subtest 'test_update_profile' => sub {
        my $operator = $schema->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID);
        $schema->txn_dont( sub {
            $params = {%test_hash_keys,%test_hash_keys_2i,%test_hash_keys_3};
            XTracker::Admin::UserProfile::_update_profile($operator,$params,'');
            foreach my $test_key (keys %test_hash_keys ) {
                if ( $test_key ne "username" ) {
                    is($operator->$test_key,$test_hash_keys{$test_key},"Test User Info - KEY: $test_key VALUE: $test_hash_keys{$test_key}");
                }
                else {
                    isnt($operator->$test_key,$test_hash_keys{$test_key},"Test User Info - KEY: $test_key VALUE: $test_hash_keys{$test_key}");
                }
            }
            my $user_pref = $operator->discard_changes->operator_preference;
            isa_ok($user_pref,"XTracker::Schema::Result::Public::OperatorPreference");
            foreach my $test_key (keys %test_hash_keys_3 ) {
                is($user_pref->$test_key,$test_hash_keys_3{$test_key},"Test User Preferences - KEY: $test_key VALUE: $test_hash_keys_3{$test_key}");
            }
            my $auth_level  = $operator->operator_authorisations;
            isa_ok($auth_level,"DBIx::Class::ResultSet");
            while (my $rec = $auth_level->next) {
                ok(exists $test_hash_keys_2o{$rec->authorisation_sub_section_id},"Auth Level: ".$rec->authorisation_sub_section_id." Exists");
                is($rec->authorisation_level_id,$test_hash_keys_2o{$rec->authorisation_sub_section_id},"Auth Level: ".$rec->authorisation_sub_section_id." is Correct");
            }
        });
    };
};

done_testing;
