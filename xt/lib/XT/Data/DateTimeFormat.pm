package XT::Data::DateTimeFormat;
use NAP::policy "tt", "exporter";

use Perl6::Export::Attrs;

sub web_format_from_datetime : Export() {
    my ($datetime) = @_;
    $datetime or return "";
    return $datetime->strftime("%d/%m/%Y");
}
