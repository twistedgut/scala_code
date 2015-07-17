#!/usr/bin/env perl

use NAP::policy "tt",         'test';
use base 'Test::Class';

=head1 NAME

Test Methods used by the Fraud Rules Engine

=head1 SYNOPSIS

Tests that each of the Methods in the 'fraud.method' table 'can' actually be called from the Class
they've been associated with and can be evaluated by 'XT::Rules::Condition'.

Also tests all the Methods used for Applying the Finance Flags.

=cut

use Test::XTracker::Data;
use Test::XT::Data;

use XT::FraudRules::Engine;
use XT::Rules::Condition;
use XT::FraudRules::Actions::HelperMethod;


# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema;
}

# to be done BEFORE each test runs
sub setup : Test( setup => 2 ) {
    my $self = shift;

    $self->{schema}->txn_begin;

    $self->{data}   = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
        ],
    } );
    $self->{order}  = $self->{data}->new_order->{order_object};
    $self->{channel}= $self->{order}->channel;

    # specify the list of Classes the Methods should be operating on
    $self->{classes}    = {
        'Public::Orders'    => $self->{order},
        'Public::Customer'  => $self->{order}->customer,
    };
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;

    $self->{schema}->txn_rollback;
}

=head1 TESTS

=head2 test_all_methods_can_be_called

Tests that All Methods can be called that are defined in the 'fraud.method' table.

=cut

sub test_all_methods_can_be_called : Tests() {
    my $self    = shift;

    my $schema  = $self->{schema};

    # list of Classes the Methods should operate on
    my $classes = $self->{classes};

    my @methods = $self->{schema}->resultset('Fraud::Method')
                                    ->search( {}, { order_by => 'object_to_use, method_to_call' } )
                                        ->all;

    foreach my $method ( @methods ) {
        my $subtest_msg    = "Method: '" . $method->description . "'"
                           . " for Class: '" . $method->object_to_use . "'"
                           . " calls: '" . $method->method_to_call . "'"
                           . " returns type: '" . $method->return_value_type->type . "'"
                           . ", cost: '" . $method->processing_cost . "'"
        ;

        subtest $subtest_msg => sub {
            # use this so that if the method crashes
            # it doesn't crash the whole test
            $schema->svp_begin('method_test');

            ok( exists( $classes->{ $method->object_to_use } ), "Class used is one of the Expected Classes" );
            my $object  = $classes->{ $method->object_to_use };
            ok( $object->can( $method->method_to_call ), "Method 'can' be Called on Class" );
            $self->_can_evaluate_method( $classes, $method );
            $self->_can_get_helper_values( $method );

            $schema->svp_rollback('method_test');
        };
    }
}

=head2 test_all_finance_flag_rules

Tests that All Methods used to Apply the Finance Flags which are
specified in the 'XT::FraudRules::Engine' Class can be called.

=cut

sub test_all_finance_flag_fules : Tests() {
    my $self    = shift;

    my $schema  = $self->{schema};

    # list of Classes the Methods should operate on
    my $classes = $self->{classes};

    # get an Engine so as to get all the Rules for Finance Flags
    my $engine = XT::FraudRules::Engine->new( {
        order   => $self->{order},
    } );

    my $flag_rs = $schema->resultset('Public::Flag');

    foreach my $flag_rule ( $engine->all_finance_flags ) {
        my $flag_rec    = $flag_rs->find( $flag_rule->{flag} );
        note "Testing Rule for Flag: '" . $flag_rec->description . "'";

        my $conditions  = $flag_rule->{conditions};
        isa_ok( $conditions, 'ARRAY', "Flag has a 'conditions' Array" );
        cmp_ok( @{ $conditions }, '>=', 1, "and has at least one Condition in it" );

        # now test each Condition can be processed
        foreach my $condition ( @{ $conditions } ) {
            my $subtest_msg    = "Test Condition for Flag Rule"
                               . " which uses Class: '" . $condition->{class} . "'"
                               . " calling Method: '" . $condition->{method} . "'"
            ;

            subtest $subtest_msg => sub {
                $schema->svp_begin('method_test');

                ok( exists( $classes->{ $condition->{class} } ), "Class used is one of the Expected Classes" );
                my $object  = $classes->{ $condition->{class} };
                ok( $object->can( $condition->{method} ), "Method 'can' be Called on Class" );
                $self->_can_evaluate_method( $classes, $condition );

                $schema->svp_rollback('method_test');
            };
        }
    }
}

#-------------------------------------------------------------------------

# try and evaluate a Method
sub _can_evaluate_method {
    my ( $self, $classes, $to_evaluate )    = @_;

    my @objects = values %{ $classes };

    lives_ok {

        my $condition = XT::Rules::Condition->new( {
            objects     => \@objects,
            channel     => $self->{channel},
            to_evaluate =>
                (
                    # either a Method object will be passed in
                    # or it will already contain what is needed
                    ref( $to_evaluate ) =~ m/::Fraud::Method$/
                    ? {
                        class   => $to_evaluate->object_to_use,
                        method  => $to_evaluate->method_to_call,
                        params  => $to_evaluate->method_parameters,
                    }
                    : $to_evaluate
                ),
            die_on_error => 1,
        } );
        $condition->compile;
        $condition->evaluate;

    } "Method Can be Evaluated by 'XT::Rules::Condition'";

    return;
}

# try and get Helper values
sub _can_get_helper_values {
    my ( $self, $method )   = @_;

    return      if ( !$method->rule_action_helper_method );

    note "Method has a Helper: '" . $method->rule_action_helper_method . "'";

    my @values;
    lives_ok {
        my $helper = XT::FraudRules::Actions::HelperMethod->new(
            schema => $self->{schema},
        );
        if ( $helper->compile( $method->rule_action_helper_method ) ) {
            if ( my $rs = $helper->execute ) {
                @values = $rs->all;
            }
            else {
                die $helper->last_error;
            }
        }
        else {
            die $helper->last_error;
        }
    } "Method's Helper Values can be got";

    cmp_ok( scalar( @values ), '>=', 1, "and there was at Least One Value returned" );
    isa_ok( $values[0], 'HASH', "and the first Value is as expected" );
    cmp_deeply(
        {
            $values[0]->get_columns,
        },
        {
            id      => re( qr/\w+/ ),
            value   => re( qr/\w+/ ),
        },
        "and it has the correct key/value pairs"
    );

    return;
}

Test::Class->runtests;

