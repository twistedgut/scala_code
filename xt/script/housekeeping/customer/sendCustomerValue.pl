#!/opt/xt/xt-perl/bin/perl

use NAP::policy "tt";

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

=head1 NAME

sendCustomerValue.pl

=head1 SYNOPSIS

    perl script/housekeeping/customer/sendCustomerValue.pl [OPTIONS] [ account_urn account_urn ....]

=head1 DESCRIPTION

CANDO-7912 : This script is used for pushing "Customer Value" to Seaview (Bosh).

example :

perl script/housekeeping/customer/sendCustomerValue.pl -all
    or
perl script/housekeeping/customer/sendCustomerValue.pl urn:nap:account:3beafce322ab34b5ac3 urn:nap:account:3beafce322ab34b5a34 urn:nap:account:3beafce322ab34b5ac3
    or
cat /path/to/some/file | perl script/housekeeping/customer/sendCustomerValue.pl

=cut

use XTracker::Script::Customer::SendCustomerValueToSeaview;

XTracker::Script::Customer::SendCustomerValueToSeaview
    ->new_with_options
    ->invoke;
