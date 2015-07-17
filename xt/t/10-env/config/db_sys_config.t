#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::ParamCheck;

use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );

use Data::Dump  qw( pp );



BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Config::Local', qw( :DEFAULT ));
    use_ok('XTracker::Schema::Result::SystemConfig::ConfigGroup');
    use_ok('XTracker::Schema::Result::SystemConfig::ConfigGroupSetting');

    can_ok("XTracker::Config::Local", qw(
                                sys_config_var
                                sys_config_groups
                            ) );
}

# make DB connection
my $schema = get_database_handle( { name => 'xtracker_schema' } );
isa_ok($schema,"XTracker::Schema","Schema Connection");

my $conf_grp_rs = $schema->resultset('SystemConfig::ConfigGroup');
isa_ok($conf_grp_rs,"DBIx::Class::ResultSet","Config Group Table");
my $conf_grp_set_rs = $schema->resultset('SystemConfig::ConfigGroup');
isa_ok($conf_grp_set_rs,"DBIx::Class::ResultSet","Config Group Setting Table");

#---- Test Functions ------------------------------------------

_test_reqd_params($schema,1);
_test_config_funcs($schema,1);

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# Tests the Required Parameters
sub _test_reqd_params {

    my $schema      = shift;

    my $param_check = Test::XTracker::ParamCheck->new();

    SKIP: {
        skip "_test_reqd_params",1          if (!shift);

        note "Testing Required Parameters";

        $param_check->check_for_params( \&sys_config_var,
                        'sys_config_var',
                        [ $schema, "GROUP NAME", "GROUP SETTING" ],
                        [ "No Schema Connection Passed", "No Group Name Passed", "No Group Setting Passed" ]
                );
        $param_check->check_for_params( \&sys_config_groups,
                        'sys_config_groups',
                        [ $schema, qr/GROUP PA/ ],
                        [ "No Schema Connection Passed", "No Group Pattern Passed" ],
                        [ undef, "GROUP PA" ],
                        [ undef, "Group Pattern Not a RegExp" ]
                );
    }
}

# Tests some config functions
sub _test_config_funcs {

    my $schema      = shift;

    my $resultset   = _define_dbic_resultset( $schema );
    my $tmp;
    my $grp;

    my $channels    = $resultset->{channels}();
    unshift @{ $channels }, undef;

    my $cnfgrp  = $schema->resultset('SystemConfig::ConfigGroup');

    SKIP: {
        skip "_test_config_funcs",1          if (!shift);

        note "Testing Config Funcs";

        $schema->txn_do( sub {

            # Create Test Data
            foreach ( @{ $channels } ) {
                $tmp    = $cnfgrp->create( {
                                name        => 'TEST GROUP NAME 1',
                                channel_id  => $_
                            } );
                $tmp->config_group_settings->create( {
                                setting     => 'TEST SETTING 1',
                                value       => 'TEST VALUE 1 '.( defined $_ ? $_ : 'NO CHANNEL' )
                        } );
                $tmp    = $cnfgrp->create( {
                                name        => 'TEST GROUP NAME 2',
                                channel_id  => $_
                            } );
                $tmp->config_group_settings->create( {
                                setting     => 'TEST SETTING 2',
                                value       => 'TEST VALUE 2a '.( defined $_ ? $_ : 'NO CHANNEL' ),
                                sequence    => 1
                        } );
                $tmp->config_group_settings->create( {
                                setting     => 'TEST SETTING 2',
                                value       => 'TEST VALUE 2b '.( defined $_ ? $_ : 'NO CHANNEL' ),
                                sequence    => 2
                        } );

            }

            # Test Single Value Return
            foreach ( @{ $channels } ) {
                my $txt = ( defined $_ ? $_ : 'NO CHANNEL' );
                $tmp    = sys_config_var( $schema, 'TEST GROUP NAME 1', 'TEST SETTING 1', $_ );
                is($tmp,"TEST VALUE 1 ".$txt, "Single Value Return for Channel Id: ".$txt );
            }
            # Test Multi Value Return
            foreach ( @{ $channels } ) {
                my $txt = ( defined $_ ? $_ : 'NO CHANNEL' );
                $tmp    = sys_config_var( $schema, 'TEST GROUP NAME 2', 'TEST SETTING 2', $_ );
                isa_ok($tmp,"ARRAY","Multi Value Return for Channel Id: ".$txt );
                is($tmp->[0],"TEST VALUE 2a ".$txt, "Multi Value Return for Channel Id: ".$txt." 1st Value" );
                is($tmp->[1],"TEST VALUE 2b ".$txt, "Multi Value Return for Channel Id: ".$txt." 2nd Value" );
            }

            # Test Getting Group Names
            $grp    = sys_config_groups( $schema, qr/TEST GROUP NAME 2/ );
            cmp_ok(@{ $grp },"==",5,"Return Correct Number of Group Names: ".@{ $grp });
            is($grp->[0]{channel_id},undef,"First Group Shouldn't Have a Channel");
            is($grp->[1]{channel_id},$channels->[1],"Second Group Should Be First Channel");
            is($grp->[2]{channel_id},$channels->[2],"Third Group Should Be Second Channel");
            is($grp->[3]{channel_id},$channels->[3],"Fourth Group Should Be Third Channel");
            is($grp->[4]{channel_id},$channels->[4],"Fifth Group Should Be Fourth Channel");

            # Turn off a group
            $cnfgrp->find( $grp->[1]{group_id} )->update( { active => 0 } );
            $tmp    = sys_config_groups( $schema, qr/TEST GROUP NAME 2/ );
            cmp_ok(@{ $tmp },"==",4,"Turn Off Group, Number of Groups Should be 3: ".@{ $tmp });
            $tmp    = sys_config_var( $schema, 'TEST GROUP NAME 2', 'TEST SETTING 2', $channels->[1] );
            is($tmp,undef,"Requesting Inactive Group Should Return Nothing");

            # Turn off a Group's Setting
            $cnfgrp->find( $grp->[2]{group_id} )
                ->config_group_settings
                    ->search( { setting => 'TEST SETTING 2', sequence => 1 } )
                        ->update( { active => 0 } );
            $tmp    = sys_config_var( $schema, 'TEST GROUP NAME 2', 'TEST SETTING 2', $channels->[2] );
            isnt(ref($tmp),"ARRAY","After Turning Off a Setting Should Not Return an ARRAY");
            is($tmp,"TEST VALUE 2b ".$channels->[2],"Got Correct Setting after Making One Setting Inactive");

            $schema->txn_rollback();
        } );

    }
}

#--------------------------------------------------------------

# set up some data
sub _define_dbic_resultset {

    my $schema      = shift;

    my $resultset   = {};

    $resultset->{channels}  = sub {
            my $retval;
            my $channels    = $schema->resultset('Public::Channel')->search( undef, { order_by => 'id' } );

            while ( my $row = $channels->next ) {
                push @{ $retval }, $row->id;
            }
            return $retval;
        };

    return $resultset;
}
