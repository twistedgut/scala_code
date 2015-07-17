#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Department Tests

Just test various Department methods/function.

Currently testing:

* XTracker::Schema::Result::Public::Department->is_in_customer_care_group
* XTracker::Schema::ResultSet::Public::Department->customer_care_group
* XTracker::Database::Department::is_department_in_customer_care_group
* XTracker::Database::Department::customer_care_department_group

=cut


use Test::XTracker::Data;
use XTracker::Constants::FromDB     qw( :department );

use_ok( 'XTracker::Database::Department', qw(
                                        is_department_in_customer_care_group
                                        customer_care_department_group
                                    ) );
can_ok( 'XTracker::Database::Department', qw(
                                        is_department_in_customer_care_group
                                        customer_care_department_group
                                    ) );

# get a schema to query
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

note "Test Departments which ARE and ARE NOT in the Customer Care Group";

# test when called in scalar & array context the correct structure is returned
my $cc_depts    = customer_care_department_group();
my @cc_depts    = customer_care_department_group();
my $cc_dept_recs= $schema->resultset('Public::Department')->customer_care_group;
my @cc_dept_recs= $schema->resultset('Public::Department')->customer_care_group;

isa_ok( $cc_depts, 'ARRAY', "'customer_care_department_group' function in Scalar Context" );
isa_ok( $cc_dept_recs, 'ARRAY', "'customer_care_group' method in Scalar Context" );
cmp_ok( @cc_depts, '==', @{ $cc_depts }, "'customer_care_department_group' function in Array Context returns an Array" );
cmp_ok( @cc_dept_recs, '==', @{ $cc_dept_recs } , "'customer_care_group' method in Array Context returns an Array" );

# check the Departments that are Customer Care are the ones they should be
is_deeply( $cc_depts, [
                        sort { $a <=> $b } (
                            $DEPARTMENT__CUSTOMER_CARE,
                            $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                            $DEPARTMENT__PERSONAL_SHOPPING,
                            $DEPARTMENT__FASHION_ADVISOR,
                        )
                      ], "Departments in Customer Care Group are as Expected" );
is_deeply( [ map { $_->id } @cc_dept_recs ], $cc_depts,
                                        "Customer Care Group Departments from 'customer_care_group' method are as expected" );

my %departments             = map { $_->id => $_ } ( $schema->resultset('Public::Department')->all );
my @in_cust_care_group      = map { delete $departments{ $_ } } @cc_depts;
my @not_in_cust_care_group  = values %departments;

note "check those who are";
foreach my $department ( @in_cust_care_group ) {
    cmp_ok( is_department_in_customer_care_group( $department->id ), '==', 1,
                    "Using: 'is_department_in_customer_care_group' function, Department: '".$department->department."' IS in 'Customer Care' Group" );
    cmp_ok( $department->is_in_customer_care_group, '==', 1,
                    "Using: 'is_in_customer_care_group' method, Department: '".$department->department."' IS in 'Customer Care' Group" );
}

note "check those who are not";
foreach my $department ( @not_in_cust_care_group ) {
    cmp_ok( is_department_in_customer_care_group( $department->id ), '==', 0,
                    "Using: 'is_department_in_customer_care_group' function, Department: '".$department->department."' is NOT in 'Customer Care' Group" );
    cmp_ok( $department->is_in_customer_care_group, '==', 0,
                    "Using: 'is_in_customer_care_group' method, Department: '".$department->department."' is NOT in 'Customer Care' Group" );
}


done_testing;
