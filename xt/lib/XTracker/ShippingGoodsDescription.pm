package XTracker::ShippingGoodsDescription;
use strict;
use warnings;
use NAP::policy "tt", qw( exporter );

use List::Util qw( max );
use Perl6::Export::Attrs;
use MooseX::Params::Validate;

=head1 DESCRIPTION

Functions to generate description of goods for shipments.

=head1 METHODS

=head2 description_of_goods

Return the Description of Goods string for a shipment suitable for use in a
DHL label or manifest, or in an outward proforma. The string consists of
descriptive text optionally preceeded by HS codes. If multiple lines are
allowed (by the 'lines' argument), then this returns an array of strings.

Arguments:
    line_len  -- Maximum length of the return line. If multiple lines are
                 allowed by the lines argument, then this is the length of
                 each line.
    lines     -- Maximum number of lines to return.
    hs_codes  -- Array ref containing HS codes for items in the shipment.
    docs_only -- Whether the shipment contains only documents.
    hazmat    -- Whether the shipment contains any hazmat items.

=cut

sub description_of_goods :Export() {
    my %args = validated_hash( \@_,
        line_len  => { isa => 'Num',      required => 1 },
        lines     => { isa => 'Num',      default  => 1 },
        hs_codes  => { isa => 'ArrayRef', optional => 1 },
        docs_only => { isa => 'Bool',     default  => 0 },
        hazmat    => { isa => 'Bool',     default  => 0 },
        hazmat_lq => { isa => 'Bool',     default  => 0 },
    );

    # Set up descriptive text and delimiter
    my $text = $args{docs_only}   ? 'Documents'
               : $args{hazmat}    ? 'DG in LQ'
               : $args{hazmat_lq} ? 'DG in LQ'
               : 'Not restricted for transport';

    # Get array with text strings and return them
    my @codestrings = _genstrings($text, \%args);

    # Return a scalar if caller asked for one line, otherwise an array of lines
    return  $args{lines} == 1  ?  $codestrings[0]  : @codestrings;
}


# Generate array of codes strings, based on maximum number and length of lines
sub _genstrings {
    my ($text, $args) = @_;

    my $delim = ', ';

    # Count occurrences of HS codes and make list of them sorted and formatted for display
    my @list;
    push @list, $text;

    unless ($args->{docs_only}) {
        my %count;
        for my $code (@{$args->{hs_codes}}) {
            $count{$code} = $count{$code} ? $count{$code} + 1 : 1;
        }
        my @countlist = map { $count{$_} == 1 ? $_ : "${_}x$count{$_}" }
                    sort {$count{$b} <=> $count{$a} || $a cmp $b} keys %count;
        push @list, @countlist;
    }

    # Make strings listing the codes and text, but not exceeding maximum line length
    my @codestrings;
    my $lineno = 1;
    my $line = '';
    my $listpos = 0;
    while ($listpos < @list && $lineno <= $args->{lines}) {
       my $to_add = ($line ? $delim : '') . $list[$listpos];
       if ( length($line) + length($to_add) <= $args->{line_len} ) {
           $line .= $to_add;
           $listpos++;
           push @codestrings, $line if $listpos == @list;
       }
       else {
           push @codestrings, $line;
           $lineno++;
           $line = '';
       }
    }

    return @codestrings;
}

1;
