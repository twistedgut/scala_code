package Test::XTracker::Overlay;
use NAP::policy "tt";
use Scalar::Util qw(reftype);

# copied from the defunct Net::ActiveMQ distribution, only used in
# Test::XTracker::Artifacts::RAVNI

# we should probably move to Test::Deep

sub overlay {
    my ( $data, $overlay ) = @_;

    my $level = 0;

    if ( reftype($overlay) eq 'HASH' ) {
        return overlay_hash( $data, $overlay, $level + 2 );
    }
    elsif ( reftype($overlay) eq 'ARRAY' ) {
        return overlay_array( $data, $overlay, $level + 2 );
    }
    else {
        return ( $data eq $overlay ) ? 1 : 0;
    }

}

sub overlay_hash {
    my ( $data, $overlay, $level ) = @_;

    for my $k ( keys %$overlay ) {
        my $overlay_item = $overlay->{$k};
        my $reftype = reftype($overlay_item) || '';

        if ( $reftype eq 'SCALAR' && $$overlay_item eq 'Missing' ) {

            # foo => \'Missing' says we *want* this value to not be present in
            # $data
            return 0 if exists $data->{$k};
        }
        else {
            return 0 if !exists $data->{$k};
        }
        my $data_item = $data->{$k};

        if ( !ref($overlay_item) ) {
            return 0 if !( $data_item eq $overlay_item );
            next;
        }

        if ( reftype($overlay_item) eq 'HASH' ) {
            return 0 if !overlay_hash( $data_item, $overlay_item, $level + 2 );
        }
        elsif ( reftype($overlay_item) eq 'ARRAY' ) {
            return 0 if !overlay_array( $data_item, $overlay_item, $level + 2 );
        }
    }

    return 1;
}

sub overlay_array {
    my ( $data, $overlay, $level ) = @_;

    # Go through each item in the overlay and compare against each element of
    # the data
    my $all_items_found = 1;
    for my $item (@$overlay) {
        my $overlay_item_found = 0;

      INT: for my $data_entry (@$data) {
            if ( !ref($item) ) {
                $overlay_item_found = ( $item eq $data_entry ) ? 1 : 0;
            }
            elsif ( reftype($item) eq 'HASH' ) {
                $overlay_item_found =
                  overlay_hash( $data_entry, $item, $level + 2 );
            }
            elsif ( reftype($item) eq 'ARRAY' ) {
                $overlay_item_found =
                  overlay_array( $data_entry, $item, $level + 2 );
            }
            last INT if $overlay_item_found;
        }

        # if we currently think all items up to now are found then we
        if ($all_items_found) {
            $all_items_found = $overlay_item_found ? 1 : 0;
        }

        if ( !$all_items_found ) {
            last;
        }
    }

    return $all_items_found;
}

1;
