package XTracker::Navigation;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;
use XTracker::Database;
use XTracker::Database::Sample          qw( guess_variant_id );
use XTracker::Database::SampleRequest   qw( get_operator_request_types );
use XTracker::Database::Product;
use XTracker::Database::Profile         qw( get_department get_authentication_information );
use XTracker::Config::Local             qw( :carrier_automation sys_config_groups config_var );
use XTracker::Constants::FromDB         qw( :authorisation_level :department );
use XTracker::RAVNI_transient 'is_ravni_disabled_section';
use XTracker::PRLPages 'is_prl_disabled_section';

use Data::Dump qw( pp );

=head1 NAME

XTracker::Navigation

=head1 DESCRIPTION

Navigation related helper methods for handlers.

=head1 METHODS

=cut

### Subroutine : get_navtype                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_navtype :Export() {

    # IMPORTANT
    # takes 2 or 3 (or 4) params
    #   auth_level  - mandatory
    #   type        - or id         TO BE DEPRECATED
    #   id          - else type
    #   dbh         - DEPRECIATED
    # orginally -> get_navtype( { auth_level => $auth_level, type => $type } )
    # then decided not to hard code the 'type' instead type should be db
    # driven by a new table (not created at the time of writing) called
    # department_authorisation, a copy of operator_authorisation.
    # Until then, if an ID is passed we check for hard coded types, such as
    # 'sample', if no ID, or an ID and no hard coded type, then we look for
    # the param of type. Make sense?

    my ( $args, $navtype ) = @_;

    # this will be the new handler - db driven

    my $dept_name = '';

    if ( $args->{id} ) {
        $dept_name = get_department( { id => $args->{id} });
    }

    if ( $args->{type} eq 'product' or $args->{type} eq 'variant' ) {

        if ( $dept_name eq 'Sample' ) {
            $navtype = 'inventory_sample';
        }
        elsif ( $dept_name eq 'Stock Control' || $dept_name eq 'Distribution Management' ) {
            $navtype = 'inventory_sc';
        }
        elsif ( $dept_name eq 'Distribution' && $args->{auth_level} == $AUTHORISATION_LEVEL__MANAGER ) {
            $navtype = 'inventory_sc';
        }
        else {
            $navtype = 'inventory';
        }

    }
    elsif ( $args->{type} eq 'location') {

        if ( $args->{auth_level} == $AUTHORISATION_LEVEL__MANAGER ) {
            $navtype = 'location_ma';
        }
        elsif ( $args->{auth_level} == $AUTHORISATION_LEVEL__OPERATOR ) {
            $navtype = 'location_op';
        }
        elsif ( $args->{auth_level} == $AUTHORISATION_LEVEL__READ_ONLY ) {
            $navtype = 'location_ro';
        }
        else {
            $navtype = 'location_ro';
        }
    }
    else {
        $navtype = $args->{type};
    }

    return $navtype;

}


### Subroutine : build_nav                              ###
# usage        : $n = build_nav( $p );                    #
# description  :                                          #
# parameters   : dbh => $dbh, operator_id => $operator_id #
# returns      : $nav_ref                                 #

sub build_nav :Export(:DEFAULT) {
    my $p = shift;
    my ( $dbh, $operator_id );
    if ( ref( $p ) eq "HASH" ) {
        $dbh         = $p->{dbh};
        $operator_id = $p->{operator_id};
    }
    else {
        $dbh         = read_handle();
        $operator_id = $p;
    }

    my $qry = qq{
  select asn.section, ass.sub_section, oa.authorisation_level_id, ass.ord
    from operator_authorisation oa, authorisation_section asn, authorisation_sub_section ass
   where oa.operator_id = ?
     and oa.authorisation_sub_section_id = ass.id
     and ass.authorisation_section_id = asn.id
order by ord
};
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $operator_id );

    my $nav;
    while ( my $row = $sth->fetchrow_hashref( ) ) {

        # DCEA check
        next if is_ravni_disabled_section($row->{section}, $row->{sub_section});

        # DC2A/PRL check
        next if is_prl_disabled_section($row->{section}, $row->{sub_section});

        $nav->{$row->{section}}->{$row->{ord}} = $row;
    }

    return $nav;

}


### Subroutine : build_sidenav                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub build_sidenav :Export(:DEFAULT) {

    my ( $args_ref ) = @_;

    my $navtype       = $args_ref->{navtype};
    my $type          = $args_ref->{type} || 'none';
    my $id            = $args_ref->{id} // q{};
    my $po_id         = $args_ref->{po_id} // q{};
    my $so_id         = $args_ref->{so_id} // q{};
    my $operator_id   = $args_ref->{operator_id};
    my $department_id = $args_ref->{department_id};
    my $auth_level    = $args_ref->{auth_level};
    my $res_list      = $args_ref->{res_list} // q{};
    my $res_filter    = $args_ref->{res_filter} // q{};
    my $num_incomplete = $args_ref->{num_incomplete} // q{};

    my $variant_id = q{};
    my $product_id = q{};

    my $dbh = read_handle();

    if( $type eq 'variant_id' ){
        my %args = ( type => 'variant_id', id => $id );
        $product_id = get_product_id( $dbh, \%args );
    }
    elsif ( $id ) {
        $product_id = $id;
        $variant_id = guess_variant_id( { dbh => $dbh, product_id => $id, type => 'sample' } );
    }
    else {
        # We don't have a product_id, variant_id or id, so we don't do
        # anything
    }

    my $inventory_general =
        [
                {   title => 'New Search',
                    url   => "/StockControl/Inventory/SearchForm",
                }
        ];

    my $product_general =
        [
                {   title => 'Product Overview',
                    url   => "/StockControl/Inventory/Overview?product_id=$product_id",
                },
                {   title => 'Product Details',
                    url   => "/StockControl/Inventory/ProductDetails?product_id=$product_id",
                },
                {   title => 'Pricing',
                    url   => "/StockControl/Inventory/Pricing?product_id=$product_id",
                },
                {   title => 'Sizing',
                    url   => "/StockControl/Inventory/Sizing?product_id=$product_id",
                },
                {   title => 'Purchase Orders',
                    url   => "/StockControl/PurchaseOrder/Search?$type=$id&search=1",
                },
                {   title => 'Measurements',
                    url   => "/StockControl/Inventory/Measurement?product_id=$product_id",
                },
        ];

    my $stock_control_manager =
        [
                {   title => 'Move/Add Stock',
                    url   => "/StockControl/Inventory/MoveAddStock?$type=$id",
                },
                {   title => 'Quarantine Stock',
                    url   => "/StockControl/Inventory/StockQuarantine?$type=$id",
                },
        ];

    my $stock_control =
        [
                {   title => 'Move/Add Stock',
                    url   => "/StockControl/Inventory/MoveAddStock?$type=$id",
                },
                {   title => 'Quarantine Stock',
                    url   => "/StockControl/Inventory/StockQuarantine?$type=$id",
                },
        ];

    my $inventory_sample =
        [
                {   title => 'Purchase Order',
                    url   => "/StockControl/Sample/PurchaseOrder?$type=$id",
                },
                {   title => 'Sample Goods In',
                    url   => "/StockControl/Sample/SamplesIn?$type=$id",
                },
                {   title => 'Sample Rotation',
                    url   => "/StockControl/Sample/GoodsOut?$type=$id",
                },
                {   title => 'Request Stock',
                    url   => "/StockControl/Sample/RequestStock?$type=$id",
                },
                {   title => 'Return Stock',
                    url   => "/StockControl/Sample/ReturnStock?$type=$id",
                },
        ];

    # to hold the 'Add to Sample Cart' menu option for Sample Cart Users and
    # to be placed in their menu structure if they are
    my $inventory_samplecart_users;

    if ( $type eq 'variant_id' ) {
        my $addtosamplecart_ref = { title => 'Add to Sample Cart', url => "/Sample/SampleCart/Process/AddItemVariant?action=add&$type=$id" };
        # if theres a variant add the 'Add to Sample Cart' menu option to the sample menu options
        push @{$inventory_sample}, $addtosamplecart_ref;
        if ( ( defined $operator_id ) && ( $navtype =~ /^inventory/ ) && ( $navtype ne "inventory_sample" ) ) {
            # see if user is a Sample Cart User, and then give them the option to 'Add to Sample Cart'
            my $use_samplecart  = get_operator_request_types( { dbh => $dbh, operator_id => $operator_id } );
            if ( scalar( @{$use_samplecart} ) ) {
                push @{$inventory_samplecart_users}, $addtosamplecart_ref;
            }
        }
    }

    my @link_permissions = (
        # Add Stock Adjustment link if they've got access
        [
            sub { grep { $type eq $_ } qw{variant_id product_id} },
            [ 'Stock Control', 'Stock Adjustment', ],
            {
                title => 'Adjust Stock',
                url => "/StockControl/StockAdjustment/AdjustStock?$type=$id",
            },
            [ $stock_control_manager, $stock_control, ],
        ],
        [
            sub { grep { $type eq $_ } qw{variant_id product_id} },
            [ 'Stock Control', 'Sample Adjustment', ],
            {
                title => 'Sample&nbsp;Adjustment',
                url => "/StockControl/SampleAdjustment?$type=$id",
            },
            [ $stock_control_manager, $stock_control, $inventory_sample, ],
        ],
        # Add Recode link if they've got access and they're looking at a variant
        # that might have stock in the right state for being recoded
        [
            sub { $type eq 'variant_id' && $args_ref->{can_recode_variant} },
            [ 'Stock Control', 'Recode', ],
            {
                title => 'Recode Stock',
                url => "/StockControl/Recode?$type=$id",
            },
            [ $stock_control_manager, $stock_control, ],
        ],
    );
    for ( @link_permissions ) {
        next unless defined $operator_id;
        my ( $cond, $section_ref, $link, $menus ) = @$_;
        next unless $cond->();
        my $fake_session = {operator_id => $operator_id};
        get_authentication_information ($fake_session, @$section_ref);
        next unless $fake_session->{auth_level};
        push @$_, $link for @$menus;
    }

    my $stockc_sample   =
        [
                {   title   => 'Stock Transfer In',
                    url     => '/StockControl/Sample/GoodsIn'
                },
                {   title   => 'Transfer Requests',
                    url     => '/StockControl/Sample/Request'
                },
                {   title   => 'Transfer Returns',
                    url     => '/StockControl/Sample/Return'
                }
        ];


    my $logs =
        [
                {   title => 'Deliveries',
                    url   => "/StockControl/Inventory/Log/Product/DeliveryLog?product_id=$product_id",
                },
                {   title => 'Allocated',
                    url   => "/StockControl/Inventory/Log/Product/AllocatedLog?$type=$id",
                },
                {   title => 'Discrepancies',
                    url   => "/StockControl/Inventory/Log/Product/DiscrepancyLog?$type=$id",
                },

        ];

    my $po =
        [
          {   title => 'Search',   url   => "/StockControl/PurchaseOrder/SearchForm", },
        ];


    my $po_summary =
        [
          {   title => 'Overview', url   => "/StockControl/PurchaseOrder/Overview?po_id=$po_id", },
          {   title => 'Edit',     url   => "/StockControl/PurchaseOrder/Edit?po_id=$po_id", },
          {   title => 'Confirm',  url   => "/StockControl/PurchaseOrder/Confirm?po_id=$po_id", },
          {   title => 'Re-Order',  url   => "/StockControl/PurchaseOrder/ReOrder?po_id=$po_id", },
          #{   title => 'Replacement',  url   => "/StockControl/PurchaseOrder/Replacement?po_id=$po_id", },
        ];

    my $po_no_edit =
        [
          {   title => 'Search',   url   => "/StockControl/PurchaseOrder/SearchForm", }
        ];


    my $po_summary_no_edit =
        [
          {   title => 'Overview', url   => "/StockControl/PurchaseOrder/Overview?po_id=$po_id", }
        ];

    my $stock_order =
        [
          {   title => 'Add Item', url   => "/StockControl/PurchaseOrder/AddItem?so_id=$so_id", },
        ];

    # Links that apply to the putaway prep admin page (only shows if prl_phase = 1)
    my $putaway_prep_admin = [
        {   title => 'Main Stock',
            url   => "/GoodsIn/PutawayPrepAdmin?putaway_type=all_but_customer_returns"
        },
        {   title => 'Customer Returns',
            url   => "/GoodsIn/PutawayPrepAdmin?putaway_type=customer_returns_only"
        },
    ];

    my $rtv_summary =
        [ {   title => 'Summary', url   => "/StockControl/RTV", }, ];

    my $rtv_search =
        [
      {   title => 'Request RMA',       url => "/StockControl/RTV/RMARequest", },
          {   title => 'Awaiting RMA',      url => "/StockControl/RTV/RMAWait", },
          {   title => 'Awaiting Dispatch', url => "/StockControl/RTV/Dispatch", },
          {   title => 'Completed RTV',     url => "/StockControl/RTV/Complete", },
          {   title => 'Working Picking',   url => "/StockControl/RTV/WorkingPicking", },
          {   title => 'Working Putaway',   url => "/StockControl/RTV/WorkingPutaway", },
        ];

    my $transfer_summary =
        [ {   title => 'Summary', url   => "/StockControl/Transfer", }, ];

    my $transfer_search =
        [ {   title => 'Search', url    => "/StockControl/Transfer/SearchForm", }, ];

    my $transfer_request =
        [ {   title => 'Request', url   => "/StockControl/Transfer/Request", }, ];

    my $upload_check =
        [   {   title => 'Pricing',         url => "/Upload/Worklist/PriceCheck", },
            {   title => 'Wear it With',        url => "/Upload/Worklist/RecommendedCheck", },
            {   title => 'Classification',  url => "/Upload/Worklist/ClassificationCheck", },
        ];

    my $stockcheck_summary =
        [ {   title => 'Summary', url   => "/StockControl/StockCheck", }, ];

    my $stockcheck =
        [ {   title => 'Check Location', url => "/StockControl/StockCheck/Location", },
          {   title => 'Check Product',  url => "/StockControl/StockCheck/Product", },
        ];

    my $quarantine_summary =
        [ {   title => 'Summary', url   => "/StockControl/Quarantine", }, ];

    my $quarantine =
        [ {   title => 'Quarantine List', url => "/StockControl/Quarantine/List", },
          {   title => 'RTV',             url => "/StockControl/Quarantine/Detail", },
        ];
    my $location_ro =
    [ {'title' => 'Search', 'url'   => "/StockControl/Location/SearchLocationsForm"},
    ];
    my $location_op =
    [ {'title' => 'Search', 'url'   => "/StockControl/Location/SearchLocationsForm"},
      {'title' => 'Print',  'url'   => "/StockControl/Location/PrintLocationsForm"},
    ];
    my $location_ma =
    [ {'title' => 'Search', 'url'   => "/StockControl/Location/SearchLocationsForm"},
      {'title' => 'Create', 'url'   => "/StockControl/Location/CreateLocationsForm"},
      {'title' => 'Delete', 'url'   => "/StockControl/Location/DeleteLocationsForm"},
      {'title' => 'Print',  'url'   => "/StockControl/Location/PrintLocationsForm"},
    ];

    my $product_approval =
        [
          {   title => 'Create', url   => "/StockControl/ProductApproval", },
          {   title => 'Archive', url   => "/StockControl/ProductApproval/Archive", },
        ];

    my $reservation_summary = [
          {   title => 'Summary', url   => "/StockControl/Reservation", },
    ];

    my $reservation_overview = [
          {   title => 'Upload',        url   => "/StockControl/Reservation/Overview?view_type=Upload", },
          {   title => 'Pending',       url   => "/StockControl/Reservation/Overview?view_type=Pending", },
          {   title => 'Waiting List',  url   => "/StockControl/Reservation/Overview?view_type=Waiting", },
    ];

    my $reservation_view = [
          {   title => 'Live Reservations',     url   => "/StockControl/Reservation/Listing?list_type=Live&show=$res_filter", },
          {   title => 'Pending Reservations',  url   => "/StockControl/Reservation/Listing?list_type=Pending&show=$res_filter", },
          {   title => 'Waiting Lists',         url   => "/StockControl/Reservation/Listing?list_type=Waiting&show=$res_filter", },
    ];

    my $preorder_view = [
          {   title => 'Pending Pre-Orders',    url   => "/StockControl/Reservation/PreOrder/PreOrderExported", },
          {   title => 'Pre-Order List',        url   => "/StockControl/Reservation/PreOrder/PreOrderList", },
          {   title => 'Orders on Hold',        url   => "/StockControl/Reservation/PreOrder/PreOrderOnhold", },
    ];

    my $reservation_filter = [
          {   title => 'Show All',      url   => "/StockControl/Reservation/Listing?list_type=$res_list&show=All", },
          {   title => 'Show Personal', url   => "/StockControl/Reservation/Listing?list_type=$res_list&show=Personal", },
    ];

    my $reservation_search = [
          {   title => 'Product',   url   => "/StockControl/Reservation/Product", },
          {   title => 'Customer',  url   => "/StockControl/Reservation/Customer", },
          {   title => 'Pre-Order',  url   => "/StockControl/Reservation/PreOrder/PreOrderSearch", },
    ];

    my $reservation_email = [
          {   title => 'Customer Notification', url   => "/StockControl/Reservation/Email", },
    ];

    my $reservation_reports = [
          {   title => 'Uploaded',   url   => "/StockControl/Reservation/Reports/Uploaded/P", },
          {   title => 'Purchased',  url   => "/StockControl/Reservation/Reports/Purchased/P", },
    ];

    my $reservation_actions = [
          {   title => 'Bulk Reassign', url => "/StockControl/Reservation/BulkReassign", },
    ];

    my $dist_rep_overview   = [
        { title => 'Overview', url => '/Reporting/DistributionReports' }
    ];

    my $dist_rep_outbound   = [
        { title => 'Shipment Report', url => '/Reporting/DistributionReports/ShipmentReport' },
        { title => 'Picking Report', url => '/Reporting/DistributionReports/Outbound?report_type=Picking' },
        { title => 'Packing Report', url => '/Reporting/DistributionReports/Outbound?report_type=Packing' },
        { title => 'Labelling Report', url => '/Reporting/DistributionReports/LabellingReport' },
    ];

    my $dist_rep_inbound    = [
        { title => 'Stock In', url => '/Reporting/DistributionReports/Inbound?report_type=stock_in' },
        { title => 'Item Count', url => '/Reporting/DistributionReports/Inbound?report_type=item_count' },
        { title => 'QC', url => '/Reporting/DistributionReports/Inbound?report_type=QC' },
        { title => 'Bag &amp; Tag', url => '/Reporting/DistributionReports/Inbound?report_type=Bag_Tag' },
        { title => 'Putaway Prep', url => '/Reporting/DistributionReports/Inbound?report_type=Putaway_Prep', prl_phase => 1 },   # Only show if prl_phase = 1
        { title => 'Putaway', url => '/Reporting/DistributionReports/Inbound?report_type=Putaway' },
        { title => 'Returns In', url => '/Reporting/DistributionReports/Returns?report_type=Booked_In' },
        { title => 'Returns QC', url => '/Reporting/DistributionReports/Returns?report_type=QC' },
        { title => 'Returns Putaway Prep', url => '/Reporting/DistributionReports/Returns?report_type=Putaway_Prep', prl_phase => 1 },
        { title => 'Returns Putaway', url => '/Reporting/DistributionReports/Returns?report_type=Putaway' },
        { title => 'By Action', url => '/reporting/distribution/inbound_by_action' },
    ];

    my $prl_phase = config_var('PRL', 'rollout_phase') || 0;

    # only include if the prl phase matches (or if it isn't specified)
    $dist_rep_inbound = [ grep { ($_->{prl_phase} // $prl_phase) == $prl_phase } @$dist_rep_inbound ];

    my $ship_report         = [
#       { title => 'Overview', url => '/Reporting/ShippingReports' },
        { title => 'Air Waybill Report', url => '/Reporting/ShippingReports/AirwaybillReport' },
        { title => 'Premier Report', url => '/Reporting/ShippingReports/PremierReport' },
        { title => 'Box Report', url => '/Reporting/ShippingReports/BoxReport' },
        { title => 'Duplicate Paperwork', url => '/Reporting/ShippingReports/DuplicatePaperwork' },
        { title => 'Nominated Day', url => '/Reporting/ShippingReports/NominatedDay' },
    ];

    # Links that apply to channel transfers in all cases
    my $channel_transfer = [
                {   title => 'Pending Requests',
                    url   => "/StockControl/ChannelTransfer",
                },
                {   title => 'Completed Transfers',
                    url   => "/StockControl/ChannelTransfer?list_type=Complete",
                },
                {   title => 'Search Transfers',
                    url   => "/StockControl/ChannelTransfer?list_type=Search",
                },
        ];

    # Links that apply to only manual channel transfers
    my $channel_transfer_manual_steps =
        [
                {   title => 'Awaiting Picking',
                    url   => "/StockControl/ChannelTransfer?list_type=Picking",
                },
                {   title => 'Incomplete Pick'.$num_incomplete,
                    url   => "/StockControl/ChannelTransfer?list_type=Incomplete",
                },
                {   title => 'Awaiting Putaway',
                    url   => "/StockControl/ChannelTransfer?list_type=Putaway",
                },
        ];

    # If we don't have IWS or PRL, then channel transfer is manual so add in those steps
    unless ( config_var('IWS', 'rollout_phase') || config_var('PRL', 'rollout_phase') ) {
        splice( @$channel_transfer, 1, 0, @$channel_transfer_manual_steps );
    }

    my $marketing_promotion =
        [
            { title => 'Summary', url => '/NAPEvents/InTheBox' },
            { title => 'Create ', url => '/NAPEvents/InTheBox/Create' },
        ];

    my $customer_segment =
        [
            { title => 'Summary', url => '/NAPEvents/InTheBox/CustomerSegment' },
            { title => 'Create', url => '/NAPEvents/InTheBox/CustomerSegment/Create' },
            { title => 'Search', url => '/NAPEvents/InTheBox/CustomerSegment/Search' },
        ];

    my $view_fraud_rules =
        [
            { title => 'Live Rules', url => '/Finance/FraudRules/ViewLiveRules' },
            { title => 'Staging Rules', url => '/Finance/FraudRules/ViewStagingRules' },
            { title => 'Bulk Test', url => '/Finance/FraudRules/BulkTest' },
            { title => 'List Manager', url => '/Finance/FraudRules/ListManager' }
        ];

    my $variant_logs;

    # Setup Variant Log Menu if needed
    if( $type eq 'variant_id' ){
        $variant_logs   = [
            {
                title => 'Transaction Log',
                url   => "/StockControl/Inventory/Log/Variant/StockLog?$type=$id",
            },
            {
                title => 'PWS Log',
                url   => "/StockControl/Inventory/Log/Variant/PWSLog?$type=$id",
            },
            {
                title => 'RTV Log',
                url   => "/StockControl/Inventory/Log/Variant/RTVLog?$type=$id",
            },
            {
                title => 'Reservation Log',
                url   => "/StockControl/Inventory/Log/Variant/ReservationLog?$type=$id",
            },
            {
                title => 'Cancellation Log',
                url   => "/StockControl/Inventory/Log/Variant/CancellationLog?$type=$id",
            },
            {
                title => 'Location Log',
                url   => "/StockControl/Inventory/Log/Variant/LocationLog?$type=$id",
            },
            {
                title => 'Sample Adjustment Log',
                url => "/StockControl/Inventory/Log/Variant/SampleAdjustmentLog?$type=$id",
            },
        ];
    }

    # All menu structures which require Logs, add in here any new ones
    my %menu_with_logs  = qw(
            inventory               1
            inventory_sc            1
            inventory_manager       1
            inventory_sample        1
        );


    my %subnav = (
                   'inventory'          => [ { 'None'           => $inventory_general   },
                                             { 'Product'        => $product_general     },
                                             ( defined $inventory_samplecart_users ? { 'Sample' => $inventory_samplecart_users } : undef ),
                                             { 'Product Logs'   => $logs                },
                                          ],
                   'inventory_sc'       => [ { 'None'           => $inventory_general   },
                                             { 'Product'        => $product_general     },
                                             ( defined $inventory_samplecart_users ? { 'Sample' => $inventory_samplecart_users } : undef ),
                                             { 'Stock Actions'  => $stock_control_manager   },
                                             { 'Product Logs'   => $logs                },
                                          ],
                    'inventory_manager'  => [ { 'None'           => $inventory_general   },
                                             { 'Product'        => $product_general     },
                                             ( defined $inventory_samplecart_users ? { 'Sample' => $inventory_samplecart_users } : undef ),
                                             { 'Stock Actions'  => $stock_control       },
                                             { 'Product Logs'   => $logs                },
                                          ],
                   'inventory_sample'  => [ { 'None'            => $inventory_general   },
                                             { 'Product'        => $product_general     },
                                             { 'Sample'         => $inventory_sample    },
                                             { 'Product Logs'   => $logs                },
                                          ],
                   # Sample menu for StockControl/Sample
                    'stockc_sample' => [
                                     { 'Sample' => $stockc_sample }
                                  ],
                    'transfer'  => [
                                     { 'Stock Transfer'         => $transfer_request  },
                                  ],


                   'rtv'       => [
                                     { 'RTV'             => $rtv_search   },
                                  ],


                   'purchase_order_no_edit' => [
                                     { 'None' => $po_no_edit  },
                                  ],

                   'purchase_order' => [
                                     { 'None' => $po  },
                                  ],

                   'purchase_order_summary' => [
                                    { 'None'     => $po  },
                                    { 'Purchase Order' => $po_summary  },
                                  ],

                    'purchase_order_summary_no_edit' => [
                                    { 'None'     => $po_no_edit  },
                                    { 'Purchase Order' => $po_summary_no_edit  },
                                  ],

                    'stock_order' => [
                                    { 'None'     => $po  },
                                    { 'Purchase Order' => $po_summary  },
                                    { 'Stock Order' => $stock_order  },
                                  ],

                   'stock_check' => [
                                     { 'Check'   => $stockcheck          },
                                    ],


                   'quarantine'  => [
                                     { 'General' => $quarantine_summary  },
                                     { 'Actions' => $quarantine          },
                                    ],
                   'location_ro'    => [
                            {'Location' => $location_ro },
                               ],
                   'location_op'    => [
                            {'Location' => $location_op },
                               ],

                   'location_ma'    => [
                            {'Location' => $location_ma },
                               ],

                   'productapproval' => [
                                     { 'Product Approval'       => $product_approval },
                                  ],
                    'reservations' => [
                                    { 'None'        => $reservation_summary },
                                    { 'Overview'    => $reservation_overview },
                                    { 'View'        => $reservation_view },
                                    { 'PreOrder'    => $preorder_view },
                                    { 'Search'      => $reservation_search },
                                    { 'Email'       => $reservation_email },
                                    { 'Reports'     => $reservation_reports },
                                    { 'Actions'     => $reservation_actions },
                                  ],
                    'reservations_filter' => [
                                    { 'None'        => $reservation_summary },
                                    { 'Overview'    => $reservation_overview },
                                    { 'View'        => $reservation_view },
                                    { 'Filter'      => $reservation_filter },
                                    { 'PreOrder'    => $preorder_view },
                                    { 'Search'      => $reservation_search },
                                    { 'Email'       => $reservation_email },
                                    { 'Reports'     => $reservation_reports },
                                  ],

                    'distribution_reports' => [
                                        { 'None'    => $dist_rep_overview },
                                        { 'Outbound'=> $dist_rep_outbound },
                                        { 'Inbound' => $dist_rep_inbound },
                                    ],

                    'shipping_reports' => [
                                        { 'None'    => $ship_report }
                                    ],
                    'channel_transfer' => [
                                        { 'None'    => $channel_transfer }
                                    ],
                    'marketing_promotion' => [
                                        { 'Promotion'          => $marketing_promotion },
                                        { 'Customer Segment'   => $customer_segment },
                                    ],
                    'fraud_rules' => [
                        {
                            'View'          => $view_fraud_rules
                        },
                    ],
                    'putaway_prep_admin' => [
                        {
                            'None'          => $putaway_prep_admin
                        },
                    ],
                 );

    # If menu requires logs and there is a variant id passed then add in variant log menus
    if (($navtype && exists $menu_with_logs{$navtype}) && ($type eq 'variant_id')) {
        push @{ $subnav{$navtype} },{ 'Variant Logs' => $variant_logs };
    }

    return $subnav{$navtype};
}


=head2 build_packing_nav

  usage        : $hash_ref = build_packing_nav( $schema );

  description  : This builds a section for the left hand navigation to provide a link
                 to the 'Select Packing Station' page. It first checks to see if there
                 are any packing stations available for the DC for any Sales Channel,
                 if not then nothing is returned else a link & title combination is
                 returned which can then be put into a page's left hand menu.

  parameters   : A DBiC Schema Connection.
  returns      : A HASH Ref (or nothing) containing the link to the page.

=cut

sub build_packing_nav :Export() {

    my $schema      = shift;

    die "No Schema Connection Passed"           if ( !$schema );

    my $retval;

    # build the nav section if we need to
    if ( sys_config_groups( $schema, qr/PackingStationList/ ) ) {
        $retval = {
                    title   => 'Set Packing Station',
                    url     => '/Fulfilment/Packing/SelectPackingStation'
                  };
    }

    return $retval;
}


### Subroutine : build_form                     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub build_form :Export() {

    my ( $type ) = @_;

    return {
              action => '/StockControl/Inventory/Search',
              param  => 'product_id',
           };
}


=head2 build_orderview_sidenav

    $hash_ref = build_orderview_sidenav( $data );

Builds the Sidenav Options for the Order View page. The '$data' that should
be passed in is generated in 'XTracker::Order::Functions::Order::OrderView'.

=cut

sub build_orderview_sidenav :Export() {
    my $data = shift;

    # set up base for links (section/sub section)
    my $link_base = $data->{short_url};

    # if there is only one Shipment then some options can target it directly
    my $extra_url = "";
    if ( $data->{num_shipments} == 1) { $extra_url = "&shipment_id=".$data->{master_shipment_id}; }

    my $egain_url = config_var('eGain', 'url');

    my %links = (
        "None" => {
            "Back" => [0, ""],
            "View Access Log" => [2, "$link_base/OrderAccessLog?order_id=$data->{orders_id}", 'order_view_access_log'],
            "View Status Log" => [3, "OrderLog?orders_id=$data->{orders_id}"],
        },
        "Order" => {
            "Credit Hold"           => [0, "/Finance/Order/CreditHold?order_id=$data->{orders_id}&action=Hold"],
            "Credit Check"          => [1, "/Finance/Order/CreditCheck?order_id=$data->{orders_id}&action=Check"],
            "Accept Order"          => [2, "/Finance/Order/Accept?order_id=$data->{orders_id}&action=Accept"],
            "Edit Order"            => [3, "EditOrder?orders_id=$data->{orders_id}"],
            "Edit Billing Address"  => [4, "ChooseAddress?address_type=Billing&order_id=$data->{orders_id}"],
            "Cancel Order"          => [5, "CancelOrder?orders_id=$data->{orders_id}"],
            "Pre-Authorise Order"   => [6, "AuthorisePayment?method=pre&orders_id=$data->{orders_id}"],
            "Remove Watch"          => [7, "EditWatch?action=Remove&watch_type=Finance&order_id=$data->{orders_id}&customer_id=$data->{orders}{customer_id}"],
            "Add Watch"             => [8, "EditWatch?action=Add&watch_type=Finance&order_id=$data->{orders_id}&customer_id=$data->{orders}{customer_id}"],
            "Send Email"            => [0, "SendEmail?order_id=$data->{orders_id}"],
            "Add Note"              => [10, "Note?parent_id=$data->{orders_id}&note_category=Order&sub_id=$data->{orders_id}"],
        },
        "Customer" => {
            "Add Watch"             => [0, "EditWatch?action=Add&watch_type=Customer&order_id=$data->{orders_id}&customer_id=$data->{orders}{customer_id}"],
            "Remove Watch"          => [1, "EditWatch?action=Remove&watch_type=Customer&order_id=$data->{orders_id}&customer_id=$data->{orders}{customer_id}"],
            "Contact History"       => [2, "$egain_url/system/web/view/platform/agent/info/custhist/Custom_Customer_history_NAP/getCustomerCaseNap.jsp?email_address=".$data->{customer}{email}, 'order_view_contact_history']
        },
        "Shipment" => {
            "Edit Shipment"         => [0, "EditShipment?order_id=$data->{orders_id}$extra_url"],
            "Edit Shipping Address" => [1, "ChooseAddress?address_type=Shipping&order_id=$data->{orders_id}$extra_url"],
            "Hold Shipment"         => [3, "HoldShipment?order_id=$data->{orders_id}$extra_url"],
            "Amend Pricing"         => [4, "AmendPricing?order_id=$data->{orders_id}$extra_url"],
            "Check Pricing"         => [5, "ChangeCountryPricing?order_id=$data->{orders_id}&action=Check$extra_url"],
            "Create Credit/Debit"   => [6, "Invoice?action=Create&order_id=$data->{orders_id}$extra_url"],
            "Dispatch/Return"       => [7, "DispatchAndReturn?order_id=$data->{orders_id}$extra_url"],
            "Create Shipment"       => [8, "CreateShipment?order_id=$data->{orders_id}$extra_url"],
            "Lost Shipment"         => [9, "LostShipment?order_id=$data->{orders_id}$extra_url"],
            "Add Note"              => [10, "Note?parent_id=$data->{orders_id}&note_category=Shipment" . ( $data->{num_shipments} == 1 ? "&sub_id=".$data->{master_shipment_id} : "" ) ],
            "Cancel Re-Shipment"    => [11, "CancelReshipment?order_id=$data->{orders_id}$extra_url"],
        },
        "Shipment Item" => {
            "Cancel Shipment Item"  => [0, "CancelShipmentItem?orders_id=$data->{orders_id}$extra_url"],
            "Size Change"           => [1, "SizeChange?order_id=$data->{orders_id}$extra_url"],
            "Returns"               => [2, "Returns/View?order_id=$data->{orders_id}$extra_url"],
        },
        "Fraud Rules" => {
            "Show Outcome"          => [0, "/Finance/FraudRules/Outcome?order_id=$data->{orders_id}", 'order_view_fraud_rules_outcome' ],
            "Test Using Live"       => [1, "/Finance/FraudRules/Test?order_id=$data->{orders_id}&rule_set=live", 'order_view_fraud_rules_live' ],
            "Test Using Staging"    => [2, "/Finance/FraudRules/Test?order_id=$data->{orders_id}&rule_set=staging", 'order_view_fraud_rules_staging' ],
        },
    );

    return _remove_orderview_sidenav_options( $data->{department_id}, \%links );
}

#
# $hash_ref = remove_orderview_sidenav_options( $department_id, $links );
#
# Remove Order View Sidenav Options based on a Department Id. As the
# XT Access Controls project progresses then this function will need
# to be maintained to stop it removing links that would be protected
# by an Operator's Roles and NOT their Department.
#
sub _remove_orderview_sidenav_options {
    my ( $dept_id, $links ) = @_;

    # specifys what needs to be removed from
    # the Sidenav options for each Department
    my %to_remove = (
        $DEPARTMENT__FINANCE => {
            Shipment => [
                'Amend Pricing',
                'Dispatch/Return',
                'Create Shipment',
                'Lost Shipment',
                'Cancel Re-Shipment',
            ],
            'Shipment Item' => [
                'Cancel Shipment Item',
                'Size Change',
                'Returns',
            ],
            Customer => [
                'Add Watch',
                'Remove Watch',
            ],
        },
        $DEPARTMENT__CUSTOMER_CARE => {
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
            ],
            Shipment => [
                'Amend Pricing',
                'Create Shipment',
                'Create Credit/Debit',
            ],
        },
        $DEPARTMENT__CUSTOMER_CARE_MANAGER => {
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
            ],
            Shipment => [
                'Create Shipment',
            ],
        },
        $DEPARTMENT__SHIPPING => {
            Customer => [
                'Add Watch',
                'Remove Watch',
            ],
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
            ],
            Shipment => [
                'Amend Pricing',
                'Create Shipment',
                'Create Credit/Debit',
            ],
        },
        $DEPARTMENT__SHIPPING_MANAGER => {
            Customer => [
                'Add Watch',
                'Remove Watch',
            ],
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
            ],
            Shipment => [
                'Amend Pricing',
                'Create Shipment',
            ],
        },
        $DEPARTMENT__DISTRIBUTION_MANAGEMENT => {
            Customer => [
                'Add Watch',
                'Remove Watch',
            ],
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
            ],
            Shipment => [
                'Amend Pricing',
                'Create Credit/Debit',
                'Lost Shipment',
            ],
        },
        $DEPARTMENT__STOCK_CONTROL => {
            Customer => [
                'Add Watch',
                'Remove Watch',
            ],
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
            ],
            Shipment => [
                'Amend Pricing',
                'Create Shipment',
                'Create Credit/Debit',
                'Lost Shipment',
            ],
            'Shipment Item' => [
                'Returns',
            ],
        },
        $DEPARTMENT__PERSONAL_SHOPPING => {
            Customer => [
                'Add Watch',
                'Remove Watch',
            ],
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
                'Edit Billing Address',
                'Send Email',
            ],
            Shipment => [
                'Amend Pricing',
                'Create Shipment',
                'Create Credit/Debit',
                'Dispatch/Return',
                'Lost Shipment',
                'Cancel Re-Shipment',
            ],
        },
        $DEPARTMENT__FASHION_ADVISOR => {
            same_as => $DEPARTMENT__PERSONAL_SHOPPING,
        },
        # all other Departments will use 'DEFAULT'
        'DEFAULT' => {
            Customer => [
                'Add Watch',
                'Remove Watch',
            ],
            Order => [
                'Pre-Authorise Order',
                'Add Watch',
                'Remove Watch',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Send Email',
            ],
            Shipment => [
                'Amend Pricing',
                'Create Shipment',
                'Create Credit/Debit',
                'Edit Shipment',
                'Edit Shipping Address',
                'Create Credit/Debit',
                'Check Pricing',
                'Hold Shipment',
                'Amend Pricing',
                'Dispatch/Return',
                'Create Shipment',
                'Lost Shipment',
                'Cancel Re-Shipment',
            ],
            'Shipment Item' => [
                'Cancel Shipment Item',
                'Size Change',
            ],
        },
    );

    # get the options to remove base on Department
    # or if that can't be found use 'DEFAULT'
    my $remove  = $to_remove{ $dept_id } || $to_remove{'DEFAULT'};
    # if there is a 'same_as' key then get the options
    # from %to_remove that 'same_as' points to
    $remove     = $to_remove{ $remove->{same_as} }      if ( exists( $remove->{same_as} ) );

    foreach my $group ( keys %{ $remove } ) {
        # remove the specified options for the Group
        delete @{ $links->{ $group } }{ @{ $remove->{ $group } } };
        # if after removing options there are none left then remove the Group too
        delete $links->{ $group }       if ( !scalar( keys %{ $links->{ $group } } ) );
    }

    return $links;
}

1;

