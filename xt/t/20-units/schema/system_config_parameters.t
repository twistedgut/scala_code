#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Guard;
use XTracker::Logfile 'xt_logger';
use Test::MockModule;

my $schema = Test::XTracker::Data->get_schema();

my $p_rs = $schema->resultset('SystemConfig::Parameter');
my $g_rs = $schema->resultset('SystemConfig::ParameterGroup');
my $t_rs = $schema->resultset('SystemConfig::ParameterType');

# Track any parameters and groups we create so we can clean up on exit
my (@parameters, @parameter_groups);
my $guard = guard {
    map { $_->delete } (@parameters, @parameter_groups);
};

my $group_create_params = {
    name => "test/group$$",
    description => 'Test/Example Group',
    visible => 1,
};
my @create_params = (
    {
        type => 'boolean',
        name => 'example_boolean',
        description => 'A Boolean Value',
        value => 1,
        sort_order => 99999,
    },
    {
        type => 'string',
        name => 'example_string',
        description => 'A String Value',
        value => 'test string',
        sort_order => 99998,
    },
    {
        type => 'integer',
        name => 'example_integer',
        description => 'An Integer Value',
        value => '5',
        sort_order => 99997,
    },
    {
        type => 'integer-set',
        name => 'example_set',
        description => 'A Set Value',
        value => [1,2,5],
        sort_order => 99996,
    },
);
my %params_by_type;

# Create a group of test parameters
subtest 'creation' => sub {
    ok my $group = $g_rs->create($group_create_params),
        'should create example group';
    push @parameter_groups, $group;
    for my $create_params (@create_params) {
        # find parameter_type
        my $type = delete $create_params->{type};
        ok my $p_type = $t_rs->find({ type => $type }),
            "should find $type parameter type";
        ok my $new_parameter = $group->create_related(
            'parameters' => {
                %$create_params,
                parameter_type => $p_type,
            }
        ), 'should create '.$create_params->{name}.' parameter';
        $create_params->{type} = $type; # to simplify the comparison later
        push @parameters, $new_parameter;
        $params_by_type{$type} = $new_parameter;
    }
};

subtest 'round-trip' => sub {
    # examine the parameter group as a hash
    my $group_hash = $g_rs->get_parameter_hash( 'test' );

    my $expect ={
        $group_create_params->{name} => {
            %$group_create_params,
            parameters => bag(
                map {
                    my $v = {%$_};
                    delete $v->{sort_order};
                    $v->{id} = ignore();
                    $v
                } @create_params,
            ),
        },
    };
    cmp_deeply($group_hash,$expect,
               'parameter hash has expected value')
        or diag "Got: ".p($group_hash)."\nExpected: ".p($expect);
};

subtest 'validation' => sub {
    throws_ok { $params_by_type{integer}->value('foo') }
        qr{\ABad (.*?): 'foo' is not a valid integer\Z},
            'integer validation works';

    throws_ok { $params_by_type{'integer-set'}->value('foo') }
        qr{\ABad (.*?): 'foo' is not a valid integer\Z},
            'integer validation inside array works (from string)';

    throws_ok { $params_by_type{'integer-set'}->value('1,2,foo') }
        qr{\ABad (.*?): 'foo' is not a valid integer\Z},
            'integer validation inside array works (mixed, from string)';

    throws_ok { $params_by_type{'integer-set'}->value(['foo']) }
        qr{\ABad (.*?): 'foo' is not a valid integer\Z},
            'integer validation inside array works (from ref)';

    throws_ok { $params_by_type{'integer-set'}->value([1,2,'foo']) }
        qr{\ABad (.*?): 'foo' is not a valid integer\Z},
            'integer validation inside array works (mixed, from ref)';
    lives_ok { $params_by_type{'integer-set'}->value(' 3 , 1 , 2 ') }
        'a set can be passed in as comma-separated list of values';
    cmp_deeply($params_by_type{'integer-set'}->value,
               [1,2,3],
               'string sets get parsed correctly');
    lives_ok { $params_by_type{'integer-set'}->value('') }
        'an empty set can be passed in as empty string';
    cmp_deeply($params_by_type{'integer-set'}->value,
               [],
               'empty string sets get parsed correctly');
    $params_by_type{'integer-set'}->discard_changes;
};

subtest 'setting values' => sub {
    my %tests = (
        boolean => [0,1],
        integer => [1,2],
        string => ['foo','longer'],
    );
    $schema->txn_do(
        sub {
            for my $type (sort keys %tests) {
                for my $value (@{$tests{$type}}) {
                    $params_by_type{$type}->update({value=>$value});
                    cmp_deeply($params_by_type{$type}->value,$value,
                               "setting $type to $value (via update) works");
                    $params_by_type{$type}->discard_changes;
                    cmp_deeply($params_by_type{$type}->value,$value,
                               "setting $type to $value (via update, and db) works");
                }
            }
            $schema->txn_rollback;
        }
    );
    for my $type (sort keys %tests) {
        $params_by_type{$type}->discard_changes;
    }
    $schema->txn_do(
        sub {
            for my $type (sort keys %tests) {
                for my $value (@{$tests{$type}}) {
                    $params_by_type{$type}->value($value);
                    cmp_deeply($params_by_type{$type}->value,$value,
                               "setting $type to $value (via accessor) works");
                }
            }
            $schema->txn_rollback;
        }
    );
    for my $type (sort keys %tests) {
        $params_by_type{$type}->discard_changes;
    }
    $schema->txn_do(
        sub {
            for my $type (sort keys %tests) {
                for my $value (@{$tests{$type}}) {
                    $params_by_type{$type}->update_if_necessary({value=>$value});
                    cmp_deeply($params_by_type{$type}->value,$value,
                               "setting $type to $value (via update_if_necessary) works");
                    $params_by_type{$type}->discard_changes;
                    cmp_deeply($params_by_type{$type}->value,$value,
                               "setting $type to $value (via update_if_necessary, and db) works");
                }
            }
            $schema->txn_rollback;
        }
    );
    for my $type (sort keys %tests) {
        $params_by_type{$type}->discard_changes;
    }
};

subtest 'logging' => sub {
    my @info_messages;
    my $logger = xt_logger('XTracker::Schema::Result::SystemConfig::Parameter');
    my $logger_class = ref($logger);
    my $log_mock = Test::MockModule->new($logger_class);
    $log_mock->mock(info => sub { push @info_messages,$_[1] });

    $params_by_type{integer}->update_if_necessary({
        value => 5,
        operator_id => 99,
    });
    cmp_deeply(\@info_messages,[ ],'nothing logged if int value stays the same')
        or note p @info_messages;
    @info_messages=();

    $params_by_type{integer}->update_if_necessary({
        value => 6,
        operator_id => 99,
    });
    cmp_deeply(\@info_messages,[
        re(qr{\ASystem parameter (.*?) updated from 5 to 6 by operator id 99\Z}),
    ],'operation logged if int value changes')
        or note p @info_messages;
    @info_messages=();

    $params_by_type{'integer-set'}->update_if_necessary({
        value => [1,2,5],
        operator_id => 99,
    });
    cmp_deeply(\@info_messages,[ ],'nothing logged if set value stays the same')
        or note p @info_messages;
    @info_messages=();

    $params_by_type{'integer-set'}->update_if_necessary({
        value => [2,5,1],
        operator_id => 99,
    });
    cmp_deeply(\@info_messages,[ ],'nothing logged if set value stays the same (order is ignored on sets)')
        or note p @info_messages;
    @info_messages=();

    $params_by_type{'integer-set'}->update_if_necessary({
        value => [2,5,1,2,5,5],
        operator_id => 99,
    });
    cmp_deeply(\@info_messages,[ ],'nothing logged if set value stays the same (duplicates are ignored on sets)')
        or note p @info_messages;
    @info_messages=();

    $params_by_type{'integer-set'}->update_if_necessary({
        value => [2,6,1],
        operator_id => 99,
    });
    cmp_deeply(\@info_messages,[
        re(qr{\ASystem parameter (.*?) updated from 1,2,5 to 1,2,6 by operator id 99\Z}),
    ],'operation logged if set value changes')
        or note p @info_messages;
};

done_testing();
