package Test::XT::Data;

use NAP::policy qw( class test );

with 'MooseX::Traits';

use Test::XTracker::Data;

=head1 NAME

Test::XT::Data

=head1 DESCRIPTION

This is the base Class which can be used in conjunction with 'Test::XT::Data::*' Roles
to create data for your tests. The difference between this and 'Test::XT::Flow' is that
it does NOT require the Test App. to be running in order to work. This Class is
extended by 'Test::XT::Flow' so you can use the same 'Test::XT::Data::*' roles when using
that Class as you can with this.

=head2 SYNOPSIS

In your test file:

    use Test::XT::Data;

    my $data    = Test::XT::Data->new_with_traits(
                                    traits  => [
                                            # then list the Roles you
                                            # wish to include, such as:
                                            Test::XT::Data::Channel,
                                            Test::XT::Data::Customer,
                                            Test::XT::Data::PreOrder,
                                            ...
                                        ],
                                );

    my $pre_order   = $data->pre_order;


=head1 ATTRIBUTES

=head2 schema

=head2 dbh

C<XTracker::Schema> and C<DBI::db objects>. These pull the singleton ones out of
C<Text::XTracker::Data> if you don't specify them.

=cut

with 'XTracker::Role::WithSchema';

=head1 METHODS

=head2 config_var

Rather than every trait needing to setup and import the C<config_var> function
itself, along with the modules it needs, this is a convenience method.

=cut

sub config_var {
    my $self = shift;
    return &XTracker::Config::Local::config_var; ## no critic(ProhibitAmpersandSigils)
}
