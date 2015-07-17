package XTracker::Schema::Role::ResultSet::FraudRule;
use NAP::policy "tt", 'role';
with 'XTracker::Role::WithXTLogger';

=head1 XTracker::Schema::Role::ResultSet::FraudRule

A Role for returning a ResultSet of Rules that can be used for the Fraud Rules Engine.

Currently a Role for:
    * ResultSet::Fraud::StagingRule
    * ResultSet::Fraud::LiveRule

=cut

use DateTime;
use Carp;


=head2 get_active_rules_for_channel

    $result_set = $self->get_active_rules_for_channel( $channel );
        or
    $result_set = $self->get_active_rules_for_channel( $channel, $date_rules_are_active );

This will Query the 'fraud.*_rule' tables (Live or Staging) and bring back a list of Enabled
Rules that are applicable to NOW taking into account the Start & End Dates of the Rules,
in Sequence Order and for the Sales Channel. Remember 'NULL' in a Start and/or End Date implies
from the beginning of or to the end of time respectively.

If you pass a 'DateTime' object it will bring back a list of Rules that are applicable
to that date.

=cut

sub get_active_rules_for_channel {
    my ( $self, $channel, $active_date )    = @_;

    if ( !$channel || ref( $channel ) !~ /::Public::Channel$/ ) {
        croak "Must pass a Channel Object as first Argument, for '" . __PACKAGE__ . "::get_active_rules_for_channel'";
    }

    if ( $active_date && ref( $active_date ) !~ /DateTime/ ) {
        croak "Second Argument should be a DateTime object if passes, for '" . __PACKAGE__ . "::get_active_rules_for_channel'";
    }

    # format the DateTime properly for the database, by getting a DateTime Formatter
    my $dtf     = $self->result_source->schema->storage->datetime_parser;
    my $date    = $dtf->format_datetime( $active_date // DateTime->now( time_zone => 'local' ) );

    return $self->search(
        {
            # get Rules for the Sales Channel and All Channels
            channel_id  => [ $channel->id, undef ],
            enabled     => 1,
            -and    => {
                -or => [
                    {
                        # Rules where both Start & End Dates are NULL
                        start_date  => undef,
                        end_date    => undef,
                    },
                    {
                        # Rules where $date is between Start & End Date
                        start_date  => { '<=' => $date },
                        end_date    => { '>=' => $date },
                    },
                    {
                        # Rules where Start Date is before or equal to Date
                        # and End Date is NULL
                        start_date  => { '<=' => $date },
                        end_date    => undef,
                    },
                    {
                        # Rules where Start Date is NULL and End Date is
                        # greater than or equal to $date
                        start_date  => undef,
                        end_date    => { '>=' => $date },
                    },
                ],
            },
        },
    )->by_sequence;
}

=head2 by_sequence

    $result_set = $self->by_sequence;

Return Resultset in 'rule_sequence' order

=cut

sub by_sequence {
    my $self    = shift;
    return $self->search( {}, { order_by => 'rule_sequence ASC' } );
}

=head2 process_rules_for_channel

    $deciding_rule_obj  = $self->process_rules_for_channel( $channel, {
        cache       => $cache,          # cache to store the output of the Methods for the Conditions
        object_list => [ ... ],         # list of objects that Methods can be called on
        outcome     => $outcome_obj,    # an instance of 'XT::FraudRules::Engine::Outcome' to
                                        # populate with the Results of the Rules processed
        # optional
        logger      => $log4perl_obj,   # a Log4perl object
        update_metrics => 1 or 0,       # will update the Metric Counters on the Rule Tables
    } );

Will process all Rules for the Sales Channel by calling 'get_active_rules_for_channel' and
return the First Rule that PASSES. If No Rules pass then 'undef' will be returned.

It will also populate the following Attributes on the 'outcome' object:

    * rules_processed_rs - A ResultSet of all the Rules processed upto and including the Rule that Passes.
    * textualisation     - A texutalised list of Rules and Conditions that were processed.

=cut

sub process_rules_for_channel {
    my ( $self, $channel, $args )   = @_;

    my $cache       = $args->{cache};
    my $object_list = $args->{object_list};
    my $outcome     = $args->{outcome};
    my $logger      = $args->{logger};
    my $update_metrics = $args->{update_metrics} // 0;

    my $method_name = __PACKAGE__ . "::process_rule";
    croak "No 'channel' passed in Arguments to '${method_name}'"
                                    if ( !$channel );
    croak "No 'cache' passed in Arguments to '${method_name}'"
                                    if ( !$cache );
    croak "No 'object_list' or Not an Array Ref passed in Arguments to '${method_name}'"
                                    if ( !$object_list || ref( $object_list ) ne 'ARRAY' );
    croak "No 'outcome' Object passed in Arguments to '${method_name}'"
                                    if ( !$outcome || ref( $outcome ) !~ /::Outcome/ );

    # explictly set the logger if one has been passed
    $self->set_xtlogger( $logger )  if ( $logger );

    # get all the Rules to process
    my @rules   = $self->get_active_rules_for_channel( $channel )->all;

    # the first Rule that Passes
    my $deciding_rule;

    # a list of all the Rule Ids processed
    my @rule_ids;

    $self->xtlogger->debug( "Processing Rules for Channel: " . $channel->name );

    RULE:
    foreach my $rule ( @rules ) {
        push @rule_ids, $rule->id;

        my $passed  = $rule->process_rule( {
            cache       => $cache,
            object_list => $object_list,
            outcome     => $outcome,
            update_metrics => $update_metrics,
        } );

        if ( $passed ) {
            $deciding_rule  = $rule;

            $self->xtlogger->debug( "Rule: '" . $rule->name . "' was the Deciding Rule" );
            last RULE;
        }
    }

    # store on the Outcome a ResultSet of the Rule Ids processed
    $outcome->set_rules_processed( \@rule_ids );

    return $deciding_rule;
}

1;
