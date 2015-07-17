#!/usr/bin/env perl
use NAP::policy "tt",     'test';
use Test::Exception;

use XTracker::Config::Local     qw( config_var ldap_config );

note( "Test LDAP Configuration ... " );
my $ldap_config = ldap_config();
ok( $ldap_config, "ldap_config() returns something" );
ok( ref $ldap_config eq 'HASH', "... and that something is a Hash ref" );
ok( defined $ldap_config->{host}, "... which has host defined" );
ok( ( ! ref $ldap_config->{host} || ref $ldap_config->{host} eq 'ARRAY' ),
    "... and host is either a scalar or an array reference" );
ok( defined $ldap_config->{domain}, "... and has domain defined" );
ok( ( ! ref $ldap_config->{domain} || ref $ldap_config->{domain} eq 'ARRAY' ),
    "... and domain is either a scalar or an array reference" );

my $ldap_username;
my $ldap_password;
ok( $ldap_username = config_var('LDAP','default_ldap_login'),
    "The default XT LDAP username exists in config" );
ok( $ldap_password = config_var('LDAP','default_ldap_password'),
    "The default XT LDAP password exists in config" );

TODO: {
    note( "Testing Interface::LDAP ... " );

    use_ok( 'Interface::LDAP' );
    dies_ok( sub { Interface::LDAP->new(); }, "instantiation fails without host" );

    lives_ok( sub {
            Interface::LDAP->new( host => $ldap_config->{host} )
        }, "Instantiation succeeds with host" );

    my $ldap = Interface::LDAP->new( host => $ldap_config->{host}, port => 3268 );

    isa_ok( $ldap, "Interface::LDAP" );

    lives_ok( sub { $ldap->connect }, "I can connect to the LDAP server" );

    dies_ok( sub { $ldap->bind() },
        "... but attempting to bind without parameters dies" );

    lives_ok( sub {
            $ldap->bind($ldap_username, $ldap_password);
        }, "Bind with XT default username and password lives" );

    lives_ok( sub {
            $ldap->domain( ref $ldap_config->{domain} ?
                $ldap_config->{domain}->[0] :
                $ldap_config->{domain} )
        }, "Can set domain in LDAP object" );

    ok( $ldap->base, "Can call base() method to get DC base" );

    lives_ok( sub { $ldap->ldap->unbind; }, "Can unbind" );

    lives_ok( sub {
            $ldap->dn_bind( $ldap_username, $ldap_password );
        }, "Can call dn_bind on LDAP object with username and password" );

    ok( $ldap->get_dn, "Can get dn from LDAP object" );
    cmp_ok( $ldap->get_user, 'eq', $ldap_username, "get_user() methods returns the correct username" );

    $ldap = undef;

    note( "Moving on to test XTracker::Interface::LDAP ..." );

    use_ok( 'XTracker::Interface::LDAP' );
    my $xt_ldap;

    ok( $xt_ldap = XTracker::Interface::LDAP->new(), "Instantiates OK without parameters" );
    lives_ok( sub { $xt_ldap->connect }, "... and connects OK" );

    lives_ok( sub {
            my $bind = $xt_ldap->dn_bind;
            die if ( ref $bind && $bind->is_error );
        }, "... and binds via dn_bind without parameters" );

    ok( $xt_ldap->authenticate( $ldap_username, $ldap_password ),
        "... and authenticate works using default username/password" );

    my $search_result;
    lives_ok( sub {
            $search_result = $xt_ldap->search('sAMAccountName='. $xt_ldap->get_user());
        }, "... search result against sAMAccountName works" );

    my $dn = $search_result->[0]->get_value('distinguishedName');
    ok( $dn, "... I have a distinguishedName" );

    ok( $xt_ldap->get_ldap_groups_by_dn( $dn ),
        "... and I can get groups using the distinguishedName" );

    ok( my @roles = $xt_ldap->get_ldap_roles, "get_ldap_roles() returns a value" );
}

done_testing();

