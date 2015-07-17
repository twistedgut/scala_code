package XTracker::Stock::Location::Common;

use NAP::policy "tt", 'exporter';

use Perl6::Export::Attrs;
use XTracker::Utilities qw/ generate_list /;
use XTracker::Config::Local qw/ config_var /;

sub selectable_floors :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','floors_start'),
        config_var('Stock_Location','floors_end')
    )];
}
sub selectable_units :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','units_start'),
        config_var('Stock_Location','units_end')
    )];
}
sub selectable_aisles :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','aisles_start'),
        config_var('Stock_Location','aisles_end')
    )];
}
sub selectable_bays :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','bays_start'),
        config_var('Stock_Location','bays_end')
    )];
}
sub selectable_positions :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','positions_start'),
        config_var('Stock_Location','positions_end')
    )];
}
sub selectable_zones :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','zones_start'),
        config_var('Stock_Location','zones_end')
    )];
}
sub selectable_locations :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','locations_start'),
        config_var('Stock_Location','locations_end')
    )];
}
sub selectable_levels :Export(:selectable) {
    return [generate_list(
        config_var('Stock_Location','levels_start'),
        config_var('Stock_Location','levels_end')
    )];
}

1;
