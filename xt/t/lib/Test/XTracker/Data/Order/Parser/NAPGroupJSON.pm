package Test::XTracker::Data::Order::Parser::NAPGroupJSON;
use NAP::policy "tt", qw( test class);
extends "Test::XTracker::Data::Order::Parser";

use Data::Dumper;
use Carp qw/ croak /;
use JSON;


use Test::XTracker::Data;
use XT::Order::Parser;

use XTracker::Config::Local         qw( config_var );

# these files should be in 't/data/'
has "+dc_order_template_file" => (
    default => 'orders_template_napgroup.json.tt',
);

=head2 pending_order_dir

=head2 processed_order_dir

=head2 error_order_dir

Return the path of the appropriate directory from the config.

=cut

# Thin wrappers at the moment until we have a more sensible Config wrapper.
# Note pending_order_dir has removed the s from 'order' in the method name it
# wraps for consistency.
sub pending_order_dir   { return config_var('AMQOrders', 'waiting_dir'); }
sub processed_order_dir { return config_var('AMQOrders', 'proc_dir'); }
sub error_order_dir     { return config_var('AMQOrders', 'problem_dir'); }

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
            # Remove the JSON artifacts, but keep a count of the ones removed
            # too
            my $count = 0;
            ++$count && unlink $_ for File::Find::Rule
                ->file()
                ->name('*order_*')
                ->in( $directory_path );
            note("$count JSON artifacts removed from $directory_path")
                if $count;
        }
    }

}

=head2 create_and_parse_order( { order data } or [ { order data } ... ] );

Given some Order Data will create a JSON file and parse it using the
New Order Importer.  Will return an array ref of 'XT::Data::Order'
objects. Can create multiple files if you pass in the order data in an
Array Ref.

=cut

sub create_and_parse_order {
    my ($self, $args) = @_;
    $args = [ $args ] if (ref($args) ne 'ARRAY');

    note "Will Create & Parse " . @$args . " Order JSON Files";

    my @orders;
    for my $arg (@$args) {
        $self->_ensure_order_line_items($arg);

        my $order_data  = $self->render_and_deserialise_order_template(
            $self->order_template_file,
            $arg,
        );
        isa_ok( $order_data, 'HASH' );

        my $parser = XT::Order::Parser->new_parser({
            schema => $self->schema,
            data   => $order_data,
        });
        isa_ok( $parser, 'XT::Order::Parser::NAPGroupJSON' );
        push @orders, @{ $parser->parse };
    }

    cmp_ok( @orders + 0, '==', @$args + 0, "Correct Number of Orders Parsed: " . @$args );
    for my $order (@orders) {
        isa_ok( $order, "XT::Data::Order", "Order Parsed" );
    }

    return ( wantarray ? @orders : \@orders );
}

=head2 render_and_deserialise_order_template($template_filename, $order_args)

Render the JSON $template_filename (something in t/data/) with
$order_args, parse it, and return the order import data structure.

=cut

sub render_and_deserialise_order_template {
    my ($self, $template_filename, $args) = @_;
    $args ||= {};

    my $order_data = Test::XTracker::Data->prepare_order($args);
# warn "Render_and_deserialise_order_template: input " . Data::Dumper->new([$order_data])->Maxdepth(3)->Dump(); use Data::Dumper;

    my $rendered_import = "";
    Test::XTracker::Data->render_sample_order_template(
        $template_filename,
        $order_data,
        \$rendered_import,
    );
    # Clean out trailing commas in lists of nested structures
    $rendered_import =~ s/
        ([\]}]) \s* ,
        (\s+) (?= [\]}] )
    /$1$2/gsmx;

# warn "render_and_deserialise_order_template: Rendered JSON: ((($rendered_import)))\n";
    my $json = JSON->new;
    my $data = eval { $json->decode($rendered_import) };
    $@ and die("Could not parse rendered JSON file ($template_filename) + (((" . Data::Dumper->new([$order_data])->Maxdepth(3)->Dump() . "))) = (((((($rendered_import)))).\nError: ($@)\n");

    return $data;
}

=head2 prepare_data_for_parser

    $xml_doc    = $self->prepare_data_for_parser( $order_args );

=cut

sub prepare_data_for_parser {
    my ($self, $args) = @_;

    # convert $args into an ARRAY REF if it isn't already
    $args = [ $args ] if ( ref( $args ) ne 'ARRAY' );
    my @hashs;

    foreach my $arg ( @{ $args } ) {
        $self->_ensure_order_line_items($arg);
        my $hash    = $self->render_and_deserialise_order_template($self->order_template_file, $arg );
        isa_ok( $hash, 'HASH' );
        push(@hashs, $hash);
    }

    note "Created ".@hashs." Order HASHs";

    return ( wantarray ? @hashs : \@hashs );
}

1;
