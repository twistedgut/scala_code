#!/opt/xt/xt-perl/bin/perl
use NAP::policy;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Script::Customer::OutOfDateCustomerValue;

=head1 NAME

script/housekeeping/customer/out_of_date_customer_value.pl

=head1 DESCRIPTION

Wrapper script to invoke L<XTracker::Script::Customer::OutOfDateCustomerValue>,
see the POD for that class for details.

=head1 SYNOPSIS

perl script/housekeeping/customer/out_of_date_customer_value.pl [options]

=cut

XTracker::Script::Customer::OutOfDateCustomerValue
    ->new_with_options
    ->invoke;

