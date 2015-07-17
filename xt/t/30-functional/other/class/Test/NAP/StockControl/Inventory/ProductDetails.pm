package Test::NAP::StockControl::Inventory::ProductDetails;

use NAP::policy "tt", 'test';

=head1 NAME

Test::NAP::StockControl::Inventory::ProductDetails - Test the Product Details page

=head1 DESCRIPTION

Test the Product Details page.

#TAGS inventory loops

=head1 METHODS

=cut

use FindBin::libs;

use Test::XT::Flow;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';
use XTracker::Constants ':conversions';
use XTracker::Constants::FromDB qw( :authorisation_level );

use parent 'NAP::Test::Class';

=head2 product_details_submission

Test the following scenarios, checking the user feedback message and that a
pid_update message was sent following a submission on the I<Product Details>
page:

=over

=item A valid submission with weight only

=item A valid submission with weight and all dimensions

=item A valid submission with empty dimensions

=item A valid submission with weight and dimensions with leading/trailing whitespace

=item A failed submission due to one non-numeric dimension (width)

=item A failed submission due to one unset dimension (width)

=item A failed submission due to a negative value for weight

=item A failed submission due to a 0 value for weight

=item A failed submission due to a non-numeric value for weight

=item A failed submission due to unsetting the weight field

=item A failed submission due to a voucher submission

=back

=cut

sub product_details_validation : Tests {
    my $self = shift;

    my $product = ( Test::XTracker::Data->grab_products )[1]->[0]{product};

    my $framework = Test::XT::Flow->new_with_traits(
        traits => [ 'Test::XT::Flow::StockControl', ],
    );

    $framework->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [ 'Stock Control/Inventory' ],
        },
    });

    foreach my $case (
        {
            name => 'Try a valid submission with weight only',
            input => { weight => 1 },
        },
        {
            name => 'Try a valid submission with weight and all dimensions',
            input => {
                length => 1,
                width  => 1,
                height => 1,
                weight => 1,
            },
        },
        {
            name => 'Try a valid submission with no dimensions',
            input => {
                length => q{},
                width  => q{},
                height => q{},
            },
        },
        {
            name => 'Try a valid submission with weight and leading/leading whitespace dimensions',
            input => {
                length => q{ 1 },
                width  => q{ 1 },
                height => q{ 1 },
                weight => 1,
            },
        },
        {
            name => 'Try an invalid dimension submission (string)',
            input => {
                length => 1,
                width  => 'asdf',
                height => 1,
                weight => 1,
            },
            error_re => qr{width should be a positive number},
        },
        {
            name => 'Try an invalid dimension submission (unset just one dimension)',
            input => {
                length => 1,
                width  => q{},
                height => 1,
                weight => 1,
            },
            error_re => qr{must all be either set or unset},
        },
        {
            name => 'Try negative value for product "weight"',
            input => { weight  => -1 },
            error_re => qr{Product weight should be a positive number},
        },
        {
            name => 'Try zero (0) value for product "weight"',
            input => { weight  => 0 },
            error_re => qr{Product weight should be a positive number},
        },
        {
            name => 'Try some non numeric values product "weight"',
            input => { weight  => 'blabla' },
            error_re => qr{Product weight should be a positive number},
        },
        {
            name => 'Try undefined value for product "weight"',
            input => { weight => undef },
            error_re => qr{Product weight should be a positive number},
        },
    ) {
        subtest $case->{name} => sub {

            my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

            $framework
                ->flow_mech__stockcontrol__inventory_productdetails( $product->id )
                ->flow_mech__stockcontrol__inventory_productdetails_submit(
                    $case->{input},
                );
            if ( $case->{error_re} ) {
                $framework->mech->has_feedback_error_ok($case->{error_re});
                $xt_to_wms->expect_no_messages;
                return;
            }

            $framework->mech->has_feedback_success_ok(
                qr{Product attributes updated successfully}
            );

            $xt_to_wms->expect_messages({ messages => [ { type => 'pid_update' } ]});

            my $shipping_attribute = $self->schema
                ->resultset('Public::ShippingAttribute')
                ->find({product_id => $product->id});

            # If we've passed any dimensions, check they're stored in cm
            for my $dimension (
                sort grep { m{^(?:length|width|height)$} } keys %{$case->{input}}
            ) {
                my $expected
                    = $case->{input}{$dimension}
                    ? $CONVERT{config_var(qw/Units dimensions/)}{cm}($case->{input}{$dimension})
                    : undef;
                my $msg = "$dimension stored in cm correctly";
                if ( defined $expected ) {
                    cmp_ok($shipping_attribute->$dimension, q{==}, $expected, $msg);
                }
                else {
                    is( $shipping_attribute->$dimension, $expected, $msg);
                }
            }
        };
    }
    # All fields should be disabled for vouchers, but submitting anything
    # should error anyway
    subtest 'Try to submit a voucher change' => sub {
        $framework->flow_mech__stockcontrol__inventory_productdetails(
                Test::XTracker::Data->create_voucher->id
            )->flow_mech__stockcontrol__inventory_productdetails_submit({ weight => 1 })
            ->mech->has_feedback_error_ok(qr{This page doesn't support voucher changes});
    };
}
