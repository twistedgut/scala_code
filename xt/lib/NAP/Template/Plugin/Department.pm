package NAP::Template::Plugin::Department;
use strict;
use warnings;
use XTracker::Database::Department();   # don't export anything you polluting *******!

use base qw{ Template::Plugin };

our $VERSION = '0.01_01';

sub new {
    my ($class, $context, @args) = @_;
    my $new_obj = bless {}, $class;

    return $new_obj;
}


sub in_department_group {
    # shift off the params that are needed so any extra can be passed
    # straight through to the function that is actually called via '@_'
    my $self    = shift;
    my $group   = shift;
    my $dept_id = shift;

    my $retval  = 0;

    CASE: {
        if ( $group eq 'Customer Care' ) {
            $retval = XTracker::Database::Department::is_department_in_customer_care_group( $dept_id, @_ );
            last CASE;
        }
    };

    return $retval;
}

1;
__END__

=pod

=head1 NAME

NAP::Template::Plugin::Department - v. simple plugin to wrap XTracker::Database::Department

This will allow you to use the functions in 'XTracker::Database::Department' in particular:

=head1 SYNOPSIS

Make sure that the plugin namespace is specified in XTemplate.pm:

  Template->new(
    # ...
    PLUGIN_BASE => 'NAP::Template::Plugin',
  );

Then use the plugin in your TT templates:

  [% USE Department %]

=head1 Functions

=head2 in_department_group

    $boolean    = in_department_group( 'Customer Care', $department_id );

Allows you to return TRUE or FALSE if a Department Id is in a particualr group of Departments.

Currently only 'Customer Care' Group has been created.

=cut

=head1 AUTHOR

Andrew Beech C<< andrew.beech@net-a-porter.com> >>

=cut
