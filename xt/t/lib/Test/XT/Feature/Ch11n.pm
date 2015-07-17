package Test::XT::Feature::Ch11n;

use NAP::policy "tt", qw( test role );

=head1 NAME

Test::XT::Feature::Ch11n - Channelisation support tests

=cut

use XTracker::Config::Local;

use Data::Dump qw/pp/;

=head1 METHODS

=head2 mech_logo_ch11n

Check the page has a channel has a logo.

=cut

sub mech_logo_ch11n {
    my ($self) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $logo = $self->mech->channel->name;

    $logo =~ s/ /_/g;
    $logo =~ s/\.com//gi;

    # This algorithm must match that used in root/base/shared/layout/page
    $logo = "logo_${logo}_".config_var('XTracker','instance').'.gif';

    my $image_src = $self->mech->look_down('src', "/images/$logo");
    isnt($image_src, undef, 'channel has a logo');

    return $self;
}

=head2 mech_select_box_ch11n

Test that a select box is correctly channelised e.g. on the /GoodsIn/StockIn
page.

=head3 Arguments

=over

=item name

The name of the select box (defaults to 'channel_id')

=item no_all

If true, does not expect an 'All' select option (defaults to false)

=item long_value

If true, option values are expected to include the name as well as the id
(e.g. '1__NET-A-PORTER.COM'), otherwise just the id

=back

=cut

sub mech_select_box_ch11n {
    my ($self, $args) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $name        = defined $args->{name} ? $args->{name} : 'channel_id';
    my $no_all      = defined $args->{no_all} ? $args->{no_all} : 0;
    my $long_value  = defined $args->{long_value} ? $args->{long_value} : 0;

    my $select = $self->mech->look_down('name', $name);
    is(ref($select), 'HTML::Element', 'found channel select box')
        or diag $self->uri;
    my @options = $select->find('option');

    my $channel_data = Test::XTracker::Model->get_channel_order;

    if (!$no_all) {
        unshift(@$channel_data, {id => '', name => 'All', enabled => 1 });
    }

    # Ensure there are the correct number of options
    my @enabled = grep { $_->{enabled} } @{$channel_data};
    my $expected = scalar(@enabled);

    is( scalar(@options), $expected,"correct number of options - $expected");

    my $index = 0;
    while ($index < scalar(@enabled)) {
        my $option = $options[$index];
        my $channel = $enabled[$index];

        if ($channel->{enabled}) {
            is($option->string_value,   $channel->{name},  "option name at index $index");
            if ($long_value) {
                is($option->attr('value'),  "$channel->{id}__$channel->{name}",    "option value at index $index");
            } else {
                is($option->attr('value'),  $channel->{id},    "option value at index $index");
            }
        } else {
            is($option, undef,  "option name not found");
            is($option, undef,  "option value not found");
        }
        $index++;
    }
    return $self;
}

=head2 mech_title_ch11n

Check that a titles on a page are displayed with the correct channelisation style
these are normally displayed as follows
  <span class="title title-MRP">Stock Orders</span><br />

pass a channel object and a list of titles.

=cut

sub mech_title_ch11n {
    my ($self, $title_ref, $channel) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $title_seen;
    my $title_class = $self->data_title_class($channel);

    my @titles  = $self->mech->look_down('class', qr{\b$title_class\b});
    my $reg_exp = join('|', @$title_ref);

    for my $title (@titles) {
        my @content = $title->content_list;
        my $html = $content[0];
        if (my ($found_title) = $html =~ m/($reg_exp)/) {
            $title_seen->{$found_title} = 1;
        }
    }
    for my $title (@$title_ref) {
        is($title_seen->{$title}, 1, "title ($title) is channelised correctly");
    }
    return $self;
}

=head2 data_title_class

Returns the expected CSS 'title' class-name for this channel.

=cut

sub data_title_class {
    my ($self,  $channel ) = @_;

    $channel //= $self->mech->channel;

    return "title-".$channel->business->config_section;

}

=head2 mech_tab_ch11n

Check that there is a tab for the channel

=cut

sub mech_tab_ch11n {
    my ($self, $channel) = @_;
    $channel //= $self->mech->channel;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $class_name = "contentTab-". $channel->business->config_section;
    my @titles  = $self->mech->look_down('class', $class_name);
    is(scalar @titles, 1, "found tab for '$class_name'");

    return $self;
}

=head2 mech_element_classes_ch11n

Can't write POD for this as I can't work out what this does... Seems to ignore
C<$expect> and C<$channel>.

=cut

sub mech_element_classes_ch11n {
    my($self,$opts) = @_;

    my $expect  = $opts->{expect} || undef;
    my $channel = $opts->{channel} || undef;
    my $names   = $opts->{names} || [];
    note "test_element_classes";

    $self->mech_title_ch11n($names);

    return $self;
}

=head2 mech_row_item_ch11n

Check that an HTML::Element object has the right class and content for this
channel. Useful for checking table rows.

=cut

sub mech_row_item_ch11n {
    my($self,$opts) = @_;

    if (!defined $opts->{'element'}) {
        note "called mech_row_item_ch11n without anything to check, doing nothing";
        return;
    }

    my $channel = $opts->{'channel'} || $self->channel;

    my $channel_title_class = "title-".$channel->business->config_section;
    my $channel_name = $channel->name;

    is($opts->{'element'}->attr('class'), $channel_title_class, 'element class channelised correctly');
    is($opts->{'element'}->as_text(), $channel_name, 'correct channel name displayed');

    return $self;
}

=head2 mech_somewhere_td_span_ch11n

Check that somewhere on the page is a span in a td with the right class and
content for this channel.

=cut

sub mech_somewhere_td_span_ch11n {
    my($self,$opts) = @_;

    my $channel = $opts->{'channel'} || $self->channel;

    my $channel_title_class = "title title-".$channel->business->config_section;
    my $channel_name = $channel->name;


    my $element = $self->mech->find_xpath(
        "//td/span[.=~'$channel_name']"
    )->pop;
    isnt($element, undef, "$channel_name <span> exists in a <td>");
    is($element->attr('class'), $channel_title_class, 'element class channelised correctly');

    return $self;
}

sub _title_class {
    my($self) = @_;
    return "title-".$self->mech->channel->business->config_section;
}

sub _tab_class {
    my($self) = @_;
    return "contentTab-". $self->channel->business->config_section;
}

1;
