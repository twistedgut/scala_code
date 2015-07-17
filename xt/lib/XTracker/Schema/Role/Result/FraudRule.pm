package XTracker::Schema::Role::Result::FraudRule;
use NAP::policy "tt", 'role';
with 'XTracker::Role::WithXTLogger';

=head1 XTracker::Schema::Role::Result::FraudRule

Currently a Role for:
    * Result::Fraud::StagingRule
    * Result::Fraud::LiveRule

=cut

use Carp;


=head2 id_for_textualisation

    $integer = $self->id_for_textualisation;

Id to use for Textualisation.

=cut

sub id_for_textualisation {
    my $self    = shift;

    # if its a Live Rule use the Archive Rule Id
    return (
        $self->can('archived_rule_id')
        ? $self->archived_rule_id
        : $self->id
    );
}

=head2 textualise

    $string = $self->textualise;

Turns into English the Rule. Currently just uses the 'name'
but could be extended in the future.

=cut

sub textualise {
    my $self    = shift;

    # use this method instead of just using 'name' now
    # so that if this gets extended to do more in the future
    # everything will already be set-up to call it

    return $self->name;
}

=head2 conditions

    $condition_result_set   = $self->conditions;

Returns a Result Set of Conditions appropriate to the Class of the Rule.
This gives back the appropriate '*_conditions' relationship for the Class
this method is called on.

=cut

sub conditions {
    my $self    = shift;

    # go through all Relationships looking for a '*_conditions' one
    my ( $link )    = grep { m/\w+_conditions$/ } $self->result_source->relationships;

    if ( !$link ) {
        croak "Couldn't find a Relationship between '" . ref( $self ) . "' and its Conditions, for '" . __PACKAGE__ . "::conditions'";
    }

    return $self->$link;
}

=head2 process_rule

    $boolean = $self->process_rule( {
        cache       => $cache,          # cache to store the output of Methods
        object_list => [ ... ],         # list of objects that Methods can be called on
        outcome     => $outcome_obj,    # an instance of 'XT::FraudRules::Engine::Outcome' to
                                        # populate with the Results of the Conditions processed
        # optional
        update_metrics => 1 or 0,       # will update the Metric Counters on the Rule Table
    } );

This will Evaluate all the Conditions in the Rule and return TRUE or FALSE to
indicate that the Rule Passed or Failed, base on ALL the Conditions Passing or not.

=cut

sub process_rule {
    my ( $self, $args ) = @_;

    my $cache       = $args->{cache};
    my $object_list = $args->{object_list};
    my $outcome     = $args->{outcome};
    my $update_metrics = $args->{update_metrics} // 0;

    my $method_name = __PACKAGE__ . "::process_rule";
    croak "No 'cache' passed in Arguments to '${method_name}'"
                                    if ( !$cache );
    croak "No 'object_list' or Not an Array Ref passed in Arguments to '${method_name}'"
                                    if ( !$object_list || ref( $object_list ) ne 'ARRAY' );
    croak "No 'outcome' Object passed in Arguments to '${method_name}'"
                                    if ( !$outcome || ref( $outcome ) !~ /::Outcome/ );

    # add the Rule to the Textualisation Outcome
    $outcome->add_textualisation_rule( $self );

    # get all the conditions to process
    my @conditions  = $self->conditions->enabled->by_processing_cost->all;

    $self->xtlogger->debug( "Processing Rule: '" . $self->name . "'" );

    # go through and evaluate each Condition,
    # stop when the first one FAILS
    my $passed_count    = 0;
    CONDITION:
    foreach my $condition ( @conditions ) {
        # add the Condition to the Rule's Textualisation
        $outcome->add_textualisation_condition( $self, $condition );

        # evaluate the Condition
        my $result  = $condition->evaluate( $object_list, $cache );

        # update the Condition's 'passed' flag in the Rule's Textualisation
        $outcome->update_textualisation_condition_passed( $self, $condition, $result->has_passed );

        # stop processing any more Conditions as soon as one hasn't Passed
        last CONDITION      if ( !$result->has_passed );

        $self->xtlogger->debug( "Condition Id: '" . $condition->id . "' - PASSED" );

        $passed_count++;
    }

    my $rule_result = 0;
    # the Rule must have at least One Condition to 'Pass' and
    # if ALL the Conditions have 'Passed' then so has the Rule
    $rule_result    = 1     if ( $passed_count && $passed_count == scalar @conditions );

    $self->xtlogger->debug( "Rule: '" . $self->name . "' - " . ( $rule_result ? 'PASSED' : 'FAILED' ) );

    # update the Rule's Textualisation 'passed' flag
    $outcome->update_textualisation_rule_passed( $self, $rule_result );

    # update the Rule's Metrics if required
    $self->increment_metric( $rule_result )         if ( $update_metrics );

    return $rule_result;
}

=head2 increment_metric

    $self->increment_metric;        # will increment 'metric_used' counter
            or
    $self->increment_metric( 1 );   # will increment both 'metric_used' & 'metric_decided' counters

This will increment the Metric Counters on the record. To increment
the 'metric_decided' counter as well pass in a TRUE value as the
only parameter.

This will NOT increment any Counters for 'fraud.archived_rule' records.

=cut

sub increment_metric {
    my ( $self, $is_decider )   = @_;

    # don't increment counters for Archived Rules and only
    # those records should have a 'change_log_id' field
    return      if ( $self->can('change_log_id') );

    # set-up the fields to be updated
    my $upd_args = {
        metric_used => \"metric_used + 1",
        (
            $is_decider
            ? ( metric_decided => \"metric_decided + 1" )
            : ()
        ),
    };

    $self->update( $upd_args );

    return;
}


1;
