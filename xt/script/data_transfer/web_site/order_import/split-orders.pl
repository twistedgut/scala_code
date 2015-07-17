#!/opt/xt/xt-perl/bin/perl
#
# Given an orders file, bust it into myriad individual order files
# grouped by channel and shipping type, and drop them in the
# appropriate places
#
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use NAP::policy "tt";
use File::Path qw(make_path);
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use open ':encoding(utf8)';

# The XT_LOGCONF env var must be set before XTracker::Logfile is imported via
# the XTracker:: 'use' chain otherwise it will pick up 'default.conf'
BEGIN {
    if( ! defined $ENV{XT_LOGCONF} ){
        $ENV{XT_LOGCONF} = 'order_importer.conf';
    }
}

use XTracker::Logfile qw( xt_logger );
use XTracker::Config::Local qw( config_var config_section_slurp );

use XTracker::Database qw( schema_handle );

use Data::Printer;

my $logger = xt_logger( qw( OrderImporter ) );

my $output_dir=config_var('SystemPaths', 'xmparallel_dir');

$logger->debug("Got this output dir:".p($output_dir));

my $names = config_section_slurp('ParallelOrderImporterNames');

$logger->debug("Got these names:".p($names));

my $priority_by_shipping_method = config_section_slurp('ParallelOrderImporterShippingPriorities');
my $priority_by_business_name   = config_section_slurp('ParallelOrderImporterBusinessPriorities');

foreach (keys %$priority_by_business_name) {
    $priority_by_business_name->{uc $_}   = $priority_by_business_name->{$_};
}

foreach (keys %$priority_by_shipping_method) {
    $priority_by_shipping_method->{uc $_} = $priority_by_shipping_method->{$_};
}

# didn't want to pollute the config file with this 'we didn't find it' value
$priority_by_business_name->{UNK} = 9;

$logger->debug("Got these shipping priorities:".p($priority_by_shipping_method));
$logger->debug("Got these business priorities:".p($priority_by_business_name));

my $unique_suffix = "$$-".time."-".int(rand(1000000));

$logger->debug("Unique suffix is '$unique_suffix'");

my $default_xml_heading=qq{<?xml version="1.0" encoding="UTF-8"?>\n};

my $orders_open="<ORDERS>";
my $orders_close="</ORDERS>";

my $orders_open_nl="$orders_open\n";
my $orders_close_nl="$orders_close\n";

# feel free to make this a query against the customer table for
# customers with a category of 'Board Member' or something

my $ei_staff = {
    'natalie.massenet'        => 1,
    'mark.sebba'              => 1,
    'richard.lloyd-williams'  => 1,
    'alison.loehnis'          => 1,
    'ian.tansley'             => 1,
    'naomi.hewitt'            => 1,
    'richard.mills'           => 1,
    'stephanie.phair'         => 1,
};


# we fetch all shipping_charges in one DB hit, transform them into
# shipping_methods, and cache them in a hash, rather than doing a DB
# hit per order that we need to process
#
# I outrageously presume that the overhead of hitting the DB
# is big enough that doing it once, even if the result set is
# dozens of rows, is lighter-weight that doing it even twice
# with a result set of one row each time
#
# this adds a start-up penalty to the script, but it's
# pretty unavoidable if we want to set priority based on
# SKU rather than DESCRIPTION, which we have to support
# if we're going to accommodate translated product
# descriptions

# alternatives, such as squirting out the SKUs and their relative
# priorities into some kind of config file, as part of deployment, for
# this script to pick up seem too ugly to contemplate, when the saving
# is just a few seconds per batch of orders processed.  We always have
# that option if we decide we really need those seconds and
# we're still running these scripts to do order importing...
#
# and remember, the start-up penalty for this script is *not* in the
# order import process directly -- we're just shuffling data around
# in input queues here, and we can do that in parallel across all
# the files we've been handed, so it shouldn't be so bad

my $shipping_methods_by_sku = _get_shipping_methods( schema_handle(),
                                                     $logger );

my $order_defaults = {
             body => '',
    business_name => 'UNK',
  shipping_method => 'UNRECOGNIZED',
  fallback_method => 'UNRECOGNIZED',
     order_number => 'ORDER-NO',
        nap_buyer => 0,
      is_ei_staff => 0,
 contains_voucher => 0,
};

# ensure that we do have a default priority that works
$priority_by_shipping_method->{$order_defaults->{shipping_method}} = 31
    unless $priority_by_shipping_method->{$order_defaults->{shipping_method}};

# sequence number on the end of file names to protect us from
# where the same order number is detected in more than one file,
# which includes where we were unable to detect the order number at all

my $order_file_number=1;

my $next_order = { };
my $xml_heading;

# set the defaults for the first order we process
$next_order->{$_} = $order_defaults->{$_} foreach keys %$order_defaults;

my $processing_orders = 0;
my $order_count = 0;

LINE:
while (<>) {
    if (m{\A<\?xml\s}) {
        $xml_heading = $_;
        next LINE;
    }

    if (m{$orders_open}) {
        $logger->warn( "Found unexpected '$orders_open' within '$orders_open'\n" )
            if $processing_orders > 0;

        ++$processing_orders;

        next LINE;
    }

    $next_order->{body} .= $_ if m{<ORDER\b}..m{</ORDER>};

    # include multiple versions of OUTNET and JCHOO names in case some
    # naughty person changes them
    #
    # bonus feature -- ready for DC3!
    if (m{<ORDER\b.*\bCHANNEL="(?<business_name>OUTNET|OUT|JCHOO|JC|NAP|MRP)-(?:AM|INTL|APAC)"}) {
        $next_order->{business_name}=$+{business_name};
        # does not have next LINE, because of the following rule
    }

    if (m{<ORDER\b.*\bO_ID="(?<order_number>\d+)"}) {
        $next_order->{order_number}=$+{order_number};
        next LINE;
    }

    if (m{<EMAIL>(?<nap_email_address>[^<\@]+)\@(?i:net-a-porter|mrporter|theoutnet).com</EMAIL>}) {
        $next_order->{nap_buyer}=1;
        $next_order->{is_ei_staff}=1 if exists $ei_staff->{lc ($+{nap_email_address})};
        next LINE;
    }

    if (m{<ORDER_LINE_VIRTUAL_VOUCHER}) {
        $next_order->{contains_voucher} = 1;
        next LINE;
    }

    # try to discover shipping priority by SKU, because
    # translation means we can no longer rely on shipping item
    # descriptions being in English
    #
    # letters are in the SKU patter because JCHOO SKUs are actually
    # not SKUs, but strings like 'londonpremierzoneb'

    if (m{<ORDER_LINE\b.*\bSKU="\s*(?<sku>[0-9a-z-]+)\s*"}i) {
        my $sku = $+{sku};

        if ( $sku
             && exists $shipping_methods_by_sku->{ $sku }
             &&        $shipping_methods_by_sku->{ $sku } ) {
            my $method = $shipping_methods_by_sku->{ $sku };

            $next_order->{shipping_method} = $method;

            $logger->info("Setting shipping method to '$method' based on SKU '$sku'");

            next LINE;
        }
    }

    if (   $next_order->{shipping_method} eq $order_defaults->{shipping_method}
        && $next_order->{fallback_method} eq $order_defaults->{fallback_method} ) {
        # then look for a fallback method in the item description, and stash it for later

        if (m{<ORDER_LINE\b.*\bDESCRIPTION="(?:[^"]+\s+)?(?<fallback_method>Standard|International|Express|Ground|Premier|Daytime)\b(?:\s+\d+\b)?"}i) {
            my $method = uc($+{fallback_method});

            $logger->info("Setting fallback method to '$method' based on DESCRIPTION extract 1 '$+{fallback_method}'");

            $next_order->{fallback_method} = $method;

            next LINE;
        }

        if (m{<ORDER_LINE\b.*\bDESCRIPTION="(?:\s*)?(?<fallback_method>Daytime|Evening)\b(?:,\s*[^"]*)?"}i) {
            $logger->info("Setting fallback method to 'DAYTIME' based on DESCRIPTION extract 2 '$+{fallback_method}'");

            $next_order->{fallback_method} = 'DAYTIME';

            next LINE;
        }
    }

    if (m{</ORDER>}) {

        if (   $next_order->{shipping_method} eq $order_defaults->{shipping_method}
            && $next_order->{fallback_method} ne $order_defaults->{fallback_method}) {
            # we didn't find a SKU, but we did find a description we could parse

            $logger->info("Setting shipping method to fallback method '$next_order->{fallback_method}'");

            $next_order->{shipping_method} = $next_order->{fallback_method};
        }

        if ($next_order->{nap_buyer}) {
            # actually, although it might seem silly or even
            # contradictory, we do need both of these checks, because
            # the method can be set to either of 'PREMIER' or 'STAFF'
            # by _determine_shipping_method_from_charge() for staff
            # orders, and this happens independently of the check for
            # EIP-ness

            my $shipping_method = $next_order->{shipping_method};

            if ($shipping_method eq 'PREMIER') {
                unless ($next_order->{is_ei_staff}) {
                    $logger->info("Switching NAP buyer premier order $next_order->{order_number} to STAFF");

                    $next_order->{shipping_method} = 'STAFF';
                }
            }
            elsif ($shipping_method eq 'STAFF') {
                if ($next_order->{is_ei_staff}) {
                    $logger->info("Switching EI staff order $next_order->{order_number} to PREMIER");

                    $next_order->{shipping_method} = 'PREMIER';
                }
            }
            else {
                # shouldn't happen, don't touch the priority, but whine a little
                # CANDO-3255: NAP Group emails no longer default to Staff
                #$logger->info("Order $next_order->{order_number} is by NAP buyer, but has unexpected shipping method '$shipping_method'\n");
            }
        }

        $logger->info("Not able to discover order number for order sequence number $order_file_number")
            if $next_order->{order_number} eq $order_defaults->{order_number};

        $logger->info("Not able to discover business name for order sequence number $order_file_number")
            if $next_order->{business_name} eq $order_defaults->{business_name};

        if ($next_order->{shipping_method} eq $order_defaults->{shipping_method}) {
            if ($next_order->{contains_voucher}) {
                # vouchers go in the middle of the queue
                $logger->info("Setting shipping method for voucher-only order $next_order->{order_number} to STANDARD");

                $next_order->{shipping_method} = 'STANDARD';
            }
            else {
                $logger->info("Not able to discover shipping method for order sequence number $order_file_number")
            }
        }

        unless (exists $priority_by_shipping_method->{$next_order->{shipping_method}}) {
            $logger->warn("Arrived at unprioritized shipping method '$next_order->{shipping_method}' for order sequence number $order_file_number\n");

            $next_order->{shipping_method} = $order_defaults->{shipping_method};
        }

        unless (exists $priority_by_business_name->{$next_order->{business_name}}) {
            $logger->warn("Arrived at unprioritized business name '$next_order->{business_name}' for order sequence number $order_file_number\n");

            $next_order->{business_name} = $order_defaults->{business_name};
        }

        if ( exists $next_order->{body} ) {
            my $pri_chan_name=sprintf(
                '%02d-%s',
                $priority_by_shipping_method->{$next_order->{shipping_method}},
                $next_order->{shipping_method}
            );

            my $stream_dir="$output_dir/$pri_chan_name";

            my $dirs = { map { $_ => "$stream_dir/$names->{$_}" } keys %$names };

            $logger->debug( "Got these dirs: ".p($dirs) );

            # we have to make them all, since nothing else now does
            foreach my $dir (values %$dirs) {
                unless (-d $dir) {
                    $logger->debug( "Making path for '$dir'" );

                    make_path($dir)
                        or $logger->warn( "Unable to make path for '$dir'");

                    $logger->debug( "Path made for '$dir'" ) if -d $dir;
                }
            }

            # note that %03d doesn't limit the file number to 999, it just
            # prevents it from having a ridiculous number of leading digits

            my $order_file=sprintf(
                '%01d-%s-order-%s-%03d.xml',
                $priority_by_business_name->{$next_order->{business_name}},
                $next_order->{business_name},
                $next_order->{order_number},
                $order_file_number++
            );

            # unique suffix is present on incoming file to avoid clashes
            # on file creation from accidentally concurrent instances of
            # this process from the same data
            #
            # that the results eventually get renamed to the same target
            # doesn't matter, because if either process is working from the
            # same data, it'll produce the same output file, so whichever
            # one finishes last wins, and nothing is lost

            my $incoming_path="$dirs->{incoming}/$order_file.$unique_suffix";
            my    $ready_path="$dirs->{ready}/$order_file";

            # We're using the open pragma to enforce UTF-8 encoding
            open (my $order_fd, '>', $incoming_path)
                or $logger->logdie( "Cannot open '$incoming_path' for writing: $@\n" );

            unless ($xml_heading) {
                $logger->warn( "Don't have an XML heading -- using canned default\n" );
                $xml_heading = $default_xml_heading;
            }

            print $order_fd $xml_heading, $orders_open_nl, $next_order->{body}, $orders_close_nl
                or $logger->logdie( "Cannot write order data to '$incoming_path': $@\n" );

            close $order_fd
                or $logger->logdie( "Closing '$incoming_path' after writing failed: $@\n" );

            rename($incoming_path,$ready_path)
                or $logger->logdie( "Cannot rename '$incoming_path' to '$ready_path': $@\n" );

            $logger->info( "Split order ID $next_order->{order_number} onto stream '$pri_chan_name'\n" );

            ++$order_count;
        }
        else {
            $logger->warn( "Got to order file export with an empty order body -- SKIPPING\n" );
        }

        # reset the defaults for the next order
        $next_order->{$_} = $order_defaults->{$_} foreach keys %$order_defaults;
    }

    if (m{$orders_close}) {
        $logger->warn( "Found extra '$orders_close'\n" )
            if $processing_orders <= 0;

        --$processing_orders;

        next LINE;
    }
}

$logger->info( "Orders split: $order_count\n" );

if ($processing_orders > 0) {
    $logger->warn( "Unexpected end of input\n" );

    exit 1;
}

exit 0;

=head1

    C<get_shipping_methods> returns a ref to a hash, keyed by SKU, of
    the shipping method associated with that SKU.

=cut

sub _get_shipping_methods {
    my ($schema, $logger) = @_;

    my $results = { };

  RESULT:
    foreach my $result ( $schema->resultset('Public::ShippingCharge')
                                ->search( { is_enabled => 1 } )
                                ->all() ) {
        my $sku = $result->sku;

        next RESULT unless $sku; # yes, there are some blank SKUs

        my $method = _determine_shipping_method_from_charge( $result )
                         || $order_defaults->{shipping_method};

        if ( exists $results->{ $sku } ) {
            if ( $method eq $results->{ $sku } ) {
                $logger->warn( "Duplicate SKU '$sku' with same method '$method'\n" );
            }
            else {
                $logger->warn( "Duplicate SKU '$sku' with different method: was '$results->{$sku}', now '$method'\n" );
            }
        }

        $results->{ $sku } = $method;
    }

    return $results;
}


=head1

Returns the name of the shipping method associated with the
shipping_charge row provided.

The results from this function ought to match the property
names in the I<ParallelOrderImporterShippingPriorities>
config section, otherwise they'll be mapped to the default.

Returns undef when the method can't be determined -- we rely on the
caller to set policy on how undeterminable methods are handled, rather
than imposing the choice here.

=cut

sub _determine_shipping_method_from_charge {
    my $result = shift;

    return unless $result;

    my $charge_info = {
        class               => uc( $result->shipping_charge_class->class ),
        description         => uc( $result->description ),

        has_premier_routing =>     $result->premier_routing
                                          ? 1
                                          : 0,

        has_nom_time        =>     $result->latest_nominated_dispatch_daytime
                                          ? 1
                                          : 0,
    };

    # only three shipping charge classes that we recognize
    if ( $charge_info->{class} eq 'GROUND' ) {
        return 'GROUND';
    }
    elsif ( $charge_info->{class} eq 'SAME DAY' ) {
        # this includes nominated day and premier,
        # so let's disambiguate those

        if ( $charge_info->{has_nom_time} ) {
            # nominated day
            return 'DAYTIME';
        }
        elsif ( $charge_info->{has_premier_routing} ) {
            # other premier
            return 'PREMIER';
        }
        elsif ( $charge_info->{description} =~ m{\bSTAFF\b} ) {
            # staff
            return 'STAFF';
        }
        # else unrecognized
    }
    elsif ( $charge_info->{class} eq 'AIR' ) {
        if ( $charge_info->{description} =~ m{\bEXPRESS\b} ) {
            return 'EXPRESS';
        }
        elsif ( $charge_info->{description} =~ m{\bINTERNATIONAL\b} ) {
            return 'INTERNATIONAL';
        }
        else {
            return 'STANDARD';
        }
    }
    # else unrecognized

    return;
}
