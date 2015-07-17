package XT::Warehouse;

use NAP::policy "tt", 'class';
use MooseX::Singleton;

use XTracker::Config::Local;

=head1 NAME

XT::Warehouse - A singleton class that abstracts warehouse-specific methods.

=head2 SYNOPSIS

    package MyApp;

    use XT::Warehouse;

    my $warehouse = XT::Warehouse->instance;

    my $has_iws   = $warehouse->has_iws;
    my $has_prl   = $warehouse->has_prls;
    my $has_ravni = $warehouse->has_ravni;

=cut

=head2 DESCRIPTION

Add a description when this class grows a bit more.

=head2 has_iws() : Bool

Whether this warehouse object has IWS.

=cut

# Look at making this a predicate and making this an iws attribute.
has 'has_iws' => (
    is => 'ro',
    isa => 'Bool',
    default => sub { !!XTracker::Config::Local::config_var(qw/IWS rollout_phase/); },
);

=head2 has_prl() : Bool

Whether this warehouse object has PRLs.

=head3 NOTE

=cut

# Look at making this a predicate and making this a prls attribute.
has 'has_prls' => (
    is => 'ro',
    isa => 'Bool',
    default => sub { !!XTracker::Config::Local::config_var(qw/PRL rollout_phase/); },
);

=head2 has_ravni() : Bool

Whether this warehouse object makes use of RAVNI.

=cut

has 'has_ravni' => (
    is => 'ro',
    isa => 'Bool',
    lazy => 1,
    builder => '_build_has_ravni',
);

sub _build_has_ravni {
    my $self = shift;
    return !($self->has_iws || $self->has_prls);
}
