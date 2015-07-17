#!/usr/bin/env perl


#
# Test Receive::Product::ColourVariationGroups job
#

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::DC::JQ::Receive qw(send_job get_channels redefine_db_connection);
use XTracker::Comms::DataTransfer qw( :transfer_handles );
use List::MoreUtils qw( uniq );
use DBD::Mock::Session;

use Const::Fast;
const my $RECEIVER => 'XT::JQ::DC::Receive::Product::ColourVariationGroups';

use_ok($RECEIVER) or BAIL_OUT('Syntax errors');

my $payload;

# TESTING WRONG PAYLOAD
throws_ok {
    send_job( $payload, $RECEIVER );
} qr/payload.*does not pass the type constraint/, 'cannot pass wrong payload arg (1)';

$payload = 'somescalar';
throws_ok {
    send_job( $payload, $RECEIVER );
} qr/payload.*does not pass the type constraint/, 'cannot pass wrong payload arg (2)';

$payload = {};
throws_ok {
    send_job( $payload, $RECEIVER );
} qr/payload.*does not pass the type constraint/, 'cannot pass wrong payload arg (3)';

$payload = [];
throws_ok {
    send_job( $payload, $RECEIVER );
} qr/There must be at least one colour variation group specified/, 'cannot pass wrong payload arg (4)';

$payload = [[]];
throws_ok {
    send_job( $payload, $RECEIVER );
} qr/All Colour variation groups must have at least one product ID/, 'cannot pass wrong payload arg (5)';

$payload = [[qw(1 2 1)]];
throws_ok {
    send_job( $payload, $RECEIVER );
} qr/Each product ID can only occur once across all colour variation groups/, 'cannot pass wrong payload arg (6)';

$payload = [[qw(1 2)],[qw(1 2)]];
throws_ok {
    send_job( $payload, $RECEIVER );
} qr/Each product ID can only occur once across all colour variation groups/, 'cannot pass wrong payload arg (7)';


# Create some products
my $channel_id = (get_channels())[0];
my ($channel, $product_set_1);
($channel, $product_set_1) = Test::XTracker::Data->grab_products({
        how_many   => 2,
        channel_id => $channel_id,
        force_create => 1,
});
($channel, my $product_set_2) = Test::XTracker::Data->grab_products({
        how_many   => 3,
        channel_id => $channel_id,
        force_create => 1,
});

# Redefine mocked DBD connection so that we can pass mock_params to it.
my %mock_params;
redefine_db_connection( \%mock_params );

# TEST: Let's receive a message having 1 group of 3 products as payload
my @pid_set_1 = map { $_->{pid} } @{$product_set_1};
$payload = [ [@pid_set_1] ];

%mock_params = (
    mock_clear_history => 1,
    mock_session       => _mock_session(payload => $payload),
);
send_job( $payload, $RECEIVER );


# TEST: Let's receive a message having 2 group of 3 products as payload
my @pid_set_2 = map { $_->{pid} } @{$product_set_2};
$payload = [ [@pid_set_1], [@pid_set_2] ];

%mock_params = (
    mock_clear_history => 1,
    mock_session       => _mock_session( payload => $payload )
);
send_job( $payload, $RECEIVER );

# TEST: Let's receive a message but let's fail in connecting to the DB
%mock_params = (mock_clear_history => 1, mock_connect_fail => 1);

my $job = send_job( $payload, $RECEIVER );
like(
    $job->{failed},
    qr/Can't Talk to Web Site/,
    'job marked as failed when DB connection is not available',
);

# TEST: Let's receive a message having only ONE group containing only ONE PID
$payload = [ [ $pid_set_1[0] ] ];

# note that we're not expecting any INSERT to run, but still we run
# the DELETE statements for sanitiy check.
%mock_params = (
    mock_clear_history => 1,
    mock_session       => _mock_session(payload => $payload, no_insert => 1),
);
send_job( $payload, $RECEIVER );


# TEST: Let's unpublish 1 product out of 2: we're expecting it to be removed
# from the list of products to be linked together so that linking them is
# no longer required.
$product_set_1->[0]->{product}
    ->get_product_channel($channel_id)->update({ live => 0 });

$payload = [ [@pid_set_1] ];

%mock_params = (
    mock_clear_history => 1,
    mock_session => _mock_session( payload  => $payload, no_insert => 1 ),
);

send_job( $payload, $RECEIVER );

END {
    done_testing();
}

=head2 _mock_session

Return an DBD::Mock::Session object to be passed to the redefined dbh.
If at any time the SQL statement does not match the current state's 'statement',
or the session runs out of available states, an error will be raised,
so this subroutine does some nice testing for us.

The expected queries for this sessions are:

 - 2 DELETE are executed to ensure that no relationships exist between any of
   the products in the set and any product outside of the set.

 - 1 INSERT is executed to ensure that relationships exist between all
   of the product in the set.

Check L<XT::JQ::DC::Receive::Product::ColourVariationGroups> for details

INPUT: an HashRef having the following keys:

  - payload   : the message payload you want to check the queries for.
  - no_insert : whether you're NOT expecting an insert to happen.

=cut

sub _mock_session {
    my (%args) = @_;

    my $payload   = $args{payload};
    my $no_insert = $args{no_insert};

    my $number_of_groups = scalar @{$payload};

    my @colour_group_query_set;
    for ( 0 .. $number_of_groups - 1 ) {

        my $number_of_pids = scalar @{ $payload->[$_] };

        # Building the bindings
        my $in          = join(',' => ('?') x $number_of_pids);
        my $inner_table = 'SELECT id FROM searchable_product WHERE id IN ('.
            join (',' => ('?') x $number_of_pids).
        ')';

        unless ($no_insert) {
            push @colour_group_query_set,
            {
                statement => 'INSERT INTO related_product '.
                '(search_prod_id, related_prod_id, type_id, sort_order, position,'.
                ' created_dts, created_by, last_updated_dts, last_updated_by)'.
                ' SELECT '.
                    'search_prod.id AS search_prod_id, '.
                    'related_prod.id AS related_prod_id, '.
                    '? AS type_id, '.
                    '0 AS sort_order, '.
                    '0 AS position, '.
                    'current_timestamp AS created_dts, '.
                    '\'XTRACKER\' AS created_by, '.
                    'current_timestamp AS last_updated_dts, '.
                    '\'XTRACKER\' AS last_updated_by '.
                    'FROM ('.$inner_table.') search_prod '.
                    'CROSS JOIN ('.$inner_table.') related_prod '.
                    'LEFT JOIN related_product rp '.
                        'ON rp.search_prod_id = search_prod.id '.
                        'AND rp.related_prod_id = related_prod.id '.
                        'AND rp.type_id = ? '.
                    'WHERE '.
                    'search_prod.id <> related_prod.id '.
                    'AND rp.search_prod_id IS NULL',
                results   => [[]],
            };
        }

        push @colour_group_query_set,
            {
                statement =>  'DELETE FROM related_product'.
                                ' WHERE search_prod_id'.
                                ' IN ('.$in.') AND related_prod_id NOT'.
                                ' IN ('.$in.') AND type_id = ?',
                results   => [[]],
            };

        push @colour_group_query_set,
            {
                statement =>  'DELETE FROM related_product'.
                                ' WHERE search_prod_id'.
                                ' NOT IN ('.$in.') AND related_prod_id'.
                                ' IN ('.$in.') AND type_id = ?',
                results   => [[]],
            };
    }

    push @colour_group_query_set,
        {
            statement => 'COMMIT',
            results   => [[]],
        };

    my $session = DBD::Mock::Session->new(
        colour_group_stamp => @colour_group_query_set,
    );

    return $session;
}
