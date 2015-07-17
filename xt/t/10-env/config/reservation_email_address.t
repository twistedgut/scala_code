#!/usr/bin/env perl
# vim: ts=8 sts=4 et sw=4 sr sta

use NAP::policy "tt",     'test';

use Test::XTracker::LoadTestConfig;

use Data::Dump  qw( pp );

use Test::Differences;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

=head2

This tests the email addresses used as the From address for reservation emails are as expected.

=cut

BEGIN {
    use_ok('XTracker::Config::Local', qw(
                            customercare_email
                            personalshopping_email
                            fashionadvisor_email
                        ));

    can_ok("XTracker::Config::Local", qw(
                            customercare_email
                            personalshopping_email
                            fashionadvisor_email
                        ) );
}

my %expected    = (
        'DC1'   => {
            'NAP'   => {
                customer_care   => 'customercare.dave@net-a-porter.com',
                personal_shopper=> 'MyShop.dave@net-a-porter.com',
                fashion_advisor => 'fashionconsultant.dave@net-a-porter.com',
            },
            'OUTNET'=> {
                customer_care   => 'customercare.dave@theOutnet.com',
                personal_shopper=> 'customercare.dave@theOutnet.com',
                fashion_advisor => 'customercare.dave@theOutnet.com',
            },
            'MRP'   => {
                customer_care   => 'customercare.dave@mrporter.com',
                personal_shopper=> 'personalshopping.dave@mrporter.com',
                fashion_advisor => 'customercare.dave@mrporter.com',
            },
        },
        'DC2'   => {
            'NAP'   => {
                customer_care   => 'customercare.usa.dave@net-a-porter.com',
                personal_shopper=> 'MyShop.usa.dave@net-a-porter.com',
                fashion_advisor => 'fashionconsultant.dave@net-a-porter.com',
            },
            'OUTNET'=> {
                customer_care   => 'customercare.usa.dave@theoutnet.com',
                personal_shopper=> 'customercare.usa.dave@theoutnet.com',
                fashion_advisor => 'customercare.usa.dave@theoutnet.com',
            },
            'MRP'   => {
                customer_care   => 'customercare.usa.dave@mrporter.com',
                personal_shopper=> 'personalshopping.usa.dave@mrporter.com',
                fashion_advisor => 'customercare.usa.dave@mrporter.com',
            },
        },
        'DC3'   => {
            'NAP'   => {
                customer_care   => 'customercareapac.dave@net-a-porter.com',
                personal_shopper=> 'myshop.cn.dave@net-a-porter.com',
                fashion_advisor => 'fashionconsultant.dave@net-a-porter.com',
            },
            'OUTNET'=> {
                customer_care   => 'customercare.cn.dave@theoutnet.com',
                personal_shopper=> 'customercare.cn.dave@theoutnet.com',
                fashion_advisor => 'customercare.cn.dave@theoutnet.com',
            },
            'MRP'   => {
                customer_care   => 'customercare.cn.dave@mrporter.com',
                personal_shopper=> 'personalshopping.cn.dave@mrporter.com',
                fashion_advisor => 'customercare.cn.dave@mrporter.com',
            },
        },
    );

# get what to expect based on which DC we are in
my $to_expect   = $expected{ $distribution_centre } or fail( "No tests for DC: $distribution_centre" );
my $tmp;

foreach my $conf_section ( sort keys %{ $to_expect } ) {
    note "Sales Channel Conf Section: $conf_section";
    my $emails  = $to_expect->{ $conf_section };

    $tmp    = customercare_email( $conf_section );
    is( lc($tmp), lc($emails->{customer_care}), "Customer Care email address correct: ".$emails->{customer_care} );

    $tmp    = personalshopping_email( $conf_section );
    is( lc($tmp), lc($emails->{personal_shopper}), "Personal Shopper email address correct: ".$emails->{personal_shopper} );

    $tmp    = fashionadvisor_email( $conf_section );
    is( lc($tmp), lc($emails->{fashion_advisor}), "Fashion Advisor email address correct: ".$emails->{fashion_advisor} );
}

done_testing;

#--------------------------------------------------------------
