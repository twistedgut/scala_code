package Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use Moose;
extends "Test::XTracker::Data::Order::Parser";

use NAP::policy "tt", 'test';


use Test::More;

use XML::LibXML;

# needed for the Old Importer stuff
use Log::Log4perl::Level;
use XTracker::Logfile   qw( xt_logger );


use Test::XTracker::Data;
use XT::Order::Parser;

# these files should be in 't/data/order/template/'
has "+dc_order_template_file" => (
    #default => sub { +{
    #    DC1 => 'INTL_orders_template.xml.tt',
    #    DC2 => 'AM_orders_template.xml.tt',
    #} },
    default => 'orders_template.xml.tt',
);

=head2 pending_order_dir

=head2 processed_order_dir

=head2 error_order_dir

Return the path of the appropriate directory from the config.

=cut

# Thin wrappers at the moment until we have a more sensible Config wrapper.
# Note pending_order_dir has removed the s from 'order' in the method name it
# wraps for consistency.
sub pending_order_dir   { return Test::XTracker::Data::pending_orders_dir();  }
sub processed_order_dir { return Test::XTracker::Data::processed_order_dir(); }
sub error_order_dir     { return Test::XTracker::Data::error_order_dir();     }

=head2 purge_order_directories

Remove files from the various order directories.

=cut

sub purge_order_directories {
    my $self = shift;

    for my $method (qw(
        pending_order_dir
        processed_order_dir
        error_order_dir
    )) {
        my $directory_path = $self->$method;
        # Check that directory exists and isn't the root
        if ( -d $directory_path && $directory_path =~ m/\w/ ) {
            # Remove the XML artifacts, but keep a count of the ones removed
            # too
            my $count = 0;
            ++$count && unlink $_ for File::Find::Rule
                ->file()
                ->name( '*.xml')
                ->in( $directory_path );
            note("$count XML artifacts removed from $directory_path")
                if $count;
        }
    }

}

=head2 parse_order_file($file) : @$orders[XT::Data::Order]

Parse the test xml order $file, and return parsed orders.

=cut

sub parse_order_file {
    my ($self, $order_file) = @_;
    note "Parsing order file ($order_file)";

    my $order_xml = $self->slurp_order_xml($order_file);
    my $parser = XT::Order::Parser->new_parser({
        schema => $self->schema,
        data   => $order_xml,
    });

    my $orders = $parser->parse;

    return $orders;
}

=head2 create_and_parse_order( { order data } or [ { order data } ... ] );

Given some Order Data will create an XML file and parse it using the
New Order Importer.  Will return an array ref of 'XT::Data::Order'
objects. Can create multiple files if you pass in the order data in an
Array Ref.

=cut

sub create_and_parse_order {
    my ($self, $args) = @_;
    my $schema = $self->schema;

    # delete all existing xml files in case of previously crashed test:
    $self->purge_order_directories();

    # decide if all orders should be imported by the old order importer
    my $use_old_importer_for_all    = 0;
    if ( ref( $args ) eq 'HASH' ) {
        if ( exists( $args->{use_old_importer_for_all} ) ) {
            $use_old_importer_for_all   = $args->{use_old_importer_for_all} || 0;
            $args   = $args->{order_args};
        }
    }

    # convert $args into an ARRAY REF if it isn't already
    $args = [ $args ] if ( ref( $args ) ne 'ARRAY' );

    note "Will Create & Parse " . @{ $args } . " Order XML Files";

    my @orders;
    my %old_orders_index;
    foreach my $arg ( @{ $args } ) {
        $self->_ensure_order_line_items($arg);

        # decide to use the new or old importer
        my $use_old_importer    = $use_old_importer_for_all || $arg->{use_old_importer} || 0;

        if ( !$use_old_importer ) {
            my $order_xml  = $self->slurp_order_xml(
                $self->order_template_file,
                $arg,
            );
            isa_ok( $order_xml, 'XML::LibXML::Document' );

            my $parser = XT::Order::Parser->new_parser({
                schema  => $schema,
                data    => $order_xml
            });
            isa_ok( $parser, 'XT::Order::Parser::PublicWebsiteXML' );

            push @orders, @{ $parser->parse };
        }
        else {
            note "USING Old Importer";

            # first make sure that 'XT::Order::ImportUtils' uses the same DB connection as everything else
            # then make sure it doesn't Disconnect it when it's finished with it and drops out of scope
            no warnings "redefine";
            ## no critic(ProtectPrivateVars)
            *XT::Order::ImportUtils::_build_dbh = sub { return $schema->storage->dbh; };
            *XT::Order::ImportUtils::DEMOLISH   = sub { return; };
            use warnings "redefine";

            # turn on ERROR logging only for the Old Order Importer
            xt_logger('XT::OrderImporter')->level( $ERROR );

            my $order = Test::XTracker::Data->use_old_importer_from_xml({
                skip_commit => 1,   # don't commit order created
                filename    => $self->order_template_file,
                order_args  => $arg,
            });
            push @orders, $order;
            $old_orders_index{ $#orders }   = 1;
        }
    }

    cmp_ok( @orders, '==', @{ $args }, "Correct Number of Orders Parsed: " . @{ $args } );
    foreach my $idx ( 0..$#orders ) {
        my $order   = $orders[ $idx ];
        (
            !exists( $old_orders_index{ $idx } )
            ? isa_ok( $order, "XT::Data::Order", "Order Parsed" )
            : isa_ok( $order, "XTracker::Schema::Result::Public::Orders", "Order Parsed" )
        );
    }

    return ( wantarray ? @orders : \@orders );
}

=head2 slurp_order_xml

    my $dom = Test::XTracker::Data::Order->slurp_order_xml( $filename );

Returns the DOM/tree representation of an order when passed in an order template
filename (e.g. something in t/data/).

=cut

sub slurp_order_xml {
    my ($self, $filename, $args) = @_;
    croak "XML order filename required" unless $filename;
    $args ||= {};

    my $order_nr = Test::XTracker::Data->create_xml_order({
        filename => $filename,
        %{ $args },
    });

    my $file = $self->pending_order_dir . '/' . $order_nr . '.xml';
    note "Rendered order template ($filename) into ($file).";

    my $dom = XML::LibXML->load_xml(
        location => $file,
    );

    return $dom;

}

=head2 prepare_data_for_parser

    $xml_doc    = $self->prepare_data_for_parser( $order_args );

=cut

sub prepare_data_for_parser {
    my ($self, $args) = @_;

    # cleanu-up after others
    $self->purge_order_directories();

    # convert $args into an ARRAY REF if it isn't already
    $args = [ $args ] if ( ref( $args ) ne 'ARRAY' );
    my @docs;

    foreach my $arg ( @{ $args } ) {
        $self->_ensure_order_line_items($arg);
        my $doc = $self->slurp_order_xml($self->order_template_file, $arg );
        isa_ok( $doc, 'XML::LibXML::Document' );
        push(@docs, $doc);
    }

    note "Created ".@docs." Order XML Documents";

    # cleanu-up after ourselves
    $self->purge_order_directories();

    return ( wantarray ? @docs : \@docs );
}

1;
