package XT::FraudRules::Engine::Outcome;

use NAP::policy "tt",     'class';
with 'XTracker::Role::WithXTLogger';

=head1 NAME

XT::FraudRules::Engine::Outcome

=head1 DESCRIPTION

    use XT::FraudRules::Engine::Outcome;

    $outcome = XT::FraudRules::Engine::Outcome->new( {
        schema          => $schema,
        rule_set_used   => 'live' or 'staging',
        # optional
        logger          => $log4perl_obj,
    } );

This will store the result from running the Fraud Rules Engine, it will hold the
outcome from both Applying the Finance Flags and from running the Rules.

=cut

use Moose::Util::TypeConstraints;

use Clone       qw( clone );
use JSON;

use XT::FraudRules::Type;

use XT::JQ::DC;


=head1 ATTRIBUTES

=head2 schema

DBIC Schema Object.

=cut

has schema => (
    is      => 'ro',
    isa     => 'XTracker::Schema',
    required => 1,
);

=head2 rule_set_used

Either 'live' or 'staging' to indicate which Rule Set was used.

=cut

has rule_set_used => (
    is      => 'ro',
    isa     => 'XT::FraudRules::Type::RuleSet',
    required => 1,
);

=head2 flags_assigned_rs

Resultset containing a list of all the Finance Flags applied to the Order.

=cut

has flags_assigned_rs => (
    is      => 'rw',
    isa     => 'XTracker::Schema::ResultSet::Public::Flag',
);

=head2 rules_processed_rs

Resultset containing a list of all the Rules that were processed upto and
including the 'Decisioning' Rule.

=cut

has rules_processed_rs => (
    is      => 'rw',
    # can be any of the 'fraud.*_rule' table's ResultSets
    isa     => 'XT::FraudRules::Type::ResultSet::Rule',
    init_arg => undef,
);

=head2 decisioning_rule

The Rule that 'PASSED', if none of the Rules passed then this will be 'undef'
meaning that 'action_order_status' will contain the default Action.

=cut

has decisioning_rule => (
    is      => 'rw',
    # can be any of the 'fraud.*_rule' tables
    isa     => 'XT::FraudRules::Type::Result::Rule|Undef',
    init_arg => undef,
);

=head2 textualisation

This will hold the Textualistion of the Rules and Conditions that were processed.
It is an ArrayRef containing the Rules and their Conditions that were processed in
Rule Sequence order.

    [
        {
            id  => $record_id_of_rule,      # this 'id' will be the 'archived_rule_id' when 'live' Rule Sets are used
            textualisation => 'Rule Description',
            passed => 1 or 0,
            conditions => [
                {
                    id => $record_id_of_condition,
                    textualisation  => 'Condition Description',
                    passed => 1 or 0,
                },
                ...
            ],
        },
        ...
    ]

=cut

has textualisation => (
    is      => 'rw',
    isa     => 'ArrayRef[HashRef]',
    default => sub { return []; },
    traits  => ['Array'],
    handles => {
        all_textualisation_rules    => 'elements',
    },
);

=head2 archived_rule_ids_used

This returns an Array of all the Archived Rule Ids that have been
used by using the 'textualisation' Attribute and taking the Rule Ids
that have been stored there. Only when the 'live' Rule Set has been
used will this Attribute contain anything.

=cut

has archived_rule_ids_used => (
    is      => 'ro',
    isa     => 'ArrayRef|Undef',
    init_arg=> undef,
    lazy_build => 1,
);

sub _build_archived_rule_ids_used {
    my $self = shift;

    # if not Live then return nothing
    return  if ( $self->rule_set_used ne 'live' );

    my @ids;
    # go through all of the 'textualisation' and just
    # use the Id which when using 'live' Rule Sets will
    # be the 'archived_rule_id' on the 'live_rule' record
    @ids = map {
        $_->{id}
    } $self->all_textualisation_rules;

    return \@ids;
}

=head2 action_order_status

The 'Public::OrderStatus' object that was the result of the Decisining Rule that passed.
If the there was no Decisioning Rule then this will hold the Default action.

=cut

has action_order_status => (
    is      => 'rw',
    isa     => 'XTracker::Schema::Result::Public::OrderStatus',
    init_arg => undef,
);

=head2 has_default_action_been_used

Will be TRUE if none of the Rules PASSED and the 'order_action_status' is the Default.

=cut

has has_default_action_been_used => (
    is      => 'ro',
    isa     => 'Bool',
    init_arg => undef,
    lazy_build => 1,
);

sub _build_has_default_action_been_used {
    my $self    = shift;
    return ( defined $self->decisioning_rule ? 0 : 1 );
}

=head2 fraud_rule_metric_jobq_worker

This contains the Job Queue worker that will be sent a Job
to Increase the Fraud Rule Metrics.

=cut

has fraud_rule_metric_jobq_worker => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Receive::Fraud::UpdateFraudRuleMetrics',
);


# change the BUILD sub to handle a logger
sub BUILD {
    my ( $self, $args ) = @_;

    if ( my $logger = delete $args->{logger} ) {
        $self->set_xtlogger( $logger );
    }

    return $self;
}

=head1 METHODS

=head2 set_flags_assigned

    $self->set_flags_assigned( [ Flag Ids ] );

Use this to build the ResultSet of Flags assigned to the Order.

Access the Result Set by using '$self->flags_assigned_rs'

=cut

sub set_flags_assigned {
    my ( $self, $flag_ids ) = @_;

    my $rs  = $self->schema->resultset('Public::Flag')->search( {
        id  => { 'IN' => $flag_ids // [ -1 ] },     # no Flags then give an Empty Result Set
    } );

    # set the 'flags_assigned_rs' attribute
    $self->flags_assigned_rs( scalar $rs );

    return;
}

=head2 set_rules_processed

    $self->set_rules_processed( [ Rule Ids ] );

Use this to build the ResultSet of Rules that were processed.

Access the Result Set by using '$self->rules_processed_rs'

=cut

sub set_rules_processed {
    my ( $self, $rule_ids ) = @_;

    my $class   = 'Fraud::' . ucfirst( $self->rule_set_used ) . 'Rule';
    my $rs      = $self->schema->resultset( $class )->search( {
        id  => { 'IN' => $rule_ids // [ -1 ] },     # no Ids then give an Empty Result Set
    } )->by_sequence;

    # set the 'rules_processed_rs' attribute
    $self->rules_processed_rs( scalar $rs );

    return;
}

=head2 add_textualisation_rule

    $self->add_textualistion_rule( $rule_object );

Adds to the 'textualisation' array attribute the Rule Id of the Rule and calls
the 'textualise' method to get the text for the Rule.

=cut

sub add_textualisation_rule {
    my ( $self, $rule ) = @_;

    push @{ $self->textualisation }, {
        id              => $rule->id_for_textualisation,
        textualisation  => $rule->textualise,
    };

    return;
}

=head2 update_textualisation_rule_passed

    $self->update_textualisation_rule_passed( $rule_object, TRUE or FALSE );

Updates a Rule in the 'textualistion' Array to say whether it has Passed or Failed.

=cut

sub update_textualisation_rule_passed {
    my ( $self, $rule, $passed )    = @_;

    # find the Rule in the Array
    my $element = $self->_find_textualistion_rule( $rule->id_for_textualisation );
    $element->{passed}  = $passed;

    return;
}

=head2 add_textualisation_condition

    $self->add_textualisation_condition( $rule_object, $condition_object );

Adds to the Rule's 'textualisation' element in the array a Condition where it
will store the Conditions Id and call its 'textualise' method.

=cut

sub add_textualisation_condition {
    my ( $self, $rule, $condition ) = @_;

    my $element = $self->_find_textualistion_rule( $rule->id_for_textualisation );
    push @{ $element->{conditions} }, {
        id              => $condition->id,
        textualisation  => $condition->textualise,
    };

    return;
}

=head2 update_textualisation_condition_passed

    $self->update_textualisation_condition_passed( $rule_object, $condition_object, TRUE or FALSE );

Updates a Condition for a Rule in the 'textualistion' Array to say whether it has Passed or Failed.

=cut

sub update_textualisation_condition_passed {
    my ( $self, $rule, $condition, $passed )    = @_;

    # find the Rule in the Array
    my $element = $self->_find_textualistion_rule( $rule->id_for_textualisation );

    # find the Condition in the 'conditions' array
    my ( $cond_element ) = grep { $_->{id} == $condition->id } @{ $element->{conditions} };
    $cond_element->{passed} = $passed;

    return;
}

=head2 flags_assigned_to_string

    $string = $self->flags_assigned_to_string;

Converts the list of Flags assigned to a comma seperated list of Flag Ids.

=cut

sub flags_assigned_to_string {
    my $self    = shift;

    my @flag_ids    = sort { $a <=> $b } map { $_->id } $self->flags_assigned_rs->all;

    return ''       if ( !@flag_ids );
    return join( ',', @flag_ids );
}

=head2 textualisation_to_json

    $json_string = $self->textualisation_to_json;

Will return a JSON string representation of the 'textualisation' attribute.

=cut

sub textualisation_to_json {
    my $self    = shift;

    # clone 'textualisation' and remove all
    # IDs from the 'conditions' part as they
    # aren't useful outside of this module
    my $clone   = clone( $self->textualisation );
    foreach my $rule ( @{ $clone } ) {
        delete $_->{id}     foreach ( @{ $rule->{conditions} } );
    }

    my $json    = JSON->new();
    return $json->encode( $clone );
}

=head2 send_update_metrics_job

    $job_id = $self->send_update_metrics_job( 'string to tag the job' );

This will Create and Send the Job to The Schwartz Job Queue
that increases the Metrics for the Fraud Rules that have been
used.

This will only send the job if The Rule Set used was 'live' and
the 'archived_rule_ids_used' Attribute has at least one Id.

Will return the Job Id for the Job if one was sent else will
return 'undef'.

Pass a String to identify (tag) the Job when it's in the Job Queue
so it's not just a list of Ids, most likely just pass the Order Nr.

=cut

sub send_update_metrics_job {
    my ( $self, $tag ) = @_;

    # not using Live Rule Set then don't sent Job
    return      if ( $self->rule_set_used ne 'live' );

    # no Ids then don't send Job
    my $ids = $self->archived_rule_ids_used // [];
    return      if ( scalar( @{ $ids } ) <= 0 );

    # set-up the Job Payload
    my $job_payload = {
        job_tag => $tag // '',
        decisioning_archived_rule_id => (
            defined $self->decisioning_rule
            ? $self->decisioning_rule->archived_rule_id
            : undef
        ),
        archived_rule_ids_used => $ids,
    };

    my $job_rq = XT::JQ::DC->new( {
        funcname => $self->fraud_rule_metric_jobq_worker,
    } );
    $job_rq->set_payload( $job_payload );

    if ( my $job = $job_rq->send_job() ) {
        return $job->jobid;
    }
    return;
}


# finds the element in the 'textualistion' Array for a Rule Id
sub _find_textualistion_rule {
    my ( $self, $rule_id )  = @_;

    my ( $element ) = grep { $_->{id} == $rule_id } $self->all_textualisation_rules;
    return $element;
}

