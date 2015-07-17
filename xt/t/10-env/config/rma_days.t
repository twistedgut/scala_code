#!/usr/bin/env perl
use NAP::policy "tt",     'test';

=head2 CANDO-217: Checks Various Settings to do with Days you have to make Returns and to Return Items

This will test the following settings in the Config file and the Shipping Account table :

* That the number of days to Return an Item is 14 (RMA Expiry Days)
* That the number of days in the Shipping Account table is at least 28 (See CANDO-685) for all records

=cut

# these constants goven what the tests are checking against,
# change these here to update the tests as and when required
use Readonly;
# Readonly my $DAYS_SHOWN_IN_EMAIL_COPY                               => 14;
my %days_shown_in_email_copy = (
                         'DC1' =>{
                            'NAP'    => 14,
                            'MRP'    => 14,
                            'OUTNET' => 14,
                            'JC'     => 30,
                                 },
                         'DC2' =>{
                            'NAP'    => 14,
                            'MRP'    => 14,
                            'OUTNET' => 14,
                            'JC'     => 30,
                                 },
                         'DC3' =>{
                            'NAP'    => 14,
                            'MRP'    => 14,
                            'OUTNET' => 14,
                            'JC'     => 30,
                                 },

                            );


Readonly my $NUMBER_OF_DAYS_TO_RETURN_ITEMS                         => 14;
# governs the number of days a Customer has the option on the PWS to return
# items, different from above which is what we tell the Customers they have
Readonly my $MINIMUM_RETURN_CUTOFF_DAYS_ON_SHIPPING_ACCOUNT_TABLE   => 28;      # Shhh! don't tell the Customers

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            dc => [ qw( DC1 DC2 ) ], # Fails under DC3
                            export => [ qw( $distribution_centre ) ];

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    rma_cutoff_days_for_email_copy_only
                                    rma_expiry_days
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    rma_cutoff_days_for_email_copy_only
                                    rma_expiry_days
                                ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Sanity Check' );

# the number of buffer days there are per shipping account
# added on to the cut-off days for the 'return_cutoff_days' field
# to allow for the shipment to be delivered to the Customer
my %buffer_days = (
        'DC1'   => {
            'Unknown'           => 0,
            'Domestic'          => 3,
            'International'     => 5,
            'International Road'=> 9,
            'FTBC'              => 3,
        },
        'DC2'   => {
            'Unknown'           => 0,
            'Domestic'          => 3,
            'International'     => 3,
        },
    );

# get all Sales Channels
my @channels    = $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->all;
foreach my $channel ( @channels ) {
    note "Sales Channel: ".$channel->name;
    note "testing 'rma_cutoff_days_for_email_copy_only' function";
    my $conf_section    = $channel->business->config_section;
    my $days = $days_shown_in_email_copy{$distribution_centre}{$conf_section};
    cmp_ok( rma_cutoff_days_for_email_copy_only( $channel ), '==', $days,
                                            "Using Channel Object - Number of Days to Request an RMA shown in the Email Copy is as expected: $days" );
    cmp_ok( rma_cutoff_days_for_email_copy_only( $channel->business->config_section ), '==', $days,
                                            "Using Config Section - Number of Days to Request an RMA shown in the Email Copy is as expected: $days" );

    note "testing 'rma_expiry_days' function";
    $days   = $NUMBER_OF_DAYS_TO_RETURN_ITEMS;
    cmp_ok( rma_expiry_days( $channel ), '==', $days, "Using Channel Object - RMA Expiry days is as expected: $days" );
    cmp_ok( rma_expiry_days( $channel->business->config_section ), '==', $days, "Using Config Section - RMA Expiry days is as expected: $days" );

    # check the Shipping Accounts for the Channel
    $days       = $MINIMUM_RETURN_CUTOFF_DAYS_ON_SHIPPING_ACCOUNT_TABLE;
    my $buffer  = $buffer_days{ $distribution_centre };     # get the buffer days for the DC that should be added to $days

    fail( "No Buffer Days have been Assigned in this Test for the DC: $distribution_centre" )       if ( !$buffer );

    note "testing Shipping Accounts 'return_cutoff_days' must be at least $days days";
    my @accounts    = $channel->shipping_accounts->search( { return_cutoff_days => { '!=' => undef } }, { order_by => 'id' } )->all;
    foreach my $account ( @accounts ) {
        my $buffer_days = $buffer->{ $account->name } || 0;
        cmp_ok( ( $account->return_cutoff_days - $days ), '>=', $buffer_days,
            "'".$account->name."' is at least $days days with the correct buffer of '$buffer_days' days: ".$account->return_cutoff_days );
    }
}

done_testing;
