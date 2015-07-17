package Test::XT::Net::Seaview::Utils;

use NAP::policy "tt", 'test', 'class';

use Test::XTracker::RunCondition export => qw( $distribution_centre );

BEGIN {
    extends "NAP::Test::Class";
};

use Test::XTracker::Data;
use XT::Net::Seaview::Utils;

sub init : Test(startup) {
    my $self = shift;
    $self->{schema} = Test::XTracker::Data->get_schema;

    # All categories
    @{$self->{categories}}
      = $self->{schema}->resultset('Public::CustomerCategory')->search;
}

sub test_category_urn : Tests() {
    my $self = shift;

    # Category should be a single string with no spaces, special characters,
    # and internal underscores only
    foreach my $cat (@{$self->{categories}}){
        my $cat_urn = XT::Net::Seaview::Utils->category_urn($cat->category);

        my $cat_part = (split(/:/, $cat_urn, 4))[3];
        like( $cat_part, qr/\w+[\w_]*\w+/,
              'Category \'' . $cat->category . "\' produces a valid URN: $cat_urn")
    }
}

sub test_urn_to_category : Tests() {
    my $self = shift;

    my $urns = [];
    foreach my $cat (@{$self->{categories}}){

        my $urn = XT::Net::Seaview::Utils->category_urn($cat->category);
        my $processed_cat = XT::Net::Seaview::Utils->urn_to_category($urn);

        is($cat->category, $processed_cat, "Category '$processed_cat' is correctly created from the URN");
    }
}

sub test_state_county_switch : Tests() {
    my $self = shift;

    my $address_with_county_only = { county => 'county' };
    my $address_with_state_only = { state => 'state' };
    my $address_with_state_and_county
      = { county => 'county', state => 'state' };
    my $address_with_state_and_undef_county
      = { county => undef, state => 'state' };
    my $address_with_empty_state_and_county
      = { county => 'county', state => '' };


    my $address_with_undef_state_and_county
      = { county => 'county', state => undef };

    $address_with_county_only
      = XT::Net::Seaview::Utils->state_county_switch(
                                   $address_with_county_only);

    ok($address_with_county_only->{county} eq 'county',
       'Address with county only maintains county field');

    ok(! defined $address_with_county_only->{state},
       'Address with county only has undefined state field');

    $address_with_state_only
      = XT::Net::Seaview::Utils->state_county_switch(
                                   $address_with_state_only);

    ok($address_with_state_only->{state} eq 'state',
       'Address with state only maintains state field');

    ok($address_with_state_only->{county} eq 'state',
       'Address with state only has state value in county field');

    $address_with_state_and_county
      = XT::Net::Seaview::Utils->state_county_switch(
                                   $address_with_state_and_county);

    if( $distribution_centre eq 'DC2' ){
        ok($address_with_state_and_county->{county} eq 'state',
           'Address with state and county has state value in county field in DC2');
    }
    else {
        ok($address_with_state_and_county->{county} eq 'county',
           'Address with state and county has county value in county field in DC1/DC3');
    }

    $address_with_state_and_undef_county
      = XT::Net::Seaview::Utils->state_county_switch(
                                   $address_with_state_and_undef_county);

    ok($address_with_state_and_undef_county->{county} eq 'state',
           'Address with state and undefined county has state value in county field');

    $address_with_undef_state_and_county
      = XT::Net::Seaview::Utils->state_county_switch(
                                   $address_with_undef_state_and_county);

    ok($address_with_undef_state_and_county->{county} eq 'county',
       'Address with undefined state and county has county value in county field');

    $address_with_empty_state_and_county
      = XT::Net::Seaview::Utils->state_county_switch(
                                   $address_with_empty_state_and_county);

    if( $distribution_centre eq 'DC2' ){
        ok($address_with_empty_state_and_county->{county} eq '',
           'Address with empty state and county has empty value in county field in DC2');
    }
    else {
        ok($address_with_empty_state_and_county->{county} eq 'county',
           'Address with empty state and county has county value in county field in DC1/DC3');
    }
}
