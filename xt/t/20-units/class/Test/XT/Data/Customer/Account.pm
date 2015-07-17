package Test::XT::Data::Customer::Account;

use NAP::policy 'tt', 'test';
use parent "NAP::Test::Class";

use Data::UUID;

use Test::XTracker::Data;
use Test::XT::Data::Customer;

sub startup : Test(startup) {
    my $self = shift;
    $self->{schema} = Test::XTracker::Data->get_schema;
}

sub test_as_dbi_like_hash : Tests() {
    my $self = shift;

    my $account = $self->_create_account_data_obj;
    my $account_data = $account->as_dbi_like_hash;

    my @included_fields = qw/ urn last_modified title first_name last_name
                              email date_of_birth category category_id
                              porter_subscriber /;

    # Fields are as expected
    is_deeply([sort @included_fields], [sort keys %{$account_data}],
              'Only expected fields are included in DBI-like hash');

    # All field data is as expected
    foreach my $field (@included_fields){
        next if $field eq 'category_id';
        is($account_data->{$field},
           $account->$field, "Account $field as expected in DBI-like hash");
    }
}

sub test_storage_interaction : Tests() {
    my $self = shift;

    # Create a database customer
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Customer',
                     'Test::XT::Data::Channel', ], );

    # Create an account data object
    my $account = $self->_create_account_data_obj;

    # Link account object with database
    $data->customer->update( { account_urn => $account->urn } );

    # Test retrieving database object
    my $db_obj = $account->storage_obj;

    is( $data->customer->id, $db_obj->id,
        'DBIC object correctly retrieved via data obj');

    # Test comparison of data object with local database
    my $pre_update_differences = $account->compare_with_storage;

    is_deeply( [sort @$pre_update_differences],
               [qw/ category email first_name last_name title /],
               'Customer data is different between data object and database '
                . 'for expected fields');

    # Test update of local database
    $account->update_local_storage( { fields => $pre_update_differences });

    my $post_update_differences = $account->compare_with_storage;

    is(scalar @{$post_update_differences}, 0,
       'Data object and database data is identical post-update')
}


sub _create_account_data_obj {
    my $self = shift;

    return XT::Data::Customer::Account->new(
             { email => 'test-' . int(rand(1000)) . '@net-a-porter.com',
               encrypted_password => 'my new password',
               title => 'Miss',
               first_name => 'Test First Name ' . int(rand(1000)),
               last_name => 'Test Last Name ' . int(rand(1000)),
               country_code => 'GB',
               category => 'EIP',
               origin_id => 666, # Magic client id - unvalidated
               origin_region => 'TEST',
               origin_name => 'XT',
               date_of_birth => DateTime->now(),
               schema => $self->{schema},
               urn => 'urn:nap:account:' . Data::UUID->new->create_str(),
             });

}
