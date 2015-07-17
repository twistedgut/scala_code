package Test::XTracker::Client::SelfTest;
use NAP::policy "tt",     qw( class test );

use URI;
use HTML::TreeBuilder::XPath;
use Data::Dumper;

=head1 NAME

Test::XTracker::Client::SelfTest - Sanity tests for Test::XTracker::Client

=head1 DESCRIPTION

Utility to help you write sanity tests for Test::XTracker::Client::SelfTest

=head1 SYNOPSIS

 use Test::XTracker::Client::SelfTest;
 Test::XTracker::Client::SelfTest->new(
    # Either specify a URL:
    uri        => '/GoodsIn/Putaway?process_group_id=123456',
    # Or a page spec name:
    spec       => 'GoodsIn/StockIn/SingleResult',

    # Put the page you're parsing here. Stuffing it in to __DATA__ makes this
    # self-contained...
    content    => (join '', (<DATA>)),

    # Here's the data you're expecting out:
    expected   => {},

    # If you're not sure what you're expecting, throw in:
    # dump_parse => 1,
 );

 # And that's all. The object instantiation runs the test itself!

=head1 FURTHER EXPLANATION

Idea here is to allow very quick creation of sanity tests. Once you've got a
page parsing as you'd like, throw in a quick test of the HTML content and output
parse, and then if anyone breaks it when they update Client.pm, it'll nag them.

=cut

has 'content' => ( is => 'ro', isa => 'Str', required => 1 );
has 'tree'    => (
    is => 'ro',
    isa => 'HTML::TreeBuilder::XPath',
    required => 1,
    handles => [qw( find_xpath )],
);
has 'uri'        => ( is => 'ro', isa => 'URI'     );
has 'spec'       => ( is => 'ro', isa => 'Str'     );
has 'expected'   => ( is => 'ro', isa => 'HashRef' );
has 'dump_parse' => ( is => 'ro', isa => 'Bool'    );

with 'Test::XTracker::Client';

# Set up the object
around BUILDARGS => sub {
    my ( $orig, $class, %args ) = @_;

    # Set up the HTML::TreeBuilder obj
    $args{'tree'} = HTML::TreeBuilder::XPath->new;
    $args{'tree'}->parse( $args{'content'} );

    # Transform the URI
    $args{'uri'} = URI->new( $args{'uri'}, 'http' ) if exists $args{'uri'};

    return $class->$orig( %args );
};

# Run the tests
sub BUILD {
    my $self = shift;

    # Parse the HTML
    my $data_received = $self->as_data( $self->spec );

    # Debugging mode
    if ( $self->dump_parse ) {
        require Data::Dumper;
        diag Data::Dumper->Dump([$data_received],['data_received']);
    # Actual test mode
    } else {
        # Tell the user how we parsed the page
        my $parser_name =
            $self->spec ?
                'User-supplied ' . $self->spec :
                'Auto-matched ' .
                    $Test::XTracker::Client::LAST_PARSER_SELECTED_BY_REGEX;

        # Test or complain
        eq_or_diff( $data_received, $self->expected,
            "Page parsed as expected using $parser_name"
        );

        done_testing;
    }
}

1;
