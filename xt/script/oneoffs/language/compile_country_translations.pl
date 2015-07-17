#!perl

use warnings;
use strict;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use JSON;
use Text::CSV;
use Getopt::Long::Descriptive;
use IO::File;

use Data::Dumper;

use XTracker::Database qw( schema_handle );

use feature ':5.14';

my ($opt, $usage) = describe_options(
    'compile_country_translations.pl %o',
    [ 'format|f=s', "Output format", { default  => 'hash' } ],
    [ 'output|o=s', "Filename to write to" ],
    [],
    [ 'help',       "print usage message and exit" ],
);

print($usage->text), exit if $opt->help;

my $data   = {};
my $schema = schema_handle();

my $preposition_map = {
    "en" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_EN',
    "à" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_AU',
    "au" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_A',
    "à l’" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_AL',
    "à la" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA',
    "aux" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_AUX',

    "pour" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_POUR',
    "pour l’" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L',
    "pour le" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE',
    "pour la" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA',
    "pour les" => '$LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES',

    "in" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_IN',
    "im" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_IM',
    "in die" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE',
    "in der" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER',
    "in den" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN',
    "in das" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DAS',

    "nach" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_NACH',
    "in nach" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_IN_NACH',

    "für" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_FUR',
    "für die" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE',
    "für das" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DAS',
    "für den" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DEN',

    "auf den" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN',
    "auf die" => '$LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE',
};


foreach my $lang (qw{fr de zh}) {

    my $file = $lang.'.csv';

    my $csv = Text::CSV->new ({ binary => 1, eol => $/ });

    my $fh = IO::File->new("< $file");

    while (my $row = $csv->getline($fh)) {

        my $iso  = $row->[0];
        my $name = $row->[1];

        my ($for, $to, $in);
        $for  = $preposition_map->{$row->[2]} if $row->[2];
        $to   = $preposition_map->{$row->[3]} if $row->[3];
        $in   = $preposition_map->{$row->[4]} if $row->[4];

        next unless $schema->resultset('Public::Country')->find_code($iso);

        $data->{$iso}{$lang}{country_name} = $name;

        $data->{$iso}{$lang}{preposition} = {
                for => $for,
                to  => $to ,
                in  => $in
        } if ($for || $to || $in);

    }

    $fh->close;

}

my $output;

given ($opt->{format}) {
    when ('hash') {
        $output = Dumper($data);
    }
    when ('json') {
        $output = to_json($data);
    }
    when ('csv') {
        $output = "ISO, French Name, For, To, In, German, For, To, In, Chinese\n";

        foreach my $iso (keys %{$data}) {
            $output .= $iso.",";
            foreach my $lang (qw{fr de zh}) {
                $output .= $data->{$iso}{$lang}{country_name}.',';
                $output .= $data->{$iso}{$lang}{preposition}{for}.',';
                $output .= $data->{$iso}{$lang}{preposition}{to}.',';
                $output .= $data->{$iso}{$lang}{preposition}{in}.',';
            }
            $output .= "\n";
        }
    }
}

if ($opt->{output}) {
    my $fh = IO::File->new('> '.$opt->{output});
    print $fh $output;
    $fh->close();
}
else {
    print $output;
}
