package XT::FraudRules::DryRun::Result;
use NAP::policy "tt", 'class';

=head1 NAME

XT::FraudRules::DryRun::Result

=head1 DESCRIPTION

This object is created by C<XT::FraudRules::DryRun>
when testing orders.

It contains the results of running an order against
a rule set.

=head1 SYNOPSIS

    my $result = XT::FraudRules::DryRun::Result->new(
        order          => $order,
        engine_outcome => $engine->outcome,
    );

=cut

use Moose::Util::TypeConstraints;

=head1 ATTRIBUTES

=head2 order

The C<Public::Orders> object.

=cut

has 'order' => (
    is       => 'ro',
    isa      => class_type( 'XTracker::Schema::Result::Public::Orders' ),
    required => 1,
);

=head2 engine_outcome

Stores the  XT::FraudRules::Engine::Outcome object
returned by the Engine.

=cut

has 'engine_outcome' => (
    is       => 'ro',
    isa      => 'XT::FraudRules::Engine::Outcome',
    required => 1,
);

1;

