package XTracker::Schema::ResultSet::Any::Variant;
use NAP::policy "tt";
use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Any::Variant - work with any variant type

=head1 SYNOPSIS

    my $resultset = $schema->resultset('Any::Variant');

    # get the 'thing' for the SKU
    my $variant = $resultset->find_by_sku( $sku );

    # get the type of the 'thing' for the sku
    # (PRODUCT, VOUCHER, SHIPPING)
    my $type = $resultset->type_of( $sku );

=head1 DESCRIPTION

How often have you found yourself with a SKU and just wanted to grab the
relevant record from the database?

Maybe you don't care what it is until you've found it.

Maybe you don't care what it is at all, and you just want to know it's a valid
SKU.

Maybe you don't want to do anything more than know what it is.

.. but you don't want to search multiple tables.

This virtual resultset should take away some of that pain.

=cut

=head1 METHODS

The class provides the following methods:

=cut

=head2 find_by_sku($resultset, $sku)

Returns the relevant database record object representing the SKU, or C<undef>
if no matches are found.

    # get the 'thing' for the SKU
    my $variant = $resultset->find_by_sku( $sku );

=cut
sub find_by_sku {
    my ($resultset, $sku) = @_;
    my $schema = $resultset->result_source->schema;
    my $variant;

    # product is the most common case, so we search product variants first,
    # then fall back to voucher variants
    # (there was a question about shipping variants, but we'll worry about
    # those when it's a problem)
    $variant = $schema->resultset('Public::Variant')->find_by_sku(
        $sku,
        { dont_die_when_cant_find => 1 },
    );

    # look for a voucher
    if (not defined $variant) {
        $variant = $schema->resultset('Voucher::Variant')->find_by_sku(
            $sku,
            { dont_die_when_cant_find => 1 },
        );
    }

    # look for a shipping SKU
    if (not defined $variant) {
        $variant = $schema->resultset('Public::ShippingCharge')->find_by_sku(
            $sku,
        );
    }

    return $variant;
}

=head2 type_of($resultset, $sku)

Returns a string representing the I<type> of the record representing the given
SKU, or undef if the SKU can't be found.

In the case where the record type isn't one of the expected types, a warning
is emitted and the full type (C<ref($variant)>) is returned.

    my $type = $resultset->type_of( $sku );

=cut
sub type_of {
    my ($resultset, $sku) = @_;
    my $variant = $resultset->find_by_sku($sku);

    return
        unless defined $variant;

    given(ref($variant)) {
        when (m{::Public::Variant}) {
            return 'PRODUCT';
        }

        when (m{::Voucher::Variant}) {
            return 'VOUCHER';
        }

        when (m{::Public::ShippingCharge}) {
            return 'SHIPPING';
        }

        default {
            warn qq{unexpexted variant type: } . ref($variant);
            return ref($variant);
        }
    }
}

=head2 is_shippingcharge_sku($resultset, $sku)

This is a method that's used in the MRP Order Importer tests and originally
lived as a full lookup in L<Test::XTracker::Data::Shipping>.

    if ($resultset->is_shippingcharge_sku( $sku )) {
        ...
    }

The function returns the (boolean) result of an C<eq()> comparison.

=cut
# copied from Test::XTracker::Data::Shipping
sub is_shippingcharge_sku {
    my ($resultset ,$sku) = @_;
    return ($resultset->type_of($sku)//q{} eq 'SHIPPING');
}

=head1 AUTHOR

Chisel C<< <chisel.wright@net-a-porter.com> >>

=cut
