#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 XTracker::Utilities Test

Tests various functions in the 'XTracker::Utilities' package.

currently tests:

    * is_date_in_range & time_now
    * prefix_country_code_to_phone & known_mobile_number_for_country
    * get_class_suffix & class_suffix_matches

=cut

use Test::XTracker::Data;
use DateTime        qw( compare );


use_ok( 'XTracker::Utilities', qw(
                                is_date_in_range
                                prefix_country_code_to_phone
                                known_mobile_number_for_country
                                get_class_suffix
                                class_suffix_matches
                                time_now
                                strip
                                flatten
                                ltrim
                                rtrim
                                trim
                                string_to_boolean
                                extract_pids_skus_from_text
                                apply_discount
                                remove_discount
                                find_in_AoH
                            ) );
can_ok( 'XTracker::Utilities', qw(
                                is_date_in_range
                                prefix_country_code_to_phone
                                known_mobile_number_for_country
                                time_now
                                strip
                                flatten
                                ltrim
                                rtrim
                                trim
                                string_to_boolean
                                extract_pids_skus_from_text
                                apply_discount
                                remove_discount
                                find_in_AoH
                            ) );

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', "sanity check got a Schema" );

#------------- TESTS -------------
_test_is_date_in_range(1);
_test_phone_functions( $schema, 1 );
_test_class_suffix_functions( $schema, 1 );
_test_string_functions();
_test_extract_pids_skus_from_text( 1 );
_test_apply_and_remove_discount( 1 );
_test_find_in_Aoh(1);
#---------------------------------


done_testing;

sub _test_is_date_in_range {
    my $oktodo      = shift;

    SKIP: {
        skip '_test_is_date_in_range',1     if ( !$oktodo );

        note "TESTING: _test_is_date_in_range_and_time_now";

        note "testing 'time_now'";
        my $now     = DateTime->now( time_zone => 'local' );
        my $got     = time_now();
        isa_ok( $got, 'DateTime', "'time_now' returned expected object" );
        is( $got->time_zone->name, $now->time_zone->name, "Time Zone is local when no TZ specified" );
        $got        = time_now( 'UTC' );
        is( $got->time_zone->name, 'UTC', "Specify a TZ and Time has the expected Time Zone" );

        note "testing 'is_date_in_range'";

        my $start   = $now->clone->subtract( days => 2 );
        my $end     = $now->clone->add( days => 2 );

        my %tests   = (
                'between' => {
                        date    => $now->clone,
                        expected=> 1,
                    },
                'start'     => {
                        date    => $start->clone,
                        expected=> 1,
                    },
                'end'       => {
                        date    => $end->clone,
                        expected=> 1,
                    },
                'before'    => {
                        date    => $start->clone->subtract( seconds => 1 ),
                        expected=> 0,
                    },
                'after'     => {
                        date    => $end->clone->add( seconds => 1 ),
                        expected=> 0,
                    },
            );

        foreach my $label ( keys %tests ) {
            my $test    = $tests{ $label };
            my $result  = is_date_in_range( $test->{date}, $start, $end );
            ok( defined $result, "$label, 'is_date_in_range' returned a defined value" );
            cmp_ok( $result, '==', $test->{expected}, "$label: value is as Expected: $test->{expected}" );
        }
    };

    return;
}

# this tests various phone functions
sub _test_phone_functions {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip '_test_phone_functions',1          if ( !$oktodo );

        note "TESTING: _test_phone_functions";

        my $country_rs  = $schema->resultset('Public::Country')->search( { country => { '!=' => 'Unknown' } } );

        # get Countries just not 'Unknown'
        my $country     = $country_rs->search( { code => { 'NOT IN' => [ 'GB', 'US' ] } } )->first;
        my $prefix      = $country->phone_prefix;
        my $uk_prefix   = $country_rs->search( { country => 'United Kingdom' } )->first->phone_prefix;
        my $us_prefix   = $country_rs->search( { country => 'United States' } )->first->phone_prefix;

        note "Testing 'known_mobile_number_for_country'";
        my $result  = known_mobile_number_for_country();
        ok( defined $result, "Calling function with 'undef' returns a defined Value" );
        cmp_ok( $result, '==', 0, "and the Value is FALSE" );
        $result     = known_mobile_number_for_country( "" );
        ok( defined $result, "Calling function with an empty string returns a defined Value" );
        cmp_ok( $result, '==', 0, "and the Value is FALSE" );

        my %tests   = (
                "UK Mobile '07*' with leading '+'"              => { number => "+${uk_prefix}7000123321", result => 1 },
                "UK Mobile '07*' without leading '+'"           => { number => "${uk_prefix}7000123321", result => 1 },
                "UK Non-Mobile '012*' with leading '+'"         => { number => "+${uk_prefix}1205123321", result => 0 },
                "UK Non-Mobile '012*' without leading '+'"      => { number => "${uk_prefix}1205123321", result => 0 },
                "Any US Number with leading '+'"                => { number => "+${us_prefix}321456987", result => 1 },
                "Any US Number without leading '+'"             => { number => "${us_prefix}321456987", result => 1 },
                "Any Other Country Number with leading '+'"     => { number => "+${prefix}321456987", result => 1 },
                "Any Other Country Number without leading '+'"  => { number => "${prefix}321456987", result => 1 },
            );

        foreach my $label ( keys %tests ) {
            note "testing: $label";
            my $test    = $tests{ $label };
            my $reslabel= ( $test->{result} ? 'TRUE' : 'FALSE' );

            my $got = known_mobile_number_for_country( $test->{number} );
            ok( defined $got, "function returned a defined Value" );
            cmp_ok( $got, '==', $test->{result}, "and the Value is $reslabel" );
        }


        note "Testing 'prefix_country_code_to_phone' function";
        note "test parameter requirements for 'prefix_country_code_to_phone' function";
        throws_ok { prefix_country_code_to_phone( "124" ) } qr/Missing Country or Country NOT a 'Public::Country' object passed/i,
                                                    "Passing Phone Number with NO Country to function dies with expected message";
        throws_ok { prefix_country_code_to_phone( "124", [ 1 ] ) } qr/Missing Country or Country NOT a 'Public::Country' object passed/i,
                                                    "Passing Phone Number with a NON 'Public::Country' to function dies with expected message";

        # test various invalid numbers throw an error
        foreach my $inv_number (
                                " +01244",
                                "+012+44",
                                "+01244+",
                                "012+44",
                                "01244+",
                                "+01244a",
                                "+",
                            ) {
            throws_ok { prefix_country_code_to_phone( $inv_number ) } qr/Invalid Phone Number:/i,
                                                        "Passing Invalid Phone Number '$inv_number' to function dies with expected message";
        }

        my $number  = prefix_country_code_to_phone( undef, $country );
        ok( defined $number && $number eq "", "Passing in 'undef' for Phone and NO Country returns an Empty String" );
        $number     = prefix_country_code_to_phone( "" );
        ok( defined $number && $number eq "", "Passing in an Empty String for Phone and NO Country returns an Empty String" );
        $number     = prefix_country_code_to_phone( "+1234" );
        ok( defined $number && $number eq "+1234", "Passing in a leading '+' Number for Phone but NO Country returns Passed in Number" );

        %tests      = (
                "Leading Zero Removed"  => {
                    number  => '07900321123',
                    expected=> "+${prefix}7900321123",
                },
                "No Leading Zero"  => {
                    number  => '456234123',
                    expected=> "+${prefix}456234123",
                },
                "Prefix '+' already present" => {
                    number  => '+456234123',
                    expected=> '+456234123',
                },
            );

        foreach my $label ( keys %tests ) {
            my $test    = $tests{ $label };
            note "Testing: $label";

            my $got = prefix_country_code_to_phone( $test->{number}, $country );
            ok( $got, "'prefix_country_code_to_phone' returned a Defined Value" );
            is( $got, $test->{expected}, "'prefix_country_code_to_phone' returned as Expected" );
        }
    };

    return;
}

sub _test_class_suffix_functions {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip '_test_class_suffix_functions',1       if ( !$oktodo );

        note "TESTING: _test_class_suffix_functions";

        # grab any kind of DBIC record
        my $country = $schema->resultset('Public::Country')->first;

        note "check 'get_class_suffix' function";
        is( get_class_suffix(), "", "With no Class passed in returned an Empty String" );
        is( get_class_suffix( "" ), "", "With an empty string passed in returned an Empty String" );
        my $class   = get_class_suffix( $country );
        is( $class, 'Country', "For 'Public::Country' Record, 'get_class_suffix' returned 'Country'" );
        $class      = get_class_suffix('Country');
        is( $class, 'Country', "For 'get_class_suffix' with a Class passed in as a parameter returned 'Country'" );
        $class      = get_class_suffix('Public::Country');
        is( $class, 'Country', "For 'get_class_suffix' with 'Public::Country' passed in as a parameter returned 'Country'" );
        $class      = get_class_suffix( ref( $country ) );
        is( $class, 'Country', "For 'get_class_suffix' with a Full Class name passed in as a parameter returned 'Country'" );

        note "check 'class_suffix_matches' function using a 'Public::Country' record to match against";
        cmp_ok( class_suffix_matches(), '==', 0, "With no params at all returns FALSE" );
        cmp_ok( class_suffix_matches( $country, '' ), '==', 0, "returns FALSE when using a record and an empty class string" );
        cmp_ok( class_suffix_matches( $country, undef ), '==', 0, "returns FALSE when using a record and 'undef' as a class string" );
        cmp_ok( class_suffix_matches( undef, 'Country' ), '==', 0, "returns FALSE when using 'undef' as a record and a class string" );
        cmp_ok( class_suffix_matches( 'Country', 'Country' ), '==', 0, "returns FALSE when using a Class Name as a record and a class string" );
        cmp_ok( class_suffix_matches( $country, $country ), '==', 0, "returns FALSE when using a record and a record as a class string" );
        cmp_ok( class_suffix_matches( $country, 'Country' ), '==', 1, "returns TRUE for 'Country'" );
        cmp_ok( class_suffix_matches( $country, 'Public::Country' ), '==', 1, "returns TRUE for 'Public::Country'" );
        cmp_ok( class_suffix_matches( $country, 'Public::Return' ), '==', 0, "returns FALSE for 'Public::Return'" );
        cmp_ok( class_suffix_matches( $country, ref( $country ) ), '==', 1, "returns TRUE when using the full Class Name" );
    };

    return;
}


sub _test_string_functions {
    my $string_function_tests = {
        trim => {
                   do_space_subs => 1,
                   do_arrays     => 1,
                   test_cases    => [
                        {
                             name => 'undefined',
                              arg => undef,
                           result => undef,
                        },
                        {
                             name => 'empty string',
                              arg => '',
                           result => '',
                        },
                        {
                             name => 'non-spacey string',
                              arg => 'abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'left-spacey string',
                              arg => ' abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'right-spacey string',
                              arg => 'abc123 ',
                           result => 'abc123',
                        },
                        {
                             name => 'both-spacey string',
                              arg => ' abc123 ',
                           result => 'abc123',
                        },
                        {
                             name => 'embedded-spacey string',
                              arg => 'abc 123',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-left-spacey string',
                              arg => ' abc 123',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-right-spacey string',
                              arg => 'abc 123 ',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-both-spacey string',
                              arg => ' abc 123 ',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-multi-spacey string',
                              arg => ' a b c 1 2 3 ',
                           result => 'a b c 1 2 3',
                        },
                    ],
        },

        ltrim => {
                   do_space_subs => 1,
                   do_arrays     => 0,
                   test_cases    => [
                        {
                             name => 'undefined',
                              arg => undef,
                           result => undef,
                        },
                        {
                             name => 'empty string',
                              arg => '',
                           result => '',
                        },
                        {
                             name => 'non-spacey string',
                              arg => 'abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'left-spacey string',
                              arg => ' abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'right-spacey string',
                              arg => 'abc123 ',
                           result => 'abc123 ',
                        },
                        {
                             name => 'both-spacey string',
                              arg => ' abc123 ',
                           result => 'abc123 ',
                        },
                        {
                             name => 'embedded-spacey string',
                              arg => 'abc 123',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-left-spacey string',
                              arg => ' abc 123',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-right-spacey string',
                              arg => 'abc 123 ',
                           result => 'abc 123 ',
                        },
                        {
                             name => 'embedded-both-spacey string',
                              arg => ' abc 123 ',
                           result => 'abc 123 ',
                        },
                        {
                             name => 'embedded-multi-spacey string',
                              arg => ' a b c 1 2 3 ',
                           result => 'a b c 1 2 3 ',
                        },
                    ],
        },

        rtrim => {
                   do_space_subs => 1,
                   do_arrays     => 0,
                   test_cases    => [
                        {
                             name => 'undefined',
                              arg => undef,
                           result => undef,
                        },
                        {
                             name => 'empty string',
                              arg => '',
                           result => '',
                        },
                        {
                             name => 'non-spacey string',
                              arg => 'abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'left-spacey string',
                              arg => ' abc123',
                           result => ' abc123',
                        },
                        {
                             name => 'right-spacey string',
                              arg => 'abc123 ',
                           result => 'abc123',
                        },
                        {
                             name => 'both-spacey string',
                              arg => ' abc123 ',
                           result => ' abc123',
                        },
                        {
                             name => 'embedded-spacey string',
                              arg => 'abc 123',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-left-spacey string',
                              arg => ' abc 123',
                           result => ' abc 123',
                        },
                        {
                             name => 'embedded-right-spacey string',
                              arg => 'abc 123 ',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-both-spacey string',
                              arg => ' abc 123 ',
                           result => ' abc 123',
                        },
                        {
                             name => 'embedded-multi-spacey string',
                              arg => ' a b c 1 2 3 ',
                           result => ' a b c 1 2 3',
                        },
                    ],
        },

        strip => {
                   do_space_subs => 1,
                   do_arrays     => 1,
                   test_cases    => [
                        {
                             name => 'undefined',
                              arg => undef,
                           result => undef,
                        },
                        {
                             name => 'empty string',
                              arg => '',
                           result => '',
                        },
                        {
                             name => 'non-spacey string',
                              arg => 'abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'left-spacey string',
                              arg => ' abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'right-spacey string',
                              arg => 'abc123 ',
                           result => 'abc123',
                        },
                        {
                             name => 'both-spacey string',
                              arg => ' abc123 ',
                           result => 'abc123',
                        },
                        {
                             name => 'embedded-spacey string',
                              arg => 'abc 123',
                           result => 'abc123',
                        },
                        {
                             name => 'embedded-left-spacey string',
                              arg => ' abc 123',
                           result => 'abc123',
                        },
                        {
                             name => 'embedded-right-spacey string',
                              arg => 'abc 123 ',
                           result => 'abc123',
                        },
                        {
                             name => 'embedded-both-spacey string',
                              arg => ' abc 123 ',
                           result => 'abc123',
                        },
                        {
                             name => 'embedded-multi-spacey string',
                              arg => ' a b c 1 2 3 ',
                           result => 'abc123',
                        },
                    ],
        },

        flatten => {
                   do_space_subs => 0,
                   do_arrays     => 1,
                   test_cases    => [
                        {
                             name => 'undefined',
                              arg => undef,
                           result => undef,
                        },
                        {
                             name => 'empty string',
                              arg => '',
                           result => '',
                        },
                        {
                             name => 'non-spacey string',
                              arg => 'abc123',
                           result => 'abc123',
                        },
                        {
                             name => 'left-spacey string',
                              arg => ' abc123',
                           result => ' abc123',
                        },
                        {
                             name => 'multi-left-spacey string',
                              arg => '    abc123',
                           result => ' abc123',
                        },
                        {
                             name => 'right-spacey string',
                              arg => 'abc123    ',
                           result => 'abc123 ',
                        },
                        {
                             name => 'embedded-spacey string',
                              arg => 'abc 123',
                           result => 'abc 123',
                        },
                        {
                             name => 'embedded-multi-spacey string',
                              arg => ' a b c 1 2 3 ',
                           result => ' a b c 1 2 3 ',
                        },
                        {
                             name => 'embedded bursty-spacey string',
                              arg => ' a   b  c    1   2     3   ',
                           result => ' a b c 1 2 3 ',
                        },
                        {
                             name => 'embedded variable-spacey string',
                              arg => qq{ a\t\n\nb\x{2028} \r c \t \n\r 1\x{85}\r\n2\f\n \n \r \t 3\x{2029}  },
                           result => ' a b c 1 2 3 ',
                        },
                    ],
        },

        string_to_boolean => {
                   do_space_subs => 0,
                   do_arrays     => 0,
                   test_cases    => [
                        {
                             name => 'undefined',
                              arg => undef,
                           result => undef
                        },
                        {
                             name => 'lower-case true',
                              arg => 'true',
                           result => 1
                        },
                        {
                             name => 'upper-case true',
                              arg => 'TRUE',
                           result => 1
                        },
                        {
                             name => 'capitalized true',
                              arg => 'True',
                           result => 1
                        },
                        {
                             name => 'upper-case letter t',
                              arg => 'T',
                           result => 1
                        },
                        {
                             name => 'lower-case letter t',
                              arg => 't',
                           result => 1
                        },
                        {
                             name => 'lower-case yes',
                              arg => 'yes',
                           result => 1
                        },
                        {
                             name => 'upper-case yes',
                              arg => 'YES',
                           result => 1
                        },
                        {
                             name => 'capitalized yes',
                              arg => 'Yes',
                           result => 1
                        },
                        {
                             name => 'upper-case letter y',
                              arg => 'Y',
                           result => 1
                        },
                        {
                             name => 'lower-case letter y',
                              arg => 'y',
                           result => 1
                        },
                        {
                             name => 'digit 1 as a string',
                              arg => '1',
                           result => 1
                        },
                        {
                             name => 'digit 1 as a number',
                              arg => 1,
                           result => 1
                        },
                        {
                             name => 'lower-case false',
                              arg => 'false',
                           result => 0
                        },
                        {
                             name => 'upper-case false',
                              arg => 'FALSE',
                           result => 0
                        },
                        {
                             name => 'capitalized false',
                              arg => 'False',
                           result => 0
                        },
                        {
                             name => 'upper-case letter f',
                              arg => 'F',
                           result => 0
                        },
                        {
                             name => 'lower-case letter f',
                              arg => 'f',
                           result => 0
                        },
                        {
                             name => 'lower-case no',
                              arg => 'no',
                           result => 0
                        },
                        {
                             name => 'upper-case no',
                              arg => 'NO',
                           result => 0
                        },
                        {
                             name => 'capitalized no',
                              arg => 'No',
                           result => 0
                        },
                        {
                             name => 'upper-case letter n',
                              arg => 'N',
                           result => 0
                        },
                        {
                             name => 'lower-case letter n',
                              arg => 'n',
                           result => 0
                        },
                        {
                             name => 'digit 0 as a string',
                              arg => '0',
                           result => 0
                        },
                        {
                             name => 'digit 0 as a number',
                              arg => 0,
                           result => 0
                        },
                        {
                             name => 'empty string',
                              arg => '',
                           result => 0
                        },
                   ]
        }
    };

    my @whitespace_chars = (
       [ space       => " "       ],
       [ tab         => "\t"      ],
       [ newline     => "\n"      ],
       [ return      => "\r"      ],
       [ formfeed    => "\f"      ],
       [ unicode85   =>"\x{85}"   ],
       [ unicode2028 =>"\x{2028}" ],
       [ unicode2029 =>"\x{2029}" ]
    );
    note "TESTING: _test_string_functions";

    foreach my $function (keys %$string_function_tests) {
        my ( $do_space_subs, $do_arrays, $test_cases )
            = @{$string_function_tests->{$function}}{ qw( do_space_subs do_arrays test_cases )};

        note "Testing string function $function";

      TEST:
        foreach my $test_case (@$test_cases) {
            my ($arg, $result, $name) = @{$test_case}{qw( arg result name )};

            no strict 'refs'; ## no critic(ProhibitNoStrict)
            is( &$function( $arg ), $result, $name );
            use strict;

            if ($do_arrays) {
                foreach my $amount ( 0 .. 3 ) {
                    my $arrayed;

                    $arrayed->{arg}    = [ ( $arg ) x $amount ];
                    $arrayed->{result} = [ ( $result ) x $amount ];
                    $arrayed->{name}   = "$name times $amount";

                    no strict 'refs'; ## no critic(ProhibitNoStrict)
                    my @a = &$function( @{$arrayed->{arg}} );
                    use strict;

                    is_deeply( \@a, $arrayed->{result}, $arrayed->{name} );
                }
            }

            next TEST unless defined $arg && $arg =~ m{ };

            if ($do_space_subs) {
                foreach my $multiplier ( 1 .. 3 ) {
                    foreach my $ws_char ( @whitespace_chars ) {
                        my ( $char_name, $char ) = @$ws_char;

                        my $subbed;

                        ($subbed->{arg}, $subbed->{result}, $subbed->{name})
                            = ( $arg, $result, $name );

                        my $chars = $char x $multiplier;

                        $subbed->{arg}    =~ s{ }{$chars}g;
                        $subbed->{result} =~ s{ }{$chars}g;
                        $subbed->{name}   .= " using $char_name multiplied by $multiplier";

                        no strict 'refs'; ## no critic(ProhibitNoStrict)
                        is( &$function( $subbed->{arg} ), $subbed->{result}, $subbed->{name} );
                        use strict;
                    }
                }
            }
        }
    }
}

# tests the function 'extract_pids_skus_from_text'
sub _test_extract_pids_skus_from_text {
    my $oktodo  = shift;

    SKIP:{
        skip '_test_extract_pids_skus_from_text', 1     if ( !$oktodo );

        note "TESTING: '_test_extract_pids_skus_from_text'";

        my @tests   = (
                {
                    input   =>
q{
12345-345,
1003
45544-3456

sdlkfsklfs
10323-0454 sdjfsjfkl
fsflksf;lsf;sf;ls ;sldf;kas f;l
},
                    expect  => {
                            clean_pids  => [
                                    { pid => 12345, size_id => 345, sku => '12345-345' },
                                    { pid => 1003, size_id => '' },
                                    { pid => 45544, size_id => 3456, sku => '45544-3456' },
                                    { pid => 10323, size_id => 454, sku => '10323-0454' },
                                ],
                            errors      => [],
                        },
                },
                {
                    input   => q{12345,4234234234242,1231234-012,3456-2134,jjksf s, 234hh22343},
                    expect  => {
                            clean_pids  => [
                                    { pid => 12345, size_id => '' },
                                    { pid => 1231234, size_id => 12, sku => '1231234-012' },
                                    { pid => 3456, size_id => 2134, sku => '3456-2134' },
                                    { pid => 234, size_id => '' },
                                ],
                            errors      => [
                                    '4234234234242',
                                ],
                        },
                },
                {
                    input   =>
q{
123424
48454
3424424
242949
1203013
1313134
},
                    expect  => {
                            clean_pids  => [
                                    { pid => 123424, size_id => '' },
                                    { pid => 48454, size_id => '' },
                                    { pid => 3424424, size_id => '' },
                                    { pid => 242949, size_id => '' },
                                    { pid => 1203013, size_id => '' },
                                    { pid => 1313134, size_id => '' },
                                ],
                            errors      => [],
                        },
                },
                {
                    input   =>
q{
123424-213
48454-2133
3424424-002
242949-2343
1203013-032
1313134-001
},
                    expect  => {
                            clean_pids  => [
                                    { pid => 123424, size_id => 213, sku => '123424-213' },
                                    { pid => 48454, size_id => 2133, sku => '48454-2133' },
                                    { pid => 3424424, size_id => 2, sku => '3424424-002' },
                                    { pid => 242949, size_id => 2343, sku => '242949-2343' },
                                    { pid => 1203013, size_id => 32, sku => '1203013-032' },
                                    { pid => 1313134, size_id => 1, sku => '1313134-001' },
                                ],
                            errors      => [],
                        },
                },
                {
                    input   =>
q{
sfkljsjk#
sdfsk
0239929342894kf
lkjdlkslk
lsdjlksj
129001982309
sdjflskjflk
},
                    expect  => {
                            clean_pids  => [],
                            errors      => [
                                        '0239929342894kf',
                                        '129001982309',
                                    ],
                        },
                },
                {
                    input   =>
q{
sljdflksjklfs
asfjas flkasflk jaslkfjs
fs;lfjsklf lksafs
sadkfskljf
},
                    expect  => {
                            clean_pids  => [],
                            errors      => [],
                        },
                },
                {
                    input   => undef,
                    expect  => {
                            clean_pids  => [],
                            errors      => [],
                        },
                },
                {
                    input   => '',
                    expect  => {
                            clean_pids  => [],
                            errors      => [],
                        },
                },
            );

        note "Series of tests providing Text to be Parsed and the Expected output";

        foreach my $test ( @tests ) {
            my $input   = $test->{input};
            my $expected= $test->{expect};

            my $got     = extract_pids_skus_from_text( $input );
            is_deeply( $got, $expected, "Text Parsed and Got the Exepected PIDs/SKUs" )
                                                    or note "Didn't Parse Text Correctly:\n---------\n${input}\n---------";
        }
    };

    return;
}

=head2 _test_apply_and_remove_discount

Tests the 'apply_discount' & 'remove_discount' functions.

=cut

sub _test_apply_and_remove_discount {
    my $oktodo = 1;

    SKIP: {
        skip '_test_apply_and_remove_discount', 1      if ( !$oktodo );

        note "TESTING: '_test_apply_and_remove_discount'";

        my %tests = (
            'Apply 10% Discount' => {
                setup => {
                    price => 200,
                    apply_discount => 10,
                },
                expect => 180,
            },
            'Remove 10% Discount' => {
                setup => {
                    price => 180,
                    remove_discount => 10,
                },
                expect => 200,
            },
            'Apply 0% Discount' => {
                setup => {
                    price => 200,
                    apply_discount => 0,
                },
                expect => 200,
            },
            'Remove 0% Discount' => {
                setup => {
                    price => 180,
                    remove_discount => 0,
                },
                expect => 180,
            },
            'Apply 1% Discount' => {
                setup => {
                    price => 20,
                    apply_discount => 1,
                },
                expect => 19.8,
            },
            'Remove 1% Discount' => {
                setup => {
                    price => 19.8,
                    remove_discount => 1,
                },
                expect => 20,
            },
            'Apply 100% Discount' => {
                setup => {
                    price => 200,
                    apply_discount => 100,
                },
                expect => 0,
            },
            'Remove 100% Discount' => {
                setup => {
                    price => 200,
                    remove_discount => 100,
                },
                expect_to_die => 1,
            },
            'Apply Discount to ZERO values' => {
                setup => {
                    price => 0,
                    apply_discount => 30,
                },
                expect => 0,
            },
            'Remove Discount from ZERO values' => {
                setup => {
                    price => 0,
                    remove_discount => 30,
                },
                expect => 0,
            },
            'Apply 23.75% Discount' => {
                setup => {
                    price => 30,
                    apply_discount => 23.75,
                },
                expect => 22.875,
            },
            'Remove 23.75% Discount' => {
                setup => {
                    price => 22.875,
                    remove_discount => 23.75,
                },
                expect => 30,
            },
            'Apply 101% Discount' => {
                setup => {
                    price => 200,
                    apply_discount => 101,
                },
                expect_to_die => 1,
            },
            'Remove 101% Discount' => {
                setup => {
                    price => 200,
                    remove_discount => 101,
                },
                expect_to_die => 1,
            },
        );

        foreach my $label ( keys %tests ) {
            note "Testing: ${label}";
            my $test   = $tests{ $label };
            my $setup  = $test->{setup};
            my $expect = $test->{expect};

            if ( !$test->{expect_to_die} ) {
                my $got = (
                    exists( $setup->{apply_discount} )
                    ? apply_discount( $setup->{price}, $setup->{apply_discount} )
                    : remove_discount( $setup->{price}, $setup->{remove_discount} )
                );
                is( $got, $expect, "got Expected Price back" )
                                        or diag "Price Failed - Got: " . p( $got )
                                                      . ", Expected: " . p( $expect );
            }
            else {
                dies_ok {
                    my $got = (
                        exists( $setup->{apply_discount} )
                        ? apply_discount( $setup->{price}, $setup->{apply_discount} )
                        : remove_discount( $setup->{price}, $setup->{remove_discount} )
                    );
                } "Function DIEs";
            }
        }
    };

    return;
}


sub _test_find_in_Aoh {
    my $oktodo = shift;
    SKIP: {
        skip '_test_find_in_Aoh', 1      if ( !$oktodo );

        note "TESTING: '_test_find_in_AoH'";

       my $test_dataset = [
            { sku => '123', quantity => 50 , price =>10 },
            { sku => '321', quantity => 50 , price =>10 },
            { sku => '142', quantity => 20 , price =>10 },
            { sku => '124', quantity => 30 , price =>10 },
        ];


        my %tests = (
            'Find 2 keys in hash' => {
                setup => {
                    find_hash => { sku => '321', quantity => 50 }
                },
                expect => { sku => '321', quantity => 50 , price =>10 },
            },
            'Find 1 keys in hash' => {
                setup => {
                    find_hash => { quantity => 50 }
                },
                expect => { sku => '123', quantity => 50 , price =>10 },
            },
            'Non-Existing keys' => {
                setup => {
                    find_hash => { quantity => 100 }
                },
                expect => 0,
            },
            'Wrong Arguments' => {
                setup => {
                    find_hash => [],
                },
                expect_to_die => 1,
            },
        );

        foreach my $label ( keys %tests ) {
            note "Testing: ${label}";
            my $test   = $tests{ $label };
            my $setup  = $test->{setup}->{find_hash};
            my $expect = $test->{expect};

            if ( !$test->{expect_to_die} ) {
                my $got = find_in_AoH( $test_dataset,$setup);
                 is_deeply( $got, $expect);
            } else {
                dies_ok {
                    my $got = find_in_AoH( $test_dataset,$setup)
                } "Function DIEs";

            }


        }


    };
    return ;
}

