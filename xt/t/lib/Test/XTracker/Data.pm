package Test::XTracker::Data;
use NAP::policy qw(test exporter);

# some tests fail in strange and misleading ways if we\ve forgotten to source
# this is a moderately common module, let's just die here
BEGIN {
    if (not defined $ENV{XTDC_BASE_DIR}) {
        die 'XTDC_BASE_DIR is unset - did you forget to source xtdc/xtdc.env?';
    }
}

# HEY YOU!
# Please don't put anything else in me. 3,000 lines is enough for any module.
# Try instead to write a shiny Test::XT::Data::* thingy for your data.

BEGIN {
  # Both Test::Deep and Moose export blessed, with different signiture's.
  # We only need one. without this we get a warning:
  # Prototype mismatch: sub Test::XTracker::Data::blessed: none vs ($)
  # http://stackoverflow.com/questions/2836350/how-can-i-use-moose-with-testclass

  require Test::Deep;
  @Test::Deep::EXPORT = grep { $_ ne 'blessed' } sort( @Test::Deep::EXPORT);
}

# Test::Most also exports blessed from Test::Deep and gives the same error as
# the above. We should be able to fix this once we upgrade to 0.22. See
# https://rt.cpan.org/Public/Bug/Display.html?id=57501
use Time::HiRes qw( sleep time );
use List::MoreUtils qw/uniq/;
use Catalyst::Utils;
use Path::Class qw/file/;
use File::Find::Rule;
use Data::Dump 'pp';

BEGIN {
  $ENV{XT_CONFIG_LOCAL_SUFFIX} ||= 'test_intl';
  (my $file = __FILE__) =~ s{Test/XTracker/Data\.pm$}{};

  $file = file($file)->absolute
                     ->resolve
                     ->parent  # lib/
                     ->parent;  # t/

  require Test::XTracker::Config;
  Test::XTracker::Config->import($file);
};

use XTracker::Config::Local ':DEFAULT','iws_location_name','config_var','default_carrier';
use XTracker::Schema;
use XTracker::Database::Channel qw( get_channels );
use XTracker::Database::Customer;
use XTracker::Database::Return;
use XTracker::Constants qw/:application/;
use XTracker::Constants::FromDB qw/
  :channel
  :country
  :currency
  :customer_category
  :customer_issue_type
  :delivery_item_status
  :delivery_item_type
  :delivery_status
  :delivery_type
  :flow_status
  :order_status
  :purchase_order_status
  :purchase_order_type
  :pws_action
  :refund_charge_type
  :renumeration_class
  :renumeration_status
  :renumeration_type
  :return_item_status
  :return_status
  :return_type
  :season
  :season_act
  :shipment_class
  :shipment_item_returnable_state
  :shipment_item_status
  :shipment_status
  :shipment_type
  :shipment_window_type
  :stock_order_item_status
  :stock_order_item_type
  :stock_order_status
  :stock_order_type
  :stock_process_status
  :stock_process_type
  :storage_type
  :sub_region
  :variant_type
  :product_channel_transfer_status
/;

use XT::Domain::Returns;
use XT::Domain::PRLs;
use XT::OrderImporter;
use XT::LP;
use XT::Warehouse;
use String::Random;
use XML::LibXML;
use IPC::Cmd qw/run/;
use Template;
use DateTime;
use DateTime::Format::Pg;
use Fcntl qw(:flock);
use IPC::Cmd qw/run/;
use Path::Class qw();
use Carp qw/croak/;
use File::Basename;
use XTracker::Database::Product::SortOrder ();

use Moose;
use MooseX::Types::Moose qw/ArrayRef HashRef Str Any/;
use MooseX::Types::Structured qw/Dict slurpy/;

extends 'Test::XTracker::Model';

with    qw(
            Test::XT::Data::Location
            Test::Role::Address
            Test::Role::Channel
            Test::Role::Correspondence
            Test::Role::PSP
            Test::Role::Status
        );
use Test::Config;
use Test::XT::Rules::Solve;
use Test::XTracker::MessageQueue;
use Test::XTracker::Data::Order;
use Test::RoleHelper;

use Exporter 'import';
our @EXPORT_OK = qw(qc_fail_string);

require Net::Stomp::MooseHelpers::TracerRole;
# a list of directories where messages for PRLs will be stored,
# including trace_basedir
my $trace_basedir = config_var('Model::MessageQueue', 'args')->{trace_basedir};
our @prls = XT::Domain::PRLs::get_all_prls();
our @prl_queue_dirs = @prls ? map {
    $trace_basedir . '/' .
    (Net::Stomp::MooseHelpers::TracerRole
          ->_dirname_from_destination($_->amq_queue))
      } @prls
    : ( "$trace_basedir/fake_prl_receipt_dir" );
# ^^^ we stil need to pass *something* to File::ChangeNotify...

# a list of directories where messages for IWS will be stored,
# including trace_basedir
our @iws_queues = uniq
    map { config_var('WMS_Queues', $_) }
    qw(
        wms_inventory
        wms_fulfilment
        wms_printing
    );
our @iws_queue_dirs = map {
    $trace_basedir . '/' .
    (Net::Stomp::MooseHelpers::TracerRole
          ->_dirname_from_destination($_))
      } @iws_queues;
our ($iws_queue_dir_regex) =
    map { qr/(?:$_)$/ }
    join '|',
    map { s/\W+/_/gr }
    @iws_queues;
our ($iws_queue_regex) =
    map { qr/(?:$_)$/ }
    join '|',
    @iws_queues;

use Data::Dump qw (pp);
use Test::XT::Rules::Solve;

# use this to set whether the old order
# importer saves the orders it creates
my $old_order_importer_skip_commit  = undef;        # default is WILL COMMIT

# Make IPC::Cmd use IPC::Run to get split out/err buffers
$IPC::Cmd::USE_IPC_RUN = 1;

sub pending_orders_dir  { config_var('SystemPaths', 'xmlwaiting_dir'); }
sub processed_order_dir { config_var('SystemPaths', 'xmlproc_dir'); }
sub error_order_dir     { config_var('SystemPaths', 'xmlproblem_dir'); }
sub _routing_schedule_base_dir { return config_var( 'SystemPaths', 'routing_dir' ) . '/schedule'; };
sub routing_schedule_ready_dir {
    my $class   = shift;
    return $class->_routing_schedule_base_dir . '/ready';
}
sub routing_schedule_processed_dir {
    my $class   = shift;
    return $class->_routing_schedule_base_dir . '/processed';
}
sub routing_schedule_fail_dir {
    my $class   = shift;
    return $class->_routing_schedule_base_dir . '/failed';
}

=head1 METHODS

=head2 get_main_stock_location

Returns a main-stock location. In IWS phases, this will be the IWS
location. Returns a DBIC row.

=cut

sub get_main_stock_location {
    my ($class, $schema) = @_;
    $schema //= $class->get_schema();

    if (XT::Warehouse->has_iws) {
        return $schema->resultset('Public::Location')->search({
            location => iws_location_name()
        })->first;
    } elsif(XT::Warehouse->has_prls) {
        # TODO: Hard-coded PRL name.
        return XT::Domain::PRLs::get_location_from_prl_name({
            prl_name => 'Full',
        });
    } else {
        return $schema->resultset('Public::Location')->search({
            'location_allowed_statuses.status_id' =>
                $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        },{
            rows=>1,
            join => [ 'location_allowed_statuses' ],
        })->first;
    }
}

sub prepare_order {
    my ($class, $data) = @_;
    $data ||= {};

    # This is the O_ID field in the XML, ends up as order_nr in the DB.
    my $o_nr = $class->_next_order_id;

    my $order = ($data->{order} ||= {});
    $order->{id} = $o_nr;
    $order->{date} ||= DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%m');
    if ( !delete $order->{no_items} ) {
        $order->{items} ||= [
            {
                sku         => "48499-097",
                description => "Suede thigh-high boots",
                unit_price  => 691.30,
                tax         => 48.39,
                duty        => 0.00
            }
        ];
    }
    else {
        $order->{items} = [];
    }

    my $schema = $class->get_schema;
    $order->{channel_web_name} ||= $schema->resultset('Public::Channel')->search({
        'name' => 'NET-A-PORTER.COM',
    })->single->web_name;

    my $channel = $schema->resultset('Public::Channel')
                         ->find({web_name => $order->{channel_web_name}});
    my $description = $class->default_shipping_charge->{international}{$channel->web_name}
        || q{Couldn't find international shipping charge for } . $channel->web_name;
    $order->{default_international_shipping_sku}
        ||= $channel->find_related('shipping_charges', {
            description => $description,
        })->sku;
    return $data;
}

=head2 create_xml_routing_schedule

    __PACKAGE__->create_xml_routing_schedule_file( $tt_filename, {
                                external_id         => '',  # if not passed in will be calculated for you
                                nap_ref             => '',
                                shipment_id         => '',
                                type                => '',
                                task_window         => '',
                                driver              => '',
                                run_number          => '',
                                run_order_number    => '',
                                status              => '',
                                signatory           => '',
                                sig_date            => '',
                                sig_time            => '',
                                undelivered_notes   => '',
                        } );

Creates an XML file in the correct directory for 'Routing Schedule' files that can be used by the 'script/routing/process_schedule.xml' script.
Pass in the name of the TT file in the 't/data' directory to use to build the XML file.

=cut

sub create_xml_routing_schedule_file {
    my ( $class, $tt_filename, $data )  = @_;

    my $ready_dir   = $class->routing_schedule_ready_dir;

    die $ready_dir . " needs to exist"              unless -e $ready_dir;
    die $ready_dir . " needs to be a directory"     unless -d $ready_dir;
    die $ready_dir . " needs to be writable"        unless -w $ready_dir;

    my $tt  = Template->new( { ABSOLUTE => 1, ENCODING => 'UTF-8' } );

    my $external_id = $data->{external_id};
    if ( !$external_id ) {
        $external_id    = $class->_next_routing_schedule_id;
    }

    note "External Id: $external_id, will create a Routing Schedule XML file in: $ready_dir";

    $tt->process(
                $class->sample_order_template( $tt_filename ),     # this method prefixes the 't/data' dir which is what is wanted
                {
                    %{ $data },                         # doing it this way means a generated 'external_id' does
                    external_id => $external_id,        # not get passed up to the caller if they didn't pass it in
                },
                $ready_dir . "/${external_id}.xml",
                { binmode => ':utf8' },
              ) or die $tt->error;
    return $external_id;
}

=head2 purge_routing_schedule_directories

 Test::XTracker::Data->purge_routing_schedule_directories();

Removes files from the various Routing Schedule directories.

=cut

sub purge_routing_schedule_directories {
    my $class = shift;

    foreach my $method ( qw(
                            routing_schedule_ready_dir
                            routing_schedule_processed_dir
                            routing_schedule_fail_dir
                    ) ) {
        my $directory_path  = $class->$method;

        # Check that directory exists and isn't the root
        if ( -d $directory_path && $directory_path =~ m/\w/ ) {
            # Remove the XML artifacts, but keep a count of the ones removed too
            my $count   = 0;
            ++$count && unlink $_ for File::Find::Rule
                                        ->file()
                                            ->name( '*.xml')
                                                ->in( $directory_path );
            note( "$count XML artifacts removed from $directory_path" )     if $count;
        }
    }
}

=head2 create_xml_order

    __PACKAGE__->create_xml_order({
        order => {
            id      => $id,      # gets set to next order number
            date    => DateTime, # optional
            items   => [         # optional
                {
                    sku         => $hardcoded,
                    description => $hardcoded,
                    tax         => $hardcoded,
                    duty        => $hardcoded,
                },
            ],
        },
    })

Returns the order number.

Old docs: Take a filename (or lacking one sample_order_xml.tt), process it and stick
it in the pending orders dir

=cut

sub create_xml_order {
    my ($class, $data) = @_;
    die $class->pending_orders_dir . " needs to exist"
        unless -e $class->pending_orders_dir;
    die $class->pending_orders_dir . " needs to be a directory"
        unless -d $class->pending_orders_dir;
    die $class->pending_orders_dir . " needs to be writable"
        unless -w $class->pending_orders_dir;

    $data = $class->prepare_order($data);
    my $o_nr = $data->{order}->{id};

    $class->_get_order_importer_lock();

    my $output_file = $class->pending_orders_dir . "/$o_nr.xml";
    $class->render_sample_order_template(
        delete $data->{filename},
        $data,
        $output_file,
    );
    note "made $output_file";
    return $o_nr;
}

sub render_sample_order_template {
    my ($class, $template_filename, $order_data, $output_destination) = @_;
    my $abs_template_filename =
        $class->sample_order_template($template_filename);
    if (! -f $abs_template_filename) {
        die "template missing: $abs_template_filename";
    }
    my $tt = Template->new({ABSOLUTE    => 1,
                            PLUGIN_BASE => 'NAP::Template::Plugin',
                            ENCODING => 'UTF-8',
                           });
    $tt->process(
        $class->sample_order_template($template_filename),
        $order_data,
        $output_destination,
        { binmode => ':utf8' },
    ) or die $tt->error;
}

sub use_old_importer_from_xml {
    my ( $class, $args )    = @_;

    # specify whether the importer should commit it's orders
    $old_order_importer_skip_commit = $args->{skip_commit};

    my $filename    = $args->{filename};
    my $order_args  = $args->{order_args};
    return $class->get_order_from_xml_ok( $filename, $order_args );
}

sub get_order_from_xml_ok {
    my ( $class, $filename, $args ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $order_nr = $class->import_order_ok( $filename, $args );
    return $class->get_order_ok( $order_nr );
}

# takes multiple filenames for test order .TT files and
# gets the order importer to import them all at once rather
# than one at a time. Returns an Array Ref or Order records.
sub get_multi_orders_from_xml_ok {
    my ( $class, $filenames, $args )    = @_;

    my @ordrec;
    my @order_nr;

    if ( ref( $filenames ) ne "ARRAY" ) {
        die "Need to Pass in an Array Ref of Filenames!";
    }

    $args ||= {};

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    foreach my $fname ( @{ $filenames } ) {
        # create the order file
        my $local_args  = {};
        # any extra arguments specified for this file
        if ( exists $args->{ $fname } ) {
            $local_args = $args->{ $fname };
        }
        my $order_nr    = $class->create_xml_order(
                                    { %$local_args, filename => $fname }
                                );
        push @order_nr, $order_nr;
    }

    # import the order files
    $class->run_order_importer_ok;

    # get the order records
    foreach my $order_nr ( @order_nr ) {
        push @ordrec, $class->get_order_ok( $order_nr );
    }
    return \@ordrec;
}

sub import_order_ok {
    my ( $class, $filename, $args ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $args ||= {};

    my $order_nr = $class->create_xml_order(
        { %$args, filename => $filename }
    );

    $class->run_order_importer_ok;
    $class->check_order_tender($order_nr);

    # The order importer now allocates after import, so we should too
    $class->allocate_order($order_nr, $args);

    return $order_nr;
}

sub get_order_ok {
    my ( $class, $order_nr ) = @_;
    my $order = $class->get_schema->resultset('Public::Orders')
                                  ->search( { order_nr => $order_nr } )
                                  ->slice(0,0)
                                  ->single;
    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' ) || return;
    return $order;
}

sub run_order_importer_ok {
    my ($class, $msg) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $msg ||= "ran order importer";

    my $script = $class->_importer_script_name;
    die "Script not executable!" unless -x $script;

    my $parser = XML::LibXML->new;
    $parser->validation(0);

    my $channels= $class->get_schema->resultset('Public::Channel')->get_channels({fulfilment_only => 0});
    my $dbh_web = $class->get_webdbhs;

    # read in waiting directory
    opendir(my $waiting_dir_handle, $class->pending_orders_dir) or die $!;
    while ( defined( my $filename = readdir( $waiting_dir_handle ) ) ) {
        next if $filename =~ /^\./; # skip . and .. and .hidden files
        my $file = $class->pending_orders_dir . "/$filename";
        next if ( -z $file );    # skip if the order file is empty

        # localise STDOUT/STDERR hacking for order import
        # CCW = 2010-07-29
        my $import_error;
        {
            my $nullfh;
            # suppress the importer SPAM on STDOUT
            #open ($nullfh, '>/dev/null') or die "Can't open /dev/null: $!";
            #local *STDOUT = $nullfh;

            my $dbh = $class->get_schema->storage->dbh;
            my $old_autocommit = $dbh->{AutoCommit};
            $dbh->{AutoCommit} = 0;

            # process the XML in a vacuum-of-silence
            $import_error = XT::OrderImporter::process_order_xml(
                path     => $file,
                dbh      => $dbh,
                DC       => $class->whatami,
                dbh_web  => $dbh_web,
                parser   => $parser,
                channels => $channels,
                (
                    defined $old_order_importer_skip_commit
                    ? ( skip_commit => $old_order_importer_skip_commit )
                    : ()
                ),
            );

            $dbh->{AutoCommit} = $old_autocommit;
            #close $nullfh
            #    or die "Can't close \$nullfh: $!";
        }

        if ($import_error) {
            $import_error=~m/, 2='(\d+)'/;
            #print STDERR '$import_error = ' . $import_error . "\n";
            ## no critic(ProhibitCaptureWithoutTest)
            __PACKAGE__->revert_broken_import($class->get_schema,$1);
            die "Order importer failed to run and rollback attempted: $import_error";
        }

        XT::OrderImporter::archive($filename, $class->processed_order_dir(), $class->pending_orders_dir);
        ok(!$import_error, "imported $file ok")
    }

    $class->_release_order_importer_lock();

    ok(1, $msg);
    return 1;
}

sub check_order_tender {
    my ($class, $order_nr) = @_;
    my $s = $class->get_schema;
    my $order = $s->resultset('Public::Orders')
        ->search( { order_nr => $order_nr } )
        ->slice(0,0)->single;
    ok ($order, 'found order');

    ok($order->tenders->count, 'orders associated with tender');
}

sub allocate_order {
    my ($class, $order_nr, $args) = @_;
    my $s = $class->get_schema;
    my $order = $s->resultset('Public::Orders')
        ->search( { order_nr => $order_nr } )
        ->slice(0,0)->single;
    ok ($order, 'found order to allocate');
    Test::XTracker::Data::Order->allocate_order($order, $args);
}

sub _enable_operator {
    my ($class,$user) = @_;

    $user->auto_login(1);
    $user->disabled(0);
    $user->update;
}

sub create_unmatchable_customer_email {
    my ($class, $dbh) = @_;

    my $i = 0;

    my $rstring  = String::Random->new(max => 15);

    my $email;
    my $customer_matching;
    RANDOM_EMAIL: while ($i <= 10) {
        if ($i > 10) {
            ok (0,'Failed to find an unmatchable customer email');
        }
        $i++;
        $email = $rstring->randregex('\w\w\w\w\w\w\w\w\w\w\w').'@gmail.com';
        note("Random email $email");
        $customer_matching = XTracker::Database::Customer::get_customer_by_email($dbh, $email);
        last RANDOM_EMAIL unless $customer_matching;
        note("Matching customer $customer_matching");
    }
    return $email;
}

=head2 CLASS METHOD grant_permissions

    __PACKAGE__->grant_permissions( $user, $section, $subsection, $level )

Where C<$user> is the operator name, C<$section> and C<$subsection>
refer to the Authorisation Section and Authorisation Sub-section tables,
and C<$level> is an optinoal authorisation level.

=cut

sub grant_permissions {
  my ($class, $user, $section, $sub, $level) = @_;

  $user = $class->_get_operator($user);

  my $rs = $class->get_schema->resultset('Public::AuthorisationSection')->search(
    { section => $section }
  )->related_resultset('sub_section');

  my $sub_sec = $rs->search({ sub_section => $sub },{rows=>1})->first
    or die "Unable to find auth section $section/$sub";

  # Enables it.god user for auto log in
  $class->_enable_operator($user);
  return unless defined $level;
  my $curr = $user->permissions->search({authorisation_sub_section_id => $sub_sec->id},{rows=>1});
  if ( $level eq q{} ) {
    $curr->delete;
  }
  elsif ($curr->single) {
    $curr->update({authorisation_level_id => $level});
  }
  else {
    $user->permissions->create({
      authorisation_sub_section_id => $sub_sec->id,
      authorisation_level_id => $level
    });
  }
}

=head2 create_super_purchase_order( $args )

Creates a dummy super_purchase_order with defaults or given arguments.

=cut

sub create_super_purchase_order {
    my ( $class, $args ) = @_;

    my $vpo = $class->get_schema->resultset('Public::SuperPurchaseOrder')->create({
        purchase_order_number => $args->{purchase_order_nr}     || 'test super po',
        status_id             => $args->{status_id}             || $PURCHASE_ORDER_STATUS__ON_ORDER,
        currency_id           => $args->{currency_id}           || $CURRENCY__GBP,
        type_id               => $args->{type_id}               || $PURCHASE_ORDER_TYPE__FIRST_ORDER,
        cancel                => $args->{cancel}                || 0,
        supplier_id           => $args->{supplier_id}           || 1,
        channel_id            => $args->{channel_id}            || $class->channel_for_nap->id,
        created_by            => $args->{created_by}            || $APPLICATION_OPERATOR_ID,
    });
    return $vpo;
}

=head2 setup_purchase_order( \@pids )

A wrapper sub that sets up a purchase_order and its stock_order and
stock_order_item rows. It takes an array ref of pids, and creates one variant
per product.

=cut

sub setup_purchase_order {
    my ( $class, $pids, $args ) = @_;
    $args //= {};

    $pids = [ $pids ] unless ref $pids eq 'ARRAY';
    my @vouchers = $class->get_schema
                         ->resultset('Voucher::Product')
                         ->search({ id => { -in => $pids } })
                         ->all;

    if ( scalar @vouchers ) {
        my $vpo = $class->create_voucher_purchase_order();

        VOUCHER:
        foreach my $voucher ( @vouchers ) {
            my $stock_order = $class->create_stock_order({
                voucher_product_id => $voucher->id,
                purchase_order_id  => $vpo->id,
            });
            my $stock_order_item = $class->create_stock_order_item({
                voucher_variant_id => $voucher->variant->id,
                stock_order_id     => $stock_order->id,
            });
        }
        return $vpo;
    }

    my @products = $class->get_schema
                         ->resultset('Public::Product')
                         ->search({ id => { -in => $pids } })
                         ->all;

    if ( scalar @products ) {
        my $po = $class->create_purchase_order($args);

        PRODUCT:
        foreach my $product ( @products ) {
            my $stock_order = $class->create_stock_order({
                product_id        => $product->id,
                purchase_order_id => $po->id,
            });
            # We need to fix the variant we're receiving to prevent spacebats...
            my $variant_rs = $product->search_related(
                'variants', undef, { order_by => 'me.id' }
            );
            if( ! $args->{create_stock_order_items_for_all_variants} ) {
                $variant_rs = $variant_rs->slice(0,0);
            }
            for my $variant_row ($variant_rs->all) {
                my $stock_order_item = $class->create_stock_order_item({
                    variant_id     => $variant_row->id,
                    stock_order_id => $stock_order->id,
                });
            }
        }
        return $po;
    }

    confess 'PID ( '. join(',', @$pids)
        . ") not found in public.product/voucher.product\n" ;
}

sub create_purchase_order {
    my ( $class, $args ) = @_;
    my $id = $class->get_schema->storage->dbh_do( sub {
        my ($storage, $dbh) = @_;
        my $x = $dbh->selectall_arrayref("SELECT nextval('purchase_order_id_seq')");
        return $x->[0][0];
    });
    note "Will create purchase order with id of $id and args:", pp($args);
    my $po = $class->get_schema->resultset('Public::PurchaseOrder')->create({
        id                    => $id,
        purchase_order_number => $args->{purchase_order_nr}     || "test po $id",
        description           => $args->{description}           || 'test description',
        designer_id           => $args->{designer_id}           || 1,
        status_id             => $args->{status_id}             || $PURCHASE_ORDER_STATUS__ON_ORDER,
        comment               => $args->{comment}               || 'test comment',
        currency_id           => $args->{currency_id}           || $CURRENCY__GBP,
        season_id             => $args->{season_id}             || $SEASON__CONTINUITY,
        type_id               => $args->{type_id}               || $PURCHASE_ORDER_TYPE__FIRST_ORDER,
        cancel                => $args->{cancel}                || 0,
        supplier_id           => $args->{supplier_id}           || 1,
        act_id                => $args->{act_id}                || $SEASON_ACT__MAIN,
        confirmed             => $args->{confirmed}             || 0,
        confirmed_operator_id => $args->{confirmed_operator_id} || $APPLICATION_OPERATOR_ID,
        placed_by             => $args->{placed_by}             || 'Application',
        channel_id            => $args->{channel_id}            || $class->channel_for_nap->id,
    });
    return $po;
}

=head2 create_voucher_purchase_order( $args )

Creates a dummy voucher_purchase_order with defaults or given arguments.

=cut

sub create_voucher_purchase_order {
    my ( $class, $args ) = @_;

    my $id = $class->get_schema->storage->dbh_do( sub {
        my ($storage, $dbh) = @_;
        my $x = $dbh->selectall_arrayref("SELECT nextval('purchase_order_id_seq')");
        return $x->[0][0];
    });
    my $vpo = $class->get_schema->resultset('Voucher::PurchaseOrder')->create({
        id                    => $id,
        purchase_order_number => $args->{purchase_order_nr} || "test voucher po $id",
        currency_id           => $args->{currency_id}       || $CURRENCY__GBP,
        status_id             => $args->{status_id}         || $PURCHASE_ORDER_STATUS__ON_ORDER,
        type_id               => $args->{type_id}           || $PURCHASE_ORDER_TYPE__FIRST_ORDER,
        cancel                => $args->{cancel}            || 0,
        supplier_id           => $args->{supplier_id}       || 1,
        channel_id            => $args->{channel_id}        || $class->channel_for_nap->id,
        created_by            => $args->{created_by}        || $APPLICATION_OPERATOR_ID,
    });
    return $vpo;
}

sub create_db_order {
    # DEBUG "Enter";
    my ($class, $data) = @_;

    if (defined $data->{pids}) {
        # DEBUG "Leave via apply_db_order";
        return __PACKAGE__->apply_db_order($data);
    } else {
        return __PACKAGE__->do_create_db_order($data);
    }
}

=head2 apply_db_order

  my ($order, $order_hash) = Test::XTracker::Data->apply_db_order({
    pids => $pids,
    attrs => [
      { price => 100.00 },
      { price => 250.00 },
    ],
  });

Takes the output from grab_products or find_products and creates the order
direct to the db. Returns a hash of what was used to create the order and
a order DBIx row

=cut

sub apply_db_order {
    # DEBUG "Enter";
    my($class, $opts) = @_;
    my $base = delete $opts->{base} || { };
    my $pids = delete $opts->{pids} || undef;
    my $attrs = delete $opts->{attrs} || undef;

    if (not defined $pids) {
        croak "No pids provided - did you forget { pids => \$pids }";
    }

    my $hash = __PACKAGE__->make_order_hash(
        $base, $pids, $attrs
    );

    my $order = __PACKAGE__->do_create_db_order($hash);

    # DEBUG "Leave";
    return ($order,$hash);
}

=head2 make_order_hash($base,$pids,$prices)

Takes the output from grab_products or find_products and produces a order_hash
that can be used with create_db_order. If prices is provided will provide
prices too

=cut

sub make_order_hash {
    my($class, $base, $pids, $attrs) = @_;

    my $items = undef;
    my $sku_info = undef;

    # create the items from the pids and merge in prices if they have one
    $pids = [ $pids ] unless ref $pids eq 'ARRAY';
    for my $i (0 .. $#{$pids}) {
        my $pid_hash = $pids->[$i];
        if (defined $attrs->[$i]) {
            $items->{ $pid_hash->{sku} } = $attrs->[$i];
        } else {
            $items->{ $pid_hash->{sku} } = { };
        }
        # if this SKU has been used before then presumably there is
        # a need to create more than one shipment item for the order
        if ( exists $sku_info->{ $pid_hash->{sku} } ) {
            $sku_info->{ $pid_hash->{sku} }{num_ship_items}++;
        }
        else {
            $sku_info->{ $pid_hash->{sku} } = $pid_hash;
            $sku_info->{ $pid_hash->{sku} }{num_ship_items} = 1;
        }
    }

    my $hash    = Catalyst::Utils::merge_hashes(
                        $base,
                        { items => $items }
                    );
    return Catalyst::Utils::merge_hashes(
        $hash,
        { sku_info => $sku_info }
    );
}

=head2 grab_multi_variant_product

 my ( $channel, $pids ) =
    Test::XTracker::Data->grab_multi_variant_product({
        channel => 'nap',
        ensure_stock => 1
    });

Given a channel, finds a product with more than one variant, and returns all
variants for it having ensured stock for them all. The output is intentionally
the same as C<grab_products> and documented there.

If you set C<ensure_stock> then we ensure stock for each varient found

=cut

sub grab_multi_variant_product {
    my ( $self, $opts ) = @_;
    my $channel = $opts->{channel};
    $channel = $self->get_local_channel( $channel ) unless ref $channel;

    my $not_in = ($opts->{'not'} && ref $opts->{'not'} eq 'ARRAY')
                 ? join ',', @{$opts->{'not'}}
                 : undef;

    # TODO nasty hack: check DC2.5 locations exist
    $self->ensure_non_iws_locations;
    my $qry = "SELECT
            variant.product_id as pid
        FROM
            variant,
            product,
            product_channel
        WHERE
            variant.type_id = 1 AND
            variant.product_id = product.id AND
            product.id = product_channel.product_id ";
    if ($opts->{live}){
        $qry .= "AND product_channel.live = 't' AND
            product_channel.visible = 't' ";
    }

    my $query = $self->get_dbh->prepare($qry . "AND
                product_channel.channel_id = ? ".
                ( $not_in ? "AND variant.product_id NOT IN ( $not_in )" : '' )
             . " GROUP BY
                    variant.product_id
                HAVING
                    count(*) > 1
                ORDER BY variant.product_id desc
                LIMIT 1");

    $query->execute( $channel->id );
    my $product_id = $query->fetchrow_hashref()->{'pid'};

    # Get the variants associated with this product

    # Make sure the product_channel we return is the one they wanted, in
    # case the product has more than one.
    my $product_channel = $self->get_schema->resultset('Public::ProductChannel')->find({
        product_id => $product_id,
        channel_id => $channel->id,
    });

    my @variants = map {
        {
            pid        => $_->product->id,
            size_id    => $_->size->id,
            sku        => $_->sku,
            variant_id => $_->id,
            product    => $_->product,
            variant    => $_,
            product_channel => $product_channel,
        }
    } $self->get_schema->resultset('Public::Variant')->search({
        'me.product_id' => $product_id,
        'me.type_id'    => 1,
    });

    if ( my $quantity = $opts->{'ensure_stock'} ) {
        $self->ensure_variants_stock( $product_id );
    }
    if ($opts->{ensure_stock_all_variants}) {
        for my $product ( map { $_->{product} } @variants ) {
            for my $variant ($product->variants->all) {
                $self->ensure_stock(
                    $product->id,
                    $variant->size_id,
                    $channel->id,
                );
            }
        }
    }
    return ($channel, \@variants);
}

=head2 grab_products

 my($channel,$product_data) =
    Test::XTracker::Data->grab_products({how_many => 2, channel => 'nap' });

 print $product_data->[0]->{'pid'}; # product ID

Returns a list containing:
(0) an XTracker::Schema::Result::Public::Channel object,
(1) an array-ref of product data. The array-ref contains hash-refs, of the form:

 {
    pid              => '77828',
    size_id          => '229',
    sku              => '77828-229',
    variant_id       => '385268',
    product          => XTracker::Schema::Result::Public::Product,
    variant          => XTracker::Schema::Result::Public::Variant,
    product_channel  => XTracker::Schema::Result::Public::ProductChannel
 }

Also if you want it to grab some products with vouchers here is how to do it:
  my($channel,$product_data) =
    Test::XTracker::Data->grab_products( {
                                how_many => 2,
                                channel => 'nap',
                                no_markdown => 1, # If you only want products with no markdowns
                                # when requesting vouchers this actually creates new vouchers
                                # it doesn't get existing ones
                                phys_vouchers => {
                                    how_many => 1,
                                    want_stock => 3,   # the amount of stock you want set for the voucher
                                    want_code => 4,    # the number of Voucher Codes to generate for the vouqcher
                                    ... # you can also add all the arguments for create_voucher() here as well
                                },
                                virt_vouchers => {
                                    how_many => 1,
                                    want_code => 4,    # the number of Voucher Codes to generate for the voucher
                                    ... # you can also add all the arguments for create_voucher() here as well
                                }
                            } )

Gives you some product-related data, and DBIx row for the channel it got it from.

If you want to ensure that fresh products are always created (recommended), pass in force_create => 1,
and for simplicity, you probably want to pass how_many_variants => 1 as well:

  my ($channel, $product_data) =
    Test::XTracker::Data->grab_products( {
                                how_many => 2,
                                channel => 'nap',
                                force_create => 1,
                                how_many_variants => 1,
                            } );

=cut

sub grab_products {
    my($class,$opts) = @_;
    my $ch              = delete $opts->{channel};
    # normal products
    # ORT-17: sometimes we ONLY want virtual vouchers
    my $num_products    = delete $opts->{how_many} // 1;
    my $with_quantities = delete $opts->{with_quantities} || '';

    my $phys_vouchers   = delete $opts->{phys_vouchers};
    my $virt_vouchers   = delete $opts->{virt_vouchers};
    my $no_markdown     = delete $opts->{no_markdown};

    my $channel;
    my $pids; # an arrayref of hashrefs of product-related data, see POD
    my @vouchers;
    my %vouch_codes;

    # TODO nasty hack: check DC2.5 locations exist
    $class->ensure_non_iws_locations;
    # how many are we asking for?
    # used in a is() test at the end of the method
    my $expected_pids = 0;

    subtest 'grab_products' => sub {
        if (my $chid = delete $opts->{channel_id}) {
            note "overriding channel by id $chid";
            $channel = $class->get_schema->resultset('Public::Channel')->find({
                id => $chid
            });
        }
        elsif (ref($ch)) {
            $channel = $ch;
        }
        else {
            $channel = __PACKAGE__->get_local_channel($ch);
        }
        ok(
            defined $channel,
            sprintf ('found a channel to use [%s (%d)]', $channel->name, $channel->id)
        );

        if ($num_products > 0) {
            $expected_pids += $num_products;
            $pids = __PACKAGE__->find_or_create_products({
                channel_id                  => $channel->id,
                how_many                    => $num_products,
                how_many_variants           => $opts->{how_many_variants},
                # this is correct. really.
                # we always ensure stock later, if we need to
                # asking for stock here would meant we only get back products
                # that *already* have stock.
                dont_ensure_stock           => 1,
                dont_ensure_live_or_visible => $opts->{dont_ensure_live_or_visible} || 0,
                no_markdown                 => $no_markdown || 0,
                avoid_one_size              => $opts->{avoid_one_size},
                with_delivery               => $opts->{with_delivery},
                force_create                => $opts->{force_create},
                storage_type_id             => $opts->{storage_type_id},
                from_products               => $opts->{from_products},
                %{$opts->{shipping_attribute}||{}},
            });
            my $products_found = @$pids;
            unless ( $products_found >= $num_products ) {
                fail("Too few products found, bailing");
                confess "Can't find $num_products PID(s) in channel [$ch] - we found $products_found";
            }

            # Ensure we have actual stock for them
            unless ( $opts->{'dont_ensure_stock'} ) {
                if ($opts->{ensure_stock_all_variants}) {
                    for my $product (map {$_->{product}} @$pids) {
                        for my $variant ($product->variants->all) {
                            $class->ensure_stock($product->id,
                                                $variant->size_id,
                                                $channel->id);
                        }
                    }
                }
                else {
                    $class->ensure_stock( $_->{'pid'}, $_->{'size_id'} ) for @$pids;
                }
            }
        }

        # Physical Vouchers
        if ( defined $phys_vouchers ) {
            my $num    = delete $phys_vouchers->{how_many};
            $num    ||= 1;
            $expected_pids += $num;
            my $want_stock  = delete $phys_vouchers->{want_stock};
            my $want_code   = delete $phys_vouchers->{want_code};
            $phys_vouchers->{channel_id}    = $channel->id;
            $phys_vouchers->{is_physical}   = 1;
            foreach ( 1..$num ) {
                delete $phys_vouchers->{name};
                delete $phys_vouchers->{id};
                my $voucher = $class->create_voucher( $phys_vouchers );
                push @vouchers, $voucher;
                if ( $want_stock ) {
                    $class->set_voucher_stock( { voucher => $voucher, quantity => $want_stock } );
                }
                if ( $want_code ) {
                    # create as many codes for the voucher that is requested
                    foreach ( 1..$want_code ) {
                        my $vcode   = $voucher->create_related( 'codes', { code => $_.'TEST'.$voucher->id } );
                        push @{ $vouch_codes{ $voucher->id } }, $vcode;
                    }

                    is (
                        @{ $vouch_codes{ $voucher->id } },
                        $want_code,
                        qq{created $want_code codes for virtual voucher}
                    );
                }
            }
        }

        # Virtual Vouchers
        if ( defined $virt_vouchers ) {
            my $num    = delete $virt_vouchers->{how_many};
            $num    ||= 1;
            $expected_pids += $num;
            my $want_stock  = delete $virt_vouchers->{want_stock};
            my $want_code   = delete $virt_vouchers->{want_code};
            delete $phys_vouchers->{want_stock};        # get rid of this if its been set
            $virt_vouchers->{channel_id}    = $channel->id;
            $virt_vouchers->{is_physical}   = 0;
            foreach ( 1..$num ) {
                delete $virt_vouchers->{name};
                delete $virt_vouchers->{id};
                my $voucher = $class->create_voucher( $virt_vouchers );
                push @vouchers, $voucher;
                if ( $want_code ) {
                    # create as many codes for the voucher that is requested
                    foreach ( 1..$want_code ) {
                        my $vcode   = $voucher->create_related( 'codes', { code => $_.'TEST'.$voucher->id } );
                        push @{ $vouch_codes{ $voucher->id } }, $vcode;
                    }

                    is (
                        @{ $vouch_codes{ $voucher->id } },
                        $want_code,
                        qq{created $want_code codes for virtual voucher}
                    );
                }
            }
        }

        # blend vouchers into the $pids array with the normal products
        foreach my $voucher ( @vouchers ) {
            push @{ $pids }, {
                        voucher     => 1,
                        is_physical => $voucher->is_physical,
                        pid         => $voucher->id,
                        size_id     => $voucher->variant->size_id,
                        sku         => $voucher->variant->sku,
                        variant_id  => $voucher->variant->id,
                        product     => $voucher,
                        variant     => $voucher->variant,
                        voucher_codes => $vouch_codes{ $voucher->id },
                };
        }

        is(
            @$pids,
            $expected_pids,
            q{grab_products() returned SKUs; } . join (', ',map { $_->{sku} } @$pids )
        );
    };
    return ($channel, $pids);
}

=head2 get_invalid_product_id

Returns the last product_id + 1

=cut

sub get_invalid_product_id {
    my($class,$opts) = @_;
    return $class->get_schema->resultset('Public::Product')->get_column('id')->max()+1;
}

=head2 get_business

    Test::XTracker::Data->get_business( $name )

Returns a DBIx object for a business. If a $name is provided it will search for
that business otherwise it will return the first business in the table.

=cut

sub get_business {
    my ( $class, $name ) = @_;
    my $schema = $class->get_schema;

    my $business_rs = $schema->resultset('Public::Business')->search(
        {},
        { order_by => { -asc => 'id' } },
    );
    return $business_rs->first unless defined $name;
    return $business_rs->search({ name => { ilike => "%$name%" } })->single;
}

=head2 get_local_channel

  Test::XTracker::Data->get_local_channel($name)

Return back the DBIx row for a channel. If $name is provided it will try
to find it in the public.channel.web_name - its shorter ;)

=cut

sub get_local_channel{
    my($class,$name) = @_;
    my $schema = $class->get_schema;
    if (not defined $name) {
        $name = 'nap';
    }

    my $channel_rs = $schema->resultset('Public::Channel')->search({
        web_name => { ilike => "%${name}%" },
    });

    if ($channel_rs->count == 0) {
        diag "Cannot find a channel that matches '$name'";
        return undef;
    }

    if ($channel_rs->count > 1) {
        diag "Found more than one channel that matches '$name' - "
            ."be more specific";
        return undef;
    }
    return $channel_rs->first;
}

=head2 get_local_channel_or_nap

  Test::XTracker::Data->get_local_channel_or_nap($name)

Wraps get_local_channel and will give you nap channel if it can not find it

=cut

sub get_local_channel_or_nap {
    my($self,$name) = @_;

    # try find mr porter...
    my $channel = $self->get_local_channel($name);

    # ..otherwise cheat and use nap ;)
    if (not defined $channel) {
        $channel = $self->get_local_channel('nap');
        diag "  WARNING: using ". $channel->name ." cos could not find $name";
    }
    return $channel;
}

=head2 ensure_variants_stock($product_id)

Given a pid, make sure that there is enough stock to exchange or order any
of its variants on the channel where the product currently exists .

=cut

sub ensure_variants_stock {
    my($self, $pid) = @_;
    my $schema = $self->get_schema;

    my $product = $schema->resultset('Public::Product')->find($pid);

    for my $variant ( $product->variants->all ) {
        $self->ensure_stock(
            $variant->product_id,
            $variant->size_id,
            $product->get_product_channel->channel_id,
        );
    }
}

=head2 ensure_stock($pid, $size, $channel_id)

Given a pid and a size, make sure that there is enough stock to exchange or
order that variant. Currently this will be "at least 100 units" to be safe, but
might end up setting it higher.

=cut

sub ensure_stock {
    my ($class, $pid, $size, $channel_id, $location_id ) = @_;

    confess sprintf('ensure_stock() erroneously called with PID:[%s] and Size:[%s]',
            ($pid//'<undefined>'),
            ($size//'<undefined>')
        ) unless $pid && $size;

    #note "Ensuring stock for [$pid-$size]";

    my $schema = $class->get_schema;

    # look for a normal variant
    my $var_id = $schema->resultset('Public::Variant')->search(
        { product_id => $pid, size_id => $size, },
        { order_by => 'id', rows => 1 }
    )->get_column('id')->first;
    # if we didn't get a normal product look for a voucher
    if (not $var_id) {
        my $var = $schema->resultset('Voucher::Variant')->search({
        voucher_product_id => $pid
        });

        $var_id = $var->single();

        # We couldn't find a regular or voucher variant for the given pid, so
        # we die
        die "Cant find variant $pid-$size" unless $var_id;
        return;
    }

    # So this could also do with checking reservation and transfers, but those
    # are much less likely to exist
    my $reserved_stock = $schema->resultset('Public::ShipmentItem')->search({
      variant_id => $var_id,
      shipment_item_status_id => {'<' => $SHIPMENT_ITEM_STATUS__PICKED}
    })->count;
    # TODO: Should really be all the tables unioned in
    # XTracker::Database::Stock->get_total_item_quantity

    my $product = $schema->resultset('Public::Product')->find($pid);
    if ($product) {
        $class->ensure_product_storage_type($product);
    }

    # PSe: 11May2012 set_product_stock will return a location on success.
    # Tests rely on this behaviour, but someone had helpfully added a
    # return value below this. Fixed.
    return $class->set_product_stock({
      variant_id   => $var_id,
      quantity     => 1000 + $reserved_stock,
      stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
      ( $channel_id ? (channel_id => $channel_id) : () ),
      ( $location_id ? ( location_id => $location_id ) : () ),
    });
}

=head2 ensure_product_storage_type

Given a Product Row as its only argument, sets its storage type to FLAT if
it doesn't already have a storage type set.

=cut

sub ensure_product_storage_type {
    my ( $class, $product ) = @_;

    unless ( defined $product->storage_type_id ) {
        my $schema = $product->result_source->schema;
        $product->storage_type_id( $PRODUCT_STORAGE_TYPE__FLAT );
        $product->update;
    }

    return $product->storage_type;
}

=head2 set_product_stock

At the time of this writing you will need to pass as variable

stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS

if you really want to ensure that the stock created is in a particular status.
Main in this case.
Otherwise it will indeed ensure it has stock on the first status that it finds different from
$FLOW_STATUS__DEAD_STOCK__STOCK_STATUS for which the overall quantity of stock is > 0

=cut

sub set_product_stock {
    my ($class, $args) = @_;

    my $schema = $class->get_schema;
    $args->{channel_id} //= $class->channel_for_nap->id;

    my $var_id = $args->{variant_id};
    my $exact_quantity = $args->{exact_quantity} || 0;

    # Get the variant object
    my $variant_obj = $var_id ?
        $schema->resultset('Public::Variant')->find( $var_id ) :
        $schema->resultset('Public::Variant')->search({
            product_id => $args->{product_id},
            size_id    => $args->{size_id},
        })->first;

    $var_id ||= $variant_obj->id;

    # We can't set product stock unless we have a storage type, because we
    # wouldn't know where to put it...
    $class->ensure_product_storage_type( $variant_obj->product );

    die sprintf("Can't find variant for [%s]-[%s]",
        $args->{product_id},
        $args->{size_id}
    ) unless $variant_obj;

    my $q_rs = $schema->resultset('Public::Quantity');
    my $location;

    # PS-2010-09-09; The way this currently works, it'll look for an existing
    # quantity of any status other than DEAD_STOCK, and use that. If it creates
    # one, it'll be MAIN_STOCK. This means that if there's an existing quantity
    # it finds with a non-DEAD status, it'll add to that, even if the status is
    # something strange. That may be a feature, or it may be a bug. Tests
    # written to rely on that will fail or act odd when we have a single-aisle
    # to test against too.
    #
    # Therefore: this routine now accepts a 'stock_status' argument. If it's set
    # it'll only search for quantity table rows with that stock_status, and
    # it'll create new ones without it. If none is set, it'll use its old
    # default behaviour.

    # Main Stock under the PRL architecture should come from a PRL location
    my $has_prls = XT::Warehouse->has_prls;
    my $fulfill_from_prl = $has_prls && (
        (! defined $args->{'stock_status'}) ||
        $args->{'stock_status'} == $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
    );

    # Delete IWS stock if for some reason there is some there in phase 0!
    my $has_iws = XT::Warehouse->has_iws;
    $q_rs->search({ 'location.location' => iws_location_name() }, {join => 'location'})->delete
        unless $has_iws;

    my $qs_options = {
        'me.variant_id' => $var_id,
        ($args->{channel_id} ? ( 'me.channel_id' => $args->{channel_id} ) : ()),
        # Use a specific location if requested.
        ($args->{location_id} ? ( 'me.location_id' => $args->{location_id} ) : ()),
    };
    my $other_options = {};
    if ( defined $args->{'stock_status'} ) {
        $qs_options->{'status_id'} = $args->{'stock_status'};
        if($qs_options->{'status_id'} == $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS && !$has_iws && !$has_prls) {
            # Make sure it comes from what looks like a 'proper' main location. Bit hacky, but avoids annoying situations
            # with mysterious locations like 'PRE-ORDER' appearing in the db.
            $qs_options->{'location.location'} = { 'like' => '0%' };
            $other_options->{'join'} = 'location';
        }
    } else {
        $qs_options->{'status_id'} =
            { '!=' => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS }
    }
    my $quantity_search_rs = $q_rs->search($qs_options, $other_options);

    # If we're looking for MAIN stock, and we're in the PRL rollout phase, we
    # want a PRL location. During development, we're liable to have XT and PRL
    # locations defined, so specialize the quantity_search to be PRL-specific
    $quantity_search_rs = $quantity_search_rs->filter_prl if $fulfill_from_prl;

    if ($quantity_search_rs->count == 0) {
        note "No quantity, going to create one";
        my $stock_status_type = # Default this appropriately
            $args->{'stock_status'} //= $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

        my $loc_id;
        if ($has_iws) {
            # preferentially use the IWS location if it supports the stock status requested
            $loc_id = $schema->resultset('Public::Location')->search({
                'location_allowed_statuses.status_id' => $stock_status_type,
                'location' => iws_location_name(),
            },{
                join=> 'location_allowed_statuses',
            })->get_column('id')->first;
        }

        # If we're in PRL rollout phase, and they're after MAIN stock, we can
        # lookup an appropriate location
        if ( $fulfill_from_prl ) {
            note(sprintf("Looking up storage type for PID: [%s]",
                $variant_obj->product->id ));

            # If we're intending to fulfil the product, that product will need
            # a storage type...
            my $storage_type = $variant_obj->product->storage_type;

            note(sprintf("Looking up PRL for storage type: [%s]",
                $storage_type->name ));

            my $prl_config_part = XT::Domain::PRLs::get_prls_for_storage_type_and_stock_status({
                storage_type => $storage_type->name,
                stock_status => $schema->resultset('Flow::Status')
                    ->find( $stock_status_type )->name,
            });
            my $intended_prl_name = (keys %$prl_config_part)[0];

            note(sprintf("Looking up location for PRL: [%s]",
                $intended_prl_name));

            my $intended_prl = XT::Domain::PRLs::get_prl_from_name({
                prl_name => $intended_prl_name,
            });

            $loc_id = $intended_prl->location_id;
        }

        # Overide the location if requested.
        $loc_id = $args->{location_id}
            if $args->{location_id};

        unless ($loc_id){
            my $loc_rs = $schema->resultset('Public::Location')->search({
                'location' => {like => '0%'},
                'location_allowed_statuses.status_id' => $stock_status_type,
            }, {
                rows =>1,
                join => ['location_allowed_statuses'],
            });

            $loc_rs = Test::XT::Rules::Solve->solve(
                'XTracker::Data::SetProductStock::ApplyChannelisation' => {
                    '-schema'           => $schema,
                    'stock_status_type' => $stock_status_type,
                    'locations'         => $loc_rs,
                }
            );

            $loc_id = $loc_rs->get_column('id')->first;
        }
        $schema->resultset('Public::Quantity')->create({
          quantity    => $args->{quantity},
          variant_id  => $var_id,
          channel_id  => $args->{channel_id},
          location_id => $loc_id,
          status_id   => $stock_status_type,
        });
        $location   = $schema->resultset('Public::Location')->find( $loc_id );
    }
    else {
        if ($exact_quantity) {
            $quantity_search_rs->update({quantity => 0 });
            $quantity_search_rs->slice(0,0)->single->update({quantity => $args->{quantity} });
            $quantity_search_rs->search({ quantity => 0 })->delete;
        }
        else {
            $quantity_search_rs->update({quantity => $args->{quantity} });
        }

        $location   = $quantity_search_rs->first->location;
    }

    $schema->resultset('Public::LogPwsStock')->log_stock_change(
        variant_id      => $var_id,
        channel_id      => $args->{channel_id},
        pws_action_id   => $PWS_ACTION__MANUAL_ADJUSTMENT,
        # This is wrong, as this value is meant to be a delta. For now, it
        # works. If you break it in the future, that's why!
        quantity        => $args->{quantity},
        notes           => "Adjusted by Test::XTracker::Data",
    );

    ok(
        defined $location,
              qq{ensured variant }
            . $var_id
            . q{ has location with stock [}
            . $location->location
            . q{]}
    );
    return $location;
}

sub set_voucher_stock {
    my ($class, $args)  = @_;

    # TODO: This really should live somewhere common... so we don't call it
    # all over the place. See other calls to this. Maybe put it in a BEGIN
    # block in this module?
    $class->ensure_non_iws_locations;

    my $schema  = $class->get_schema;

    my $voucher = $args->{voucher};

    my $location;
    my $quantity_rs = $schema->resultset('Public::Quantity');
    $quantity_rs = $quantity_rs->search({
        'me.variant_id' => $voucher->variant->id,
        'me.channel_id' => $voucher->channel_id,
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });

    if ( $quantity_rs->count == 0 ) {
        note "No locations, need to create one";
        my $search = { 'location_allowed_statuses.status_id' => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS };
        my $dc_loc = sprintf('%02d', config_var('DistributionCentre', 'name') =~ m{(\d+$)});
        $search->{'location'}  = {-like => "${dc_loc}%"} if $dc_loc eq '03';
        my $loc_id = $schema->resultset('Public::Location')->search(
            $search,
            {
                rows => 1,
                join => [ 'location_allowed_statuses' ],
            } )->get_column('id')->first;

        $schema->resultset('Public::Quantity')->create( {
                quantity    => $args->{quantity},
                variant_id  => $voucher->variant->id,
                channel_id  => $voucher->channel_id,
                location_id => $loc_id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            } );
        $location   = $schema->resultset('Public::Location')->find( $loc_id );
        ok(defined $location, qq{created new location});
    }
    else {
        $quantity_rs->update( { quantity => $args->{quantity} } );
        $location = $quantity_rs->first->location;
    }
    ok(
        defined $location,
              qq{ensured voucher }
            . $voucher->sku
            . q{ has location with stock [}
            . $location->location
            . q{]}
    );
    return $location;
}

sub find_location_by_channel {
    my($self, $channel_name, $match, $count, $type_id) = @_;
    my $schema = $self->get_schema;

    note "SUB find_location_by_channel";
    if (not defined $count) {
        $count = 1;
    }

    my $channel = $schema->resultset('Public::Channel')->search({
        web_name    => { ilike => "$channel_name%" },
    })->first;

    my $set = $schema->resultset('Public::Location')->search({
        location    => { ilike => "${match}%" },
    },{
        'rows' => $count,
    });

    if (defined $type_id) {
        $set = $set->search({type_id => $type_id});
    }

    if ($set && $set->count == $count) {
        return $set;
    }
    return undef;
}

sub get_next_shipment_box_id {
  my ($class) = @_;

  my $dbh = $class->get_dbh;
  return 'C' . $dbh->selectall_arrayref( "SELECT NEXTVAL('shipment_box_id_seq') + 1000000000")->[0][0];
}

sub get_inner_outer_box {
    my ($class,$channel_id) = @_;

    my $rs = $class->get_schema->resultset('Public::InnerBox')->search(
        {
            -and => [
                'me.channel_id'   => $channel_id,
                'me.outer_box_id' => { '!=' => undef }
            ]
        },
        {
            rows => 1,
            prefetch => 'outer_box',
        })->single;
    return { inner_box_id => $rs->id,
             outer_box_id => $rs->outer_box->id
         };
}

=head2 create_test_products

  Test::XTracker::Data->create_test_products( { channel_id => ?, how_many => ? } );

This will create some test products, to try and ensure that calling find_products later
will work.

It makes a load of associated data for each product, from PO onwards.

=cut

sub create_test_products {
    my ($class, $args) = @_;

    my $how_many    = $args->{how_many}   || 1;
    my $channel_id  = $args->{channel_id} || $class->channel_for_nap->id;
    my $is_live_on_channel  = (defined($args->{is_live_on_channel}) ?  $args->{is_live_on_channel} : 1);
    my $product_type_id  = $args->{product_type_id} || 6;
#    my $storage_type_id = $args->{storage_type_id} || 1;
    my $how_many_variants = $args->{how_many_variants} || 2;
    if (ref $how_many_variants && ref $how_many_variants eq 'HASH') {
        $how_many_variants = (values %$how_many_variants)[0];
    }
    my $sizes;
    my $size_scheme_id;
    if ( $args->{sizes} ) {
        $sizes = $args->{sizes};
        # If you specify sizes, best to specify a matching
        # size scheme ID too.
        #
        # If you specify sizes without a size scheme id,
        # you'll have to hope this finds something useful
        # (potentially finds the wrong one if a size belongs
        # to more than one size scheme)
        $size_scheme_id =
            $args->{size_scheme_id}
            //
                $class
                ->get_schema
                ->resultset('Public::SizeSchemeVariantSize')
                ->search(
                    { size_id => $sizes->[0]->id },
                    { order_by => { -asc => [qw/ id /] } }
                )
                ->first
                ->size_scheme_id;
    }
    else {
        my $sizing = $class->get_sizing($how_many_variants);
        $sizes = $sizing->{sizes};
        $size_scheme_id = $sizing->{size_scheme_id};
    }

    my $product_quantity = $args->{product_quantity} || 40;
    my $upload_date      = $args->{upload_date} || "2011-01-01 00:00:00";
    my $designer_id      = $args->{designer_id} || 1,

    my $country_of_origin = $args->{country_of_origin} || $COUNTRY__UNITED_KINGDOM;
    my $fish_wildlife     = $args->{fish_wildlife}     || 0;
    my $cites_restricted  = $args->{cites_restricted}  || 0;
    my $length            = $args->{length};
    my $width             = $args->{width};
    my $height            = $args->{height};
    my $weight            = exists $args->{weight} ? $args->{weight} : 1;

    my @products;

    for my $i (0..$how_many-1) {
        my $purchase_order = $class->create_from_hash({
            channel_id      => $channel_id,
            placed_by       => 'Test User',
            stock_order     => [{
                status_id       => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                product         => {
                    product_type_id => $product_type_id,
                    style_number    => 'ICD STYLE',
                    ( $args->{storage_type_id} ? (storage_type_id => $args->{storage_type_id}) : () ),
                    designer_id     => $designer_id,
                    variant         => [
                        map { +{
                            size_id         => $_->id,
                            stock_order_item    => {
                                quantity            => $product_quantity,
                            },
                        } } @$sizes,
                    ],
                    product_channel => [{
                        channel_id      => $channel_id,
                        upload_date     => $upload_date,
                        live            => $is_live_on_channel,
                    }],
                    product_attribute => {
                        description     => "New Description $i",
                        size_scheme_id  => $size_scheme_id,
                    },
                    shipping_attribute => {
                        country_id       => $country_of_origin,
                        weight           => $weight,
                        fabric_content   => $args->{fabric_content} // 'test_fabric',
                        fish_wildlife    => $fish_wildlife,
                        cites_restricted => $cites_restricted,
                        length           => $length,
                        width            => $width,
                        height           => $height,
                    },
                    price_purchase => {},
                    ( $args->{with_delivery} ? (delivery => {}) : () ),
                },
            }],
            skip_measurements => $args->{skip_measurements},
        });
        #note "made PO".$purchase_order->id;
        my $so = $purchase_order->stock_orders;
        push @products, $purchase_order->stock_orders->first->product;
    }
    return @products;
}

sub get_sizing {
    my ($class,$how_many) = @_;

    my $ss = $class->get_schema->resultset('Public::SizeSchemeVariantSize')
        ->search({
            position => { '>=' , $how_many },
        })->slice(0,0)->single
        ->size_scheme;
    my @sizes = $ss->sizes->slice( 0, $how_many - 1 )->all;
    return {
        size_scheme_id => $ss->id,
        sizes => \@sizes,
    };
}

sub get_some_sizes {
    my ($class, $how_many) = @_;

    my $sizing = $class->get_sizing($how_many);

    return wantarray ? @{ $sizing->{sizes} } : $sizing->{sizes};
}

=head2 find_or_create_products

  Test::XTracker::Data->find_or_create_products( { channel_id => ?, how_many => ? } );

This will attempt to find products using Test::XTracker::Data->find_products and
if it does not find enough, create them and try the finding again.

All parameters are optional. Will return in an array ref
the following per product:

[ {
    pid => 12345,
    size_id => 34,
    sku => '12345-034',
    variant_id => 2342345
} ]

Passing 'how_many' indicates how many products to return it will not go thorugh all variants
for a product first it will just get the first variant for a product and then get the next
product.

=cut

sub find_or_create_products {
    my ($class, $args) = @_;

    # TODO nasty hack: check DC2.5 locations exist
    $class->ensure_non_iws_locations;

    $args->{how_many} ||= 1;

    my $force_create = $args->{force_create};

    my $found;

    my $failed = 0;

    if ($force_create) {
        note 'Forcing product creation';
    }
    else {
        $found = $class->find_products($args);

        if (!$found) {
            $failed = 1;
        } elsif (scalar @$found < $args->{how_many}) {
            $failed = 1;
        } else {
            # find_products sometimes returns an array of the right length even
            # if it got nothing, it just might be full of undefs
            # so we check to make sure every element has the right bits
            foreach my $product (@$found) {
                unless ($product->{pid} && $product->{sku}) {
                    $failed = 1;
                    last;
                }
            }
        }
    }

    if ($failed || $force_create) {
        my @created_products = $class->create_test_products($args);
        $found = $class->find_products({
                %$args,
                dont_ensure_stock => 1,
                # if we forced product creation, make sure we only use those
                # newly-created products
                ($force_create
                    ? (from_products => \@created_products)
                    : ()
                ),
        });
    }
    return $found;
}

=head2 find_products

  Test::XTracker::Data->find_products( { channel_id => ?, how_many => ? } );

This will find products. All parameters are optional. Will return in an array ref
the following per product:

[ {
    pid => 12345,
    size_id => 34,
    sku => '12345-034',
    variant_id => 2342345
} ]

Passing 'how_many' indicates how many products to return it will not go thorugh all variants
for a product first it will just get the first variant for a product and then get the next
product.

This function will only return products that have located stock. If you do not
believe you have located stock in the database to return, you can pass in
"dont ensure stock" as a boolean.

=cut

sub find_products {
    my ($class, $args) = @_;

    my $schema  = $class->get_schema;
    my @retarr;

    my $channel_id      = $args->{channel_id}   || $class->channel_for_nap->id;
    my $how_many        = $args->{how_many}     || 1;

    my $prod_rs = $schema->resultset('Public::ProductChannel');

    # restrict to subset of products if supplied
    if (my $from_products = $args->{from_products}) {
        if (my @from_products = (ref $from_products ? @$from_products : ($from_products))) {
            $prod_rs = $prod_rs->search({
                'variants.product_id' => { in => [ map { $_->id } @from_products ] },
            });
        }
    }

    # Sometimes we care about the upload_date
    if ($args->{upload_date}) {
        $prod_rs = $prod_rs->search({
            'me.upload_date' => $args->{upload_date},
        });
    }

    # Force a specific product type
    if ($args->{product_type_id}) {
       $prod_rs = $prod_rs->search({
            'product.product_type_id' => $args->{product_type_id},
        });
    }
    # Force a specific storage type
    if ($args->{storage_type_id}) {
       $prod_rs = $prod_rs->search({
            'product.storage_type_id' => $args->{storage_type_id},
        });
    }

    if ($args->{no_markdown}) {
        $prod_rs = $prod_rs->search({
            'price_adjustments.percentage' => undef,
        });
    }
    # sometimes we don't want One-Size products
    if ($args->{avoid_one_size}) {
        $prod_rs = $prod_rs->search({
            'variants.size_id' => {'!=' => 5}, # magic number alert!
        });
    }
    # Sometimes we don't want to ensure there is stock
    my %quantity_ensuration_search;
    unless ( $args->{dont_ensure_stock} ) {
        %quantity_ensuration_search = (
            'quantities.channel_id' => $channel_id,
            'quantities.status_id'  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            'quantities.quantity'   => { '>' => 0 },
        );
    }

    # Sometimes we don't care if it is live or visible
    unless ($args->{dont_ensure_live_or_visible}) {
        $prod_rs = $prod_rs->search({
            'me.live'       => 1,
            'me.visible'    => 1,
        });
    }

    if ($args->{with_delivery}) {
        # this means:
        # only give me product(_channel)s for which all variants have a delivery_item
        # sometimes we get some variants without delivery_items, I'm not sure why
        # this makes sure that we ignore those, otherwise some code (e.g. quarantine_stock) will barf
        $prod_rs = $prod_rs->search({
        },{
            '+select' => [ { count => 'link_delivery_item__stock_order_items.delivery_item_id' },
                           { count => 'variants.id' } ],
            '+as' => [ 'soi_di_count','vars_di_count' ],
            join => {
                product => {
                    stock_order => {
                        stock_order_items => {
                            link_delivery_item__stock_order_items =>
                                'delivery_item',
                        }
                    },
                },
            },
            having => [
                'count(link_delivery_item__stock_order_items.delivery_item_id)'
                    => \'= count(variants.id)', #',
            ],
        });
    }

    # Let's make an assumption that if we want to avoid_one_size we also want a
    # product that has more than one variant, even if we haven't passed a value
    # for how_many_variants
    if (my $num_vars = $args->{how_many_variants} || ($args->{avoid_one_size} ? 2 : 0)) {
        my $num_vars_condition = ref($num_vars) ? $num_vars : { '>=' => $num_vars };
        $prod_rs = $prod_rs->search({},{
            '+select' => [ { count => 'variants.id' } ],
            '+as' => [ 'var_count' ],
            having => [
                'count(variants.id)' => $num_vars_condition,
            ],
        });
    }

    my %product_name_search=();
    if ($args->{require_product_name}) {
        $product_name_search{'product_attribute.name'} = {"!=", undef, "!=", ''};
    }

    $prod_rs = $prod_rs->search( {
            'me.channel_id'         => $channel_id,
            'me.transfer_status_id' => { '!=' => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED },
            'variants.type_id'      => $VARIANT_TYPE__STOCK,
            %product_name_search,
            %quantity_ensuration_search,
        }
        ,{
            join => [{
                'product' => ( $args->{dont_ensure_stock} ? ['variants','product_attribute'] : [{'variants'=>'quantities'},'product_attribute'] )
            }
            ,($args->{no_markdown} ? { 'product' => 'price_adjustments' } : () ) ],
            rows        => $how_many,
            order_by    => 'product_id',
            distinct    => 1,
        }
    );

    while ( my $pc = $prod_rs->next ) {
        my $variant = $pc->product->search_related( variants =>
            {
                type_id => $VARIANT_TYPE__STOCK,
                %quantity_ensuration_search
            },
            {
                rows => 1,
                distinct => 1,
                order_by => 'id',
                ( $args->{dont_ensure_stock} ? () : ( join => 'quantities' ) )
            }
        )->single;

        ok (
            defined $variant,
            "found variant for product [".$pc->id."]"
        );

        # turn off certain restrictions for products
        # which could cause tests to unexpectely fail
        # if a previous test has left them on
        $pc->product->shipping_attribute->update( {
            is_hazmat       => 0,
        } );
        $pc->product->link_product__ship_restrictions->delete;

        push @retarr,{
                pid         => $pc->product_id,
                size_id     => $variant->size_id,
                sku         => $variant->sku,
                variant_id  => $variant->id,
                product     => $pc->product,
                variant     => $variant,
                product_channel => $pc,
            };
    }
    return \@retarr;
}

# Formats a DBIx::Class Product row to be like the output of find_products, so
# that we can pass that in to various subs that require that format.
sub explode_dbic_product_row_like_find_products_does {
    my ( $class, $product ) = @_;

    my ($variant, %exploded_hash);
    if ( $product->isa('XTracker::Schema::Result::Voucher::Product') ) {
        $variant = $product->variant;
        # to explode more accurately we need to pass a key for voucher_codes
        # here, but as I don't need one right now I'll leave this as an
        # exercise for another day
        %exploded_hash = ( is_physical => $product->is_physical, voucher => 1 );
    }
    else {
        $variant = $product->variants->first;
    }

    return {
        %exploded_hash,
        pid             => $product->id,
        size_id         => $variant->size_id,
        sku             => $variant->sku,
        variant_id      => $variant->id,
        product         => $product,
        variant         => $variant,
        product_channel => $product->get_product_channel,
    };
}

=head2 add_attribute_value_to_product

    $array_ref  = Test::XTracker::Data->add_attribute_value_to_product( $attribute_id, $products )

adds the given attribute_id to the given products

=cut

sub add_attribute_value_to_product {
    my ($class, $args) = @_;

    my $schema = $class->get_schema;

    for my $product ( @{$args->{products}} ) {
        my $rs = $schema->resultset('Product::AttributeValue')->update_or_create({
            product_id => $product->{pid},
            attribute_id => $args->{attribute_id},
            deleted => 0,
            sort_order => 0,
        },{
            key => 'attribute_value_product_id_key',
        });
    }
    return;
}

=head2 remove_attribute_type

    $array_ref  = Test::XTracker::Data->remove_attribute_type( $attribute_id )

removes the attributes from attribute_value of a certain type for all products

=cut

sub remove_attribute_type {
    my ($class, $args) = @_;

    my $schema = $class->get_schema;

    my $rs = $schema->resultset('Product::AttributeType')->search({
        'id' => $args->{attribute_type_id},
    })->single();

    my $attr_rs = $rs->attribute;
    while ( my $attr =  $attr_rs->next ) {
        my $prod_attr_rs = $attr->product_attribute;
        while ( my $delete_me = $prod_attr_rs->next ) {
            $delete_me->delete;
        }
    }
    return;
}

=head2 find_products_with_x_variants

    $array_ref  = Test::XTracker::Data->find_products_with_x_variants( $channel, $num_pids, $num_variants )

This finds a number of products for a Sales Channel that has a minimum of X variants.

=cut

sub find_products_with_x_variants {
    my ( $class, $channel, $num_pids, $num_vars )   = @_;

    my $num_vars_condition = ref($num_vars) ? $num_vars : { '>=' => $num_vars };

    my $schema  = $class->get_schema;
    my @pids;

    my $prod_rs = $schema->resultset('Public::ProductChannel')->search( {
                                    channel_id      => $channel->id,
                                    live            => 1,
                                    visible         => 1,
                                    transfer_status_id => { '<' => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED },
                                    'variants.id'   => { 'IS NOT' => \"NULL" }, #"
                                    'variants.type_id' => $VARIANT_TYPE__STOCK,
                                },
                                {
                                    select  => [ 'me.product_id', { count => 'variants.id' } ],
                                    as      => [ qw( product_id var_count ) ],
                                    join    => [ { product => 'variants' } ],
                                    group_by=> [ qw( me.product_id ) ],
                                    having  => { 'count( variants.id )' => $num_vars_condition },
                                    rows => $num_pids,
                                });
    while ( my $prod = $prod_rs->next ) {
        push @pids, $schema->resultset('Public::Product')->find( $prod->get_column( 'product_id' ) );
    }
    return \@pids;
}

=head2 find_products_with_variants

  Test::XTracker::Data->find_products_with_variants( { channel_id => ?, how_many => ? } );

This finds a number of products for a Sales Channel that has a minimum of 2 variants in the same format as find_products.

=cut

sub find_products_with_variants {
    my ($class, $args) = @_;

    my $schema  = $class->get_schema;
    my @retarr;

    my $channel_id  = $args->{channel_id} || $class->channel_for_nap->id;
    my $how_many    = $args->{how_many} || 1;

    my $prod_rs = $schema->resultset('Public::ProductChannel')->search( {
                                    channel_id      => $channel_id,
                                    live            => 1,
                                    visible         => 1,
                                    transfer_status_id => { '<' => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED },
                                    'variants.id'   => { 'IS NOT' => \"NULL" }, #"
                                    'variants.type_id' => $VARIANT_TYPE__STOCK,
                                },
                                {
                                    select  => [ 'me.product_id', { count => 'variants.id' } ],
                                    as      => [ qw( product_id var_count ) ],
                                    join    => [ { product => 'variants' } ],
                                    group_by=> [ qw( me.product_id ) ],
                                    having  => { 'count( variants.id )' => { '>', 1 } },
                                    rows => $how_many,
                                });

    while ( my $pc = $prod_rs->next ) {
        my $product = $schema->resultset('Public::Product')->find( $pc->get_column( 'product_id' ) );
        my $variant = $product->search_related('variants',{ type_id => $VARIANT_TYPE__STOCK },{rows=>1})->first;
        push @retarr,{
                pid         => $product->id,
                size_id     => $variant->size_id,
                sku         => $variant->sku,
                variant_id  => $variant->id,
                product     => $product,
                variant     => $variant,
            };
    }
    return \@retarr;
}

=head2 assign_test_credit - acts only on xtracker's data

    Test::XTracker::Data->assign_test_credit( {
        customer_id => ?,
        credit => ?,
        currency_id=> ?,
        channel_id => ? });

=cut

sub assign_test_credit {
    my $class   = shift;
    my $dbh     = shift;
    my $args    = {
        customer_id     => undef,
        credit          => undef,
        currency_id     => undef,
        channel_id      => undef,
        @_
    };

    die 'assign_test_credit: requires customer_id, credit, currency_id and channel_id'
    unless defined ($args->{customer_id}) &&
        defined ($args->{credit}) &&
        defined ($args->{currency_id}) &&
        defined ($args->{channel_id});

    # First delete any matching credit that's there.
    my $qry = "DELETE FROM customer_credit WHERE customer_id = ? AND currency_id = ? AND channel_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($args->{customer_id}, $args->{currency_id},$args->{channel_id} );

    # Now add the new values in
    $qry = "INSERT INTO customer_credit VALUES (?, ?, ?, ?)";
    $sth = $dbh->prepare($qry);
    $sth->execute($args->{customer_id}, $args->{credit}, $args->{currency_id},$args->{channel_id} );

    note "Set customer_credit : customer ".$args->{customer_id}.
        " credit ".$args->{credit}." currency_id ".$args->{currency_id}.
        " channel ".$args->{channel_id}."\n";
}

=head2 create_test_customer

  Test::XTracker::Data->create_test_customer(  channel_id => ?  );

This will create a customer in the specified 'channel_id'
(no default channel is provided) and returns the customer_id

=cut

sub create_test_customer {
    my $class  = shift;
    my $args  = {
        is_customer_number  => undef,
        title               => 'Ms',
        first_name          => 'Test-forename',
        last_name           => 'Test-surname',
        email               => 'perl@net-a-porter.com',
        category_id         => 1,
        channel_id          => undef,
        telephone_1         => '+44 1234 123 123',
        telephone_2         => '+1 123 1234 1234',
        telephone_3         => '+1 123 123 123',
        account_urn         => 'urn:nap:account:6da65c59-4bda-42f3-8dbc-6b00e2e2ba55',
        @_
    };

    confess 'create_test_customer: requires a channel_id' unless defined($args->{channel_id});

    my $schema = $class->get_schema;
    my $dbh    = $schema->storage->dbh;

    $args->{is_customer_number} =  $dbh->selectall_arrayref(
        "SELECT (SELECT MAX(is_customer_number) FROM customer) + 1"
        )->[0][0] || 1;
    return create_customer($dbh, $args);
}

=head2 find_customer

  Test::XTracker::Data->find_customer( { channel_id => ? } );

This will find (or create) a customer who has greater than zero store credit.
The 'channel_id' parameter is optional, but .

=cut

sub find_customer {
    my ($class, $args)  = @_;

    my $schema  = $class->get_schema;
    my $channel_id  = $args->{channel_id};
    my $local_channel = $class->get_local_channel;
    my $cc_rs =  $schema->resultset('Public::CustomerCredit')->search( {
        'me.channel_id' => [$channel_id, $local_channel->id],
        credit          => { '>' => 0 },
        'customer.category_id' => $CUSTOMER_CATEGORY__NONE,
        'customer.channel_id' => $channel_id,
    },{
        join            => 'customer',
        order_by        => 'credit DESC',
        rows            => 1,
    } )->first;

    if (!$cc_rs) {
        note "Creating a customer";
        my $customer_id = $class->create_test_customer(%$args, 'category_id' => $CUSTOMER_CATEGORY__NONE);
        note "Customer ID: [$customer_id]";
        $cc_rs = $schema->resultset('Public::CustomerCredit')->create({
            'customer_id' => $customer_id,
            'channel_id'  => $channel_id,
            'credit'      => 250,
            'currency_id' => 1,
        });
    }

    # remove any Customer Attributes such as
    # Preferred Language so that the defaults are used
    $cc_rs->customer->delete_related('customer_attribute');

    return $cc_rs->customer;
}

=head2 delete_reservations

    Test::XTracker::Data->delete_reservations( {
        customer    => $customer_id || $customer_obj
                        or
        variant     => $variant_id || $variant_obj
                        or
        product     => $product_id || $product_obj
    } );

This will delete all Reservations for the type you pass in, including taking care of the logs.

=cut

sub delete_reservations {
    my ( $class, $args )    = @_;

    my $schema  = $class->get_schema;

    my %find_obj    = (
        customer    => $schema->resultset('Public::Customer'),
        variant     => $schema->resultset('Public::Variant'),
        product     => $schema->resultset('Public::Product'),
        operator    => $schema->resultset('Public::Operator'),
    );

    # only deal with one Type
    my ( $type )    = keys %{ $args };
    my $value       = $args->{ $type };

    my $obj_rec;
    if ( ref( $value ) ) {
        $obj_rec    = $value;
    }
    else {
        $obj_rec    = $find_obj{ $type }->find( $value );
    }

    if ( $type ne 'product' ) {
        my @reservs = $obj_rec->discard_changes->reservations->all;
        foreach my $reserv ( @reservs ) {
            $reserv->reservation_logs->delete;
            $reserv->reservation_operator_logs->delete;
            $reserv->pre_order_items->update( { reservation_id => undef } );    # removing the whole Pre-Order will end up as bad
            $reserv->link_shipment_item__reservations->delete;                  # as removing an Order, so just fudge the data
            $reserv->link_shipment_item__reservation_by_pids->delete;
            $reserv->delete;
        }
    }
    else {
        # if it's a product then go through each variant
        my @variants    = $obj_rec->discard_changes->variants->all;
        foreach my $variant ( @variants ) {
            __PACKAGE__->delete_reservations( { variant => $variant } );
        }
    }
    return $obj_rec->discard_changes;
}

=head2 find_shipping_account

  $rec = find_shipping_account(
                            $class,
                            {
                                channel_id  => 1,          # Optional
                                acc_name    => 'Domestic', # Optional
                                carrier     => 'DHL%'      # Optional
                            }
                      );

This returns a Shipping Account record based on the Channel Id, the
Shipping Account Name such as 'Domestic' or 'International Road' and
the carrier (UPS or DHL).

Defaults to picking the default carrier for the DC if C<carrier> is left
undefined.

=cut

sub find_shipping_account {
    my ($class, $args)  = @_;

    my $schema  = $class->get_schema;
    my $rec;
    my $search;

    $search = { 'me.name' => { 'NOT IN' => [ 'Unknown', 'FTBC' ] }, };

    if ( $args->{carrier_id} ) {
        $search->{'me.carrier_id'} = $args->{carrier_id};
    }
    else {
        $search->{'carrier.name'} = { ilike =>
            $args->{carrier} // config_var('DistributionCentre','default_carrier')
        };
    }
    if ( $args->{acc_name} ) {
        $search->{'me.name'} = $args->{acc_name};
    }
    if ( $args->{channel_id} ) {
        $search->{'me.channel_id'} = $args->{channel_id};
    }
    return $schema->resultset('Public::ShippingAccount')->search( $search, {
        join => 'carrier',
        rows => 1,
    })->single;
}

=head2 find_or_create_shipping_account

  $rec = find_or_create_shipping_account(
                            $class,
                            {
                                channel_id  => 1,          # Optional
                                acc_name    => 'Domestic', # Optional
                                carrier     => 'DHL%'      # Optional
                            }
                      );

This returns a Shipping Account record based on the Channel Id, the
Shipping Account Name such as 'Domestic' or 'International Road' and
the carrier (UPS or DHL).

If it does not find a matching one, it tries to make it.

=cut

sub find_or_create_shipping_account {
    my ($class, $args)  = @_;

    my $rec = $class->find_shipping_account($args);
    my $schema  = $class->get_schema;

    if (!$rec) {
        diag "Creating a new shipping account. That's pretty weird.";
        diag "Failed to find a shipping account matching:";
        require Data::Dumper;
        diag Data::Dumper::Dumper( $args );

        my $carrier;
        if ( $args->{'carrier'} ) {
            my @carriers = $schema->resultset('Public::Carrier')->search({
                name => { like => $args->{'carrier'} }
            });
            if (! @carriers) {
                diag "Can't find a carrier matching " . $args->{'carrier'};
                fail("Suitable carrier found for " . $args->{'carrier'});
                die;
            } elsif ( @carriers > 1 ) {
                diag "You specified an ambiguous carrier when trying to create a new shipping account";
                diag "Carrier name " . $args->{'carrier'} . " returns " . (scalar @carriers) . " results";
                fail("One carrier found for " . $args->{'carrier'});
                die;
            }
            $carrier = $carriers[0];
        } else {
            $carrier = $schema->resultset('Public::Carrier')->search({},{ order_by => 'id'})->first();
        }

        note "Creating test shipping account";
        $rec = $schema->resultset('Public::ShippingAccount')->create({
            id                  => $schema->resultset('Public::ShippingAccount')->get_column('id')->max + 1,
            'name'              => $args->{acc_name} || 'Test',
            'account_number'    => 'TEST1234',
            'carrier_id'        => $carrier->id,
            'channel_id'        => $args->{channel_id},
            'return_cutoff_days'=> 12,
        });
    }
    return $rec;
}

=head2 find_prem_postcode

  $rec  = find_prem_postcode($class,$channel_id);

This finds the first postcode that is marked for Premier Shipping for the Sales Channel.

=cut

sub find_prem_postcode {
    my ($class, $channel_id)    = @_;

    my $schema  = $class->get_schema;
    my $rec;

    $rec    = $schema->resultset('Public::PostcodeShippingCharge')
                        ->search({ channel_id => $channel_id })
                            ->next;
    return $rec;
}

=head2 clear_existing_manifest

 Test::XTracker::Data->clear_existing_manifest($carrier);

This gets the existing manifests and sets their status to complete whilst remembering their current status. It returns an array of manifest records along with the original status so that they can be cleared by 'restore_cleared_manifest'. Use this to test making manifests so existing manifests are not in the way, then use 'restore_cleared_manifest' to bring them back.

=cut

sub clear_existing_manifest {
    my ( $class, $carrier ) = @_;

    my $schema  = $class->get_schema;
    my @manifests;

    my $rs  = $schema->resultset('Public::Manifest')->search(
                                                        {
                                                            'carrier.name'  => $carrier,
                                                            'me.status_id'  => { '<' => Test::Config->value( 'XTracker::Data' => 'status_cutoff' ) },
                                                        },
                                                        {
                                                            join => 'carrier',
                                                        }
                                                    );
    while ( my $rec = $rs->next ) {
        my $org_status  = $rec->status_id;
        $rec->update({ status_id => 7 });       # Update to Completed
        $rec->discard_changes;
        push @manifests, {
                        manifest_rec    => $rec,
                        manifest_status => $org_status,
                    };
    }
    return \@manifests;
}

=head2 restore_cleared_manifest

 Test::XTracker::Data->restore_cleared_manifest( $manifest_array );

This restores the status of manifests which were cleared using 'clear_existing_manifest'.

=cut

sub restore_cleared_manifest {
    my ( $class, $manifests )   = @_;

    foreach my $rec ( @{ $manifests } ) {
        $rec->{manifest_rec}->update({ status_id => $rec->{manifest_status} });
        $rec->{manifest_rec}->discard_changes;
    }
    return;
}

=head2 do_create_db_order

Create an order directly in the DB and get back a
L<XTracker::Schema::Result::Public::Orders> object. Call like:

  Test::XTracker::Data->do_create_db_order({
    items => {
      '48499-097' => { }
    }
  })

The top level hash is values for the C<orders> row, except for 'items'. The
items entry is a hash of { $variant => \%shipment_item_fields }.

Currently shipment boxes are not created, and the order is created as
'dispatched' by default.

The sub has been extended to accept value for tenders. You can add tenders in
the following manner:
  do_create_db_order({ tenders => [
    { type => 'card_debit' value => $value }.
    { type => 'store_credit', value => $value },
    { type => 'voucher_credit', value => $value, code => $voucher_code },
    { type => 'voucher_credit', value => $value, code => $voucher_code },
      ...
  ]});

You can add multiple I<voucher_credit> hashrefs, but only one I<card_debit> and
I<store_credit> rows - though there is no validation for this, so be careful!
Also you B<should> only add codes to I<voucher_credit> hashrefs, but again, no
validation - so do not do it.

You can add Nominated Day information with the top level key:

    nominated_day => {
        nominated_delivery_date           => $delivery_datetime,
        nominated_dispatch_time           => $dispatch_datetime,
        nominated_earliest_selection_time => $nominated_earliest_selection_time,
    },

=cut

sub do_create_db_order {
    # DEBUG "Enter";
    my ($class, $data) = @_;
    my %foo = %{$data}; $data = \%foo;

    my $type = Dict[
    items => HashRef,
    slurpy Any
    ];

    $type->check($data)
        or die 'create_db_order(\%data) '
            . $type->get_message($data) ." ". pp($data) .caller;

    my $sku_info = delete $data->{sku_info};

    my $items = delete $data->{items};
    is_HashRef($items)
        or die 'create_db_order: data hash must have items HashRef: '
            . HashRef->get_message($items);

    my $shipment_status_id = delete $data->{shipment_status} || $SHIPMENT_STATUS__DISPATCHED;
    my $shipment_item_status_id = delete $data->{shipment_item_status} || $SHIPMENT_ITEM_STATUS__DISPATCHED;
    my $schema = $class->get_schema;
    $data->{order_nr} ||= $class->_next_order_id;
    $data->{basket_nr} ||= $data->{order_nr};
    $data->{date} ||= $schema->format_datetime($schema->db_now->set_time_zone('Europe/London'));
    $data->{channel_id} ||= $class->channel_for_nap->id;
    $data->{customer_id} ||= $class->find_or_create_customer({channel_id => $data->{channel_id}})->id,
    $data->{email} ||= 'test.suite@xtracker';
    $data->{placed_by} ||= 'test.suite@xtracker';
    $data->{telephone} ||= 'telephone';
    $data->{mobile_telephone} ||= '';
    $data->{currency_id} ||= 1;

    $data->{order_status_id} ||= $ORDER_STATUS__ACCEPTED;

    # Pick a random order_address. we don't care
    $data->{invoice_address_id} ||= ($class->order_address({address=>'create'}))->id;

    # totals
    $data->{total_value} = 0;
    $data->{gift_credit} = 0;
    $data->{store_credit} = 0;

    my @shipment_items;

    # Create the shipment/items
    my $variants = $schema->resultset('Public::Variant');
    # Sort by pid so @shipment_items are always created in the same order -
    # prevents breakage in renumerations.t - DJ
    for my $sku ( sort { ( split /-/, $a)[0] <=> (split /-/, $b)[0] } keys %$items) {
        my $var;
        my $price;
        my $tax = $items->{$sku}{tax} || 0;
        my $duty = $items->{$sku}{duty} || 0;
        my ($var_id_fld, $var_code_id_fld, $code_id);
        my $returnable_state = $sku_info->{$sku}{item_returnable_state_id}
                               // $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
        if ( !defined $sku_info->{ $sku }{voucher} ) {
            $var_id_fld = 'variant_id';
            $var = $variants->find_by_sku($sku);
            $price = $items->{$sku}{price} || 100;
        }
        else {
            $returnable_state = $SHIPMENT_ITEM_RETURNABLE_STATE__NO;
            $var_id_fld = 'voucher_variant_id';
            $var_code_id_fld = 'voucher_code_id';
            $var = $sku_info->{ $sku }{variant};
            $price = $sku_info->{ $sku }{product}->value;

            if ( $sku_info->{ $sku }{ assign_code_to_ship_item } ) {
                $code_id = $sku_info->{ $sku }{product}->add_code(
                    'TV-'.String::Random->new->randregex('[A-Z]{8}')
                )->id;
            }
        }

        $data->{total_value} += $price;

        my $si = {
            duty => $duty,
            tax => $tax,
            unit_price => $price,
            shipment_item_status_id => $shipment_item_status_id,
            returnable_state_id => $returnable_state,
        };

       $si->{$var_id_fld} = $var->id if $var_id_fld;
       $si->{$var_code_id_fld} = $code_id if $code_id;
        $si->{gift_message} = $items->{$sku}{gift_message}  if $items->{$sku}{gift_message};
        my $num_ship_items  = $sku_info->{ $sku }{num_ship_items} || 1;
        foreach ( 1..$num_ship_items ) {
            push @shipment_items, $si;
        }
    }

    # Note: This adds 10 the total value of the order - don't expect the total
    # value of the renumeration items to match that of the order! - DJ
    $data->{shipping_charge} = 10 unless exists $data->{shipping_charge};
    $data->{total_value} += $data->{shipping_charge};

    $data->{tenders} = [ $class->_prepare_tenders_data(
        delete $data->{tenders},
        $data->{total_value},
    ) ];

    my $nominated_day = delete $data->{nominated_day} // {};
    my $nominated_delivery_date  = $nominated_day->{nominated_delivery_date};
    my $nominated_dispatch_time  = $nominated_day->{nominated_dispatch_time};
    my $nominated_earliest_selection_time
        = $nominated_day->{nominated_earliest_selection_time};

    $data->{shipping_charge_id} //= $class->_get_shipping_charge_id(
        $schema,
        $data->{shipping_charge_sku},
    );
    delete $data->{shipping_charge_sku};

    $data->{premier_routing_id} //= $class->_get_premier_routing_id(
        $schema,
        $data->{shipping_charge_id},
    );

    # Don't generate an SLA if the test data includes an explicit setting
    my $apply_SLA = (exists($data->{sla_cutoff}) ? 0 : 1);

    my $outward_airway_bill = delete $data->{outward_airway_bill};
    my $return_airway_bill = delete $data->{return_airway_bill};

    $data->{shipment} = {
        shipment_items                    => \@shipment_items,
        date                              => $data->{date},
        shipment_type_id                  => delete $data->{shipment_type}  || $SHIPMENT_TYPE__DOMESTIC,
        shipment_class_id                 => delete $data->{shipment_class} || $SHIPMENT_CLASS__STANDARD,
        shipment_status_id                => $shipment_status_id,
        shipment_address_id               => $data->{invoice_address_id},
        email                             => $data->{email},
        telephone                         => $data->{telephone},
        mobile_telephone                  => $data->{mobile_telephone},
        packing_instruction               => '',
        shipping_charge                   => delete $data->{shipping_charge}    || 10.00,
        shipping_charge_id                => delete $data->{shipping_charge_id} || 0,
        destination_code                  => delete $data->{dhl_destination}    || 'LHR',
        av_quality_rating                 => delete $data->{av_quality_rating}  || '',
        return_airway_bill                => delete $data->{return_airway_bill} || 'none',
        gift_credit                       => $data->{gift_credit},
        store_credit                      => $data->{store_credit},
        # 0 == Unknown. No constants for shipping accounts at the moment
        shipping_account_id               => delete $data->{shipping_account_id} || 0,
        premier_routing_id                => delete $data->{premier_routing_id},
        gift                              => delete $data->{gift_shipment}       || 0,
        gift_message                      => delete $data->{gift_message}        || '',
        comment                           => delete $data->{comment}             || '',
        nominated_delivery_date           => $nominated_delivery_date,
        nominated_dispatch_time           => $nominated_dispatch_time,
        nominated_earliest_selection_time => $nominated_earliest_selection_time,
        sla_cutoff                        => delete $data->{sla_cutoff},
        ( defined($outward_airway_bill) ? (outward_airway_bill => $outward_airway_bill) : () ),
        ( defined($return_airway_bill) ? (return_airway_bill => $return_airway_bill) : () ),
    };
    # DC2 does not need a DHL code... UNLESS we allow a hack to come
    # through. This is only used for DC2 tests and is currently only used for
    # t/20-units/manifest/manifest.data.
    # Hoping someone will fix the tests properly one day...
    unless ( delete $data->{keep_destination_code} ) {
        delete $data->{shipment}{destination_code}
            if $schema->resultset('Public::Channel')
                      ->find($data->{channel_id})
                      ->is_on_dc( 'DC2' );
    }

    $data->{shipment}{renumerations} = {
        invoice_nr => 'Renumeration for test order',
        renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
        renumeration_class_id => $RENUMERATION_CLASS__ORDER,
        renumeration_status_id => $RENUMERATION_STATUS__COMPLETED,
        shipping => $data->{shipment}{shipping_charge},
        store_credit => $data->{shipment}{store_credit},
        currency_id => $data->{currency_id},
        sent_to_psp => 1,
    } if delete $data->{create_renumerations};

    # card info
    $data->{card_issuer} = '-';
    $data->{card_scheme} = '-';
    $data->{card_country} = '-';
    $data->{card_hash} = '-';
    $data->{cv2_response} = '-';

    $data->{credit_rating} ||= 1;
    return $schema->txn_do(\&_create_db_order, $class, $schema, {
        apply_SLA => $apply_SLA,
        %$data
    });
}

sub _get_shipping_charge_id {
    my ($self, $schema, $sku) = @_;
    $sku or return;

    my $shipping_charge = $schema->resultset("Public::ShippingCharge")
            ->find_by_sku($sku) or return;
    return $shipping_charge->id;
}

sub _get_premier_routing_id {
    my ($self, $schema, $shipping_charge_id) = @_;
    defined $shipping_charge_id or return 0;

    # Fall back to 0 if the SKU isn't Premier since it's a NOT NULL
    # column (should be fixed)
    return $schema->find_col(
        ShippingCharge => $shipping_charge_id,
        "premier_routing_id",
    ) || 0;
}

# Returns data in a form that is ready for DBIC to make the insert when
# calling:
# $order->add_to_tenders($_) for $self->_prepare_tenders_data( $tenders, $total_value );
sub _prepare_tenders_data {
    my ( $self, $tenders, $total_value ) = @_;
    my %tender_map = (
        card_debit => $RENUMERATION_TYPE__CARD_DEBIT,
        store_credit => $RENUMERATION_TYPE__STORE_CREDIT,
        voucher_credit => $RENUMERATION_TYPE__VOUCHER_CREDIT,
    );
    my $total_input_value = 0;
    $total_input_value += $_->{value} for @$tenders;

    # If value of tenders is less than the order value make the slush store credit
    my $add_to_store_credit = $total_input_value < $total_value
                            ? $total_value - $total_input_value
                            : 0;

    my @parsed_tenders;
    my $i = scalar(@$tenders) + 1;
    foreach my $tender ( @$tenders ) {
        if ($tender->{type} eq 'store_credit') {
            $tender->{value} += $add_to_store_credit;
            $add_to_store_credit = 0;
        }

        confess "should pass a voucher_code_id instead" if defined $tender->{code};

        if ($tender->{type} eq 'voucher_credit' && !defined $tender->{voucher_code_id}) {
            my $voucher = $self->get_schema->resultset('Voucher::Product')
                ->search({value=>$tender->{value}})->first;
            $voucher = $self->create_voucher({value=>$tender->{value}})
                unless defined $voucher;
            die 'couldnt create voucher for tender' unless defined $voucher;
            my $code = 'TV-'.String::Random->new->randregex('[A-Z]{8}');
            my $vi = $voucher->add_code($code);
            $tender->{voucher_code_id} = $vi->id;
        }

        push @parsed_tenders, {
            type_id      => ($tender_map{$tender->{type}} || confess "Unknown tender type $tender->{type}"),
            rank         => $i--,
            value        => $tender->{value},
            voucher_code_id => $tender->{voucher_code_id},
        };
    }

    # We default to adding one store_credit tender row for the full order
    # value if the order has no tenders args.
    if ($add_to_store_credit) {
        push @parsed_tenders, {
            type_id => $tender_map{store_credit},
            rank => $i,
            value => $add_to_store_credit,
        };
    }
    return @parsed_tenders;
}

# Txn method for create_db_order
sub _create_db_order {
    my ($class,$schema, $data) = @_;

    my $shipment = delete $data->{shipment};
    my $renumeration = delete $shipment->{renumerations};
    my $order;

    my $apply_SLA = delete $data->{apply_SLA}//1;

    # This loop is to make things work when running prove -j4
    $schema->storage->dbh->do('SAVEPOINT _create_db_order');
    UNIQ_ORDER_NR: for (1..50) {
        my $skip_next;
        try {
            # This also adds tenders - and would also add shipments if someone
            # renames the hashref
            note "Try to create Public::Orders...";
            eval {
                $order = $schema->resultset('Public::Orders')->create({
                    session_id => '',
                      %$data
                   });
            };
            note $@ if $@;
            $skip_next=0;
        }
        catch {
            SMARTMATCH:
            use experimental 'smartmatch';
            when (/duplicate key value violates unique constraint "unique_order_nr"/) {
                note "Caught $_";
                $schema->storage->dbh->do('ROLLBACK TO _create_db_order');

                # Sleep for up to 1 second
                Time::HiRes::sleep(rand);
                # Create a new order number and try again
                $data->{order_nr} = $class->_next_order_id;
                $skip_next=1;
            }
            default {
                die $_;
            }
        };
        next UNIQ_ORDER_NR if $skip_next;
        last UNIQ_ORDER_NR;
    }

    if (not $order){
        confess "Did not create orders, so can not add them to a shipment";
    }

    note "Ok, now add to shipments";

    $order->add_to_shipments($shipment);
    $shipment = $order->get_standard_class_shipment;

    {
    my $helper = Test::RoleHelper->new_with_roles('Test::Role::Address');
    my $mocked_validate_address = $helper->mock_validate_address;
    $shipment->validate_address({operator_id => $APPLICATION_OPERATOR_ID})
        unless $shipment->carrier_is_ups;
    }

    $shipment->add_to_renumerations($renumeration)      if ( defined $renumeration );
    $shipment->apply_SLAs() if $apply_SLA;

    # Insert the shipment_status_log entry so we have the date.
    $shipment->add_to_shipment_status_logs({
      shipment_status_id => $shipment->shipment_status_id,
      date => $shipment->date,
      operator_id => 1,
    });
    return $order;
}

=head2 cancel_return

Cancel a return

    Test::XTracker::Data->cancel_return({
        id  => $return_id
    });

Returns true if return is cancelled or false

=cut

sub cancel_return {
    my ($self, $args) = @_;

    die "id parameter required" unless $args->{id};

    my $schema = $self->get_schema;

    my $return = $schema->resultset('Public::Return')->find({
        id => $args->{id}
    });

    local $@;
    eval {
        my $domain = $self->returns_domain_using_dump_dir();
        my $txn = $schema->txn_scope_guard;
        $domain->cancel({
            return_id       => $args->{id},
            operator_id     => $APPLICATION_OPERATOR_ID,
            stock_manager   => XTracker::WebContent::StockManagement->new_stock_manager({
                schema          => $schema,
                channel_id      => $return->shipment->order->channel_id
            }),
        });
        $txn->commit;
    };
    if ( $@ ) {
        note("Unable to cancel Return - $@");
        return;
    }

    return 1;
}


=head2 convert_return_to_exchange

Convert all or part of an existing return to an exchange.

    Test::XTracker::Data->convert_return_to_exchange({
        return_obj  => $return_object,
        items   => [ {
            id          => $shipment_item_id,
            variant     => $exchange_variant_id,
            size        => $exchange_variant_size,
        },
        {
            id          => $shipment_item_id,
            variant     => $exchange_variant_id,
            ...
        }, ],
    });

Returns true if successful or undef if not.

Note that this only does the basic conversion of a return to an exchange
it does NOT calculate any charges that may arise from doing so or alter
the customer invoice. If you need that functionality please do feel free
to flesh this out.

=cut

sub convert_return_to_exchange {
    my $self = shift;
    my $args = shift;

    unless ( exists $args->{return_obj}
            && ref $args->{return_obj}
            && $args->{return_obj}->isa('XTracker::Schema::Result::Public::Return')
            && exists $args->{items}
            && ref $args->{items} eq 'ARRAY'
            ) {
        die "Required parameters not passed to convert_return_to_exchange";
    }

    my $schema = $self->get_schema;
    my $dbh    = $schema->storage->dbh;

    my $reason = $schema->resultset('Public::CustomerIssueType')->find({
        description => 'Quality'
    });

    my $data = {
        operator_id         => $APPLICATION_OPERATOR_ID,
        num_remove_items    => 0,
        return_id           => $args->{return_obj}->id,
        invoice             => get_return_invoice($dbh,
            $args->{return_obj}->id ),
    };

    foreach my $item ( @{ $args->{items} } ) {
        $data->{return_items} = {
            $item->{id} => {
                reason_id           => $reason->id,
                remove              => 1,
                type                => 'Exchange',
                exchange_variant    => $item->{variant},
                exch_variant        => $item->{variant},
                exch_size           => $item->{size},
            }
        };
        $data->{num_remove_items}++;
    }

    local $@;
    eval {
        my $domain = $self->returns_domain_using_dump_dir();
        my $txn = $schema->txn_scope_guard;
        $domain->convert_items( $data );
        $txn->commit;
    };

    # We can safely use $@ without assigning it to a variable because we localised it above
    if ( $@ ) {
        note( "Unable to convert return to exchange - $@" );
        return;
    }

    return 1;
}

=head2 create_rma

Create an order and an RMA for that order directly in the DB and get back a
L<XTracker::Schema::Result::Public::Return> object. Call like:

  Test::XTracker::Data->create_rma({
    items => {
      '48498-097' => {
        # Nothing in here is required. Default values shown
        return_item_status_id   => $RETURN_ITEM_STATUS__AWAITING_RETURN,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
        customer_issue_type_id  => $CUSTOMER_ISSUE_TYPE__7__PRICE,
      },
      '48499-098' => {
        # Add this item to the order, but not the return
        _no_return => 1,
      }
    }

    # optional fileds , with default values shown
    return_status_id => $RETURN_STATUS__AWAITING_RETURN
  })

No self-consistency of the various status fields is done - if you request an
odd combination you get S.I.S.O.

Currently the return items can only be returns, not exchanges. If you need that
you will have to write it.

=cut

sub create_rma {
    my ($class,$data,$pids,$attrs) = @_;

    my $type = Dict[
        items => HashRef,
        slurpy Any
    ];

    $type->check($data)
        or die 'create_rma(\%data) '
              . $type->get_message($data);

    my $items = undef;

    # really bad insane hack - sorry
    # START
    my $o_hash = $class->make_order_hash_from_pids(
        $data, $pids, $attrs
    );

    foreach my $pid (@{$pids}) {
        $items->{ $pid->{sku} } = { };
    }

    $items = $o_hash->{items};
    # END

    my $return_status = delete $data->{return_status_id} ||
                        $RETURN_STATUS__AWAITING_RETURN;

    if ( $return_status != $RETURN_STATUS__AWAITING_RETURN ) {
        die "This function only works if Return Status is 'Awaiting Return'";
    }

    # TODO: this should be refactored to use the RMA domain
    my $schema = $class->get_schema;
    my $dbh    = $schema->storage->dbh;

    my $order_row = undef;
    my $order_hash = undef;

    if (@$pids) {
        my $hash = \%{$data};
        delete $hash->{items};
        ($order_row,$order_hash) = $class->create_db_order({
            base => $hash || undef,
            pids => $pids,
        });
    } else {
        $order_row = $class->create_db_order($data);
    }

    my $shipment    = $order_row->shipments->first;

    my $rma_number  = generate_RMA( $dbh, $shipment->id );
    my $return_id   = create_return( $dbh, $shipment->id, $rma_number, $return_status, 'TEST', 'false' );
    log_return_status( $dbh, $return_id, $return_status, $APPLICATION_OPERATOR_ID );

    my $return = $schema->resultset('Public::Return')->find($return_id);
    $return->update({
        creation_date => DateTime->now,
        expiry_date => DateTime->now->add(days => 14),
        cancellation_date => DateTime->now->add(days => 14),
    });
    $return->discard_changes;

    # TODO: Create the renumeration record!!!

    my $variants = $schema->resultset('Public::Variant');
    my $shipment_items = $shipment->shipment_items;
    while (my $item = $shipment_items->next) {
        note "sku: ". $item->variant->sku;
        my $info = { %{$items->{$item->variant->sku} } };

        # Tester has requested that we dont add this item to the return
        next if $info->{_no_return};

        delete $info->{price};
        delete $info->{_no_return};

        my $ri_status_id = $info->{return_item_status_id} ||= $RETURN_ITEM_STATUS__AWAITING_RETURN;
        my $si_status_id = delete $info->{shipment_item_status_id} || $SHIPMENT_ITEM_STATUS__RETURN_PENDING;
        $info->{customer_issue_type_id} ||= $CUSTOMER_ISSUE_TYPE__7__PRICE;

        $schema->resultset('Public::ReturnItem')->create({
          return_id => $return_id,
          shipment_item_id => $item->id,
          creation_date => DateTime->now,
          return_type_id => $RETURN_TYPE__RETURN,
          variant_id => $item->variant->id,
          return_item_status_logs => [
            {
              return_item_status_id => $ri_status_id,
              operator_id => $APPLICATION_OPERATOR_ID,
              date => DateTime->now,
            }
          ],
          %$info
        });

        $item->update({shipment_item_status_id => $si_status_id});
        $item->add_to_shipment_item_status_logs({
          shipment_item_status_id => $si_status_id,
          operator_id => $APPLICATION_OPERATOR_ID,
        })
    }
    return $return;
}

=head2 set_shipment_returnable

Sets the shipment returnable status by altering the returnable_state_id of shipment items,

Note: to make a shipment returnable, the shipment items have their
      returnable_state_id set to $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
      whereas to make a shipment non-returnable, the shipment_items have their
      returnable_state_id set to $SHIPMENT_ITEM_RETURNABLE_STATE__NO.

=cut

sub set_shipment_returnable {

    my ($class, $ship_nr, $is_returnable) = @_;
    my $schema = $class->get_schema;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    return if $shipment->is_returnable == $is_returnable;

    my $shipment_item_returnable_status = $is_returnable ? $SHIPMENT_ITEM_RETURNABLE_STATE__YES : $SHIPMENT_ITEM_RETURNABLE_STATE__NO;

    my $shipment_items = $shipment->shipment_items;
    while (my $item = $shipment_items->next) {
        $item->update({returnable_state_id => $shipment_item_returnable_status});
    }

    return;
}




=head2 create_renumeration

Creates a renumeration against the given shipment. You can explicitly pass it
args or hope the defaults work for your case.

=cut

sub create_renumeration {
    my ( $self, $shipment, $args ) = @_;
    $args //= {};

    my $renumeration_row = $shipment->add_to_renumerations({
        invoice_nr             => $args->{invoice_nr}             || 'create_email_test_invoice_'.$shipment->id,
        renumeration_type_id   => $args->{renumeration_type_id}   || $RENUMERATION_TYPE__STORE_CREDIT,
        renumeration_class_id  => $args->{renumeration_class_id}  || $RENUMERATION_CLASS__RETURN,
        renumeration_status_id => $args->{renumeration_status_id} || $RENUMERATION_STATUS__PENDING,
        shipping               => $args->{shipping}               || 0,
        misc_refund            => $args->{misc_refund}            || 0,
        alt_customer_nr        => $args->{alt_customer_nr}        || undef,
        gift_credit            => $args->{gift_credit}            || 0,
        store_credit           => $args->{store_credit}           || 0,
        currency_id            => $args->{currency_id}            || $shipment->order->currency_id,
        sent_to_psp            => $args->{sent_to_psp}            || 0,
    });

    # If a return has been supplied, associate the renumeration with it
    $args->{return_row}->add_to_link_return_renumeration({
        renumeration_id => $renumeration_row->id(),
    }) if $args->{return_row};

    return $renumeration_row;
}

=head2 create_renumeration_item

Creates a renumeration_item against the given renumeration for the given
shipment_item_id. You can explicitly pass it args or hope the defaults work
for your case.

=cut

sub create_renumeration_item {
    my ( $self, $renumeration, $shipment_item_id, $args ) = @_;
    return $renumeration->add_to_renumeration_items({
        shipment_item_id => $shipment_item_id,
        unit_price       => $args->{unit_price} || 100,
        tax              => $args->{tax}        || 0,
        duty             => $args->{duty}       || 0,
    });
}

sub make_order_hash_from_pids {
    my($class,$base,$pids,$attrs) = @_;
    my $items = { };
    $base ||= {};
    $pids ||= [];
    $attrs ||= [];

    my $pid_count = scalar @{$pids};

    for my $i (0 .. $pid_count-1) {
        my $prod = $pids->[ $i ];

        if (defined $attrs->[$i]) {
            $items->{ $prod->{sku} } = $attrs->[$i];
        } else {
            $items->{ $prod->{sku} } =  {  };
        }
    }

    my $hash = Catalyst::Utils::merge_hashes(
        $base, { items => $items }
    );
    return $hash;
}

sub make_rma {
    my($class,$opts) = @_;
    my $base = $opts->{base} || {};
    my $pids = $opts->{pids} || [];
    my $attrs = $opts->{attrs} || [];
    my $num_returns = $opts->{num_returns} || scalar @{$pids};

    my $items = { };

    my $data =$class->make_order_hash_from_pids($base,$pids,$attrs);

    # how many items to be returned?
    my $return_pids = undef;
    for my $j (0 .. $num_returns-1) {
        if (defined $pids->[$j]) {
            push @{$return_pids}, $pids->[$j];
        }
    }

    my $return = __PACKAGE__->create_rma($data, $return_pids );

    my $shipment = $return->shipment;
    my $order = $shipment->order;
    my @si;

    foreach my $pid (@{$pids}) {
        push @si, $shipment->shipment_items->find_by_sku($pid->{sku});
    }
    return ($return, $order, @si);
}

=head2 get_pid_set

  $pid_data  = Test::Xtracker::Data->get_pid_set({
    nap => 3,
    out => 3,
  });

Returns a hash containing channel and pids for that channel

The key in the input hash is the term it will pass to grab_products to
identify the channel and the value is the number of pids you require

The hash returned will be keyed on the keys provided ie

  {
    nap => {
      channel => Public::Channel row
      pids    => Array of HASHREF, # from find_products
    },
    out => {
      channel => Public::Channel row
      pids    => Array of HASHREF, # from find_products
    },
  }

=cut

sub get_pid_set {
    my($class,$opts, $aux_opts) = @_;
    $aux_opts ||= {};
    my $set = { };

    die __PACKAGE__."->get_pid_set" if (not ref($opts) eq 'HASH');

    foreach my $chan (keys %{$opts}) {
        my $how_many = $opts->{$chan} || undef;

        my($channel,$pids) = __PACKAGE__->grab_products({
            ($chan =~ /^\d+$/ ? (channel_id => $chan) : (channel => $chan)),
            how_many    => $how_many,
            %$aux_opts,
        });

        $set->{$chan} = {
            channel     => $channel,
            pids        => $pids,
        };
    }
    return $set;
}

=head2 default_shipping_charge

Return a hashref to some domestic and international shipping charges that can
be used for testing purposes.

=cut

sub default_shipping_charge {
    return {
        domestic => {
            'NAP-INTL'    => 'UK Express',
            'OUTNET-INTL' => 'UK',
            'MRP-INTL'    => 'UK Express',
            'JC-INTL'     => 'UK/London Standard',
            'NAP-AM'      => 'United States Express',
            'OUTNET-AM'   => 'USA - Saver Service',
            'MRP-AM'      => 'United States Express',
            'JC-AM'       => 'JC US Express',
            'NAP-APAC'    => 'Standard 2 days Hong Kong',
        },
        international => {
            'NAP-INTL'    => 'International',
            'OUTNET-INTL' => 'Europe EU - Express',
            'MRP-INTL'    => 'International',
            'JC-INTL'     => 'Europe',
            'NAP-AM'      => 'Canada Express',
            'OUTNET-AM'   => 'International',
            'MRP-AM'      => 'Canada Express',
            'JC-AM'       => 'JC Canada',
            'NAP-APAC'    => 'Standard 2-3 days Remaining APAC countries',
        },
    };
}

sub create_domestic_order {
    my($self,%case) = @_;
    my $channel = $case{channel}
        || $self->get_schema->resultset('Public::Channel')
            ->find(any_channel()->id);
    my $pids = $case{pids} || Test::XTracker::Data->get_pid_set({
        nap => 1, out => 1, mrp => 1, jc  => 1, });
    my $case_order_address = $case{order_address} // 'current_dc';

    my $customer    = $self->find_customer({
        channel_id => $channel->id,
    });

    $self->ensure_stock(
        $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id
    );
    my $find_shipping_account_params = {
        channel_id => $channel->id,
        acc_name   => 'Domestic',
    };

    # we have a strange situation where with DC2 whereby the
    # DistributionCentre > default_carrier is 'DHL Express' which isn't the
    # carrier that does domestic
    if (Test::XTracker::Data->whatami eq 'DC2') {
        $find_shipping_account_params->{carrier} = 'UPS';
    }

    my $shipping_account = $self->find_shipping_account(
        $find_shipping_account_params);

    my $address = $self->create_order_address_in(
        $case_order_address,
    );
    isnt($customer, undef, 'customer is defined');
    isnt($channel, undef, 'channel is defined');
    isnt($shipping_account, undef, 'shipping_account is defined');
    isnt($address, undef, 'address is defined');

    my $shipping_charge_description
        = $self->default_shipping_charge->{domestic}{$channel->web_name}
       || croak q{Couldn't find domestic shipping charge for } . $channel->web_name;
    my $shipping_charge = $channel->find_related('shipping_charges', {
        description => $shipping_charge_description,
    });
    croak sprintf(
        'Could not find shipping charge for %s on channel %s',
        $shipping_charge_description, $channel->name
    ) unless $shipping_charge;
    my($order,$order_hash) = $self->create_db_order({
        base => {
            customer_id          => $customer->id,
            channel_id           => $channel->id,
            shipment_type        => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status      => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id  => $shipping_account->id,
            invoice_address_id   => $address->id,
            shipping_charge_id   => $shipping_charge->id,
        },
        pids => $pids,
        attrs => [
            { price => 100.00 },
        ],
    });

    Test::XTracker::Data::Order->allocate_order($order);
    return $order;
}

=head2 get_non_charge_free_state

This returns a country that isn't a 'Charge Free State'. Use this if you want
a Shipping Address which will pay tax & duty charges when you Exchange an item.

=cut

sub get_non_charge_free_state {
    my $class   = shift;

    my $found;

    my $country_rs  = $class->get_schema
                                ->resultset('Public::Country')
                                    ->search;
    while ( my $country = $country_rs->next ) {
        if ( !$country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX )
             && !$country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__DUTY ) ) {
            $found  = $country;
            last;
        }
    }
    return $found;
}

=head2 get_non_tax_duty_refund_state

This returns a country that doesn't get their Tax & Duties refuned.

=cut

sub get_non_tax_duty_refund_state {
    my $class   = shift;

    my $found;

    my $country_rs  = $class->get_schema
                                ->resultset('Public::Country')
                                    ->search;
    while ( my $country = $country_rs->next ) {
        if ( !$country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX )
             && !$country->can_refund_for_return( $REFUND_CHARGE_TYPE__DUTY ) ) {
            $found  = $country;
            last;
        }
    }
    return $found;
}

=head2 print_barcodes_path

    $scalar = print_barcodes_path();

This just returns the base path where the barcodes are created before being printed.

=cut

sub print_barcodes_path {
    return config_var('SystemPaths', 'barcode_dir');
}

=head2 restore_carrier_automation_state

 restore_carrier_automation_state( $states );

This sets the Carrier Automation States for DHL shipments and, where UPS is enabled,
for each Sales Channel for UPS shipments back to the values they were when the
call to 'get_carrier_automation_state' was made.

Pass in a HASH ref that came from 'get_carrier_automation_state'.

=cut

sub restore_carrier_automation_state {
    my $class   = shift;
    my $states  = shift;

    my $channel_rs   = $class->get_schema->resultset('Public::Channel');
    my $args = {};

    foreach my $channel_id ( keys %{ $states } ) {
        $class->set_carrier_automation_state( $channel_id, $states->{$channel_id} );
    }
    return;
}

=head2 set_carrier_automation_state

 set_carrier_automation_state( $channel_id, $state );

This sets the Carrier Automation State for a particular Sales Channel.

=cut

sub set_carrier_automation_state {
    my ( $class, $channel_id, $state )  = @_;
    my $args = {
                    config_group_name  => 'Carrier_Automation_State',
                    setting            => 'state',
                    channel_id         => $channel_id,
                    value              => $state,
    };
    $class->get_schema->resultset("SystemConfig::ConfigGroupSetting")->update_systemconfig( $args );
    return;
}

=head2 create_dummy_po

    my $purchase_order  = create_dummy_po( $pid, $vid, $channel_id );

Create a Purchase Order for a product (PID) and variant (VID) for a Sales Channel and also Stock Order and Stock Order Item Records.

=cut

sub create_dummy_po {
    my ( $class, $pid, $vid, $channel_id )     = @_;
    my $schema  = $class->get_schema;

    my $time    = time();

    my $po  = $schema->resultset('Public::PurchaseOrder')->create({
        purchase_order_number => uc("PurchaseOrder$time"),
        description           => 'Testing, Testing',
        designer_id           => 1,
        status_id             => $PURCHASE_ORDER_STATUS__ON_ORDER,
        type_id               => $PURCHASE_ORDER_TYPE__FIRST_ORDER,
        currency_id           => $CURRENCY__GBP,
        season_id             => $SEASON__FW10,
        channel_id            => $channel_id
    });

    note "PO Number: ".$po->purchase_order_number;

    my $so  = $schema->resultset('Public::StockOrder')->create({
                product_id        => $pid,
                purchase_order_id => $po->id(),
                status_id         => $STOCK_ORDER_STATUS__ON_ORDER,
                type_id           => $STOCK_ORDER_TYPE__MAIN,
                shipment_window_type_id => $SHIPMENT_WINDOW_TYPE__UNKNOWN,
                start_ship_date   => \"now()",
                cancel_ship_date   => \"date( now() ) + integer '7'",
                cancel            => 0,
    });

    my $soi = $schema->resultset('Public::StockOrderItem')->create({
                stock_order_id      => $so->id(),
                original_quantity   => 10,
                quantity            => 10,
                variant_id          => $vid,
                status_id           => $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                type_id             => $STOCK_ORDER_ITEM_TYPE__UNKNOWN,
                cancel              => 0,
            });
    return $po;
}

{
    my $name;
    sub whatami {
        my($class) = @_;
        $name ||= config_var('DistributionCentre','name');

        if (not defined $name) {
            croak "Missing section in config for DistributionCentre>name";
        }

        if ($name !~ /^DC\d+$/) {
            croak "Config section DistributionCentre>name expecting 'DC' "
                ."followed by a number";
        }
        return $name;
    }

    sub whatami_as_location {
        my ($class) = @_;

        my $name = $class->whatami;
        my ($id) = $name =~ m/^DC(\d+)$/;
        return sprintf("%02d", $id);
    }
}

=head2 create a voucher.product

Create a test voucher.product and voucher.variant with defaults.

=cut

sub create_voucher {
    my ($class, $args ) = @_;
    my $schema = $class->get_schema;

    # Note: We use this instead of relying on the sequence because
    # that sequence will be removed from XT at some point - product
    # and voucher ids in the real system are generated by fulcrum and
    # so any sequence in XT is irrelevant.
    my $id = $class->next_id([qw{voucher.product product}]);

    # Create a unique name
    my $name = "Test Voucher $id $$ ".time();
    # my $name = qq{Test Voucher $id};

    $args->{id}          ||= $id;
    $args->{name}        ||= $name;
    $args->{operator_id} ||= $APPLICATION_OPERATOR_ID;
    $args->{channel_id}  ||= $class->channel_for_nap->id,
    $args->{landed_cost} ||= 0.01;
    $args->{value}       ||= 100;
    $args->{currency_id} ||= $CURRENCY__GBP;
    $args->{upload_date} ||= "2010-11-04 11:20:05+00";
    my $assign_to_ship_item= delete $args->{assign_code_to_ship_item};

    my $variant_args = {};
    $variant_args->{id} = defined $args->{variant_id}
                        ? delete $args->{variant_id}
                        : $class->next_id([qw{voucher.variant variant}]);

    $args->{is_physical}
        = defined $args->{is_physical} ? $args->{is_physical} : 1;
    $args->{disable_scheduled_update}
        = defined $args->{disable_scheduled_update}
        ? $args->{disable_scheduled_update}
        : 0;

    my $voucher = $schema->resultset('Voucher::Product')->create($args);

    $voucher->create_related('variant', $variant_args);
    $args->{assign_code_to_ship_item}   = $assign_to_ship_item;

    ok(
        defined $voucher,
        "created voucher: [".$voucher->sku."], [".( $args->{is_physical} ? 'Physical' : 'Virtual' )."], Value: ".$args->{value}
    );
    return $voucher;
}

=head2 next_id(\@tables)

Gets the MAX(id)+1 for the given table(s).

=cut

sub next_id {
    my ( $self, $tables ) = @_;
    $tables = (grep { $_ && m{^array$}i } ref $tables) ? $tables : [$tables];
    my $sub_qry = join ' UNION ', map { "SELECT MAX(id) FROM $_" } @$tables;
    return $self->get_schema->storage->dbh_do( sub {
        my ($storage, $dbh) = @_;
        local $storage->{debug} = 1;
        my $x = $dbh->selectall_arrayref( "SELECT MAX(max)+1 FROM ( $sub_qry ) s;" );
        return $x->[0][0] || 1;
    });
}

=head2 create_delivery_for_po

Create a delivery for a supplied purchase order. Takes a C<$purchase_order_id>
or a (super|voucher|product) purchase order object and a C<$stage> string,
which can be one of 'item_count', 'qc', 'bag_and_tag' or 'putaway', and
creates deliveries and delivery_items for its stock_orders and
stock_order_items with the correct statuses for that PO.

=cut

sub create_delivery_for_po {
    my ($class, $spo, $stage ) = @_;
    croak 'You need to pass this sub a $super_purchase_order_id, and a stage for the status to be set'
        unless defined $stage
           and $stage =~ m{^(?:item_count|qc|bag_and_tag|putaway)$};

    my %stage_map = (
        item_count => q{},
        qc => {
            delivery_status_id      => $DELIVERY_STATUS__COUNTED,
            delivery_type_id        => $DELIVERY_TYPE__STOCK_ORDER,
            delivery_item_status_id => $DELIVERY_ITEM_STATUS__COUNTED,
            delivery_item_type_id   => $DELIVERY_ITEM_TYPE__STOCK_ORDER,
        },
        bag_and_tag => {
            delivery_status_id      => $DELIVERY_STATUS__PROCESSING,
            delivery_type_id        => $DELIVERY_TYPE__STOCK_ORDER,
            delivery_item_status_id => $DELIVERY_ITEM_STATUS__PROCESSING,
            delivery_item_type_id   => $DELIVERY_ITEM_TYPE__STOCK_ORDER,
        },
        putaway => {
            delivery_status_id      => $DELIVERY_STATUS__PROCESSING,
            delivery_type_id        => $DELIVERY_TYPE__STOCK_ORDER,
            delivery_item_status_id => $DELIVERY_ITEM_STATUS__PROCESSING,
            delivery_item_type_id   => $DELIVERY_ITEM_TYPE__STOCK_ORDER,
        },
    );

    my @d;
    my $schema = $class->get_schema;
    eval { $schema->txn_do(sub{
        $spo = $schema->resultset('Public::SuperPurchaseOrder')->find($spo)
            unless (ref $spo) =~ m{PurchaseOrder$};

        STOCK_ORDER:
        for my $so ($spo->stock_orders) {
            my %map = %{$stage_map{$stage}};
            my $delivery = $so->create_delivery(
                $map{delivery_status_id}, $map{delivery_type_id} );

            STOCK_ORDER_ITEM:
            for my $si ($so->stock_order_items) {
                my $delivery_item = $delivery->add_to_delivery_items({
                    delivery_id => $delivery->id,
                    quantity    => $si->quantity,
                    status_id   => $map{delivery_item_status_id},
                    type_id     => $map{delivery_item_type_id},
                });
                $delivery_item->create_related('link_delivery_item__stock_order_items',{
                    stock_order_item_id => $si->id
                });
            }
            push @d, $delivery;
        }
    })};
    if ( $@ ) {
        die "Couldn't create delivery for PO: $@";
    }
    return @d;
}

=head2 create_stock_process_for_delivery_item

Creates a stock_process and for the given C<$delivery_item> DBIC object.
Optionall takes parameters for the stock_process row.

=cut

sub create_stock_process_for_delivery_item {
    my ($class, $delivery_item, $args ) = @_;

    my $sp_rs = $class->get_schema->resultset('Public::StockProcess');

    $args->{quantity}  ||= $delivery_item->quantity;
    $args->{group_id}  ||= $sp_rs->generate_new_group_id;
    $args->{type_id}   ||= $STOCK_PROCESS_TYPE__MAIN;
    $args->{status_id} ||= $STOCK_PROCESS_STATUS__NEW;

    # create stock process item
    return $delivery_item->add_to_stock_processes($args);
}

=head2 create_stock_process_for_delivery

Creates a stock process item for each delivery item in the delivery.

=cut

sub create_stock_process_for_delivery {
    my ($class, $delivery, $args ) = @_;
    my $schema = $class->get_schema;

    my @sp;
    eval { $schema->txn_do(sub{
        $args->{group_id} ||= $schema->resultset('Public::StockProcess')
                                     ->generate_new_group_id;

        # create stock process item
        push @sp, $class->create_stock_process_for_delivery_item( $_, $args )
            for ($delivery->delivery_items->all);
    })};
    if ( $@ ) {
        confess "Couldn't create stock process items for delivery: $@";
    }
    return @sp
}

sub create_shipment_for_delivery {
    my ($class, $delivery) = @_;
    my $schema = $class->get_schema;

    $schema->txn_begin;

    my $shipment = $class->create_shipment();

    my $link = $schema->resultset('Public::LinkDeliveryShipment')->create({
        delivery_id => $delivery->id,
        shipment_id=> $shipment->id,
    });

    $schema->txn_commit;
    return $shipment;
}

# Utility sub to set default values
sub _def {
    my ($defined, $default) = @_;
    return defined $defined ? $defined : $default;
}

sub create_shipment {
    my ($class, $args) = @_;
    my $schema = $class->get_schema;

    return $schema->resultset('Public::Shipment')->create({
        date                => $schema->db_now,
        shipment_address_id => $class->create_order_address->id,
        shipment_type_id    => $SHIPMENT_TYPE__DOMESTIC,
        shipment_class_id   => $SHIPMENT_CLASS__STANDARD,
        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
        email               => 'test@xtracker',
        telephone           => '123456',
        mobile_telephone    => '1234567',
        packing_instruction => '-',
        shipping_charge     => 0.0,
        %{$args//{}},
    });
}

sub create_shipment_item {
    my ($class, $args) = @_;
    return $class->get_schema->resultset('Public::ShipmentItem')->create({
        shipment_id             => delete $args->{shipment_id},
        variant_id              => delete $args->{variant_id},
        unit_price              => 0.00,
        tax                     => 0,
        duty                    => 0,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
        returnable_state_id     => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
        voucher_code_id         => delete $args->{variant_code_id},
        %{$args//{}},
    });
}

=head2 generate_voucher_code_for_delivery

generate a set of voucher codes for each delivery item

=cut

sub generate_voucher_code_for_delivery {
    my ($class, $delivery) = @_;

    my @code;
    $class->get_schema->txn_do( sub {
            my $voucher = $class->create_voucher;

            my $sr = String::Random->new;

            for my $di ($delivery->delivery_items){
                my $soi = $di->stock_order_item;
                for(1..$di->quantity){
                    my $c =  'TV-'.$sr->randregex('[A-Z]{8}');
                    $soi->add_to_voucher_codes({
                        stock_order_item_id => $soi->id,
                        voucher_product_id=>$voucher->id,
                        code=>$c
                    });
                    push @code, $c;
                }
            }
        });
    return \@code;
}

=head2 stripout_vvoucher_from_skus

This removes Virtual Vouchers from a list of skus returned from $mech->get_order_skus. It
removes them from the hash passed in and returns them in a new hash.

=cut

sub stripout_vvoucher_from_skus {
    my ($class, $skus )     = @_;

    my $vskus;
    my $voucher_rs  = $class->get_schema->resultset('Voucher::Product');

    foreach my $sku ( keys %{ $skus } ) {
        $sku    =~ m/(\d*)-\d\d\d/;
        my $voucher = $voucher_rs->find( $1 ); ## no critic(ProhibitCaptureWithoutTest)
        # if it's a voucher and it's not physical it must be virtual
        if ( defined $voucher && !$voucher->is_physical ) {
            $vskus->{ $sku }    = delete $skus->{ $sku };
        }
    }
    return $vskus;
}

=head2 get_next_preauth

This gets the highest preauth value in the 'orders.payment' table and adds one to it.

=cut

sub get_next_preauth {
    my ( $class, $dbh )     = @_;

    my $psp_refs    = $class->get_new_psp_refs();
    return $psp_refs->{preauth_ref};
}

=head2 close_to_test_time

Compare to a test time used for primary by SLA tests

    Bracket the sla 30 seconds either way and test that it falls between them

=cut

sub close_to_test_time {
    my ($class, $sla_time, $now, $sql_offset)   = @_;

    my $lower   = $class->_add_interval($now, $sql_offset);
    my $higher  = $lower->clone;
    $lower->subtract( seconds => 30 );
    $higher->add( seconds => 30 );

    if ( DateTime->compare($lower, $sla_time) < 0 && DateTime->compare($sla_time, $higher) < 0 ) {
        return 1;
    }
    note "test time is [$sla_time], should be between [$lower] and [$higher]";
    return;
}

#
#
# Private Methods
#
#

# quick and dirty way to see how our postgres count is increasing
sub diag_pgproccount {
    ## no critic(ProhibitBacktickOperators)
    my $prefix  = shift // 'postgres processes';
    my $total   = `ps aux |/bin/grep -c '[p]ostgres:'`;
    my $active  = `ps aux |/bin/grep '[p]ostgres: |grep -v [p]rocess' |grep -v idle |wc -l`;
    my $idle    = `ps aux |/bin/grep '[p]ostgres:.*idle' |/bin/grep -v in |wc -l`;
    my $idletxn = `ps aux |/bin/grep '[p]ostgres:.*idle' |/bin/grep transaction |wc -l`;
    chomp ($total, $active, $idle, $idletxn);
    my ($package, $filename, $line) = caller;
    # in void context we diag()
    if (not defined wantarray) {
        diag "$prefix: $total total, $active active, $idle idle, $idletxn idle in transaction; $filename:$line";
        return;
    }
    else {
        if (wantarray) {
            return ($total, $active, $idle, $idletxn);
        }
        return [$total, $active, $idle, $idletxn];
    }
}

sub _next_order_id {
  my ($class) = @_;

  my $dbh = $class->get_dbh;
    return $dbh->selectall_arrayref(
        "SELECT NEXTVAL('orders_id_seq')+1000000000")->[0][0];
}

sub sample_order_template {
  my ($class, $filename) = @_;
  # yes! horrible! we definitely don't want to add 'order/template/' into
  # _data_dir and this code is a bit too spaghetti-like to over-engineer this
  # fix (CCW / ORT-17 fallout)
  my $template = $class->_data_dir . "/order/template/" . ( $filename || "sample_order_xml.tt" );
  #print "Template - $template\n";
  return $template;
}

sub _next_routing_schedule_id {
  my ($class) = @_;

  my $dbh = $class->get_dbh;
    return $dbh->selectall_arrayref(
        "SELECT NEXTVAL('routing_schedule_id_seq')+100000")->[0][0];
}

{
  my $memoized;
  # Get the path to t/data
  sub _data_dir {
    return $memoized . "data/" if $memoized;

    my $dir = Path::Class::file(__FILE__)->absolute->resolve;
    (my $pkg = __PACKAGE__) =~ s{::}{/}g;

    $dir =~ s{lib/$pkg.pm}{} or die "Unable to process __FILE__";
    $memoized = $dir;
    return $dir . "data/";
  }

  sub _importer_script_name {
    my ($class ) = @_;
    # populate $memoized
    $class->_data_dir;
    return $memoized . "../script/data_transfer/web_site/order_import/fcp_order_import.pl";
  }
}

{
    my $lock;
    my $lock_file = __PACKAGE__->_importer_script_name . '.lock';

    sub _get_order_importer_lock {
        open($lock, '>', $lock_file) or die "Cant open $lock_file";
        flock($lock, LOCK_EX);
        print $lock "$$\n";
    }

    sub _release_order_importer_lock {
        if ($lock) {
            flock($lock, LOCK_UN);
            close($lock);
            undef $lock;
        }
    }

    END {
        _release_order_importer_lock();
    };
}

sub revert_broken_import{
    my ($self,$schema,$order_nr)=@_;
    my $order = $schema->resultset('Public::Orders')->search({order_nr=>$order_nr})->single;
# NORMALLY it's only the following that have imported before dying
#    $order->link_orders__shipments->delete;
#    $order->order_flags->delete;
#    $order->order_status_logs->delete;
#    $order->tenders->delete;
    if ( $order ) {
        $order->tenders->delete;
        $order->delete;
    }
}

# Find valid size id(s) from public.size
# That table is a mess, so there are no constants for
# sizes.
#
# If someone can come up with a better method for
# choosing a test size that will always exist, please
# do rewrite this.
#
sub find_valid_size_ids {
    my ($self, $how_many) = @_;

    $how_many ||= 1;

    # Create an RTV location
    my $schema  = Test::XTracker::Data->get_schema;

    my $size_rs = $schema->resultset('Public::Size')->search(undef,{
        rows        => $how_many,
    });

    my @ids;
    while (my $size = $size_rs->next()) {
        push @ids, $size->id;
    }

    if (scalar @ids < $how_many) {
        note "couldn't get $how_many size ids, only found ".(scalar @ids);
    }
    return \@ids;
}

# Add an interval 'string' to a datetime object using Pg to do the maths. Doing
# it via the database saves us from time zone inconsistencies, as that's what
# the application code uses to do the maths.
sub _add_interval {
    my ($class, $dt_start, $sql_offset)  = @_;

    my $pg_start = DateTime::Format::Pg->format_datetime($dt_start);

    my $pg_end = $class->get_schema->storage->dbh_do(sub{
        my (undef, $dbh) = @_;
        $dbh->selectcol_arrayref(
            "SELECT '${pg_start}'::timestamptz + interval '$sql_offset'"
        );
    })->[0];
    return DateTime::Format::Pg->parse_datetime($pg_end);
}

# Wraps a string you pass in so it looks as it will appear on the QC Page.
# Optionally accepts an operator name, in which case it's appended after
# a single space.
sub qc_fail_string {
    my ($string,$operator_name) = @_;
    my $ret="Failure reason: \N{U+ab}$string\N{U+bb} Packer name";

    if ($operator_name) {
        $ret.=": $operator_name";
    }
    else {
        $ret.=" unavailable";
    }
    return $ret;
}

=head2 create_dbic_customer($args)

Wrapper around create_test_customer that returns a DBIC row.

=cut

sub create_dbic_customer {
    my ( $self, $args ) = @_;
    my $customer_id = $self->create_test_customer(%$args);
    return $self->get_schema
                ->resultset('Public::Customer')
                ->find($customer_id);
}

sub find_or_create_customer {
    my ($self,$args) = @_;
    my $customer =
        $self->get_schema->resultset('Public::Customer')->search(
            {channel_id => $args->{channel_id}},
            {order_by => 'RANDOM()', rows=>1})->single
                ||
                    $self->create_dbic_customer($args);

    # remove any Customer Attributes such as
    # Preferred Language so that the defaults are used
    $customer->delete_related('customer_attribute');

    return $customer;
}

sub bump_sequence {
    my ($self,$tab,$col,$skip)=@_;
    $col||='id';
    $skip||=1;

    my $next_urn;
    $self->get_schema->storage->dbh_do(
        sub {
            my ($storage,$dbh)=@_;
            my $next = $dbh->selectrow_arrayref(qq!select setval('${tab}_${col}_seq',( COALESCE( ( select max($col) from $tab), 0 ) )+$skip)!);
            $next_urn = $next->[0];
        }
    );

    return $next_urn;
}

sub toggle_shipment_validity {
    my ( $self, $shipment, $validity ) = @_;
    $validity = !! $validity; # Set to true or false

    Test::XT::Rules::Solve->solve(
        'XTracker::Data::ShipmentValidity',
        {
            'shipment' => $shipment,
            'validity' => $validity,
        }
    );

    unless ( ($shipment->has_validated_address ) == $validity ) {
        croak "Attempt to set shipment validity to [$validity] failed";
    }
    return $validity;
}

sub ensure_non_iws_locations {
    my ( $self ) = @_;

    # Do this better as part of the Locations story (NAPAC-466)
    unless ( XTracker::Config::Local::config_var(qw/IWS rollout_phase/) ) {
        $self->data__location__initialise_non_iws_test_locations;
    }
}

sub set_pws_sort_variable_weightings {
    my ($self,$args) = @_;

    my $sql = q{INSERT INTO product.pws_sort_variable_weighting (pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by, channel_id)
                VALUES (?, ?, (SELECT id FROM product.pws_sort_destination WHERE name = ?), ?, ?)};
    my $sth = $self->get_dbh->prepare($sql);

    my $destination = $args->{destination} // 'main';
    my $operator_id = $args->{operator_id} // $APPLICATION_OPERATOR_ID;
    my $channel_id  = $args->{channel_id} // $self->any_channel->id;

    my %weights = %{$args->{weights} // {}};
    if (!%weights) {
        my $vars = XTracker::Database::Product::SortOrder::list_pws_sort_variables({
            dbh => $self->get_dbh,
        });

        %weights = map {; $_->{id} => 1 } @$vars;
    }

    for my $var_id (keys %weights) {
        $sth->execute(
            $var_id,
            $weights{$var_id},
            $destination,
            $operator_id,
            $channel_id,
        );
    }
    return;
}

# Instead of Test::XTracker::Data->find_shipping_account which ignores
# Unknown :/
sub get_shipping_account {
    my ($self,$channel_id, $carrier_name) = @_;

    # If no carrier name is supplied look for the default
    $carrier_name //= default_carrier(0);

    note('Carrier Name: ' . $carrier_name);
    note('Channel ID: ' . $channel_id);

    $self->get_schema->resultset("Public::ShippingAccount")->search(
        { "carrier.name" => $carrier_name, "channel_id" => $channel_id },
        { join => "carrier", rows => 1 },
    )->first or die("Found no Shipping Account");
}

=head2 XT::Domain::Returns returns_domain_using_dump_dir();

Instantiates a XT::Domain::Returns object setup with dump_dir

=cut

sub returns_domain_using_dump_dir {
    my($self) = @_;
    my $schema = $self->get_schema;

    my $amq = Test::XTracker::MessageQueue->new({schema=>$schema});

    my $domain = XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => $amq,
    );
    isa_ok($domain,'XT::Domain::Returns');
    return $domain;
}

=head2 generate_air_waybills

Generates two (the general use case being one each for outbound/return
waybills) strings that can be used as airway bills. And we checked - it's Air
Waybills, not Airway Bills.

=cut

sub generate_air_waybills {
    my ($class, $args) = @_;
    $args //= {};
    my $require_unique = $args->{require_unique};

    my $shipment_rs = $class->get_schema->resultset('Public::Shipment');

    return map {
        my $column = $_;
        my $awb;
        my $unique = 1;
        do {
            # Hopefully we'll never have more than this number of unique
            # waybill numbers in the test db...
            $awb = sprintf('%010d', rand 9_999_999_998);
            $unique = !(
                $shipment_rs->search({ $column => $awb })->count()
            ) if $require_unique;
        } while !$unique;
        $awb;
    } qw/outward_airway_bill return_airway_bill/;
}

=head2 get_order_number

Get a value for the order_nr field in the orders table. At present, this just
uses _next_order_id(), which is what's used to test the order importer.

=cut

sub get_order_number {
    my $class = shift;

    return $class->_next_order_id();

}

=head2 get_application_operator_id

Convenience method to return the application operator id (commonly used
in tests when a non-specific operator_id is required)

=cut

sub get_application_operator_id {
    return $APPLICATION_OPERATOR_ID;
}

=head2 get_application_operator

Convenience method to return the application operator (commonly used
in tests when a non-specific operator is required).

=cut

sub get_application_operator {
    my $self = shift;

    return $self->get_schema->resultset('Public::Operator')->find(
        $self->get_application_operator_id );

}

1;
