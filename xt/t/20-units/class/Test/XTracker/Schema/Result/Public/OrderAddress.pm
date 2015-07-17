package Test::XTracker::Schema::Result::Public::OrderAddress;

use FindBin::libs;

use parent 'NAP::Test::Class';
use NAP::policy 'test';

use XTracker::Schema::Result::Public::Shipment;
use XTracker::DBEncode qw/ encode_db decode_db /;
use XTracker::Database::Address;

use Test::XTracker::Data;

use DBI qw/ :utils /;
use Test::MockObject::Extends;

=head1 NAME

Test::XTracker::Schema::Result::Public::OrderAddress

=head1 DESCRIPTION

Test the XTracker::Schema::Result::Public::OrderAddress Class.

head1 TESTS

=cut

sub setup : Test(setup) {
    my $self = shift;

    # set this true if you want to keep the data around to play with...
    $self->{KEEP_DATA} = 0;

    # Resultset for OrderAddress
    $self->{address_rs} = $self->schema->resultset('Public::OrderAddress');

    # wrap tests in a transaction so we don't create loads of horrible addresses
    $self->schema->txn_begin unless $self->{KEEP_DATA};
}

sub teardown : Test(teardown) {
    my $self = shift;

    # wrap tests in a transaction so we don't create loads of horrible addresses
    $self->schema->txn_rollback unless $self->{KEEP_DATA};
}

sub test_create_unicode_addresses : Tests {
    my $self = shift;

    my $address_rs = $self->{address_rs};

    # columns expected to support utf8
    my @utf8_columns = qw/
        first_name
        last_name
        address_line_1
        address_line_2
        address_line_3
        towncity
        county
    /;

    # strings to try in utf8 columns
    my $test_strings = {
        ascii => 'Test',
        utf8_latin1 => "T\N{U+00E9}st",
        utf8_cyrillic => "T\N{U+0511}st",
        utf8_arabic => "تجربة",
        utf8_chinese => "試驗",
        utf8_symbol => "T\N{U+20AC}st",
    };

    my @all_column_names = grep { !( $_ ~~ [qw( id address_hash )] ) } $address_rs->result_source->columns;

    # create a load of addresses with combinations of the data above
    for my $column ( @utf8_columns ) {
        for my $string_type ( sort keys %$test_strings ) {
            # get string for this test
            my $test_value = $test_strings->{$string_type};

            # populate hash with values for this address row
            my $address_fields = {
                (map { ($_ => 'ignore') } grep { $_ ne $column }
                                          grep { $_ ne 'last_modified' } @all_column_names),
                $column => $test_value,
            };

            # Add in last modified
            $address_fields->{last_modified} = $self->schema->db_now();

            # calculate address hash for this address row
            $address_fields->{address_hash} = $self->get_address_hash( $address_fields );

            # create address object
            my $address;
            lives_ok sub { $address = $address_rs->create( $address_fields ) }, "should create address with $string_type $column";
            ok $address, "  ..and return address object";

            # force refetch from the database
            $address->discard_changes;

            # read the test string back from the address object
            my $retrieved_test_value = $address->$column;
            #my $retrieved_test_value = $address->get_inflated_column( $column );
            is $retrieved_test_value, $test_value, "  ..and $column should have the correct value"
                or diag data_diff( $retrieved_test_value, $test_value );

            # check calculated hash for the values read back is still the same
            is $self->get_address_hash( { $address->get_inflated_columns } ), $address->address_hash, '  ..and recalculating address hash should get same result';
        }
    }
}

sub test_is_equivalent_to : Tests {
    my $self = shift;

    my $address_rs = $self->{address_rs};

    my $addr_fields = { title => 'Mr',
                        first_name => 'William',
                        last_name => 'Benn',
                        address_line_1 => '52 Festive Road',
                        address_line_2 => 'Putney',
                        address_line_3 => '',
                        towncity => 'London',
                        county => '',
                        postcode => 'SW15 1LP',
                        country => 'United Kingdom',
                      };

    $addr_fields->{address_hash} = $self->get_address_hash( $addr_fields );

    # Create two identical addresses
    my ($addr_obj1, $addr_obj2);
    lives_ok sub { $addr_obj1 = $address_rs->create( $addr_fields ) },
      "Create address 1";

    lives_ok sub { $addr_obj2 = $address_rs->create( $addr_fields ) },
      "Create address 2";

    # Check equivalence
    ok($addr_obj1->is_equivalent_to($addr_obj2), 'Addresses are equivalent');

    # Change an unchecked field
    $addr_obj1->urn('urn:nap:address:test1');
    $addr_obj2->urn('urn:nap:address:test2');

    ok($addr_obj1->is_equivalent_to($addr_obj2),
       'Addresses are equivalent with differing URN: '
       . $addr_obj1->urn . ' / ' . $addr_obj2->urn);

    # Change a checked field
    $addr_obj1->update($addr_fields);
    $addr_obj2->update($addr_fields);
    $addr_obj1->address_line_1('54 Festive Road');

    ok(!$addr_obj1->is_equivalent_to($addr_obj2),
       'Addresses are not equivalent with a differing checked field: '
       . $addr_obj1->address_line_1 . ' / ' . $addr_obj2->address_line_1);

    # Remove a checked field
    $addr_obj1->address_line_1('54 Festive Road');
    $addr_obj2->address_line_2(undef);

    ok(!$addr_obj1->is_equivalent_to($addr_obj2),
       'Addresses are not equivalent with an absent checked field');

    # Add a checked field
    $addr_obj1->address_line_1('54 Festive Road');
    $addr_obj2->address_line_2(undef);

    ok(!$addr_obj1->is_equivalent_to($addr_obj2),
       'Addresses are not equivalent with an absent checked field');
}

sub test_as_carrier_string : Tests {
    my $self = shift;

    my $addr_fields = { title => 'Mr',
                        first_name => 'William',
                        last_name => 'Benn',
                        address_line_1 => '52 Festive Road',
                        address_line_2 => 'Putney',
                        address_line_3 => 'Somewhere In London',
                        towncity => 'London',
                        county => '',
                        postcode => 'SW15 1LP',
                        country => 'United Kingdom',
                      };

    $addr_fields->{address_hash} = $self->get_address_hash( $addr_fields );

    my $address = $self->schema->resultset('Public::OrderAddress')
                            ->find_or_create( $addr_fields );

    ok( $address, "I have an address record" );
    ok( $address->address_line_3, "... and it contains address_line_3 data" );
    ok( $address->address_line_3 eq $addr_fields->{address_line_3},
        "... and that data is what we expect it to be" );

    ok( $address->as_carrier_string !~ /Somewhere In London/,
        "address_line_3 is not present in the output from as_carrier_string" );

}

=head2 get_address_hash( \%details ) : $address_hash

Returns the address hash for the supplied address details. Automatically excludes
id and address_hash so you can pass it $address_dbic_object->get_columns.

=cut

sub get_address_hash {
    my ( $self, $details ) = @_;

    # get details for all columns except id and address_hash
    my $hash_details = { map { ( $_ => $details->{$_} ) } grep { !( $_ ~~ [qw( id address_hash )] ) } keys %$details };

    # use XTracker::Database::Address::hash_address to do the calculation
    return hash_address( $self->schema->storage->dbh, $hash_details );
}

=head2 test_cleaning_up_non_printable_characters

Tests that non printable characters are safely converted to a single ASCII
space and leading/trailing whitespace are removed from address data.

=cut

sub test_cleaning_up_non_printable_characters : Tests {
    my $self = shift;

    my $expected = {
        first_name      => "Another",
        last_name       => "Customer",
        address_line_1  => "C/O 10 The Street",
        address_line_2  => "Local Area",
        address_line_3  => "Should we care about address_line_3?",
        towncity        => "Some Town",
        county          => "Countyshire",
        postcode        => "CS1 1AA",
        country         => "United Kingdom",
    };

    my $test_address = {
        title           => "Ms",
        first_name      => " Another",
        last_name       => "\x{2028}Customer",
        address_line_1  => "\x{2009} ℅ 10 The Street",
        address_line_2  => " \x{2006}Local Area ",
        address_line_3  => "     Should we care \x{2003}\x{2002} about address_line_3? ",
        towncity        => "Some Town       ",
        county          => "\n\n\n\tCountyshire\x{2006} \n\n",
        postcode        => "CS1\n\n\n\n\x{2006} \n\n1AA",
        country         => "  United Kingdom  ",
    };

    # calculate address hash for this address row
    $test_address->{address_hash} = $self->get_address_hash( $test_address );


    my $address = $self->schema->resultset('Public::OrderAddress')->find_or_create( $test_address );

    ok( $address, "I have an address record" );

    # call discard_changes to ensure we're reading from the database stored record
    $address->discard_changes;
    foreach my $field ( keys %$expected ) {
        cmp_ok( $address->$field, "eq", $expected->{$field}, "$field contains expected value" );
    }

}

sub test_is_valid_for_pre_order : Tests {
    my $self = shift;

    my @test_fields = qw(
        first_name
        last_name
        address_line_1
        towncity
        country
    );

    my %test_address = (
        title           => 'Title',
        first_name      => 'First Name',
        last_name       => 'Last Name',
        address_line_1  => 'Address Line 1',
        address_line_2  => 'Address Line 2',
        address_line_3  => 'Address Line 3',
        towncity        => 'Town/City',
        county          => 'County',
        country         => 'Country',
        postcode        => 'Postcode',
    );

    $test_address{address_hash} = $self->get_address_hash( \%test_address );

    # Set the configuration to known values.
    local $XTracker::Config::Local::config{PreOrderAddress}->{field_required} = \@test_fields;

    my $order_address = $self
        ->schema
        ->resultset('Public::OrderAddress')
        ->create( \%test_address );

    ok( $order_address->is_valid_for_pre_order,
        'A complete address is valid for a Pre-Order' );

    foreach my $test_field ( @test_fields ) {

        # Take a copy of the address, but clear the current field.
        my %broken_address = %test_address;
        $broken_address{ $test_field } = '';

        my $order_address = $self
            ->schema
            ->resultset('Public::OrderAddress')
            ->create( \%broken_address );

        ok( ! $order_address->is_valid_for_pre_order,
            "An address with the '$test_field' field empty is not valid for a Pre-Order" );

    }

}

=head2 test_has_non_latin_1_characters

=cut

sub test_has_non_latin_1_characters : Tests {
    my $self = shift;

    my $address = $self->{address_rs}->new({});
    my $mock_address = Test::MockObject::Extends->new($address);

    my $ok_string = join q{}, map { chr } 0..255;
    $mock_address->mock(as_carrier_string => sub { $ok_string });
    ok(!$mock_address->has_non_latin_1_characters,
        "should detect no non-latin-1 characters");

    my $bad_string = $ok_string . chr(256);
    $mock_address->mock(as_carrier_string => sub { $bad_string });
    ok($mock_address->has_non_latin_1_characters,
        "should detect non-latin-1 characters");
}
