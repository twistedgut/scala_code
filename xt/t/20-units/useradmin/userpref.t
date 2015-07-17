#!/usr/bin/env perl

=head1 NAME

userpref.t - tests get_operator_preferences function

=head1 DESCRIPTION

Tests the get_operator_preferences function in XTracker::Database::Profile

#TAGS shouldbeunit

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;

use_ok('XTracker::Database::Profile', qw( get_operator_preferences ));

# get a schema to query
my $schema = Test::XTracker::Data->get_schema;

my $operator = $schema->resultset('Public::OperatorAuthorisation')->search(
    { 'operator.disabled' => 0, operator_id => { '>' => 10 } },
    {
        select      => [ 'operator_id', \'COUNT(operator_id)' ],
        join        => 'operator',
        group_by    => 'operator_id',
        having      => { 'COUNT(operator_id)' => { '>' => 2 } },
        rows        => 1,
    } )->related_resultset('operator')->single;

#--------------- Run TESTS ---------------

$schema->txn_dont( sub {

    my $operator_authorisations = $operator->operator_authorisations;
    my $operator_authorisation = $operator_authorisations->next;

    my @channel_ids = keys %{$schema->resultset('Public::Channel')->get_channels};
    my %test_hash_keys = (
        pref_channel_id     => pop @channel_ids,
        default_home_page   => $operator_authorisation->authorisation_sub_section_id,
        packing_station_name=> 'Packing Station 1',
    );

    my $get_user_auths  = $operator->authorisation_as_hash;
    isa_ok($get_user_auths,"HASH","Got User's Current Auths");

    my $save_ok = $operator->update_or_create_preferences(\%test_hash_keys);
    ok($save_ok,'Pass 1 Preferences Saved');

    my $operator_preference = $operator->operator_preference;
    cmp_ok($operator_preference->get_column($_),'eq',$test_hash_keys{$_},"Pass 1 Pref Key: $_")
        for keys %test_hash_keys;

    $operator_authorisation  = $operator_authorisations->next();
    isa_ok($operator_authorisation,'XTracker::Schema::Result::Public::OperatorAuthorisation','Got User Auth Record');

    %test_hash_keys = (
        pref_channel_id     => pop @channel_ids,
        default_home_page   => $operator_authorisation->authorisation_sub_section_id,
        packing_station_name=> 'Packing Station 2',
    );

    $save_ok    = $operator->update_or_create_preferences(\%test_hash_keys);
    ok($save_ok,'Pass 2 Preferences Saved');

    $operator_preference->discard_changes;
    cmp_ok($operator_preference->get_column($_),'eq',$test_hash_keys{$_},"Pass 2 Pref Key: $_")
        for keys %test_hash_keys;

    # check we can get back some preferences
    my $prefs   = get_operator_preferences( $schema->storage->dbh, $operator->id );
    isa_ok($prefs,"HASH","Got Operator Preferences Back as HASH");

    # check all keys are present
    ok( exists( $prefs->{$_} ),"Preferences Has Key: $_") for qw(
        config_section
        default_home_page
        default_home_url
        packing_station_name
        pref_channel_id
        sales_channel
    );

    # check basic preferences is correct (rest of preferences is derived from these)
    cmp_ok($prefs->{$_},'eq',$test_hash_keys{$_},"Preferences Match for Key: $_")
        for keys %test_hash_keys;
} );

done_testing;
