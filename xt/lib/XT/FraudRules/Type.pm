package XT::FraudRules::Type;
use NAP::policy "tt";

use Moose::Util::TypeConstraints;

use MooseX::Types::Moose qw(
    Int
    Str
    Undef
    ArrayRef
    Maybe
    HashRef
);
use MooseX::Types::Structured qw(
    Dict
    Optional
);

use DateTime;

=head1 SUB-TYPES

Sub-Types for the 'XT::FraudRules' namespace.

=head2 XT::FraudRules::Type::RuleSet

enumeration of:
    live
    staging

=cut

enum( 'XT::FraudRules::Type::RuleSet', [ qw(
    live
    staging
) ] );

=head2 XT::FraudRules::Type::Mode

enumeration of:
    live
    test
    parallel

=cut

enum( 'XT::FraudRules::Type::Mode', [ qw(
    live
    test
    parallel
) ] );

=head2 XT::FraudRules::Type::JQMode

Modes available to the Job Queue worker.

Initially only allow 'parallel' but later we might be-able to add 'live'

enumeration of:
    parallel

=cut

enum( 'XT::FraudRules::Type::JQMode', [ qw(
    parallel
) ] );

=head2 XT::FraudRules::Type::Result::Rule

Either 'Result::Fraud::[Staging|Live]Rule'.

=cut

union( 'XT::FraudRules::Type::Result::Rule', [
    class_type( 'XTracker::Schema::Result::Fraud::StagingRule'  ),
    class_type( 'XTracker::Schema::Result::Fraud::LiveRule'     ),
] );

=head2 XT::FraudRules::Type::ResultSet::Rule

Either 'ResultSet::Fraud::[Staging|Live]Rule'.

=cut

union( 'XT::FraudRules::Type::ResultSet::Rule', [
    class_type( 'XTracker::Schema::ResultSet::Fraud::StagingRule'  ),
    class_type( 'XTracker::Schema::ResultSet::Fraud::LiveRule'     ),
    class_type( 'DBIx::Class::ResultSet'                           ),
] );

=head1 AJAX SUB-TYPES

This is all the data types required for the AJAX payload from the UI.

=head2 XT::FraudRules::Type::AJAX::DateTime

A DateTime object that will coerce from any string that
L<DateTime::Format::ISO8601> will recognise.

=cut

subtype 'XT::FraudRules::Type::AJAX::DateTime',
    as 'DateTime';

coerce 'XT::FraudRules::Type::AJAX::DateTime',
    from 'Str',
    via { DateTime::Format::ISO8601->parse_datetime( $_ ) };

=head2 XT::FraudRules::Type::AJAX::Action

Must be one of the following:
    save
    push_to_live
    pull_from_live

=cut

enum( 'XT::FraudRules::Type::AJAX::Action', [ qw(
    save
    push_to_live
    pull_from_live
) ] );

=head2 XT::FraudRules::Type::AJAX::RuleSet::Condition

A valid condition.

=cut

subtype 'XT::FraudRules::Type::AJAX::RuleSet::Condition',
    as Dict[
        condition_id  => Maybe[Int],
        method_id     => Int,
        operator_id   => Int,
        value         => Str,
        enabled       => class_type('JSON::XS::Boolean'),
        deleted       => class_type('JSON::XS::Boolean'),
        _source       => 'Any',
    ];

=head2 XT::FraudRules::Type::AJAX::Rule

A valid Rule (containing a list of valid
L<XT::FraudRules::Type::AJAX::RuleSet::Condition>s).

=cut

subtype 'XT::FraudRules::Type::AJAX::Rule',
    as Dict[
        rule_id     => Maybe[Int],
        name        => Str,
        sequence    => Int,
        channel_id  => Maybe[Int],
        status_id   => Int,
        action_id   => Maybe[Int],
        enabled     => class_type('JSON::XS::Boolean'),
        deleted     => class_type('JSON::XS::Boolean'),
        start_date  => Maybe['XT::FraudRules::Type::AJAX::DateTime'],
        end_date    => Maybe['XT::FraudRules::Type::AJAX::DateTime'],
        tags        => Maybe[ArrayRef[Str]],
        conditions  => Maybe[ArrayRef['XT::FraudRules::Type::AJAX::RuleSet::Condition']],
        _source     => 'Any',
    ];

=head2 XT::FraudRules::Type::AJAX::RuleSet

A complete Rule Set containing an ArrayRef of C<XT::FraudRules::Type::AJAX::Rule>.

=cut

subtype 'XT::FraudRules::Type::AJAX::RuleSet',
    as ArrayRef['XT::FraudRules::Type::AJAX::Rule'];

1;
