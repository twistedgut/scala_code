#!/usr/bin/env perl

use NAP::policy "tt",     'test';


use Test::XTracker::Data;
use XTracker::Constants::FromDB         qw( :channel
                                            :business
                                          );
use XTracker::Config::Local             qw( config_var sys_config_var );


# evil globals
our ($schema);

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Database::Channel','get_channels');
    use_ok('XTracker::Schema::Result::Public::Shipment');
    use_ok('XTracker::Schema::ResultSet::Public::Shipment');
}
our $promotion_type_tests = {
    'NAP' => [
        {
            params => { code => 'en' },
            expected => 'Welcome Pack - English',
            comment => 'found English welcome pack',
        },
        {
            params => { code => 'FR' },
            expected => 'Welcome Pack - French',
            comment => 'found French welcome pack',
        },
        {
            params => { code => 'De' },
            expected => 'Welcome Pack - German',
            comment => 'found German welcome pack',
        },
        {
            params => { code => 'zH' },
            expected => 'Welcome Pack - Chinese',
            comment => 'found Chinese welcome pack',
        },
    ],
    'OUTNET' => [
        {
            params => { code => 'en' },
            expected => undef,
            comment => 'no welcome pack in English',
        },
        {
            params => { code => 'fr' },
            expected => undef,
            comment => 'no welcome pack in French',
        },
        {
            params => { code => 'de' },
            expected => undef,
            comment => 'no welcome pack in German',
        },
        {
            params => { code => 'zh' },
            expected => undef,
            comment => 'no welcome pack in Chinese',
        },
    ],
    'MRP' => [
        {
            params => { code => 'en' },
            expected => 'Welcome Pack - English',
            comment => 'found English welcome pack',
        },
        {
            params => { code => 'fr' },
            expected => undef,
            comment => 'no welcome pack in French',
        },
        {
            params => { code => 'de' },
            expected => undef,
            comment => 'no welcome pack in German',
        },
        {
            params => { code => 'zh' },
            expected => undef,
            comment => 'no welcome pack in Chinese',
        },
    ],
};

my $test_cases_has_public_website = [
    {
        title => 'All enabled',
        setup => {
            business => {
                fulfilment_only => 1,
            },
            channel => {
                is_enabled => 1,
                has_public_website => 1,
            },
        },
        expect => {
            found => 0,
        },
    },
    {
        title => 'Not fulfilment only',
        setup => {
            business => {
                fulfilment_only => 0,
            },
            channel => {
                is_enabled => 1,
                has_public_website => 1,
            },
        },
        expect => {
            found => 1,
        },
    },
    {
        title => 'Not fulfilment only, not enabled',
        setup => {
            business => {
                fulfilment_only => 0,
            },
            channel => {
                is_enabled => 0,
                has_public_website => 1,
            },
        },
        expect => {
            found => 0,
        },
    },
    {
        title => 'Not fulfilment only, no public website',
        setup => {
            business => {
                fulfilment_only => 0,
            },
            channel => {
                is_enabled => 1,
                has_public_website => 0,
            },
        },
        expect => {
            found => 0,
        },
    },
    {
        title => 'Not fulfilment only, no public website, not enabled',
        setup => {
            business => {
                fulfilment_only => 0,
            },
            channel => {
                is_enabled => 0,
                has_public_website => 0,
            },
        },
        expect => {
            found => 0,
        },
    },
];


# get a schema to query
$schema = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my $c_rs = $schema->resultset('Public::Channel');
isa_ok($c_rs, 'XTracker::Schema::ResultSet::Public::Channel',"Channel Result Set");

my $channels= $c_rs->get_channels();
isa_ok( $channels, 'HASH', 'get_channels returns a HASH' );

# get XTracker::Database::Channel version of get_channels();
my $channel_list    = get_channels( $schema->storage->dbh );

# test Carrier Automation flags on each Channel
foreach my $channel ( sort { $a->{id} <=> $b->{id} } values %{ $channels } ) {
    my $ch_rec  = $schema->resultset('Public::Channel')->find( $channel->{id} );
    isa_ok( $ch_rec, 'XTracker::Schema::Result::Public::Channel', 'Got Channel Record for: '.$channel->{id}.' - '.$channel->{name} );
    my $auto_state  = $ch_rec->config_group->search( { name => 'Carrier_Automation_State' } )
                                    ->first->config_group_settings_rs->search( { setting => 'state' } )->first;

    # while we are about it test this as well
    note "test XTracker::Database::Channel list has 'is_on_*' flags set correctly";
    ok( exists( $channel_list->{ $ch_rec->id }{ $_ } ), "flag '${_}' exists in HASH" )       foreach ( qw( is_on_nap is_on_outnet is_on_mrp ) );
    cmp_ok( $channel_list->{ $ch_rec->id }{is_on_nap}, '==', $ch_rec->is_on_nap, "'is_on_nap' is set correctly" );
    cmp_ok( $channel_list->{ $ch_rec->id }{is_on_outnet}, '==', $ch_rec->is_on_outnet, "'is_on_outnet' is set correctly" );
    cmp_ok( $channel_list->{ $ch_rec->id }{is_on_mrp}, '==', $ch_rec->is_on_mrp, "'is_on_mrp' is set correctly" );

    note "test XTracker::Schema::Result::Channel list has 'is_on_*' flags set correctly and that both functions 'is_on_*' flags match";
    my @is_on_flags_a   = map { $_ => $channel_list->{ $ch_rec->id }{ $_ } }
                                grep { /^is_on_/ } sort keys %{ $channel_list->{ $ch_rec->id } };
    my @is_on_flags_b   = map { $_ => $channel->{ $_ } }
                                grep { /^is_on_/ } sort keys %{ $channel };
    is_deeply( \@is_on_flags_a, \@is_on_flags_b, "Both functions 'is_on' Flags Match & Set Correctly" );

    $schema->txn_do( sub {
        note "Turn Carrier Automation Off";
        $auto_state->update( { value => 'Off' } );
        cmp_ok( $ch_rec->carrier_automation_is_on, '==', 0, 'Carrier Automation On Should Return FALSE' );
        cmp_ok( $ch_rec->carrier_automation_is_off, '==', 1, 'Carrier Automation Off Should Return TRUE' );
        cmp_ok( $ch_rec->carrier_automation_import_off, '==', 1, 'Carrier Automation Import Off Should Return TRUE' );
        is( $ch_rec->carrier_automation_state, 'Off', "Carrier Automation State is 'Off'" );

        note "Turn Carrier Automation On";
        $auto_state->update( { value => 'On' } );
        cmp_ok( $ch_rec->carrier_automation_is_on, '==', 1, 'Carrier Automation On Should Return TRUE' );
        cmp_ok( $ch_rec->carrier_automation_is_off, '==', 0, 'Carrier Automation Off Should Return FALSE' );
        cmp_ok( $ch_rec->carrier_automation_import_off, '==', 0, 'Carrier Automation Import Off Should Return FALSE' );
        is( $ch_rec->carrier_automation_state, 'On', "Carrier Automation State is 'On'" );

        note "Turn Carrier Automation Import Off Only";
        $auto_state->update( { value => 'Import_Off_Only' } );
        cmp_ok( $ch_rec->carrier_automation_is_on, '==', 1, 'Carrier Automation On Should Return TRUE' );
        cmp_ok( $ch_rec->carrier_automation_is_off, '==', 0, 'Carrier Automation Off Should Return FALSE' );
        cmp_ok( $ch_rec->carrier_automation_import_off, '==', 1, 'Carrier Automation Import Off Should Return TRUE' );
        is( $ch_rec->carrier_automation_state, 'Import_Off_Only', "Carrier Automation State is 'Import_Off_Only'" );

        # take the opportunity to test the helper method as well
        test_helper_method( $ch_rec );

        # test the Channel Branding method 'branding'
        test_branding_method( $ch_rec );

        $schema->txn_rollback;
    } );

    my $ch_tests = $promotion_type_tests->{ $ch_rec->business->config_section } || undef;
    if ($ch_tests) {
        test_promotion_type_welcome_packs($ch_rec,$ch_tests);
    }
    _test_supports_language_method($ch_rec);
    _test_update_customer_language_on_every_order_method($ch_rec);
}

_test_get_channels_for_action( $c_rs );
_test_enabled_channels_with_public_website();
_test_has_welcome_pack_method();

done_testing();

sub _test_enabled_channels_with_public_website {
    my $localtime = localtime;

    Test::XTracker::Data->bump_sequence('client');
    Test::XTracker::Data->bump_sequence('distrib_centre');
    Test::XTracker::Data->bump_sequence('business');
    Test::XTracker::Data->bump_sequence('channel');

    $schema->txn_do(sub {
        my $client = $schema->resultset('Public::Client')->create({
            name        => "Test Client $localtime",
            prl_name    => "TST $localtime",
            token_name  => "Test token $localtime",
        });
        my $dc = $schema->resultset('Public::DistribCentre')->create({
            name            => "Test DC $localtime",
            alias           => "Alias",
        });
        my $business = $schema->resultset('Public::Business')->create({
            name                => "Test Business $localtime",
            config_section      => "CONFIG $localtime",
            url                 => "URL $localtime",
            show_sale_products  => 0,
            fulfilment_only     => 0,
            client_id           => $client->id,
        });
        my $channel = $schema->resultset('Public::Channel')->create({
            name                => "Test Channel $localtime",
            business_id         => $business->id,
            distrib_centre_id   => $dc->id,
            web_name            => "WEBNAME $localtime",
        });


        foreach my $test (@{$test_cases_has_public_website}) {
            my $setup = $test->{setup};
            note " ##### ". $test->{title};

            if ($setup && ref($setup) eq 'HASH') {
                if ($setup->{business} && ref($setup->{business}) eq 'HASH') {
                    $business->update($setup->{business});
                }
                if ($setup->{channel} && ref($setup->{channel}) eq 'HASH') {
                    $channel->update($setup->{channel});
                }
            } else {
                diag "No setup!?";
            }

            my $set = $schema->resultset('Public::Channel')
                ->enabled_channels_with_public_website();

            my @found = grep { $_ == $channel->id } keys %{$set};
            is(scalar @found,
                $test->{expect}->{found},
                "enabled_channels_with_public_website returned expected "
                . "value ($test->{expect}->{found})"
            );
        }


        # if you're debug removing this will make sure it stays in the db
        $schema->txn_rollback;
    });
}

sub _test_has_welcome_pack_method {

    note "TESTING 'has_welcome_pack' method";

    my $channel     = Test::XTracker::Data->any_channel;
    my $language_rs = $schema->resultset('Public::Language');
    my $language    = $language_rs->find( { code => 'de' } );

    my %tests = (
        "All Data Available, method should return TRUE" => {
            expect  => 1,
        },
        "When there are NO Welcome Packs defined in 'promotion_type' table for the Language" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                # change the name of the Promotion
                # to not have 'Wecome Pack' in it
                $promo_rec->update( { name => "Shouldn't find this" } );

                return;
            },
            expect  => 0,
        },
        "'Welcome_Pack' Config Group 'active' flag set to FALSE" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                $conf_group->update( { active => 0 } );

                return;
            },
            expect  => 0,
        },
        "With NO 'Welcome_Pack' Config Group present in System Config" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                Test::XTracker::Data->remove_config_group( $conf_group->name );

                return;
            },
            expect  => 0,
        },
        "Language Config Group Setting set to 'Off'" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                my $conf_setting = $conf_group->config_group_settings->first;

                $conf_setting->update( { value => 'Off' } );

                return;
            },
            expect  => 0,
        },
        "Language Config Group Setting's 'active' flag set to FALSE " => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                my $conf_setting = $conf_group->config_group_settings->first;

                $conf_setting->update( { active => 0 } );

                return;
            },
            expect  => 0,
        },
        "With NO 'Welcome_Pack' Config Setting present for the Language in System Config" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                my $conf_setting    = $conf_group->config_group_settings->first;
                $conf_setting->delete;

                return;
            },
            expect  => 0,
        },
        "With 'Welcome_Pack' Config Setting set to 'DEFAULT', should return TRUE" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                my $conf_setting    = $conf_group->config_group_settings->first;
                $conf_setting->update( { setting => 'DEFAULT' } );

                return;
            },
            expect  => 1,
        },
        "With 'Welcome_Pack' Config Setting set to 'DEFAULT' and Language assigned to Promotion can be any Language" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                my $conf_setting    = $conf_group->config_group_settings->first;
                $conf_setting->update( { setting => 'DEFAULT' } );

                my $another_language = $language_rs->search( {
                    id => { '!=' => $language->id },
                } )->first;

                $promo_rec->language__promotion_types->delete;
                $promo_rec->language__promotion_types->create( {
                    language_id => $another_language->id,
                } );

                return;
            },
            expect  => 1,
        },
        "With 'Welcome_Pack' Config Setting set to 'DEFAULT' and NO Language assigned to Promotion" => {
            setup   => sub {
                my ( $promo_rec, $conf_group )  = @_;

                my $conf_setting    = $conf_group->config_group_settings->first;
                $conf_setting->update( { setting => 'DEFAULT' } );

                $promo_rec->language__promotion_types->delete;

                return;
            },
            expect  => 1,
        },
    );

    my %expect_label = (
        1 => 'TRUE',
        0 => 'FALSE',
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";

        my $test = $tests{ $label };

        $schema->txn_do( sub {
            # clear out existing promotions
            $schema->resultset('Public::CountryPromotionTypeWelcomePack')->delete;
            $schema->resultset('Public::LanguagePromotionType')->delete;
            $schema->resultset('Public::PromotionType')->search_related('order_promotions')->delete;
            $schema->resultset('Public::PromotionType')->delete;

            # set-up data
            my $promo_rec = $channel->promotion_types->find_or_create( {
                name        => 'Welcome Pack - German',
            } );
            $promo_rec->language__promotion_types->find_or_create( {
                language_id => $language->id,
            } );

            Test::XTracker::Data->remove_config_group( 'Welcome_Pack', $channel );
            my $conf_group = Test::XTracker::Data->create_config_group( 'Welcome_Pack', {
                channel  => $channel,
                settings => [
                    { setting => $language->code, value => 'On' },
                ],
            } );

            $test->{setup}->( $promo_rec, $conf_group )     if ( $test->{setup} );

            my $got = $channel->has_welcome_pack( $language->code );
            ok( defined $got, "'has_welcome_pack' returned a defined Value" );
            cmp_ok( $got, '==', $test->{expect}, "and the Value is: " . $expect_label{ $test->{expect} } );


            # rollback changes
            $schema->txn_rollback;
        } );
    }

    return;
}

sub test_promotion_type_welcome_packs {
    my($channel,$tests) = @_;

    foreach my $test ( @{$tests} ) {
        if ( $test->{expected} ) {
            my $promo = $channel->find_welcome_pack_for_language(
                $test->{params}->{code},
            );
            is(ref($promo), 'XTracker::Schema::Result::Public::PromotionType',
                'found promo type') or note p( $test->{params} );
            is( $promo->name =~ /^$test->{expected}$/i,
                1,
                $test->{comment},
            ) or note p( $test->{params} );
        } else {
            is(
                $channel->find_welcome_pack_for_language(
                    $test->{params}->{code},
                ),
                undef,
                $test->{comment},
            ) or note p( $test->{params} );
        }
    }
}

# used to test a helper method in the Class called '_get_active_config_group_setting'
# which will get a System Config Setting(s) for a System Config Group for a Sales Channel
sub test_helper_method {
    my $channel     = shift;

    note "testing '_get_active_config_group_setting' helper method";

    # test when there is no group
    Test::XTracker::Data->remove_config_group( 'test_config_group', $channel );
    my $retval  = $channel->_get_active_config_group_setting( 'test_config_group' );
    ok( !defined $retval, "returned 'undef' when no group present" );

    # test when there is a group and no settings
    Test::XTracker::Data->create_config_group( 'test_config_group', { channel => $channel } );
    $retval = $channel->_get_active_config_group_setting( 'test_config_group' );
    ok( !defined $retval, "returned 'undef' when group present but no settings" );
    Test::XTracker::Data->remove_config_group( 'test_config_group', $channel );

    # test when there is a group and settings
    Test::XTracker::Data->create_config_group( 'test_config_group', {
                                                                channel => $channel,
                                                                settings => [
                                                                    { setting => 'first', value => 1 },
                                                                    { setting => 'second', value => 0 },
                                                                ],
                                                            } );
    $retval = $channel->_get_active_config_group_setting( 'test_config_group' );
    isa_ok( $retval, 'ARRAY', "when calling without passing a setting returns as expected" );
    cmp_ok( @{ $retval }, '==', 2, "ARRAY contains 2 elements" );
    isa_ok( $retval->[0], 'XTracker::Schema::Result::SystemConfig::ConfigGroupSetting', "first element as expected" );
    isa_ok( $retval->[1], 'XTracker::Schema::Result::SystemConfig::ConfigGroupSetting', "second element as expected" );
    ok( $retval->[0]->setting eq 'first' && $retval->[0]->value eq '1', "1st Element's Setting and Value as expected" );

    $retval = $channel->_get_active_config_group_setting( 'test_config_group', 'second' );
    is( $retval, '0', "called with passing a setting gets back the value for that setting" );
}

# used to test the 'branding' method for the Sales Channel
sub test_branding_method {
    my $channel     = shift;

    my $branding    = $channel->result_source->schema->resultset('Public::Branding');

    note "testing 'branding' method";

    # get rid of any existing channel branding records
    $channel->channel_brandings->delete;

    note "test when there is no branding for the Sales Channel returns 'undef'";
    my $value   = $channel->branding;
    ok( !defined $value, "'method' returns 'undef'" );

    # create some new brandings and assign to the Sales Channel
    my @branding;
    my @brand_values;       # used later for comparisons in the tests
    foreach my $num ( 1..5 ) {
        my $brand   = $branding->create( {
                                code        => "TEST_BRANDING_${num}_XX",
                                description => "${num} Description",
                            } );
        $channel->create_related( 'channel_brandings', {
                                                branding_id => $brand->id,
                                                value       => "Test ${num} Value",
                                        } );
        push @brand_values, "Test ${num} Value";
        push @branding, $brand;
    }

    note "test calling with 1 parameter, should just return a value";
    $value  = $channel->branding( $branding[3]->id );       # use the 4th brand
    is( ref( $value ), '', "Return Value for 1 param is a Scalar" );
    is( $value, $brand_values[3], "Value is as expected: '$brand_values[3]'" );

    note "test calling with multiple parameters in scalar context, should return a Hash with the branding id's as the keys";
    my $expected    = {
            $branding[2]->id    => $brand_values[2],
            $branding[4]->id    => $brand_values[4],
            $branding[1]->id    => $brand_values[1],
        };
    $value  = $channel->branding( ( map { $_->id } @branding[1,2,4] ) );
    isa_ok( $value, "HASH", "Return Value for multiple params is Hash Ref" );
    is_deeply( $value, $expected, "Returned Value Hash is as expected" );

    note "test calling with multiple parameters in scalar context, but with a branding id that doesn't exist for the Channel";
    $value  = $channel->branding( ( map { $_->id } @branding[1,2,4] ), -1 );
    isa_ok( $value, "HASH", "Return Value for multiple params is Hash Ref" );
    is_deeply( $value, $expected, "Returned Value Hash is as expected so unknown Id is ignored" );

    note "test calling with multiple parameters in list context, should return an array with the values in the same order as the params";
    $expected   = [ $brand_values[2], $brand_values[4], $brand_values[1] ];
    my @values  = $channel->branding( ( map { $_->id } @branding[2,4,1] ) );
    cmp_ok( @values, '==', 3, "Return Value array has 3 elements" );
    is_deeply( \@values, $expected, "Value array is as expected" );

    note "test calling with multiple parameters in list context, but with a branding id that doesn't exist should have 'undef' in it's element";
    $expected   = [ $brand_values[2], $brand_values[4], $brand_values[1], undef ];
    @values = $channel->branding( ( map { $_->id } @branding[2,4,1] ), -1 );
    cmp_ok( @values, '==', 4, "Return Value array has 4 elements" );
    is_deeply( \@values, $expected, "Value array is as expected, unknown Id has 'undef' in its element" );

    note "test calling with 1 parameter in list context, should return an array with 1 value";
    $expected   = [ $brand_values[0] ];
    @values = $channel->branding( $branding[0]->id );
    cmp_ok( @values, '==', 1, "Return Value array has 1 element" );
    is_deeply( \@values, $expected, "Value array is as expected" );

    note "test calling with no params, should return all branding";
    $expected   = { map { $branding[ $_ ]->id => $brand_values[ $_ ] } ( 0..$#branding ) };
    $value      = $channel->branding;
    isa_ok( $value, "HASH", "Return Value for no params is a Hash Ref" );
    is_deeply( $value, $expected, "Returned Value Hash is as expected" );

    note "test calling with no params again but called in list context, should return all branding in a Hash Ref in the first element";
    @values     = $channel->branding;
    cmp_ok( @values, '==', 1, "Return Value array has 1 element" );
    isa_ok( $values[0], "HASH", "Return Value first element is a Hash Ref" );
    is_deeply( $values[0], $expected, "Returned Value Hash is as expected" );

    return;
}

# test 'XTracker::Schema::ResultSet::Channel->get_channels_for_action' method
# returns the expected Channels required for an Action
sub _test_get_channels_for_action {
    my $channel_rs  = shift;

    note "TESTING: 'XTracker::Schema::Result::Public->get_channels_for_action' method";

    my $schema  = $channel_rs->result_source->schema;

    my %all_channels    = map { $_->business->config_section => $_->id } $channel_rs->all;

    $schema->txn_do( sub {
        # set-up some test data for the Config Group 'ChannelsForAction'
        # that should return expected Sales Channel Config Sections
        Test::XTracker::Data->remove_config_group( 'ChannelsForAction' );
        Test::XTracker::Data->create_config_group( 'ChannelsForAction', {
                                                            settings    => [
                                                                    { setting => 'Test/Action', value => 'NAP', sequence => 1 },
                                                                    { setting => 'Test/Action', value => 'OUTNET', sequence => 2 },
                                                                    { setting => 'AnotherTest/Action', value => 'NAP', sequence => 1 },
                                                                    { setting => 'AnotherTest/Action', value => 'MRP', sequence => 2 },
                                                                    { setting => 'Only/One/Channel', value => 'JC', sequence => 0 },
                                                                ],
                                                        } );

        my %tests   = (
                "Passing a non-existent Action, should return All Channels" => {
                        action  => 'Non/Existent',
                        expected=> \%all_channels,
                    },
                "Passing 'undef' as an Action, should return All Channels" => {
                        action  => undef,
                        expected=> \%all_channels,
                    },
                "Passing all Spaces in Action, should return All Channels" => {
                        action  => '    ',
                        expected=> \%all_channels,
                    },
                "Passing NO Action, should return All Channels" => {
                        expected=> \%all_channels,
                    },
                "Passing 'Test/Action' should get only NAP & OUTNET" => {
                        action  => 'Test/Action',
                        expected=> {
                                NAP     => $all_channels{'NAP'},
                                OUTNET  => $all_channels{'OUTNET'},
                            },
                    },
                "Passing 'tesT/actIOn' should get only NAP & OUTNET, test method is Case Insensitive" => {
                        action  => 'tesT/actIOn',
                        expected=> {
                                NAP     => $all_channels{'NAP'},
                                OUTNET  => $all_channels{'OUTNET'},
                            },
                    },
                "Passing '  tesT /act IOn  ' should get only NAP & OUTNET, test method Strips ALL Spaces" => {
                        action  => '  tesT /act IOn  ',
                        expected=> {
                                NAP     => $all_channels{'NAP'},
                                OUTNET  => $all_channels{'OUTNET'},
                            },
                    },
                "Passing 'AnotherTest/Action' should get only NAP & MRP" => {
                        action  => 'AnotherTest/Action',
                        expected=> {
                                NAP => $all_channels{'NAP'},
                                MRP => $all_channels{'MRP'},
                            },
                    },
                "Pass an Action that should only return One Channel - JC" => {
                        action  => 'Only/One/Channel',
                        expected=> {
                                JC  => $all_channels{'JC'},
                            },
                    },
            );

        foreach my $label ( keys %tests ) {
            note "Testing: $label";
            my $test    = $tests{ $label };

            my @got = (
                        exists( $test->{action} )
                        ? $channel_rs->get_channels_for_action( $test->{action} )
                        : $channel_rs->get_channels_for_action
                      )->all;

            is_deeply( { map { $_->business->config_section => $_->id } @got }, $test->{expected},
                                                "Got the Expected Channels" );
        }


        # rollback changes
        $schema->txn_rollback();
    } );

    return;
}

sub _test_supports_language_method {
    my $channel = shift;

    my $schema = $channel->result_source->schema;

    # Wrap this in a transaction to rollback
    $schema->txn_begin();

    # Define a dummy language for the test
    my $setting = $channel->config_groups->search( {
        active  => 1,
        name    => 'Language',
    } )->first->create_related('config_group_settings', {
        setting     => 'DU',
        value       => 'Off',
        active      => 1,
    } );

    cmp_ok( $channel->supports_language( 'DU' ),
            '==',
            0,
            'supoprts_language is not true for "DU"',
          );

    # Now set the value to On
    $setting->update( { value   => 'On' } );

    cmp_ok( $channel->supports_language( 'DU' ),
            '==',
            1,
            'supoprts_language is true for "DU"',
          );

    $schema->txn_rollback();

}

sub _test_update_customer_language_on_every_order_method {
    my $channel = shift;

    my $expected = {
        $BUSINESS__NAP      =>  0,
        $BUSINESS__OUTNET   =>  0,
        $BUSINESS__MRP      =>  0,
        $BUSINESS__JC       =>  1,
    };

    cmp_ok( $channel->update_customer_language_on_every_order,
            '==',
            $expected->{$channel->business->id},
            'boolean value returned from update_customer_language_on_every_order method is correct'
          );

}
