package XT::FraudRules::Actions::Staging;

use NAP::policy 'class';

=head1 NAME

XT::FraudRules::Actions::Staging

=head1 DESCRIPTION

Handles all the validation and data manipulation of the staging area of Fraud
Rules, this includes moving rulesets to/fom live.

=head2 SYNOPSIS

    my $staging = XT::FraudRules::Actions::Staging->new( {
        schema  => $handler->{param_of}{schema},
        action  => $handler->{param_of}{action},
    } );

    $staging->ruleset( $handler->{param_of}{ruleset} )
        if $handler->{param_of}{ruleset};

    $staging->ruleset( $handler->{param_of}{force_commit} )
        if $handler->{param_of}{force_commit};

    my $result = $staging->process;

=cut

use JSON;
use Data::Dumper;
use XTracker::Logfile  qw( xt_logger );
use XT::FraudRules::Type;
use DateTime;
use XTracker::Constants::FromDB qw(
    :fraud_rule_status
    :order_status
);

use XTracker::EmailFunctions    qw( send_internal_email );
use XTracker::Config::Local;

=head1 ATTRIBUTES

=head2 schema

Required: Yes

Must be an XTracker::Schema Object.

=cut

has 'schema' => (
    is       => 'ro',
    isa      => 'XTracker::Schema',
    required => 1,
);

=head2 ruleset

Required: No
Type:     XT::FraudRules::Type::AJAX::RuleSet

A data structure containing Rules and Conditions.

See C<XT::FraudRules::Type::AJAX::RuleSet> in L<XT::FraudRules::Type>
for details.

NOTE: This must not be provided with C<ruleset_json>

=cut

has 'ruleset' => (
    is       => 'rw',
    isa      => 'Maybe[XT::FraudRules::Type::AJAX::RuleSet]',
    required => 0,
);

=head2 ruleset_json

Required: No
Type:     JSON String

If this is provided, the C<ruleset> attribute will automatically be
created from the decoded JSON.

NOTE: This must not be provided with C<ruleset>.

=cut

around BUILDARGS => sub {
    my ( $orig, $class, $args ) = @_;

    if ( exists $args->{ruleset_json} ) {
    # If the stringified version of the rulset was provided, decode it and convert it
    # to a ruleset.
        # Make sure we only hav one of ruleset_json and ruleset.
        die "ruleset_json and ruleset must not be provided together to ${class}->new"
            if exists $args->{ruleset};

        # Delete the key so it's not used by the constructor.
        # TODO: This needs to be a copy of ruleset_json not a reference, otherwise
        # we're messing around with all the original references that where passed in.
        my $ruleset_json = $args->{ruleset_json}
            ? delete $args->{ruleset_json}
            : [];

        # Start with an empty ruleset.
        my @ruleset = ();

        # Iterate over the decoded JSON string.
        foreach my $rule (@$ruleset_json ) {

            # If the rule has been deleted, we need to unset keys that Moose
            # could fail validation on, as we don't care about data that's
            # being deleted.
            # NOTE: Adding zero to force it to be evaluted in numeric context.
            if ( $rule->{deleted} + 0 ) {

                $rule->{channel}{id}   = undef;
                $rule->{action}{id}    = undef;
                $rule->{start}{date}   = undef;
                $rule->{start}{hour}   = undef;
                $rule->{start}{minute} = undef;
                $rule->{end}{date}     = undef;
                $rule->{end}{hour}     = undef;
                $rule->{end}{minute}   = undef;

            }

            my @source_conditions = ( exists $rule->{conditions}  && $rule->{conditions} )
                ?  @{ delete $rule->{conditions} }
                : ();
            my @conditions =  map {  {
                condition_id => $_->{id}|| undef,
                method_id    => $_->{method}{id},
                operator_id  => $_->{operator}{id},
                value        => $_->{value}{id},
                enabled      => $_->{enabled},
                deleted      => $_->{deleted},
                _source      => $_,
            } } @source_conditions;

            my $end_date = undef;
            my $start_date = undef;
            if( defined $rule->{end} ) {
                if( defined $rule->{end}{date} && $rule->{end}{date} ne '' ) {
                    # Concatenate the date/time parts into a string for type coercion.
                    $end_date = _format_date( $rule->{end}{date}, $rule->{end}{hour}, $rule->{end}{minute} );
                }
            }

            if( defined $rule->{start} ) {
                if( defined $rule->{start}{date} && $rule->{start}{date} ne '' ) {
                    # Concatenate the date/time parts into a string for type coercion.
                    $start_date = _format_date( $rule->{start}{date}, $rule->{start}{hour}, $rule->{start}{minute});
                }
            }


            push @ruleset, {
                rule_id    => $rule->{id} || undef ,
                name       => $rule->{name},
                sequence   => $rule->{sequence},
                channel_id => $rule->{channel}{id} ||undef,
                status_id  => $rule->{status} ||undef,
                action_id  => $rule->{action}{id},
                start_date => $start_date,
                end_date   => $end_date,
                enabled    => $rule->{enabled},
                deleted    => $rule->{deleted},
                tags       => $rule->{tags},
                conditions => @conditions ? \@conditions: undef,
                _source    => $rule,
            };

        }

        # Set the attribute so it can be validated by the contructor.
        $args->{ruleset} = @ruleset ? \@ruleset : undef;
    }

    return $class->$orig( $args );

};

=head2 unknown_action

    Decides what to do with an unknown action.

=cut

sub unknown_action {
    my ( $self, $action ) = @_;

    return _generate_error( "Action not '$action' supported'" );

}

=head2 validate_and_save

This method validates the payload and if it passes validation, it saves staging rules and conditions.
If Validation fails it injects error in the payload and send it back.

=cut

sub validate_and_save {
    my ( $self, $force_commit ) = @_;

    my $schema  = $self->schema;
    my $output  = {};
    my $rule_rs;

    if( $self->ruleset) {

        my $payload =  $self->ruleset;

        # Return if payload is empty.
        return _generate_error("No data to save. Please add rules to Save ",{
            error_count => 1,
        }) if ( scalar( @$payload ) < 1 );

        my $validation_result = $self->validate( $force_commit );

        # Return payload with errors injected if validation fails.
        if( ! $validation_result->{ok} ) {
            xt_logger->error( "Validation Failure : ". Dumper($validation_result) );
            return $validation_result;

        }

        return try {
            # Save data to staging.
            _save_to_staging($schema, $self->ruleset);

            # Return success message.
            return _generate_ok({
                ruleset => $self->ruleset,
            });

        }
        catch {

            xt_logger->warn($_);
            #TODO  :remove $_ , it is only for debugging
            return _generate_error("Error while saving to staging : $_ ",{
                ruleset => $payload,
                error_count => 1,
            });
        }

    } else {
        return _generate_error("Error in Saving: Nothing to Save",{
            ruleset => [],
            error_count => 1,
        });
    }
}

=head2 _save_to_staging

    Populates fraud.staging_rules and fraud.staging_condition table with data.

=cut

sub _save_to_staging {
    my $schema  = shift;
    my $payload = shift;

    # Return if nothing is provided.
    return if(scalar(@$payload) < 1);

    my $staging_rules_rs = $schema->resultset('Fraud::StagingRule');
    my $condition_rs  = $schema->resultset("Fraud::StagingCondition");

    # Delete all rules and conditions.
    $condition_rs->delete_all;
    $staging_rules_rs->delete_all;

    # Create rules with conditions.
    RULE:
    for my $rule ( @$payload) {

        # If deleted flag is set then move to next one.
        next RULE if ( ($rule->{deleted} + 0) );

        if ( exists $rule->{end_date} && $rule->{end_date} ) {
            if ( $rule->{end_date}->minute == 59 ) {
                $rule->{end_date}->set(second => 59);
            }
        }

        my $staging_rule    = $staging_rules_rs->create({
            channel_id              => $rule->{channel_id},
            rule_sequence           => $rule->{sequence},
            name                    => $rule->{name},
            start_date              => $rule->{start_date},
            end_date                => $rule->{end_date},
            rule_status_id          => $rule->{status_id},
            enabled                 => ( $rule->{enabled} + 0 ),
            action_order_status_id  => $rule->{action_id},
            tag_list                => $rule->{tags},
        });

        CONDITION:
        foreach my $condition ( @{ $rule->{conditions} } ) {
            next CONDITION if( $condition->{deleted} + 0);
            $staging_rule->create_related('staging_conditions',{
                method_id               => $condition->{method_id},
                conditional_operator_id => $condition->{operator_id},
                value                   => $condition->{value},
                enabled                 =>($condition->{enabled} + 0 ),
            });
        }
    }

    return;
}

=head2 _generate_error

    Prepares the Error hash

=cut

sub _generate_error {
    my ($error, $data) = @_;

    $data = {} unless ($data);

    if( $data ) {
        $data = prepare_data_for_output( $data );
    }

    my $output = {
        %{$data},
        ok     => 0,
        error_msg => $error,
    };
    return $output;
}

=head2 _generate_ok

    Prepares the Success hash

=cut

sub _generate_ok {
    my ($data) = @_;

    $data = {} unless ($data);

    if( $data ) {
        $data =  prepare_data_for_output( $data );
    }

    return {
        %{$data},
        ok     => 1,
    }
}

=head2 prepare_data_for_output

    Transforms $self->{resultset} to the original payload sent by UI

=cut

sub prepare_data_for_output {
    my $data = shift;
    my $newdataset = [];

    return unless ($data);

    # If data is not hash.
    return $data unless (ref($data) eq 'HASH');

    if( exists $data->{ruleset} && $data->{ruleset}) {
        my $ruleset = $data->{ruleset};
        # Return if empty.
        return $data if ( scalar(@$ruleset < 1));

        foreach my $rule (@$ruleset) {

            # delete conditions out of the hash
            my @conditions = exists( $rule->{conditions} ) && $rule->{conditions}
                ?  @{ delete $rule->{conditions} }
                : ();

            # formulate condition hash
            my @new_conddataset;
            foreach my $cond ( @conditions ) {
                if($cond->{_source} ) {
                    push(@new_conddataset, {
                        %{$cond->{_source}},
                        ok      => $cond->{ok}//1,
                        error_msg => $cond->{error_msg},
                    } );
                } else {
                    push(@new_conddataset, {
                        %{$cond},
                    });
                }
            }

            #formulate rule hash
            if($rule->{_source}){
                push(@$newdataset, {
                    %{$rule->{_source}},
                    ok => $rule->{ok} // 1,
                    error_msg => $rule->{error_msg},
                    conditions => \@new_conddataset // [],
                });
            } else {
                push(@$newdataset, {
                    %{$rule},
                    conditions => \@new_conddataset // [],
                });
            }

        }

        # replace ruleset with new tranformed hash
        $data->{ruleset} = $newdataset;
        return $data;

    } else {
        return $data;
    }


}
sub validate {
    my ( $self, $force_commit) = @_;

    my $payload     = $self->ruleset;
    my $schema      = $self->schema;
    my $error_count = 0;

    if( ! $force_commit ) {

        # TEST 1: Check if the payload is outof sync
        my @got_rules  = grep {$_} map {$_->{'rule_id'} } @$payload; #get rid of null/undef

        my @got_conditions = ();
        for my $rule ( @$payload ) {
            my $conditions_hash =  $rule->{'conditions'};
            my  @got =  map { $_->{'condition_id'} } @$conditions_hash;
            push( @got_conditions , @got);
        }

        @got_conditions = grep { $_} @got_conditions; # get rid of undef

        my @rule_rs         = $schema->resultset("Fraud::StagingRule")->all;
        my @condition_rs    = $schema->resultset("Fraud::StagingCondition")->all;

        my @expected_rules          = map{$_->id } @rule_rs;
        my @expected_conditions     = map{$_->id } @condition_rs;

        # return if rules are out of sync to database
        if ( is_diff(\@expected_rules, \@got_rules) || is_diff(\@expected_conditions,\@got_conditions)) {

            $error_count++;
            return _generate_error("Please Reload the Page as the Rules/Conditions have chaged in the database or use \"Force Save\" option to overwrite and click on \"Save Changes\" button again",
                {
                    error_count => $error_count,
                });
        }
    }

    my $lookup_hash     = _build_method_operator_hash($schema);
    my $method_rs       = $schema->resultset("Fraud::Method");
    my @rule_status_rs  = $schema->resultset("Fraud::RuleStatus")->all;
    my @order_status    = ($ORDER_STATUS__CREDIT_HOLD, $ORDER_STATUS__ACCEPTED) ;
    my $newruleset      = [];

    # Check if rule name and sequence is unique
    my @result_data = grep { ( $_->{deleted}+0 ) != 1 } @$payload;
    my @rule_names  = grep { $_} map {lc($_->{'name'}) } @result_data;
    my @rule_sequence =  map {$_->{'sequence'} } @result_data;

    my %seen = ();
    my @dup_rulenames = map { 1==$seen{lc($_)}++ ? lc($_) : () } @rule_names;

    %seen = ();
    my @dup_sequence =  map { 1==$seen{$_}++ ? $_ : () } @rule_sequence;

    for my $rule ( @$payload)
    {
        my @conditions = ( exists $rule->{conditions} && $rule->{conditions} )
            ?  @{ delete $rule->{conditions} }
            : ();

        my $rule_status = ( $rule->{enabled} + 0 );
        my $rule_deleted = ( $rule->{deleted} + 0 );

        next if( $rule_deleted );

        $rule->{error_msg} = [];
        $rule->{ok} = 1;

        # Add Error if rule name is not unique
        if( grep{ $_ && $_ eq lc($rule->{name}) } @dup_rulenames ) {
            $error_count++;
            push(@{ $rule->{error_msg} }, 'Rule name is duplicate. It has to be unique');
            $rule->{ok} = 0;
        }

        # rule name is null
        if( $rule->{name} eq '') {
            $error_count++;
            push(@{ $rule->{error_msg} }, 'Rule name cannot be null');
            $rule->{ok} = 0;
        }

        #if rule name is  > 255 charaters
        if( length( $rule->{name} ) > 255 ) {
            $error_count++;
            push(@{ $rule->{error_msg} }, 'Rule name is too Long.');
            $rule->{ok} = 0;
        }

        # Add error if squence is not unique
        if( grep{ $_ && $_ eq $rule->{sequence} } @dup_sequence ) {
            $error_count++;
            push(@{ $rule->{error_msg} }, 'Sequence is duplicate. It has to be unique');
            $rule->{ok} = 0;
        }

        #error for invalid date range
        if(defined $rule->{end_date} && $rule->{end_date} ne '') {
            #check it is not less than today
            my $dt = DateTime->now( time_zone => "local" );
            if( DateTime->compare( $rule->{end_date},$dt ) < 0 && $rule->{enabled} ) {
                $error_count++;
                push(@{ $rule->{error_msg} }, 'End Date/Time cannot be in the past. Please disable the rule or update the date.');
                $rule->{ok} = 0;
            }

            if( defined $rule->{start_date} && $rule->{start_date} ne ''){
                if(DateTime->compare($rule->{end_date}, $rule->{start_date} ) < 0 ) {
                    $error_count++;
                    push(@{ $rule->{error_msg} }, 'End Date/Time cannot be before the Start Date/Time');
                    $rule->{ok} = 0;
                }
            }
        }

        # Add error if rule status_id is not from allowed list
        if( ! grep { $_ && $_->id eq $rule->{status_id} } @rule_status_rs) {
            $error_count++;
            push(@{ $rule->{error_msg} }, 'Rule Status is not valid.');
            $rule->{ok} = 0;
        }

        # Add error if action_order_status_id is not from allowed list
        if ( ! grep { $_ eq $rule->{action_id} } @order_status ) {
            $error_count++;
            push(@{ $rule->{error_msg} }, 'Rule Status is not valid.');
            $rule->{ok} = 0;
        }

        # Add error if any tags contain a comma.
        if ( grep { /,/ } @{ $rule->{tags} } ) {
            $error_count++;
            push(@{ $rule->{error_msg} }, 'Tags cannot contain commas.');
            $rule->{ok} = 0;
        }

        my $condition_count = 0;
        my $newconditionset = [];
        foreach my $condition ( @conditions) {
            $condition->{error_msg} = [];
            my $conditions_status   = ($condition->{enabled} + 0 );
            my $method_row          = $method_rs->find($condition->{method_id});

            $condition_count++ if ($conditions_status);

            my $subset_lookup   = $lookup_hash->{$condition->{method_id}};

            # If method has correct condition operator
            if(! is_valid_condition_operator( $condition->{operator_id},$subset_lookup) ) {
                $error_count++;
                $condition->{ok} = 0;
                push( @{$condition->{error_msg}}, "Incorrect operator used");
            }

            if( my $method_row = $method_rs->find($condition->{method_id} ) ) {

                my $operator = $schema->resultset("Fraud::ConditionalOperator")->find(
                    $condition->{operator_id}
                );
                if ( $operator->is_list_operator ) {
                    # If the operator is a list operator valid that the list exists

                    my $list = $schema->resultset("Fraud::StagingList")->find($condition->{value} // -1);
                    if ( ! $list || $list->list_type_id != $method_row->list_type_id ) {
                        $error_count++;
                        $condition->{ok} = 0;
                        push( @{$condition->{error_msg}}, "List does not exist or is not valid" );
                    }
                }
                else {
                    # or validate the returned value

                    # If Value is correct return_type
                    # i.e, if we expect boolean then value is 1 or 0
                    my $value = $condition->{value} // '';
                    if ( ! is_valid_return_type ($method_row, $value)) {
                        $error_count++;
                        $condition->{ok} = 0;
                        push ( @{$condition->{error_msg}} , "Value is of wrong type");
                    }

                    # if Value is one of the same as what we expect
                    if ( ! is_allowable_value($method_row, $value)) {
                        $error_count++;
                        $condition->{ok} = 0;
                        push ( @{$condition->{error_msg}} , "Value provided is not from allowed list of values");
                    }
                }
            } else {
                $error_count++;
                $condition->{ok} = 0;
                push ( @{$condition->{error_msg}} , "Method not supported" );
            }

            delete $condition->{error_msg} if( scalar( @{ $condition->{error_msg}}) == 0);

            push(@$newconditionset, $condition);

       }

        # Check rule is disabled if all conditions are disabled or empty
        if( $rule_status && $condition_count == 0 ) {
            $error_count++;
            $rule->{ok} = 0;
            push ( @{ $rule->{error_msg} } , "Please disable the rule, as it does not have any enabled condition(s)" );
        }

        $rule->{conditions} = $newconditionset;
        push(@{$newruleset}, $rule );
    }

    if( $error_count > 0 ) {
        return _generate_error("Validation Errors",
            {
                ruleset => $newruleset,
                error_count => $error_count,
            }
        );
    }

    return  _generate_ok();

}

=head2 _build_method_operator_hash

    Returns a Lookup hash with values:
    {
        method_id => [ conditional_operator_id , conditional_operator_id ...],
        mthod_id => [ conditional_operator_id...]
        ..
    }

=cut

sub _build_method_operator_hash {
    my $schema = shift;

    my $return_result;

    # get all methods
    my $method_rs = $schema->resultset("Fraud::Method");
    while ( my $method = $method_rs->next ) {
        my @conditions_operator_ids;
        # get all link_return_value_type__conditional_operator records
        my @condtions_operator_rs =  $method->return_value_type->link_return_value_type__conditional_operators->all;
        foreach my $co ( @condtions_operator_rs ) {
            push (@conditions_operator_ids , $co->conditional_operator_id );
        }
        $return_result->{$method->id}  = \@conditions_operator_ids;
    }

    return $return_result;
}

sub is_valid_condition_operator {
    my $operator    = shift;
    my $lookup_ref  = shift;

    if( ! grep{ $_ && $_ eq $operator } @{$lookup_ref} ) {
        return 0;
    }
    return 1;
}

sub is_valid_return_type {
    my $method_obj = shift;
    my $value      = shift;

    return if ($value eq '');

    my $re = $method_obj->return_value_type->regex;
    if( $re && $value !~ /$re/ ){
        return 0;
    }
    return 1;
}

=head2 is_allowable_value

    checks to see if the value provided is one of the value
    returned from XT::FraudRules::Actions::HelperMethod

=cut

sub is_allowable_value {
    my $method_obj = shift;
    my $value      = shift;

    if( $method_obj && $value ne '' ) {
        my @db_values;
        my $rows = $method_obj->get_allowable_values_from_helper;

        return 1 if ( scalar @$rows == 0 );
        for my $row ( @$rows) {
            push(@db_values, $row->get_column('id'));
        }
        if( grep { $_ && $_ eq $value } @db_values) {
            return 1;
        }
    }
    return 0;

}

=head2 is_diff

    $boolean = is_diff ( $arrayRef1, $arrayRef2);
    Returns boolean value 1/0 if given 2 array refs are different/same.

=cut

sub is_diff {
    my $x = shift;
    my $y = shift;

    my @arr1 = @$x;
    my @arr2 = @$y;

    # if length is different
    if( scalar(@arr1) != scalar(@arr2) ) {
        return 1;
    }
    #sort them
    @arr1 = sort { $a <=> $b } @arr1;
    @arr2 = sort { $a <=> $b } @arr2;

    foreach my $i( 0 .. $#arr1 ) {
        if ( $arr1[$i] != $arr2[$i] ) {
            return 1;
        }
    }

    return 0;
}


sub _format_date {
    my $date    = shift;
    my $hour    = shift || 0;
    my $minute  = shift || 0;

    return unless( defined $date );

    my ($year, $month, $day) = split /-/, $date;

    my $dt = DateTime->new(
        year        => $year,
        month       => $month,
        day         => $day,
        hour        => $hour,
        minute      => $minute,
    );

    return $dt;
}

sub push_to_live {
    my ( $self, $operator_id, $change_log_message ) = @_;

    croak 'operator_id is required for push_to_live'
        unless $operator_id;

    croak 'change_log_message is required for push_to_live'
        unless $change_log_message;

    # Get the ResultSets we'll need.
    my $live_rules     = $self->schema->resultset('Fraud::LiveRule');
    my $staging_rules  = $self->schema->resultset('Fraud::StagingRule');
    my $archived_rules = $self->schema->resultset('Fraud::ArchivedRule');
    my $change_logs    = $self->schema->resultset('Fraud::ChangeLog');
    my $live_lists     = $self->schema->resultset('Fraud::LiveList');
    my $staging_lists  = $self->schema->resultset('Fraud::StagingList');
    my $archived_lists = $self->schema->resultset('Fraud::ArchivedList');

    # We must have at least one enabled rule in staging to copy to live.
    return _generate_error( 'You must have at least one enabled rule to push to live.' )
        if $staging_rules->search( { enabled => 1 } )->count == 0;

    # First, we need to create the change log entry.
    my $change_log = $change_logs->create( {
        description => $change_log_message,
        operator_id => $operator_id,
        created     => \'now()',
    } );

    # Second, we need to update the staging conditions live_id column to null,
    # otherwise when we delete the live rules, it will fail because of the
    # constraint.

    $staging_rules->update( {
        live_rule_id => undef,
    } );

    # And we need to do the same to the staging lists for the same reason.

    $staging_lists->update( {
        live_list_id => undef,
    } );

    # Third, we need to take care of the existing live and archived rules and
    # lists. The archived ones need to be 'expired' and the live ones removed.

    while ( my $live_rule = $live_rules->next ) {

        # Expire the related archived rule.
        $live_rule->archived_rule->update( {
            expired                => \'now()',
            expired_by_operator_id => $operator_id,
        } );

        # Delete the rule and associated conditions.
        $live_rule->conditions->delete;
        $live_rule->delete;

    }

    while ( my $live_list = $live_lists->next ) {
        $live_list->archived_list->update( {
            expired                 => \'now()',
            expired_by_operator_id  => $operator_id,
        } );

        $live_list->list_items->delete;
        $live_list->delete;
    }

    # Fourth, we need to create the records in the archived tables first, because
    # these are the authoritive ones. Then we populate the now empty live tables.

    # We need to process the lists first as the conditions depend upon these
    while ( my $staging_list = $staging_lists->next ) {
        # First we create the archived list as we need the id for the live
        my $new_archived_list = $archived_lists->create( {
            list_type_id            => $staging_list->list_type_id,
            name                    => $staging_list->name,
            description             => $staging_list->description,
            change_log_id           => $change_log->id,
            created                 => \'now()',
            created_by_operator_id  => $operator_id,
        } );

        # Now populate the list_items for the archived list
        my @staging_list_items = $staging_list->list_items->all;
        foreach my $list_item ( @staging_list_items ) {
            $new_archived_list->create_related('list_items', {
                value   => $list_item->value,
            } );
        }

        # With the archived list in place we can create the live one
        my $new_live_list = $live_lists->create( {
            list_type_id            => $staging_list->list_type_id,
            name                    => $staging_list->name,
            description             => $staging_list->description,
            archived_list_id        => $new_archived_list->id,
        } );

        # and the list_items
        foreach my $list_item ( @staging_list_items ) {
            $new_live_list->create_related('list_items', {
                value   => $list_item->value,
            } );
        }

        $staging_list->update( {
            live_list_id    => $new_live_list->id,
        } );
    }

    while ( my $staging_rule = $staging_rules->next ) {
    # From each staging rule.

        # All the staging conditions to copy.
        my @staging_conditions = $staging_rule->staging_conditions->all;

        # Create the archived rule.
        my $new_archived_rule = $archived_rules->create( {
            channel_id             => $staging_rule->channel_id,
            rule_sequence          => $staging_rule->rule_sequence,
            name                   => $staging_rule->name,
            start_date             => $staging_rule->start_date,
            end_date               => $staging_rule->end_date,
            enabled                => $staging_rule->enabled,
            action_order_status_id => $staging_rule->action_order_status_id,
            metric_used            => 0,
            metric_decided         => 0,
            change_log_id          => $change_log->id,
            created                => \'now()',
            created_by_operator_id => $operator_id,
            tag_list               => $staging_rule->tag_list,
        } );

        # Add the conditions to the archived rule.
        foreach my $staging_condition ( @staging_conditions ) {

            my $value;
            if ( $staging_condition->conditional_operator->is_list_operator ) {
                # We need to get the id of the list in the archived lists
                my $staging_list = $staging_lists->search( {
                    id => $staging_condition->value
                } )->first;
                $value = $staging_list->live_list->archived_list_id;
            }
            else {
                $value = $staging_condition->value;
            }

            $new_archived_rule->create_related( 'archived_conditions', {
                method_id               => $staging_condition->method_id,
                conditional_operator_id => $staging_condition->conditional_operator_id,
                value                   => $value,
                enabled                 => $staging_condition->enabled,
                change_log_id           => $change_log->id,
                created                 => \'now()',
                created_by_operator_id  => $operator_id,
            } );

        }

        # Create the live rule.
        my $new_live_rule = $live_rules->create( {
            channel_id             => $staging_rule->channel_id,
            rule_sequence          => $staging_rule->rule_sequence,
            name                   => $staging_rule->name,
            start_date             => $staging_rule->start_date,
            end_date               => $staging_rule->end_date,
            enabled                => $staging_rule->enabled,
            action_order_status_id => $staging_rule->action_order_status_id,
            metric_used            => 0,
            metric_decided         => 0,
            archived_rule_id       => $new_archived_rule->id,
            tag_list               => $staging_rule->tag_list,
        } );

        # Add the conditions to the live rule.
        foreach my $staging_condition ( @staging_conditions ) {

            my $value;
            if ( $staging_condition->conditional_operator->is_list_operator ) {
                # We need to get the id of the list in the live lists
                my $staging_list = $staging_lists->search( {
                    id => $staging_condition->value
                } )->first;
                $value = $staging_list->live_list_id;
            }
            else {
                $value = $staging_condition->value;
            }

            $new_live_rule->create_related( 'live_conditions', {
                method_id               => $staging_condition->method_id,
                conditional_operator_id => $staging_condition->conditional_operator_id,
                value                   => $value,
                enabled                 => $staging_condition->enabled,
            } );

        }

        # Finally, we need to update the live_rule_id to point to the new
        # live rule.
        $staging_rule->update( {
            live_rule_id => $new_live_rule->id,
        } );

    }

    try {
        my $send_notice_email = lc(sys_config_var($self->schema,
                                                  'CONRAD',
                                                  'email_notification_on_push_to_live'
                                  ) // 'Off');

        if ( $send_notice_email eq 'on' ) {
            my $operator_obj = $self->schema->resultset('Public::Operator')->find($operator_id);

            send_internal_email(
                to          => sys_config_var($self->schema, 'CONRAD', 'push_to_live_email_notice_recipient'),
                subject     => 'CONRAD - New Rules Pushed to Live',
                from_file   => { path => 'email/internal/conrad_rules_pushed_to_live.tt', },
                stash       => {
                    operator_id     => $operator_id,
                    operator_name   => $operator_obj->name,
                    operator_login  => $operator_obj->username,
                    change_log_msg  => $change_log_message,
                    timestamp       => $self->schema->db_now()->strftime("%a, %d %B %Y %T"),
                    dc              => config_var( 'DistributionCentre', 'name' ),
                    template_type   => 'email',
                } );
        }
    } catch {
            xt_logger->error( "Unable to call send_internal_email for CONRAD push to live - $_ " );
    };

    return _generate_ok;

}

sub pull_from_live {
    my $self = shift;

    my $live_rules         = $self->schema->resultset('Fraud::LiveRule');
    my $live_lists         = $self->schema->resultset('Fraud::LiveList');
    my $staging_rules      = $self->schema->resultset('Fraud::StagingRule');
    my $staging_conditions = $self->schema->resultset('Fraud::StagingCondition');
    my $staging_lists      = $self->schema->resultset('Fraud::StagingList');
    my $staging_list_items = $self->schema->resultset('Fraud::StagingListItem');

    # We must have at least one rule in live to copy to staging.
    return _generate_error( 'There are no rules to copy from live.' )
        if $live_rules->count == 0;

    # Delete everything from staging.
    $staging_list_items->delete;
    $staging_lists->delete;
    $staging_conditions->delete;
    $staging_rules->delete;

    # Copy the lists in Live back to Staging
    while ( my $list = $live_lists->next ) {
        my $new_staging_list = $staging_lists->create ( {
            list_type_id            => $list->list_type_id,
            name                    => $list->name,
            description             => $list->description,
            live_list_id            => $list->id,
        } );

        foreach my $list_item ( $list->list_items ) {
            $new_staging_list->create_related( 'staging_list_items', {
                value       => $list_item->value,
            } );
        }
    }

    while ( my $rule = $live_rules->next ) {
    # Copy the Rules and their Conditions in live to staging.

        my $new_staging_rule = $staging_rules->create( {
            channel_id             => $rule->channel_id,
            rule_sequence          => $rule->rule_sequence,
            name                   => $rule->name,
            start_date             => $rule->start_date,
            end_date               => $rule->end_date,
            enabled                => $rule->enabled,
            rule_status_id         => $FRAUD_RULE_STATUS__UNCHANGED,
            action_order_status_id => $rule->action_order_status_id,
            live_rule_id           => $rule->id,
            metric_used            => $rule->metric_used,
            metric_decided         => $rule->metric_decided,
            tag_list               => $rule->tag_list,
        } );

        foreach my $condition ( $rule->conditions->all ) {

            my $value;
            if ( $condition->conditional_operator->is_list_operator ) {
                my $staging_list = $staging_lists->search( {
                    live_list_id => $condition->value,
                } )->first;
                $value = $staging_list->id;
            }
            else {
                $value = $condition->value;
            }

            $new_staging_rule->create_related( 'staging_conditions', {
                method_id               => $condition->method_id,
                conditional_operator_id => $condition->conditional_operator_id,
                value                   => $value,
                enabled                 => $condition->enabled,
            } );

        }

    }

    return _generate_ok;

}

1;
