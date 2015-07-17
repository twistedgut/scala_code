#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

useradmin.t - tests the _get_users function on XTracker::Admin::UserAdmin

=head1 DESCRIPTION

Verifies that a set of keys specific to user accounts in XTracker are defined
in the data returned by the _get_users function on XTracker::Admin::UserAdmin

#TAGS shouldbeunit

=cut

use FindBin::libs;

# evil globals
our ($schema);
our %test_hash_keys;

BEGIN {
    %test_hash_keys = qw (
        id          1
        name        1
        username    1
        password    1
        auto_login  0
        disabled    1
        ldap        1
        dept        1
    );

    plan tests => keys (%test_hash_keys) + 11;

    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Schema');
    use_ok('Data::Page');
    use_ok('XTracker::Handler');
    use_ok('XTracker::Admin::UserAdmin');

    can_ok("XTracker::Admin::UserAdmin",qw(_get_users));
}

# get a schema to query
$schema = get_database_handle(
    {
        name    => 'xtracker_schema',
    }
);
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my $page = Data::Page->new(10000,10000,1);

# we have some users with no department, they're no use for this test
# so we need to exclude them
my $oper_rs = $schema->resultset('Public::Operator')->search({
    'department_id' => {'!=', undef},
});
isa_ok($oper_rs, 'XTracker::Schema::ResultSet::Public::Operator',"Operator Result Set");

my $users_1 = XTracker::Admin::UserAdmin::_get_users($oper_rs, $page, 3);
isa_ok($users_1, "HASH");

my $first_user;
foreach my $user (keys %{$users_1}){
    $first_user = $users_1->{$user};
    last;
}

foreach my $key_totest (keys %test_hash_keys) {
    ok(defined $first_user->{$key_totest}, "KEY: $key_totest is defined");
}

my $users_2 = XTracker::Admin::UserAdmin::_get_users($oper_rs, $page, 2);
isa_ok($users_2, "HASH");

cmp_ok(scalar keys %{$users_1},"!=",scalar keys %{$users_2},"User List with Auth Level 2");
