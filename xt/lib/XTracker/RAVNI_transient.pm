package XTracker::RAVNI_transient;
use strict;
use warnings;
use XTracker::Config::Local 'config_var';
use Perl6::Export::Attrs;
use XTracker::Error;

=head1 Disabling the parts of XT known as RAVNI

(aka the ones that have been replaced by the IWS)

=head2 Configuration

=head3 C<@ravni_pieces>

List of strings, of the form C<section/sub section>, like we use for C<login_with_permissions>

=cut

my @ravni_pieces = (
# 'Fulfilment/Picking', # needed for RTV shipments
#'Goods In/Putaway', # needed for non-main non-dead putaway
'Stock Control/Cancellations',
'Stock Control/Final Pick',
'Stock Control/Perpetual Inventory',
'Stock Control/Dead Stock', # check!
'Stock Control/Stock Relocation', # check!
);

my @not_p0_pieces = ();
# this only makes sense with an external WMS and not in PRL-on phase
push @not_p0_pieces, 'Stock Control/Recode' if( ! config_var( 'PRL', 'rollout_phase' ) );

=head3 C<@ravni_url_rxs>

List of pairs:

=over 4

=item *

URL regex (can also match against query string), written I<as a string> (don't use C<qr>, please)

=item *

additional message to display to the user (C<1> shows no additional message)

=back

=cut

my @ravni_url_rxs = (
    '^/StockControl/Location/CreateLocation' => 'creating locations',
    '^/StockControl/Location/DeleteLocation' => 'deleting locations',
);

# this is just initialization
my (%ravni_pieces,%not_p0_pieces,$ravni_url_rx,$ravni_rx_matched);
my $phase = config_var('IWS', 'rollout_phase');
{
use re 'eval';

$ravni_pieces{$_}=1 for @ravni_pieces;
$not_p0_pieces{$_}=1 for @not_p0_pieces;
for (my $i=0;$i<@ravni_url_rxs;$i+=2) { ## no critic(ProhibitCStyleForLoops)
    my $j = $i+1;
    my $p = $ravni_url_rxs[$i];
    $ravni_url_rx .= "(?:$p)(?{ \$ravni_rx_matched = $j })|";
}
substr($ravni_url_rx,-1,1)=''; # remove last '|'
$ravni_url_rx = qr{$ravni_url_rx};
}

=head2 Functions

=head3 C<maybe_kill_ravni>

Used in L<XTracker::Authenticate>. Returns a true value if you should
terminate processing and redirect to the home screen.

=cut

sub maybe_kill_ravni :Export() {
    my ($r, $q, $section, $sub_section) = @_;

    my $uri_obj = $r->parsed_uri;
    my $url = $uri_obj->path;
    if ($uri_obj->equery) {
        $url .= '?' . $uri_obj->equery;
    }
    my $sect_disabled = is_ravni_disabled_section($section,$sub_section);
    my $url_disabled = is_ravni_disabled_url($url);

    if (!$sect_disabled && !$url_disabled) {
        return;
    }

    my $add_message='';
    # '1' is a magic return value...
    if ($url_disabled && $url_disabled ne '1') {
        $add_message = ", $url_disabled";
    }

    if ($phase > 0) {
        xt_warn(<<"EOM");
The screen you were trying to access is no longer available in XTracker.
<br>
You should be using IWS to perform that operation.
<br>
EOM
    }
    else {
        xt_warn(<<"EOM");
The screen you were trying to access is not available when XTracker runs on its own.
<br>
It needs an external WMS such as IWS.
<br>
EOM
    }

    return 1;
}

=head3 C<remove_ravni_disabled_nav>

Used is C<XTracker::XTemplate>.

Given the value generated by the handlers, for the C<sidenav> template
parameter, filters it removing every reference to disabled sections
and URLs. Returns the new value (the parameter is I<not> altered).

=cut

sub remove_ravni_disabled_nav :Export() {
    my ($navref) = @_;

    # we currently don't need this for @not_p0_pieces, so we can return
    return $navref if $phase == 0;

    return $navref unless ref($navref) eq 'ARRAY';

    my $ret = [];

    for my $section_hashref (@$navref) {
        next unless defined $section_hashref and ref($section_hashref) eq 'HASH';
        my ($section_name,$section_links) = %$section_hashref;
        next unless defined $section_links and ref($section_links) eq 'ARRAY';
        my $new_links = [];
        for my $link (@$section_links) {
            my ($link_sect,$link_sub_sect) = _parse_url($link->{url});
            next if is_ravni_disabled_section($link_sect,$link_sub_sect);
            next if is_ravni_disabled_url($link->{url});
            push @$new_links,$link;
        }
        if (@$new_links) {
            push @$ret,{$section_name => $new_links};
        }
    }

    return $ret;
}

=head3 C<is_ravni_disabled_section>

Given a pair of strings (section and sub-section), returns true if
it's disabled. Uses C<@ravni_pieces>.

=cut

sub is_ravni_disabled_section :Export() {
    my ($section, $sub_section) = @_;

    return unless defined $section;

    $sub_section ||= '';
    my $key = "${section}/${sub_section}";
    return 1 if $phase>0 && exists $ravni_pieces{$key} && $ravni_pieces{$key};
    return 1 if $phase==0 && exists $not_p0_pieces{$key} && $not_p0_pieces{$key};
    return;
}

=head3 C<is_ravni_disabled_url>

Given a url as a string, returns true if it's disabled. Uses
C<@ravni_url_rxs>.

If the true return value is not C<1>, it's a message detailing what
the URL was used for.

=cut

sub is_ravni_disabled_url :Export() {
    my ($url_str) = @_;

    return if $phase == 0;
    return unless defined $url_str;

    $ravni_rx_matched = undef;
    my $ret = ($url_str =~ $ravni_url_rx);
    if ($ret) {
        if (defined $ravni_rx_matched) {
            return $ravni_url_rxs[$ravni_rx_matched];
        }
        else {
            return 1;
        }
    }
}

sub _parse_url {
    my ($url_str) = @_;

    my @levels = split /\//, $url_str;

    my $section = $levels[1] || '';
    $section =~ s/([^\b])([A-Z])/$1 $2/g;

    my $subsection = $levels[2] || '';
    $subsection =~ s/([^\b])([A-Z])/$1 $2/g;

    return $section, $subsection;
}

1;