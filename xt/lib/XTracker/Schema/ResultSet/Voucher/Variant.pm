package XTracker::Schema::ResultSet::Voucher::Variant;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'XTracker::Schema::ResultSetBase';

use Carp qw/croak/;

sub _parse_find_by_sku_args {
    if ('HASH' eq ref($_[0])) {
        my %hash = %{$_[0]};
        return @hash{qw(alias dont_die_when_cant_find)}
    }
    else {
        return @_;
    }
}

sub find_by_sku {
    my $self = shift;
    my $sku = shift;

    my ($pid,$size_id) = $sku =~ /^(\d+)-0?(\d+)$/;
    croak "'$sku' is not a valid SKU"
        unless $size_id and $pid;
    # allow a move towards parameterised args
    my ( $alias, $dont_die_when_cant_find ) = _parse_find_by_sku_args(@_);
    $alias ||= 'me';

    my $variant = $self->search({
      "$alias.voucher_product_id" => $pid
    })->first;

    if ( !$dont_die_when_cant_find ) {
        croak "PID $pid does not have a voucher-variant of '$sku'"
          unless $variant;
    }

    return $variant;
}

1;

