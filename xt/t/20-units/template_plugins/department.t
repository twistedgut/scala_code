#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 NAP::Template::Plugin::Department - Tests

Just testing the 'NAP::Template::Plugin::Department' Class used by the Template::Toolkit

=cut


use Test::XTracker::Data;

use XTracker::Constants::FromDB     qw( :department );
use XTracker::Database::Department  qw( customer_care_department_group );

use_ok( 'NAP::Template::Plugin::Department', qw(
                                        in_department_group
                                    ) );
can_ok( 'NAP::Template::Plugin::Department', qw(
                                        in_department_group
                                    ) );

# get a list of Customer Care Departments
my @cc_depts    = customer_care_department_group();

my $plugin  = NAP::Template::Plugin::Department->new();
isa_ok( $plugin, 'NAP::Template::Plugin::Department', "Created a new instance" );
cmp_ok( $plugin->in_department_group( 'Customer Care', $cc_depts[0] ), '==', 1,
                                                    "'in_department_group' method returned TRUE when passed a Customer Care Department" );
cmp_ok( $plugin->in_department_group( 'Customer Care', 0 ), '==', 0,
                                                    "'in_department_group' method returned FALSE when passed a non Customer Care Department" );
cmp_ok( $plugin->in_department_group( 'No Such Group', $cc_depts[0] ), '==', 0,
                                                    "'in_department_group' method returned FALSE when using an unknown Department Group" );


done_testing;
