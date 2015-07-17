#!/opt/xt/xt-perl/bin/perl

=head1 NAME

schema_loader.t - check that the XTracker::Schema::Result classes are up to date

=head1 DESCRIPTION

This test runs F<script/schema_loader.pl> in dry-run mode and checks
that it wouldn't have modified any classes.

=cut

use strict;
use warnings;
use FindBin;
use Test::More;
use Test::Requires {
    'DBIx::Class::Schema::Loader' => '0.07041',
};

use lib 't/lib';
use Test::XTracker::RunCondition (
    export => '$distribution_centre',
);

{
    local @ARGV = qw(--option=quiet=1 --option=dry_run=1);
    do "$FindBin::Bin/../../script/schema_loader.pl";
}

# This means out of sync with DC1, as that's the database we use to generate
# our schema files. So DC1 should never have an entry in this!
my $out_of_sync = {
    DC2 => {
        map {; "XTracker::Schema::Result::$_" => 1 } qw(
            DBAdmin::AppliedPatch
            Promotion::CustomerCustomerGroup
            Public::Channel
            Public::CorrespondenceTemplate
            Public::Country
            Public::CustomerIssueType
            Public::Operator
            Public::OrderAddress
            Public::Orders
            Public::PriceCountry
            Public::PriceDefault
            Public::PriceRegion
            Public::Product
            Public::ProductAttribute
            Public::ShipmentPrintLog
        )
    },
    DC3 => {
        map {; "XTracker::Schema::Result::$_" => 1 } qw(
            DBAdmin::AppliedPatch
            Promotion::CustomerCustomerGroup
            Public::Channel
            Public::CorrespondenceTemplate
            Public::Country
            Public::CustomerIssueType
            Public::Operator
            Public::OrderAddress
            Public::Orders
            Public::PriceCountry
            Public::PriceDefault
            Public::PriceRegion
            Public::Product
            Public::ProductAttribute
            Public::ShipmentPrintLog
            Public::Variant
        )
    },
}->{$distribution_centre}//{};

{
    local $TODO = "$distribution_centre schema is out of sync" if %{$out_of_sync};
    ok !@{XTracker::Schema->loader->generated_classes}, "All XTracker::Schema classes up to date";
}
for my $class (@{XTracker::Schema->loader->generated_classes}) {
    local $TODO = "$distribution_centre schema is out of sync" if $out_of_sync->{$class};
    fail "$class up to date";
}

done_testing;
