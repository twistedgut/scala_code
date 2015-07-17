#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use XTracker::Constants::FromDB     qw( :business );
use DateTime;

use Data::Dump      qw( pp );


BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Schema::Result::Public::Business');
}


my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my @businesses  = $schema->resultset('Public::Business')->all;

note "Test the Branded Date and salutation returned for each business is as expected";
# create a Date
my $date            = DateTime->new( day => 6, month=> 9, year => 2012 );
my %expected_formats= (
        $BUSINESS__NAP      => 'September 6, 2012',
        $BUSINESS__OUTNET   => 'September 6, 2012',
        $BUSINESS__MRP      => '6th September 2012',
        $BUSINESS__JC       => '6th September 2012',
    );

my $salutation_combos = {
    $BUSINESS__NAP => [
                       { title => '', first_name => 'FIRST', last_name => 'LAST', result => 'FIRST' },
                       { title => 'Title', first_name => 'FIRST', last_name => 'LAST', result => 'FIRST' },
                      ],
    $BUSINESS__OUTNET => [
                       { title => '', first_name => 'FIRST', last_name => 'LAST', result => 'FIRST' },
                       { title => 'Title', first_name => 'FIRST', last_name => 'LAST', result => 'FIRST' },
                      ],
    $BUSINESS__MRP => [
                       { title => '', first_name => 'FIRST', last_name => 'LAST', result => 'FIRST LAST' },
                       { title => 'Title', first_name => 'FIRST', last_name => 'LAST', result => 'Title LAST' },
                      ],
    $BUSINESS__JC => [
                       { title => '', first_name => 'FIRST', last_name => 'LAST', result => 'FIRST' },
                       { title => 'Title', first_name => 'FIRST', last_name => 'LAST', result => 'FIRST' },
                      ],

};


foreach my $bis ( @businesses ) {
    my $expected_format = $expected_formats{ $bis->id };
    is( $bis->branded_date( $date ), $expected_format, "Branded Date for: ".$bis->name. " as expected: ".$expected_format );
    is( $bis->branded_date( { empty => 'hash' } ), '', "Non 'DateTime' date passed Empty String Returned" );
    is( $bis->branded_date(), '', "'undef' date passed Empty String Returned" );

    foreach my $combo ( @{$salutation_combos->{$bis->id}} ) {
        my $salutation = $bis->branded_salutation( $combo );
        is( $salutation, $combo->{result}, "Branded salutation for: ".$bis->name. " as expected: ".$salutation );
    }
}

note "Test the Helper Function to return the Day of the Month Suffix";
my %suffixes    = (
        1   => 'st',
        2   => 'nd',
        3   => 'rd',
        4   => 'th',
        5   => 'th',
        6   => 'th',
        7   => 'th',
        8   => 'th',
        9   => 'th',
        10  => 'th',
        11  => 'th',
        12  => 'th',
        13  => 'th',
        14  => 'th',
        15  => 'th',
        16  => 'th',
        17  => 'th',
        18  => 'th',
        19  => 'th',
        20  => 'th',
        21  => 'st',
        22  => 'nd',
        23  => 'rd',
        24  => 'th',
        25  => 'th',
        26  => 'th',
        27  => 'th',
        28  => 'th',
        29  => 'th',
        30  => 'th',
        31  => 'st',
    );
foreach my $day ( sort { $a <=> $b } keys %suffixes ) {
    my $suffix  = $suffixes{ $day };
    is( $businesses[0]->_dotm_suffix( $day ), $suffix, "Suffix for Day: $day as expected: $suffix" );
}

done_testing;
