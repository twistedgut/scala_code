package XTracker::Markup;
use NAP::policy "tt", 'class';
use XTracker::Constants qw($PG_MAX_INT);

=head1 NAME

XTracker Markup - Convert XT markup into HTML, magically.

=head1 SYNOPSIS

    my $markup = XTracker::Markup->new({
        schema => $schema,
        product_id => 12345,
    });

    $editors_comments = $markup->editors_comments({
        editors_comments => $editors_comments,
        site => ?,
    });

    $long_description = $markup->long_description({
        long_description => $long_description,
        site => ?,
    });

    $size_fit = $markup->size_fit({
        size_fit => $size_fit,
        site => ?,
    });

    $related_facts = $markup->related_facts({
        related_facts => $related_facts,
        site => ?,
    });

=head1 DESCRIPTION

Methods to transform various bits of "markup" used in editorial content into
HTML markup for the websites.

Some of the markup and transformation rules seem very abitrary - they have been
extracted like for like from L<XTracker::Comms::DataTransfer>.

This functionality is used in two cases:

=over

=item 1

Before uploading a product to the website, the editorial data from Fulcrum
may contain some of this funny markup, so the various fields that allow
markup are passed through the appropriate method before transferring to the
website.

=item 2

The product service receives the editorial data straight from Fulcrum, so it
does some post-processing to transform any markup into the actual data.
(All these methods are exposed via a webservice).

=back

=cut

has 'EMPTY_OR_WHITESPACE_REGEXP' => (
    is => 'ro',
    default => 'qr{\A\s*\z}xms'
);

has 'schema' => (
    is => 'ro',
    required => 1,
);

has 'product_id' => (
    is => 'ro',
    required => 1,
);

has 'product' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_product {
    my ( $self ) = @_;

    return $self->schema->resultset('Public::Product')->find( $self->product_id );
}

=head1 METHODS

=head2 editors_comments

=cut

sub editors_comments {
    my ($self,$args) = @_;

    my $editors_comments = $args->{editors_comments};
    my $site = $args->{site} // '';

    return '' unless defined $editors_comments;

    my $href = $self->_link_prefix( $site );

    my $output = $self->_add_lists({ text => $editors_comments });

    $output = $self->_add_product_links({
        text => $output,
        href => $href
    });

    $output  = $self->_add_designer_links({
        text => $output
    });

    return $output;

}

=head2 long_description

=cut

sub long_description {
    my ($self,$args) = @_;

    my $long_description = $args->{long_description};
    my $site = $args->{site} // '';

    return '' unless defined $long_description;

    my $output = $self->_add_lists({ text => $long_description });

    $output = $self->_add_designer_links({
        text => $output
    });

    my $href = $self->_link_prefix( $site );

    $output = $self->_add_product_links({
        text => $output,
        href => $href
    });

    return $output;

}

=head2 size_fit

=cut

sub size_fit {
    my ($self,$args) = @_;

    my $text        = $args->{size_fit};
    my $site        = $args->{site} // '';

    return '' unless defined $text;

    my $output = '<ul>' . $text;

    $output = $self->_add_list_elements({ text => $output });

    $output = $self->_add_measurements({
        text => $output
    });

    $output .= '</ul>';

    # don't return an empty list if no content
    if ($output =~ m{^<ul>\s*</ul>$}s) {
        $output = '';
    }

    my $href = $self->_link_prefix( $site );

    $output = $self->_add_product_links({
        text => $output,
        href => $href
    });

    $output = $self->_substitute_impromptu_bullet_points({ text => $output });

    return $output;
}

=head2 related_facts

=cut

sub related_facts {
    my ($self,$args) = @_;

    my $site          = $args->{site} // '';
    my $related_facts = $args->{related_facts};

    return '' unless defined $related_facts;

    my $output = $self->_add_lists({ text => $related_facts });

    $output = $self->_add_designer_links({
        text => $output
    });

    my $href = $self->_link_prefix( $site );

    $output = $self->_add_product_links({
        text => $output,
        href => $href
    });

    return $output;
}

# Private methods..
sub _add_lists {
    my ($self,$args)   = @_;

    my $text_string = $args->{text};

    return unless $text_string;
    return '' if $text_string =~ $self->EMPTY_OR_WHITESPACE_REGEXP;

    my $new_string='';
    my @lines = split(/\r?\n/,$text_string);
    my $in_list = 0;
    while (@lines) {
        my $line = shift @lines;
        if ($line =~ s/^-\s//) {
            if (!$in_list) {
                $new_string .= "<ul>\n";
                $in_list = 1;
            }
            $new_string .= "<li>$line</li>\n";
        } else {
            if ($in_list) {
                $new_string .= "</ul>\n";
                $in_list = 0;
            }
            $new_string .= "$line\n";
        }
    }
    if ($in_list) {
        $new_string .= "</ul>\n";
    }

    return $new_string;

}

sub _add_list_elements {
    my ($self,$args) = @_;

    my $text = $args->{text};

    return unless $text;
    return '' if $text =~ $self->EMPTY_OR_WHITESPACE_REGEXP;

    # replace '-' with <li> in input
    $text =~ s/- /\<li\> /g;

    return $text;

}

sub _add_product_links {
    my ($self,$args) = @_;

    my $text = $args->{text};
    my $href = $args->{href} // '/product/';

    return unless $text;
    return '' if $text =~ $self->EMPTY_OR_WHITESPACE_REGEXP;

    $text =~ s/\n//g;
    $text =~ s/\s{2,}//g;

    my $html = qr{\<br\>.*\<\/table\>};
    $text =~ s/$html//g;

    my %tokens  = ();

    ## extract tokens
    foreach my $type ( qw|sku id| ) {
        my $PATTERN_LINK = qr{
            (           # Capture
                \[      # Open tag
                \s*     # Ignore whitespace
                (.+?)   # Match anything (link_text) - lean for when there are two tags
                \s*     # Ignore whitespace
                $type   # 'sku' or 'id'
                (\d+)   # Match product id or sku
                \s*     # Ignore whitespace
                \]      # Close tag
            )
        }xms;

        while ( $text =~ m{$PATTERN_LINK}g ) {
            my  ($token, $link_text, $id) = ($1, $2, $3);
            $link_text =~ s|\s*$||g;
            push @{ $tokens{$type} }, [$token, $link_text, $id];
        }
    }

    my $product_channel = $self->product->get_product_channel;
    ## replace tokens
    foreach my $type ( keys %tokens ) {
        foreach my $token_ref ( $tokens{$type} ) {
            foreach my $i (0..$#{$token_ref}) {
                my ($token, $link_text, $id) = @{ $token_ref->[$i] }[0..2];

                # XXX does this still work with SKUs?
                my $link_product_id
                    = $type eq 'sku'
                    #? get_product_id( $dbh, { type => 'legacy_sku', id => $id } )
                    ? $self->product_id
                    : $id;

                # some people can't copy-and-paste and enter data like:
                #   [Moschino jacket id166174166174]
                # resulting in failed jobs of the form:
                #   value \"166174166174\" is out of range for type integer
                if ($link_product_id > $PG_MAX_INT) {
                    warn "token:$token Product ID: $link_product_id too large - skipping";
                    next;
                }

                my $anchor_html = '';

                # Check the linked product's visibility on the original
                # product's channel
                my $link_product
                    = $self->schema->resultset('Public::ProductChannel')->search({
                        product_id => $link_product_id,
                        channel_id => $product_channel->channel_id,
                    })->slice(0,0)->single;

                # Hopefully we can roll out the way we do links for mrp across
                # the board, and leave the website with the visibility logic

                if ( $product_channel->channel->is_on_mrp ) {
                    $anchor_html = qq{<a href="$href$link_product_id" class="product-item">$link_text</a>};
                }
                ## link to product page if live
                ## (added in option if on staging which might break if we're running live upload and prod is on staging but not live - needs to be extended)
                elsif ( $link_product
                    and ( ( $link_product->live && $link_product->visible ) or $link_product->staging )
                ) {
                    $anchor_html = qq{<a href="$href$link_product_id">$link_text</a>};
                }
                # link to register interest if not live
                else {
                    my $designer = $link_product
                                 ? $link_product->product->designer->designer
                                 : q{};
                    $anchor_html = qq{<a href="javascript:ri('$designer', '$link_product_id');">$link_text</a>};
                }

                ## ...and convert token accordingly
                $text =~ s/\Q$token\E/$anchor_html/;
            }
        }
    }

    return $text;

}


sub _add_designer_links {
    my ($self,$args)   = @_;

    my $text        = $args->{text};

    return unless $text;
    return '' if $text =~ $self->EMPTY_OR_WHITESPACE_REGEXP;

    $text =~ s/\n//g;
    $text =~ s/\s{2,}//g;

    my $designer_name = $self->product->designer->designer;
    my $url_key = $self->product->designer->url_key;

    # set up href to landing page
    my $url = '<a class="editor-designer" href="/Shop/Designers/'. $url_key .'">'. $designer_name .'</a>';

    # Duckbill's new replacement. This is to get around creating designer links
    # inside product ids e.g. [Timex x J.Crew watch id191305]
    # replace instances of designer name with href

    while (
        $text =~ s{
            ^
            (
                # this will skip over any square bracketed terms
                (?:
                    [^\[]          # anything which isn't an [
                    | \[ [^\]]* \] # or [stuff]
                ) *                # any number of times
            )
            \  # leading space
            \Q$designer_name\E
            (?!\s<)   # mustn't be followed by \s<
            (?!\',)   # or ',
            (?!<)     # or <
            \  # trailing space
        }{$1 $url }xsg
    ) { }

    return $text;

}

sub _substitute_impromptu_bullet_points {
    my ($self,$args) = @_;

    return unless $args->{text};
    my $text = $args->{text};

    # bulletpoints text delimited with (- some text -)
    $text =~ s/\(\-/<ul><li>/g;
    $text =~ s/\-\)/<\/li><\/ul>/g;
    return $text;
}

sub _add_measurements {
    my ($self,$args) = @_;

    my $text        = $args->{text};

    my $measurement = '';

    return unless $text;

    # query to get measurement data - currently only applicable to Bags
    my $variant_rs = $self->schema->resultset('Public::Variant')->search(
        {
            product_id  => $self->product->id,
            'size.size' => [ 'One size', 'n/a' ],
        },
        {
            join        => [ 'size', { 'variant_measurements' => 'measurement' } ],
            '+select'   => [ 'variant_measurements.value', 'measurement.measurement' ],
            '+as'       => [ 'variant_measurement_value', 'variant_measurement_measurement' ],
            order_by    => [ 'measurement.id' ],
        },
    );

    # Build up a string of cm & inch measurement values for each variant_measurement
    while ( my $variant = $variant_rs->next ) {
        my $cm_value = $variant->get_column('variant_measurement_value');
        next unless $cm_value; # Not all bags have all measurements
        my $in_value = sprintf("%.0f", $cm_value * 0.3937);
        my $name     = $variant->get_column('variant_measurement_measurement');
        $measurement =~ s/_/ /g;
        $measurement .= qq{<li> $name $in_value" / $cm_value} . qq{cm};
    }

    if ($measurement) {
        # add to end of text
        $text .= $measurement;
    }

    return $text;

}

sub _link_prefix {
    my ($self,$site) = @_;

    my $href;
    given($site) {
        when ("intl") { $href = '/product/' }
        when ("am") { $href = '/am/product/' }
        default { $href = '/product/' }
    }

    return $href;
}

=head1 SEE ALSO

L<XTracker::Comms::DataTransfer>
L<XT::DC::Controller::Markup>

=head1 AUTHOR

Adam Taylor <adam.taylor@net-a-porter.com>

=cut
