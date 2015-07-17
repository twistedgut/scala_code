package XTracker::Vertex;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Carp;
use Data::Dump qw(pp);

use SOAP::Vertex '0.0.3';
use SOAP::Vertex::InvoiceRequestDoc;
use SOAP::Vertex::QuotationRequestDoc;

use XTracker::Config::Local;
use XTracker::Database qw/ get_schema_using_dbh /;
use XTracker::Database::Shipment qw( get_shipment_item_info get_shipping_address get_shipment_order_id );
use XTracker::Database::Invoice qw( get_shipment_invoices get_invoice_info get_invoice_item_info );
use XTracker::Database::Order qw( get_order_info );
use XTracker::Logfile qw( xt_logger );
use XTracker::Utilities qw( string_in_list :string );

use Number::Format qw( :subs );

use Perl6::Export::Attrs;

use DateTime;
use File::Copy;
use File::Spec::Functions   qw( catdir catfile );
use File::Path              qw( mkpath );


sub vertex_enabled :Export {
    my $enabled;
    my $config_var = config_var('Vertex', 'enabled');

    # if config_var doesn't exist, then we're disabled
    if (not defined $config_var) {
        return;
    }

    # only 'yes' will enable vertex
    $enabled = ('yes' eq $config_var);

    return $enabled;
}

sub is_in_new_york_state :Export {
    my ($data_ref) = @_;

    # make sure we're in the right country
    if ($data_ref->{country} !~ m{\AUnited States\z}i) {
        return;
    }

    # make sure the postcode is defined
    if (not defined $data_ref->{postcode}) {
        return;
    }

    # make sure we've got a 5-digit zipcode format
    # (this means we can do mathematical comparisons on the value shortly)
    if ($data_ref->{postcode} !~ m{\A\d{5}\z}) {
        return;
    }

    # for now we'll use the list from http://www.mongabay.com/igapo/zip_codes_ny.htm
    # i.e. 00501, 00544, 06390 and 10001-14925
    ## three special cases
    if ($data_ref->{postcode} =~ m{\A(?:00501|00544|06390)\z}) {
        return 1;
    }
    ## generic range
    if ( ($data_ref->{postcode} >= 10001) and ($data_ref->{postcode} <= 14925) ) {
        return 1;
    }

    # anything else must be a non-match ...
    return;
}

### Subroutine : in_vertex_area                         ###
# usage        : in_vertex_area($shipping_address_hashref)#
# description  :                                          #
# parameters   : $shipping_address                        #
# returns      : 1 or undefined                           #
sub in_vertex_area :Export {
    my ($data_ref) = @_;

    if (not ref($data_ref)) {
        Carp::carp( q{non-reference variable passed to in_vertex_area()} );
        xt_logger->error( q{non-reference variable passed to in_vertex_area()} );
        return;
    }

    # if country is missing there's not much we can do
    if (not defined $data_ref->{country}) {
        Carp::carp( q{no country information passed to in_vertex_area()} );
        xt_logger->error( q{no country information passed to in_vertex_area()} );
        return;
    }

    # if we're [shipping to] Canada - yep, it's a Vertex area!
    if ($data_ref->{country} =~ m{\ACanada\z}i) {
        return 1;
    }

    # if we're in the USA and we have "an appropriate" zip-code
    if ($data_ref->{country} =~ m{\AUnited States\z}i) {
        if (is_in_new_york_state($data_ref)) {
            return 1;
        }
    }

    # we failed the tests .. obviously not in Vertex-Ville
    return;
}

sub use_vertex :Export {
    my ($data_ref) = @_; # location data

    # we only use vertex if vertex is enabled and we're in the vertex_area
    my $use_vertex;
    $use_vertex = (vertex_enabled() and in_vertex_area($data_ref));

    return $use_vertex;
}

# this returns the value stored in public.orders.use_external_tax_rate in the database
sub use_external_tax_rate :Export {
    my ($dbh, $shipment_id) = @_;
    my ($order_id, $order_info, $use_external_tax_rate);

    # get the order id for the given shipment
    $order_id = get_shipment_order_id($dbh, $shipment_id);

    # get the order_info for the shipment's order
    $order_info = get_order_info($dbh, $order_id);

    # whether or not to use the external tax service (aka Vertex)
    $use_external_tax_rate = $order_info->{use_external_tax_rate} || 0;

    return $use_external_tax_rate;
}

sub use_vertex_for_pre_order :Export(:pre_order) {
    my ($pre_order) = @_;
    return 0 unless vertex_enabled();

    return 0 unless $pre_order;

    my $shipment_address = $pre_order->shipment_address;

    return $shipment_address->in_vertex_area;
}

sub use_vertex_for_pre_order_id :Export(:pre_order) {
    my ($dbh, $pre_order_id) = @_;
    return 0 unless vertex_enabled();

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    my $pre_order = $schema->resultset('Public::PreOrder')->find( $pre_order_id );

    return 0 unless $pre_order;

    return use_vertex_for_pre_order( $pre_order );
}

sub use_vertex_for_shipment :Export {
    my ($dbh, $shipment_id) = @_;
    my ($shipping_address, $use_vertex);

    # if we're disabled in the config file, don't use vertex
    if (not vertex_enabled()) {
        return 0;
    }

    # XXX we currently don't care about deducing the location/etc ourselves and
    # XXX just use the value of "use_external_tax_rate" passed in orders.xml from the website
    my $use_external_tax_rate = use_external_tax_rate($dbh, $shipment_id);
    return $use_external_tax_rate;
}

sub use_vertex_for_invoice :Export {
    my ($dbh, $arg_ref) = @_;
    my ($use_vertex);

    # get invoice info
    my $invoice_info = get_invoice_info(
        $dbh,
        $arg_ref->{invoice_id}
    );

    # now we can call use_vertex_for_shipment() :)
    $use_vertex = use_vertex_for_shipment($dbh, $invoice_info->{shipment_id});

    return $use_vertex;
}

sub create_vertex_quotation_from_shipment :Export {
    my ($dbh, $arg_ref) = @_;
    my ($shipment_items, $shipping_address, $vertex_qrd);
    # SOAP object class
    $vertex_qrd = _new_quotation_request_object();
    # make sure we got an object back
    if (not defined $vertex_qrd) {
        Carp::carp( q{failed to create a new SOAP::Vertex::QuotationRequestDoc object} );
        xt_logger->error( q{failed to create a new SOAP::Vertex::QuotationRequestDoc object} );
        return;
    }

    # populate data from the shipment (specified as $arg_ref->{shipment_id})
    _populate_vertex_customer_address_and_shipment_items(
        $vertex_qrd,
        $dbh,
        $arg_ref
    );

    return $vertex_qrd;
}

# never mind passing dbh's around all over the, just give me a DBIC object
sub create_vertex_quotation_request_from_pre_order :Export(:pre_order) {
    my $pre_order = shift;

    # SOAP object class
    my $vertex_qrd = _new_quotation_request_object();

    die q{Failed to create a new SOAP::Vertex::QuotationRequestDoc object}
        unless $vertex_qrd;

    _populate_vertex_customer_address_and_pre_order_items(
        $vertex_qrd, $pre_order
    );

    xt_logger->debug( "create_vertex_quotation_from_pre_order(): post-populate: ".$vertex_qrd->get_soap_data() );
    xt_logger->debug( "create_vertex_quotation_from_pre_order(): post-seller: ".$vertex_qrd->get_soap_data() );

    # set the transaction type
    $vertex_qrd->set_transaction_type('SALE');

    return $vertex_qrd;
}

sub do_external_soap_call :Export(:external_call) {
    my ( $soap_call_script, $vertex_qrd, $pre_order ) = @_;

    # go the long way around in a dragon-proof schooner

    my $vertex_soap_path = config_var('SystemPaths','soap_vertex_dir');
    my $script_dir_path  = config_var('SystemPaths','script_dir');

    # these better have values, or we're boned anyway
    my $soap_user = config_var('Vertex', 'soap_user') ;
    my $soap_pass = config_var('Vertex', 'soap_password') ;
    my $soap_host = config_var('Vertex', 'soap_host') ;
    my $soap_port = config_var('Vertex', 'soap_port') ;

    my $now = DateTime->now();

    my $date_dir     = $now->ymd('');
    my $request_dir_path = catdir( $vertex_soap_path, 'request',  $date_dir );
    my $response_dir_path= catdir( $vertex_soap_path, 'response', $date_dir );
    my $error_dir_path   = catdir( $vertex_soap_path, 'error',    $date_dir );

    my $script_path  = catfile( $script_dir_path, $soap_call_script );

    my $unique_file_name = sprintf "%s-%s-%s", $now->hms(''), $pre_order->pre_order_number, $$;

    my $request_path  = catfile( $request_dir_path, $unique_file_name );
    my $response_path = catfile( $response_dir_path, $unique_file_name );
    my $error_path    = catfile( $error_dir_path, $unique_file_name );

    foreach my $path ( ( $request_dir_path, $response_dir_path, $error_dir_path ) ) {
        # do NOT combine these into unless ( -d ...) { mkpath ... or die ... }
        #
        # it's not the same, because mkpath can fail, but the directory can still
        # exist anyway, because a race condition with another request created it
        # for us between the test and our mkpath -- in that case, we should continue

        mkpath ( $path ) unless -d $path;

        die( "Vertex quotation request failed: unable to create '$path'\n" )
            unless -d $path;
    }

    # write the request to the request file
    #
    open( my $request_fd, '>:encoding(UTF-8)', $request_path )
        or die( "Vertex quotation request failed: unable to open '$request_path' for writing\n" );

    my $soap_data = $vertex_qrd->get_soap_data();

    $soap_data->{username} = $soap_user;
    $soap_data->{password} = $soap_pass;

    my $vertex_xml = $vertex_qrd->_package_xml( $soap_data );

    print $request_fd $vertex_xml
        or die( "Vertex quotation request failed: unable to write to '$request_path'\n" );

    close $request_fd
        or warn( "close '$request_path' after writing returned $!\n" );

    # do the request
    #
    my $cmd_return = eval {

        my $env = qq{VERTEX_SOAP_HOST='$soap_host' VERTEX_SOAP_PORT='$soap_port' VERTEX_SOAP_USER='$soap_user' VERTEX_SOAP_PASS='$soap_pass'};

        my $cmdline = qq{$env '$script_path' '$request_path' '$response_path' '$error_path'};

        `$cmdline`; ## no critic(ProhibitBacktickOperators)
    };

    if (my $e = $@) {
        die( "Vertex quotation request failed: $script_path failed: $e\n" );
    }

    # check for errors
    #

    if ( -f $error_path && -s $error_path ) {
        my $error_result;

        if ( open( my $error_fd, '<:encoding(UTF-8)', $error_path) ) {
            local $/ = undef;

            $error_result=eval { <$error_fd> };

            close $error_fd;
        }
        else {
            $error_result = "unable to read error message '$error_path'";
        }

        die( "Vertex quotation request failed: "._clean_up_vertex_error($error_result) );
    }

    # inhale the response as if this is the normal way to do things
    #

    my $soap_result;

    if ( -f $response_path && -s $response_path ) {
        if ( open( my $response_fd, '<:encoding(UTF-8)', $response_path) ) {
            eval {
                local $/ = undef;
                my $response_body = <$response_fd>;
                close $response_fd;

                require Data::Serializer;

                my $serializer = Data::Serializer->new();
                $soap_result = $serializer->thaw( $response_body );
            };

            if ( my $e = $@ ) {
                die( "Vertex quotation request failed: unable to thaw response '$response_path': $e\n" );
            }
        }
        else {
            die( "Vertex quotation request failed: unable to read response '$response_path'\n" );
        }
    }
    else {
        die( "Vertex quotation request failed: unable to find response '$response_path'\n" );
    }

    return $soap_result;
}

sub create_vertex_quotation_from_pre_order :Export(:pre_order) {
    my ( $pre_order ) = @_;
    my $vertex_qrd = create_vertex_quotation_request_from_pre_order( $pre_order );

    my $soap_call_script = config_var('Vertex','soap_call_script');

    if ( $soap_call_script ) {
        return do_external_soap_call( $soap_call_script, $vertex_qrd, $pre_order );
    }
    else {
        # happy happy internal path through the valley of memory dragons
        my $soap_result = $vertex_qrd->soap_call( $vertex_qrd->get_soap_data() );

        if ( $soap_result ) {
            return $soap_result;
        }
        else {
            die "Vertex quotation request failed: "._clean_up_vertex_error( $vertex_qrd->get_soap_error() );
        }
    }
}

sub update_pre_order_from_vertex_quotation :Export(:pre_order) {
    my ( $pre_order, $vertex_quotation ) = @_;

    my $poi_count = $pre_order->pre_order_items->available_to_cancel->count;

    # don't even bother trying unless we have some pre-order items update
    return unless $poi_count;

    # equally, don't bother unless there is a sensible data structure
    # attached to the quotation request

    return unless $vertex_quotation
        && exists $vertex_quotation->{QuotationResponse}
        && exists $vertex_quotation->{QuotationResponse}{LineItem};

    my $vertex_line_items = $vertex_quotation->{QuotationResponse}{LineItem};

    return unless $vertex_line_items;

    $vertex_line_items = [ $vertex_line_items ]
        unless ref $vertex_line_items eq 'ARRAY';

    my $line_item_count = scalar @{$vertex_line_items};

    # now this is probably a bug, so assplode...

    die "Quotation and pre-order item counts do not match"
        unless $line_item_count == $poi_count;

    my $poi_ordered_rs = $pre_order->pre_order_items
                                   ->available_to_cancel
                                   ->order_by_id->reset;

    for my $i (0..$line_item_count-1) {
        my $poi       = $poi_ordered_rs->next;
        my $line_item = $vertex_line_items->[$i];

        my $new_tax = round( $line_item->{TotalTax} || 0 );
        my $poi_tax = $poi->tax   || 0;

        if ( $poi_tax != $new_tax ) {
            xt_logger->debug("updating pre_order_item->tax from $poi_tax to $new_tax");

            $poi->update( { tax => $new_tax } );
        }
    }

    $pre_order->discard_changes;

    my $total_value = $pre_order->total_value;
    my $new_total   = round( $pre_order->pre_order_items
                                       ->available_to_cancel
                                       ->total_value );

    if ( $new_total != $total_value ) {
         xt_logger->debug( "updating pre_order total value from $total_value to $new_total" );

         $pre_order->update( { total_value => $new_total } );
    }

    return $pre_order;
}

# never mind passing dbh's around all over the, just give me a DBIC object
sub create_vertex_invoice_from_pre_order :Export(:pre_order) {
    my ($pre_order) = @_;

    # SOAP object class
    my $vertex_ird = _new_invoice_request_object();

    die q{Failed to create a new SOAP::Vertex::InvoiceRequestDoc object}
        unless $vertex_ird;

    # populate data from the pre-order (specified as $arg_ref->{pre_order_id})
    _populate_vertex_customer_address_and_pre_order_items(
        $vertex_ird, $pre_order
    );

    xt_logger->debug( "create_vertex_invoice_from_pre_order(): post-populate: ".$vertex_ird->get_soap_data() );

    # add the seller information for invoices
    _populate_vertex_seller_information( $vertex_ird, 'DC2' );

    xt_logger->debug( "create_vertex_invoice_from_pre_order(): post-seller: "  .$vertex_ird->get_soap_data() );

    # set the transaction type
    $vertex_ird->set_transaction_type('SALE');

    my $soap_result = $vertex_ird->soap_call( $vertex_ird->get_soap_data() );

    xt_logger->debug( "create_vertex_invoice_from_pre_order(): post_request: ".$vertex_ird->get_soap_data() );
    xt_logger->debug( "create_vertex_invoice_from_pre_order(): soap_result: ".$soap_result->get_soap_data() );

    die "Vertex invoice request failed: "._clean_up_vertex_error( $vertex_ird->get_soap_error() )
        unless $soap_result;

    return $soap_result;
}

sub create_vertex_invoice_from_xt_id :Export {
    my ($dbh, $arg_ref) = @_;
    my ($vertex_ird, $soap_result);
    xt_logger->debug( qw{create_vertex_invoice_from_xt_id called} );

    # SOAP Object class
    xt_logger->debug( qq{calling: $vertex_ird = _new_invoice_request_object();} );
#    warn( qq{calling: $vertex_ird = _new_invoice_request_object();} );
    $vertex_ird = _new_invoice_request_object();
    # make sure we got an object back
    if (not defined $vertex_ird) {
        #Carp::carp( q{failed to create a new SOAP::Vertex::InvoiceRequestDoc object} );
        xt_logger->error( q{failed to create a new SOAP::Vertex::InvoiceRequestDoc object} );
        return;
    }

    # make sure we have either a shipment_id or invoice_id
    xt_logger->debug( qq{# make sure we have either a shipment_id or invoice_id} );
#    warn( qq{# make sure we have either a shipment_id or invoice_id} );
    if (not defined $arg_ref->{shipment_id} and not defined $arg_ref->{invoice_id}) {
        #Carp::carp( q{you must pass 'shipment_id' or 'invoice_id' in $arg_ref} );
        xt_logger->error( q{you must pass 'shipment_id' or 'invoice_id' in $arg_ref} );
        return;
    }

    # populate data from the shipment (specified as $arg_ref->{shipment_id})
    # or from the invoice (specified as $arg_ref->{invoice_id})
    xt_logger->debug( qq{# populate data from the shipment (specified as $arg_ref->{shipment_id})} );
#    warn( qq{# populate data from the shipment (specified as $arg_ref->{shipment_id})} );
    _populate_vertex_customer_address_and_shipment_items(
        $vertex_ird,
        $dbh,
        $arg_ref
    );

    # add the seller information
    xt_logger->debug( qq{# add the seller information} );
#    warn( qq{# add the seller information} );
    _populate_vertex_seller_information( $vertex_ird, 'DC2' );

    # set the transaction type
    $vertex_ird->set_transaction_type('SALE');

    # now we have a populated object, let's make a request to the server
    xt_logger->debug( qq{# now we have a populated object, let's make a request to the server} );
#    warn( qq{# now we have a populated object, let's make a request to the server} );
    $soap_result = $vertex_ird->soap_call(
        $vertex_ird->get_soap_data(),
    );
    if (not defined $soap_result) {
        #Carp::carp( $vertex_ird->get_soap_error() );
        xt_logger->error( $vertex_ird->get_soap_error() );
        return;
    }
    else {
        #Carp::carp( pp($soap_result) );
        #xt_logger->error( pp($soap_result) );
    }

    #warn( pp($soap_result) );
    #Carp::carp( qw{create_vertex_invoice_from_xt_id completed} );
    xt_logger->error( qw{create_vertex_invoice_from_xt_id completed} );
#    warn( qw{create_vertex_invoice_from_xt_id completed} );
    return $soap_result;
}


sub _populate_vertex_seller_information {
    my ($vertex_obj, $shipping_source) = @_;
    my ($config_section, $soap_data);

    # for now we only have one shipping source (DC2)
    if (not defined $shipping_source) {
        $shipping_source = 'DC2';
    }

    # check the config for a section called shipping_source_<$shipping_source>
    if (not config_section_exists(qq{shipping_source_${shipping_source}})) {
        Carp::carp( qq{shipping_source_${shipping_source} not defined in xtracker.conf - unable to populate seller information} );
        xt_logger->error( qq{shipping_source_${shipping_source} not defined in xtracker.conf - unable to populate seller information} );
        return;
    }

    # less typing, and easier to read
    $config_section = qq{shipping_source_${shipping_source}};

    # use config data to set the company name
    $vertex_obj->set_company_name(
        config_var($config_section, 'company_name')
    );

    # add seller information to the vertex object
    $vertex_obj->set_seller_location(
        {
            city            => config_var($config_section, 'city')          || undef,
            main_division   => config_var($config_section, 'main_division') || undef,
            sub_division    => config_var($config_section, 'sub_division')  || undef,
            postal_code     => config_var($config_section, 'postal_code')   || undef,
            country         => config_var($config_section, 'country')       || undef,
        }
    );

    return;
}

sub _populate_vertex_customer_address_and_shipment_items {
    my ($vertex_obj, $dbh, $arg_ref) = @_;
    my ($items, $shipment_id, $shipping_address, $invoice, @invoice_ids, $order_id, $order_info);

    # make sure vertex_obj and dbh are of the right type
    if (not ref($vertex_obj) or ref($vertex_obj) !~ m{\ASOAP::Vertex::}) {
        Carp::carp( q{$vertex_object be a SOAP::Vertex::* object} );
        xt_logger->error( q{$vertex_object be a SOAP::Vertex::* object} );
        return;
    }
    if (not ref($dbh) or ref($dbh) !~ m{DBI}) {
        Carp::carp( q{$dbh be a DBI object} );
        xt_logger->error( q{$dbh be a DBI object} );
        return;
    }

    # make sure we've been given a shipment_id or an invoice_id
#    warn qq{# make sure we've been given a shipment_id or an invoice_id};
    if (not defined $arg_ref->{shipment_id} and not defined $arg_ref->{invoice_id}) {
        Carp::carp( q{you must pass 'shipment_id' or 'invoice_id' in $arg_ref} );
        xt_logger->error( q{you must pass 'shipment_id' or 'invoice_id' in $arg_ref} );
        return;
    }

    # if we've been given a shipment_id ...
    if (defined $arg_ref->{shipment_id}) {
        my ($invoice_data, @invoice_ids);
        xt_logger->debug( q{_populate_vertex_customer_address_and_shipment_items with a shipment_id} );

        # set $shipment_id
        $shipment_id = $arg_ref->{shipment_id};

        # get the items by shipment_id
        $items = get_shipment_item_info(
            $dbh,
            $arg_ref->{shipment_id}
        );
        # make sure we fetched some items - annoyingly we don't return undef for "no results"
        if (not defined $items or not keys %{$items}) {
            Carp::carp( qq{failed to fetch items for shipment #$arg_ref->{shipment_id}} );
            xt_logger->error( qq{failed to fetch items for shipment #$arg_ref->{shipment_id}} );
            return;
        }

        ## fetch the invoice [a la Highlander there should be only one!]
        INVOICE: {
            # get the invoice number for the shipment
            $invoice_data = get_shipment_invoices( $dbh, $shipment_id );
            @invoice_ids = keys %{ $invoice_data };

            # panic if we have more than one invoice ..
            if (scalar @invoice_ids > 1) {
                Carp::carp( qq{more than one invoice was returned for shipment $shipment_id} );
                xt_logger->error( qq{more than one invoice was returned for shipment $shipment_id} );
                return;
            }
            # panic if we don't have any invoices
            if (scalar @invoice_ids == 0) {
                Carp::carp( qq{no invoice was returned for shipment $shipment_id} );
                xt_logger->error( qq{no invoice was returned for shipment $shipment_id} );
                return;
            }

            # set the invoice
            $invoice = $invoice_data->{ $invoice_ids[0] };
        }
    }
    # if we've been given an invoice_id ...
    elsif (defined $arg_ref->{invoice_id}) {
        xt_logger->debug( q{_populate_vertex_customer_address_and_shipment_items with an invoice_id} );
        # get the items by invoice_id
        xt_logger->debug( qq{get_invoice_item_info(..., $arg_ref->{invoice_id})} );
        $items = get_invoice_item_info(
            $dbh,
            $arg_ref->{invoice_id}
        );
        # make sure we fetched some items
        if (not defined $items or not keys %{$items}) {
            Carp::carp( qq{failed to fetch items for invoice #$arg_ref->{invoice_id}} );
            xt_logger->error( qq{failed to fetch items for invoice #$arg_ref->{invoice_id}} );
            return;
        }

        # get invoice info
        my $invoice_info = get_invoice_info(
            $dbh,
            $arg_ref->{invoice_id}
        );

        # set the invoice
        $invoice = $invoice_info;

        # set the shipment_id
        $shipment_id = $invoice_info->{shipment_id};
    }
    # we shouldn't get here because of the earlier "not defined" check foir invoice/shipment id
    else {
        Carp::confess( q{I don't know how we arrived here} );
        xt_logger->error( q{I don't know how we arrived here} );
        return; # we should be dead, and this should never happen
    }

    # debugging
    xt_logger->debug( qq{shipment_id: $shipment_id} );
    xt_logger->debug( qq{invoice_id:  $invoice->{invoice_nr}} );


    # get the shipment_address by the shipment_id in the invoice
    $shipping_address = get_shipping_address(
        $dbh,
        $shipment_id
    );

    # add the shipping address to the quotation
    _populate_vertex_customer_address( $vertex_obj, $shipping_address );

    # set the document date from the date returned in the shipping address data
    $vertex_obj->set_document_date( $shipping_address->{date} );

    # set the documentNumber to be the current invoice number
    $vertex_obj->set_document_number( $invoice->{invoice_nr} );

    # add the customer ID as the customercode used in the SOAP request
    ## get the order-id
    $order_id = get_shipment_order_id( $dbh, $shipment_id );
    ## get the order info
    $order_info = get_order_info( $dbh, $order_id );
    ## store the info in the SOAP data
    $vertex_obj->set_customer_code( $order_info->{customer_id} );

    # add the shipping items to the quotation
    xt_logger->debug( q{populating line-item information} );
    xt_logger->debug( pp($items) );
    _populate_vertex_lines_with_item_hash( $vertex_obj, $items );
    xt_logger->debug( q{populated line-item information} );

    return 1;
}

sub _populate_vertex_customer_address_and_pre_order_items {
    my ($vertex_obj, $pre_order) = @_;

    die q{$vertex_object be a SOAP::Vertex::* object}
        unless ref($vertex_obj)
            && ref($vertex_obj) =~ m{\ASOAP::Vertex::};

    die qq{must provide a pre-order object}
        unless $pre_order;

    _populate_vertex_customer_address(
        $vertex_obj,
        {
            # don't include address_line_n, in case they're unknown to Vertex
            towncity       => $pre_order->shipment_address->towncity,
            county         => $pre_order->shipment_address->county,
            country        => $pre_order->shipment_address->country,
            postcode       => $pre_order->shipment_address->postcode
        }
    );

    $vertex_obj->set_document_date( $pre_order->created );
    $vertex_obj->set_document_number( $pre_order->pre_order_number );

    # set class code for quotations, but customer_code for invoices, apparently
    if ( ref ($vertex_obj) =~ m{\ASOAP::Vertex::QuotationRequestDoc} ) {
        $vertex_obj->set_class_code( $pre_order->customer->is_customer_number );
    }
    else {
        $vertex_obj->set_customer_code( $pre_order->customer->is_customer_number );
    }

    my @items = ();

    foreach my $poi ( $pre_order->pre_order_items
                                ->available_to_cancel
                                ->order_by_id->all ) {
        push @items, {     unit_price => $poi->unit_price,
                       classification => $poi->variant
                                             ->product
                                             ->classification
                                             ->classification
        };
    }

    _populate_vertex_lines_with_items( $vertex_obj, \@items );
}

sub _populate_vertex_customer_address {
    my ($vertex_obj, $address) = @_;

    $vertex_obj->set_street_address(    $address->{address_line_1} || ''  );
    $vertex_obj->set_sub_division(      $address->{address_line_2} || ''  );
    $vertex_obj->set_city(              $address->{towncity}       || '' );
    $vertex_obj->set_main_division(     $address->{county}         || '' );
    $vertex_obj->set_postal_code(       $address->{postcode}       || '' );
    $vertex_obj->set_country(           $address->{country}        || '' );

    return $vertex_obj;
}

sub _populate_vertex_lines_with_item_hash {
    my ($vertex_obj, $items) = @_;

    # loop through the shipment items ...
    foreach my $item_id ( keys %{ $items } ) {
        my $li = $vertex_obj->create_lineitem(
            {
                quantity        => 1,
                unit_price      =>     $items->{ $item_id }->{unit_price},
                product_class   => uc( $items->{ $item_id }->{classification} ),
            },
        );

        $vertex_obj->add_lineitem( $li );
    }

    return $vertex_obj;
}


sub _populate_vertex_lines_with_items {
    my ($vertex_obj, $items) = @_;

    # loop through the shipment items ...
    foreach my $item ( @$items ) {
        my $li = $vertex_obj->create_lineitem(
            {
                quantity        => 1,
                unit_price      =>     $item->{unit_price},
                product_class   => uc( $item->{classification} ),
            },
        );

        $vertex_obj->add_lineitem( $li );
    }

    return $vertex_obj;
}


sub _new_quotation_request_object {
    my $vertex_qrd;

    # create a new object using options from config file
    $vertex_qrd = SOAP::Vertex::QuotationRequestDoc->new(
        {
            soap_host   => config_var('Vertex', 'soap_host') || undef,
            soap_port   => config_var('Vertex', 'soap_port') || undef,

            username    => config_var('Vertex', 'soap_user') || undef,
            password    => config_var('Vertex', 'soap_password') || undef,

            soap_trace  => config_var('Vertex', 'soap_trace') || undef,
        }
    );

    # return the new object - it's not up to this method to check that it's usable ..
    return $vertex_qrd;
}

sub _new_invoice_request_object {
    my $vertex_ird;

    # create a new object using options from config file
    $vertex_ird = SOAP::Vertex::InvoiceRequestDoc->new(
        {
            soap_host   => config_var('Vertex', 'soap_host') || undef,
            soap_port   => config_var('Vertex', 'soap_port') || undef,

            username    => config_var('Vertex', 'soap_user') || undef,
            password    => config_var('Vertex', 'soap_password') || undef,

            soap_trace  => config_var('Vertex', 'soap_trace') || undef,
        }
    );

    # return the new object - it's not up to this method to check that it's usable ..
    return $vertex_ird;
}

sub _clean_up_vertex_error {
    my $vertex_error = shift;

    if ( $vertex_error =~ m/\A(?<pre_address>.*Unable to find any applicable tax areas.*asOfDate. \()(?<address_info>.*, As Of Date=.*)(?<post_address>\).*)\z/s ) {
        # a bogus address has been provided

        if ( $+{address_info} ) {
            # and we've been able to capture what was interpreted as the address information
            # pockle it to look right, according to what the caller provided

            my $address_pairs = {
                map {
                    my $pair = $_;
                    my ( $name, $value ) = trim( split m/=/, $pair );
                    ( $name => $value );
                } split m/,\s*/, $+{address_info}
            };

            # remap Vertex's names for stuff back to ours
            # we deliberately ignore 'As Of Date'
            my @remap_pairs = (
                [ 'Street Information' => 'address_line_1' ],
                [ 'Sub Division'       => 'address_line_2' ],
                [ City                 => 'towncity'       ],
                [ 'Main Division'      => 'county'         ],
                [ 'Postal Code'        => 'postcode'       ],
                [ Country              => 'country'        ],
            );

            my @new_address_elements = ();

            foreach my $pair ( @remap_pairs ) {
                my ( $vertex_name, $our_name ) = @{$pair};

                if ( exists $address_pairs->{$vertex_name} &&
                            $address_pairs->{$vertex_name} &&
                            $address_pairs->{$vertex_name} ne 'null' ) {

                    push @new_address_elements, $our_name."=".$address_pairs->{$vertex_name};
                }
            }

            return $+{pre_address} . join(", ", @new_address_elements ) . $+{post_address};
        }
    }

    # make the best of some horribly long message
    return $vertex_error;
}

1;

=pod

=head1 NAME

XTracker::Vertex - Vertex (tax) functionality for XTracker

=head1 CONFIGURATION

Add a section to /etc/xtracker/xtracker.conf:

  [Vertex]
  enabled=yes
  soap_host=10.3.2.103
  soap_port=8080
  soap_user=sysadmin
  soap_password=vertex

To enable Vertex functionality you must set enable to 'yes' - this value is
cASe sEnsITiVe!

=head1 INTERFACE

=head2 PUBLIC METHODS

=over 4

=item vertex_enabled()

=item is_in_new_york_state($data_ref)

=item in_vertex_area($data_ref)

=item use_vertex($data_ref)

=item use_vertex_for_shipment($dbh,$shipment_id)

=item create_vertex_invoice_from_xt_shipment($arg_ref)

=item create_vertex_invoice_from_xt_invoice($arg_ref)

=item create_invoice_for_shipment($arg_ref)

=back

=head2 PRIVATE METHODS

=over 4

=item _populate_vertex_seller_information($vertex_obj,$shipping_source)

=item _populate_vertex_customer_address_and_shipment_items($vertex_obj,$arg_ref)

=item _populate_vertex_customer_address($vertex_obj,$address)

=item _populate_vertex_lines_with_shipment_items($vertex_obj,$shipment_items)

=item _new_quotation_request_object()

=item _new_invoice_request_object()

=back

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut

__END__
