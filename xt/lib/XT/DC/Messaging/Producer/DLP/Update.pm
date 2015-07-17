package XT::DC::Messaging::Producer::DLP::Update;
use NAP::policy "tt", 'class';
    with 'XT::DC::Messaging::Role::Producer',
         'XTracker::Role::WithIWSRolloutPhase',
         'XTracker::Role::WithPRLs',
         'XTracker::Role::WithSchema';
use Log::Log4perl ':easy';
use XTracker::Config::Local qw( config_var );
use Data::Dump qw/pp/;

=head1 XT::ActiveMQ::Message::DLP::Update

    This sends the new DLP to the 'other' channels
    i.e: (NAP intl <-> NAP) am and (Outnet intl <-> Outnet am)

    The transform method expects the channel we're sending from
    to be sent in the message

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::DLP::Update'
        {
            schema   => $schema,
            designer => $designer_id,
            channel  => $channel_id,
        },
    );

    and it then (should) broadcast to the other channels in this category.


=cut

sub message_spec {
    return {
        type     => '//rec',
        optional => {
            'Main'                              => '//str',
            'id'                                => '//int',
            'Title'                             => '//str',
            'Description'                       => '//str',
            'Meta'                              => '//str',
            'Snippet 1'                         => '//str',
            'elephant'                          => '//str',
            'textBody'                          => '//str',
            'Subject'                           => '//str',
            'HTMLBody'                          => '//str',
            'Common Elements Top'               => '//str',
            'Common Elements Bottom'            => '//str',
            'Single Space Promo 1'              => '//str',
            'Designer Description'              => '//str',
            'Editorial Category List'           => '//str',
            'Cover'                             => '//str',
            'Whats Hot'                         => '//str',
            'Double Space Promo'                => '//str',
            'Single Space Promo 2'              => '//str',
            'Custom Nav Folder'                 => '//str',
            'Page 1'                            => '//str',
            'Page 2'                            => '//str',
            'Page 3'                            => '//str',
            'Page 4'                            => '//str',
            'Page 5'                            => '//str',
            'Help Navigation'                   => '//str',
            'Chloe Top Nav'                     => '//str',
            'Chloe Bottom Nav'                  => '//str',
            'Manual Category Left Nav Elements' => '//str',
            'Left Navigation'                   => '//str',
            'Cat Home Extra Links'              => '//str',
            'Page 6'                            => '//str',
            'Page 7'                            => '//str',
            'Page 8'                            => '//str',
            'Page 9'                            => '//str',
            'Keywords'                          => '//str',
            'Page 10'                           => '//str',
            'Page 11'                           => '//str',
            'Page 12'                           => '//str',
            'Page 13'                           => '//str',
            'Page 14'                           => '//str',
            'GB Price Bands'                    => '//str',
            'US Price Bands'                    => '//str',
            'EURO Price Bands'                  => '//str',
            'Page 15'                           => '//str',
            'Page 16'                           => '//str',
            'Page 17'                           => '//str',
            'designerupdateson'                 => '//str',
            'Right hand promo space'            => '//str',
            'Other designers'                   => '//str',
            'Main Area Image'                   => '//str',
            'Main Area Link'                    => '//str',
            'Main Area Alt'                     => '//str',
            'Top Right Image'                   => '//str',
            'Top Right Link'                    => '//str',
            'Top Right Alt'                     => '//str',
            'Bottom Right Image'                => '//str',
            'Bottom Right Link'                 => '//str',
            'Bottom Right Alt'                  => '//str',
            'Top RIght Type'                    => '//str',
            'Top Right Whats Hot List'          => '//str',
            'Top Right What'                    => '//str',
            's Hot List'                        => '//str',
            'Link 1'                            => '//str',
            'Link 2'                            => '//str',
            'Link 3'                            => '//str',
            'Link 4'                            => '//str',
            'DesCat Block 1 Image'              => '//str',
            'DesCat Block 1 URL'                => '//str',
            'DesCat Block 2 Image'              => '//str',
            'DesCat Block 2 URL'                => '//str',
            'Left Nav Link 1 Text'              => '//str',
            'Left Nav Link 1 URL'               => '//str',
            'Left Nav Link 2 Text'              => '//str',
            'Left Nav Link 2 URL'               => '//str',
            'Left Nav Link 3 Text'              => '//str',
            'Left Nav Link 3 URL'               => '//str',
            'Link 1 Text'                       => '//str',
            'Link 1 URL'                        => '//str',
            'Link 2 Text'                       => '//str',
            'Link 2 URL'                        => '//str',
            'Link 3 Text'                       => '//str',
            'Link 3 URL'                        => '//str',
            'Link 4 Text'                       => '//str',
            'Link 4 URL'                        => '//str',
            'Link 5 Text'                       => '//str',
            'Link 5 URL'                        => '//str',
            'Link 6 Text'                       => '//str',
            'Link 6 URL'                        => '//str',
            'Link 7 Text'                       => '//str',
            'Link 7 URL'                        => '//str',
            'Link 8 Text'                       => '//str',
            'Link 8 URL'                        => '//str',
            'Page 18'                           => '//str',
            'X Old Page'                        => '//str',
            'X Old Page2'                       => '//str',
            'Page 19'                           => '//str',
            'Page 20'                           => '//str',
            'Promo Block Image'                 => '//str',
            'Promo Block URL'                   => '//str',
            'Promo Block'                       => '//str',
            'Page 21'                           => '//str',
            'Alt Text'                          => '//str',
            'Page 22'                           => '//str',
            'Slot1'                             => '//str',
            'Slot2'                             => '//str',
            'Slot3'                             => '//str',
            'Slot4'                             => '//str',
            'Slot5'                             => '//str',
            'Designer AZ - Promo bottom'        => '//str',
            'Promo bottom'                      => '//str',
            'Order Confirmation - Tracking'     => '//str',
            'Order Confirmation - Promo'        => '//str',
            'Product Page Promo'                => '//str',
            'Listing Page Promo Left1'          => '//str',
            'Listing Page Promo Left2'          => '//str',
            'How-To Content'                    => '//str',
            'Other Help Info Content'           => '//str',
            'Title, Description and Keywords'   => '//str',
            'FlashSalesLanding'                 => '//str',
            'Designer Name Font Class'          => '//str',
            'Promo Block Two'                   => '//str',
            'Designer Runway Video'             => '//str',
            'FP One - PID'                      => '//str',
            'FP One - Image Type'               => '//str',
            'FP Two - PID'                      => '//str',
            'FP Two - Image Type'               => '//str',
            'FP Three - PID'                    => '//str',
            'FP Three - Image Type'             => '//str',
            'DressMe'                           => '//str',
            'JustIn'                            => '//str',
            'Designers'                         => '//str',
            'CSS files'                         => '//str',
            'Javascript files'                  => '//str',
            'Head HTML'                         => '//str',
            'Bridal - Try It On'                => '//str',
            'Landing Page Menu'                 => '//str',
            'Custom Navigation'                 => '//str'
        },
    };
}

has '+type' => ( default => 'dlp' );

sub transform {
    my ( $self, $header, $data ) = @_;

    DEBUG("Data : ".pp($data));
    DEBUG("Header : ".pp($header));

    my $designer_id = $data->{designer};
    my $channel_id  = $data->{channel};

    my $designer_rs =
      $self->schema->resultset('Public::Designer')
      ->search( { id => $designer_id, } )->first;

    my $page_instance_rs =
      $self->schema->resultset('WebContent::Page')
      ->search( { name => 'Designer - ' . $designer_rs->designer, } )
      ->first->instances->search->first;

    my $content_rs =
      $self->schema->resultset('WebContent::Content')
      ->search( { instance_id => $page_instance_rs->id, } );

    my @fields = $self->schema->resultset('WebContent::Field')->search()->all;

    my %field_data;
    $field_data{id} = $designer_id;

    foreach my $field (@fields) {

        my $id       = $field->id;
        my $name     = $field->name;
        my $field_rs = $content_rs->search( { field_id => $id } )->next;
        next unless $field_rs;
        $field_data{$name} = $field_rs->content || '';
    }

    my $designer = { %field_data };

    return ( $header, $designer );

}

1;
