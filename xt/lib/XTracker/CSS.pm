package XTracker::CSS;

use NAP::policy "tt", 'class';

use XTracker::XTemplate;
use XTracker::Config::Local;
use XTracker::Database::Channel;
use XTracker::Database qw(get_database_handle);

sub render_to_file {
    my $class = shift;
    my $css   = shift;

    die ("Invalid CSS path $css")
      if ($css !~ m|^(.+\.css)$|);

    my $data =
    {
        'template_type' => 'none',
    };

    my $dbh = get_database_handle( { name => 'xtracker', type => 'readonly' } );
    my $channels = XTracker::Database::Channel::get_channels($dbh);
    foreach my $channel_id (keys %$channels) {
        my $config_section = $channels->{$channel_id}->{config_section};
        $data->{$config_section} = config_section_slurp('CSS_'.$config_section);
    }

    my  $root     = config_section_slurp('PWS')->{'doc_root'} . "/css/";
    my  $template = XTracker::XTemplate->template();
        $template->process( $css.'.tt', $data, $root.$css );
}

