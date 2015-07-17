package XT::Order::Importer;
use NAP::policy "tt";

use XT::Order::Parser;
use XTracker::Database qw( schema_handle get_schema_using_dbh);
use XTracker::Config::Local qw( config_var order_importer_send_fail_email config_section_slurp );
use XTracker::EmailFunctions;
use XTracker::Logfile qw( xt_logger );
use DateTime;
use Data::Dump qw/pp/; # used in error reports, not debugging
use Scalar::Util qw(blessed);
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

sub import_orders {
    my ( $self, $args ) = @_;
    ###NOTE: not $self, it's called as a class method in
    ###XT::DC::Messaging::ConsumerBase::Order

    my $skip = $args->{skip} || 0;

    croak 'Order data required' unless defined $args->{data};

    # if $args->{data} is a 'HASH' then it should have been supplied
    # by an AMQ Consumer and so it should be one Order per Request
    # otherwise it's an XML Document and 1 or more orders per request.
    # so check if $args->{data} is some kind of 'XML' object
    my $xml_order_flag = ( ref( $args->{data} ) =~ /XML/ ? 1 : 0 );

    my $logger = $args->{logger} || xt_logger( qw( OrderImporter ) );

    my $schema;

    # We pass in a schema when running this under a test, so we can roll back the
    # order creation. Generally this manages it's own schema objects when used
    # by real order processing code.
    if ( defined $args->{schema} ) {
        $schema = $args->{schema};
    }
    else {
        # connect to XT database
        $schema = schema_handle()
            or die "Error: Unable to connect to DB";
    }

    my $parser = XT::Order::Parser->new_parser({
        data    => $args->{data},
        schema  => $schema,
    });


    my @orders;
    try {
        @orders = $parser->parse;
    }
    catch {
        send_error_message({
            error       => $_,
            args        => $args,
            stage       => 'parser',
            message     => 'Parsing failed',
            logger      => $logger
        });
        # we try-catch the call to this function, and it's an easy (lazy?) way
        # to propagate the error up the stack for us to catch and send as our
        # (MRP) feedback about the order status
        Carp::confess( "Parsing Failed: " . $_ );
    };

    my $retval = 1;
    my $flag = 0;
    foreach my $order (@orders) {
        my $digest_args = { skip => $skip, duplicate => 0 };
        my $success = 0;
        try {
            my $order_row = $order->digest( $digest_args );
            $order_row->allocate($APPLICATION_OPERATOR_ID);
            $success    = 1;
        }
        catch {
            $retval = 0;
            send_error_message({
                error       => $_,
                args        => $args,
                stage       => 'digest',
                order       => $order,
                message     => 'Processing order failed',
                logger      => $logger
            });
            # as above,
            # we try-catch the call to this function, and it's an easy (lazy?) way
            # to propagate the error up the stack for us to catch and send as our
            # (MRP) feedback about the order status
            Carp::confess( "Create Failed: " . $_ ) unless ( $xml_order_flag );     # only die if Order from AMQ because it's one per request
                                                                                    # otherwise loop round creating any other Orders that are left
        };

        if ( $success ) {
            if ( $digest_args->{duplicate} ) {
                $args->{data}{duplicate}    = 1     unless ( $xml_order_flag );
            }
        }
    }

    return $retval;
}

sub send_error_message {
    my $rh_args = shift;
    my $err = $rh_args->{error};
    my $args = $rh_args->{args};
    my $order = $rh_args->{order};
    my $message = $rh_args->{message};
    my $stage = $rh_args->{stage};
    my $schema= $rh_args->{schema};

    my $logger= $rh_args->{logger} || xt_logger( qw( OrderImporter ) );

    # replace schema in args to prevent bloated message
    if (defined $args->{schema} && blessed $args->{schema}) {
        $args->{schema} = ref $args->{schema};
    }

    my $dt = DateTime->now;
    my $msg = '['.$dt->ymd('/').' '.$dt->hms.']'.
        'FAILED Importing Order: '.$message."\n".
        'DC: ' . config_var('DistributionCentre','name') . ', Sales Channel: ' . ( $order && $order->channel() ? $order->channel->name : 'Unknown' ) . "\n".
        ($order ? 'Order number: '.$order->order_number : '').'\n'.
        pp($err).
        "\n ---- Args to import_orders ------------------- \n".
        pp($args).
        "\n ============================================== \n\n\n";

    # always send an email for Parser errors
    if ( $stage eq 'parser' || order_importer_send_fail_email( $order->channel() ) ) {
        send_email(
            'order_import@net-a-porter.com',
            '',
            config_var('Orders','failed_digest_email'),
            'Order Import Error',
            $msg,
        );
    }

    $logger->warn( $msg );

    return;
}

1;
