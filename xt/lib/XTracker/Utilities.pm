package XTracker::Utilities;
use NAP::policy "tt", 'exporter';

use Carp qw/croak/;

use Perl6::Export::Attrs;
use Date::Format;
use Number::Format;
use Date::Calc qw( Today This_Year Add_Delta_Days Add_Delta_YM
                   Delta_Days Delta_YMD Week_of_Year Monday_of_Week check_date );
use Time::Duration qw/ duration /;
use File::Basename;

use XTracker::Config::Local qw( config_var );
use XTracker::Database::Utilities   qw( is_valid_database_id );
use Encode;
use DateTime    qw( compare );
use NAP::DC::Location::Format;
use URL::Encode 'url_encode_utf8';
use URI;

### Subroutine : unpack_params                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub unpack_params :Export(:DEFAULT) {

    my ( $req ) = @_;
    my $data_ref = ();
    my $rest_ref = ();

    foreach my $param ( $req->param ) {
        if ( $param =~ m/(\w+)_(\d+-?(\d+)?)/ ) {
            $data_ref->{$2}->{$1} = $req->param($param);
        }
        else {
            $rest_ref->{$param} = $req->param($param);
        }
    }

    return ( $data_ref, $rest_ref );
}

### Subroutine : unpack_handler_params                          ###
# usage        : ($data_ref,$rest_ref) =                          #
#                    unpack_handler_params($handler->{param_of})  #
# description  : Like 'unpack_params' but for Handler             #
#                goes through all parameters and splits them off  #
#                into a $data_ref or into $rest_ref for the       #
#                rest of the parameters.                          #
# parameters   : Pointer to the parameters in that the Handler    #
#                has previously got normally 'param_of'           #
# returns      : 2 Pointers to Hash's, data_ref and rest_ref      #

sub unpack_handler_params :Export(:DEFAULT) {

    my ( $param_of )    = @_;

    my $data_ref        = ();
    my $rest_ref        = ();

    foreach my $param ( keys %$param_of ) {
        if ( $param =~ m/(\w+)_(\d+-?(\d+)?)/ ) {
            $data_ref->{$2}->{$1} = $param_of->{$param};
        }
        else {
            $rest_ref->{$param} = $param_of->{$param};
        }
    }

    return ( $data_ref, $rest_ref );
}


### Subroutine : unpack_edit_params             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub unpack_edit_params :Export(:edit) {

    my ( $req ) = @_;
    my $data_ref = ();
    my $rest_ref = ();

    foreach my $param ( $req->param ) {

        if( $param =~ m/edit_cancel_(\d+)/ ){
            my $cancel = $req->param("cancel_$1") || 'off';
            $data_ref->{$1}->{cancel} = $cancel;
        }
        elsif( $param =~ m/(\w+)_(\d+-?(\d+)?)/ ) {
            if ( defined($req->param("edit_$1_$2")) && ($req->param("edit_$1_$2") eq 'on') ){
                 $data_ref->{$2}->{$1} = $req->param($param);
            }
        }
        elsif ( $param =~ m/^edit_(.*)$/ ) {
            if( $req->param( $param ) eq 'on'  ){
                $data_ref->{$1} = $req->param($1);
            }
        }
        else {
            $rest_ref->{$param} = $req->param($param);
        }
    }

    return ( $data_ref, $rest_ref );
}


### Subroutine : unpack_handler_edit_params                                  ###
# usage        : ($hash_ptr,$hash_ptr) = unpack_handler_edit_params(           #
#                       $param_of_hash_ptr                                     #
#                   );                                                         #
# description  : This is a Handler version of the above unpack_edit_params     #
#                it splits the params into 2 HASH's one containing 'cancel'    #
#                and 'edit' params and the other containing the rest.          #
# parameters   : The hash ptr to the params in the Handler usually 'param_of'. #
# returns      : 2 Hash Pointers containing the parameters.                    #

sub unpack_handler_edit_params :Export(:edit) {

    my $param_of    = shift;

    my $data_ref    = ();
    my $rest_ref    = ();

    foreach my $param ( keys %$param_of ) {

        if ( $param =~ m/edit_cancel_(\d+)/ ) {
            my $cancel = $param_of->{"cancel_$1"} || 'off';
            $data_ref->{$1}->{cancel} = $cancel;
        }
        elsif ( $param =~ m/(\w+)_(\d+-?(\d+)?)/ ) {
            if ( $param_of->{"edit_$1_$2"} eq 'on' ) {
                 $data_ref->{$2}->{$1} = $param_of->{$param};
            }
        }
        elsif ( $param =~ m/^edit_(.*)$/ ) {
            if ( $param_of->{ $param } eq 'on'  ) {
                $data_ref->{$1} = $param_of->{$1};
            }
        }
        else {
            $rest_ref->{$param} = $param_of->{$param};
        }
    }

    return ( $data_ref, $rest_ref );
}


=head2 unpack_csm_changes_params

    $hash_ref   = unpack_csm_changes_params( $params_hash_ref );

This will get all of the relevant fields that are required to update the Corrsespondenc Subject Method
changes for a Customer or Order etc. It will return a HASH Ref as follows grouping Correspondence Method
changes by Correspondence Subject Id:

    {
        subject_id  => {
                    method_id   => TRUE or FALSE,
                    ...
                },
        ...
    }

=cut

sub unpack_csm_changes_params :Export() {
    my ( $params )  = @_;

    my $retval;

    # get the changes that have been submitted in the form
    # looking for fields prefixes with 'csm_subject_method_'
    my %csm_changes =   map { $_ => $params->{ $_ } }
                            grep { m/^csm_subject(_method)?_\d+$/ }
                                keys %{ $params };

    # now group method ids by subject ids
    while ( my ( $subject, $method_ids ) = each %csm_changes ) {
        $subject    =~ m/.*?(?<has_methods>_method)?_(?<subject_id>\d+)$/;
        $retval->{ $+{subject_id} } //= {};         # create an empty Hash for each Subject but not if something is already there
        if ( $+{has_methods} ) {
            # if there isn't an Array Ref. of Method Ids already, make one
            $method_ids = ( ref( $method_ids ) ? $method_ids : [ $method_ids ] );
            $retval->{ $+{subject_id} }{ $_ }   = 1     foreach ( @{ $method_ids } );
        }
    }

    return $retval;
}

### Subroutine : dir_walk                       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub dir_walk :Export(:DEFAULT) {

    my ( $top, $filefunc, $dirfunc ) = @_;
    my $DIR;

    if ( -d $top ) {
        my $file;
        unless ( opendir $DIR, $top ) {
            warn "Couldn't open directory top: $!; skipping.\n";
            return;
        }

        my @results;
        while ( $file = readdir $DIR ) {
            next if $file eq '.' || $file eq '..';
            next if $file =~ m/^\./;
            next if $file =~ m/^\.orig/;
            push @results,
                dir_walk( "$top/$file", $filefunc, $dirfunc );
        }

        return $dirfunc ? $dirfunc->( $top, @results ) : ();
    }
    else {
        return $filefunc ? $filefunc->($top) : ();
    }
}

### Subroutine : current_datetime               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub current_datetime :Export {

    my $template = '%Y-%m-%dT%T';

    return time2str($template, time);
}

### Subroutine : current_date                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub current_date :Export {

    my( $year, $month, $day ) = Today();

    my $newmonth = sprintf( '%02d', $month );
    return "$year-$newmonth-$day";
}

### Subroutine : current_year                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub current_year :Export {

    my( $year ) = This_Year();

    return $year;
}

### Subroutine : isdates_ok                                               ###
# usage        : $boolean = isdates_ok( "2009-01-01", "2009-02-31" .... )   #
# description  : Given a list of dates returns TRUE (1) if ALL dates are    #
#                VALID or FALSE (0) if ONE or more dates are INVALID.       #
# parameters   : List of Dates in the form "YYYY-MM-DD","YYYY-MM-DD" etc.   #
# returns      : One or Zero                                                #

sub isdates_ok :Export() {

    my @date_list   = @_;

    my $isok        = 1;

    foreach ( @date_list ) {
        if (!check_date(split(/-/))) {
            $isok   = 0;
            last;
        }
    }

    return $isok;
}

sub date_range :Export {

    my( $start_date, $end_date, $range_type ) = @_;

    my @dates = ();

    my $dispatch = { 'days'   => [ sub{ Delta_Days( @_ ) }, sub{ Add_Delta_Days( @_ ) }, 0] ,
                     'months' => [ sub{ Delta_YMD( @_ ) }, sub{ Add_Delta_YM( @_ ) }, 1, ], };

    my @deltas = $dispatch->{$range_type}->[0]->( $start_date->{year}, $start_date->{month}, $start_date->{day},
                                                  $end_date->{year}, $end_date->{month}, $end_date->{day}, );

    my @args = ($start_date->{year}, $start_date->{month}, $start_date->{day} );
    if( $range_type eq 'months' ){ push @args, 0 };

    my $delta = $deltas[ $dispatch->{$range_type}->[2] ];

    for my $offset (0..($delta) ){

        my( $year, $month, $day ) = $dispatch->{$range_type}->[1]->( @args, $offset );
        my $newmonth = sprintf( '%02d', $month );
        my $newday   = sprintf( '%02d', $day );

        push @dates, "$year-$newmonth-$newday";
    }

    return @dates;
}


### Subroutine : reporting_date                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub reporting_date :Export {

    my ( $date ) = @_;

    my %dispatch = ( yesterday                    => sub { Add_Delta_Days( Today(), -1 ) },
                     tomorrow                     => sub { Add_Delta_Days( Today(), +1 ) },
                     today_last_week              => sub { Add_Delta_Days( Today(), -7 ) },
                     today_last_month             => sub { Add_Delta_YM( Today(), -0, -1 ) },
                     today_last_year              => sub { Add_Delta_YM( Today(), -1, -0 ) },
                     this_monday                  => sub { Monday_of_Week( Week_of_Year( Today() ) ) },
                     last_monday                  => sub { Monday_of_Week( Week_of_Year( Add_Delta_Days( Today(), -7 ) ) ) },
                     first_day_of_month           => sub { my ( $year, $month, $day ) = Today(); return ( $year, $month, '1' )},
                     first_day_of_month_last_year => sub { my ( $year, $month, $day ) = Today(); return ( ($year - 1), $month, '1' )},
                     first_day_of_year            => sub { ( This_Year(), '1', '1' ) },
                     first_day_of_last_year       => sub { ( ( This_Year() - 1 ), '1', '1' ) },
                     # last_monday                  => sub { },
                );

    my( $year, $month, $day ) = $dispatch{$date}->();

    my $newmonth = sprintf( '%02d', $month );
    my $newday   = sprintf( '%02d', $day );
    return "$year-$newmonth-$newday";
}

### Subroutine : get_date_db                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_date_db :Export() {

    my $args_ref        = shift;
    my $dbh             = $args_ref->{dbh};
    my $format_string   = defined $args_ref->{format_string} ? $args_ref->{format_string} : "DD-Mon-YYYY HH24:MI";


    my $sql = qq{SELECT TO_CHAR(LOCALTIMESTAMP, ?) AS current_date};

    my $sth = $dbh->prepare($sql);
    $sth->execute($format_string);

    my $date_db;

    $sth->bind_columns(\$date_db);

    $sth->fetch();
    $sth->finish();

    return $date_db;

} ### END sub get_date_db

sub _validate_time_part {
    my ($value, $name, $time_part, $max) = @_;
    if( $time_part < 0 || $time_part > $max) {
        die("Invalid Time of Day ($value), ($time_part) $name out of range");
    }
}

sub duration_from_time_of_day : Export {
    my ($value) = @_;
    return undef unless defined($value);
    $value =~ /(\d\d):(\d\d):(\d\d)/ or return undef;
    my ($hours, $minutes, $seconds) = ($1, $2, $3);
    _validate_time_part($value, hours   => $hours,   24);
    _validate_time_part($value, minutes => $minutes, 60);
    _validate_time_part($value, seconds => $seconds, 60);

    return DateTime::Duration->new(
        hours   => $hours,
        minutes => $minutes,
        seconds => $seconds,
    );
}

=head2 undef_or_equals($var, @equals_id) : Bool

Return a true value if $var is _either_ undef, or is one of the values
in @equals_id. Otherwise return a false value.

=cut

sub undef_or_equals : Export {
    my ($var, @equals_in) = @_;
    return 1 unless defined($var);
    return exists { map { $_ => 1 } @equals_in }->{$var};
}

### Subroutine : ltrim                          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub ltrim :Export(:string) {
    my ($string) = @_;
    $string =~ s/^\s+// if $string;
    return $string;
} ### END sub ltrim


### Subroutine : rtrim                          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub rtrim :Export(:string) {
    my $string = shift;
    $string =~ s/\s+$// if $string;
    return $string;
} ### END sub rtrim

################################################################
#
# I see generalization in the future for these next routines...
#

### Subroutine : trim                           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub trim :Export(:string) {
    if (wantarray) {
        return unless @_;

        return map { my $s = $_;
                     $s =~ s/^\s+// if $s;
                     $s =~ s/\s+$// if $s;
                     $s
                   } @_;
    }
    else {
        my $s = shift;

        return unless defined $s;

        $s =~ s/^\s+// if $s;
        $s =~ s/\s+$// if $s;

        return $s;
    }
} ### END sub trim

### Subroutine : strip                          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub strip :Export(:string) {
    if (wantarray) {
        return unless @_;

        return map { my $s = $_; $s =~ s/\s+//g if $s; $s } @_;
    }
    else {
    my $s = shift;

        return unless defined $s;

        $s =~ s/\s+//g;
        return $s;
    }
} ### END sub strip

sub strip_txn_do :Export(:string) {
    my ( $leading, $trailing ) = (
        qr{\A.*::txn_do\(\): }, qr{\sat\s/\S+?\sline\s\d+$}
    );
    if (wantarray) {
        return unless @_;

        return map { my $s = $_;
                     $s =~ s{$_}{} for $leading, $trailing;
                     $s
                   } @_;
    }
    else {
    my $s = shift;

        return unless defined $s;

        $s =~ s{$_}{} for $leading, $trailing;

        return $s;
    }
}

### Subroutine : flatten                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub flatten  :Export(:string) {
    if (wantarray) {
        return unless @_;

        return map { my $s = $_; $s =~ s/\s+/ /sg if $s; $s } @_;
    }
    else {
    my $s = shift;

        return unless defined $s;

        $s =~ s/\s+/ /sg;
        return $s;
    }
} ### END sub strip

### Subroutine : url_encode                     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub url_encode :Export(:string) {
    return url_encode_utf8(shift);
} ### END sub url_encode

### Subroutine : generate_list                  ###
# usage        : @a = generate_list($start, $end) #
# description  : Returns a list of all the numbers#
#              : or characters between $start and #
#              : $end inclusive                   #
# parameters   : $start, $end                     #
# returns      : @list                            #

sub generate_list :Export() {
    my $start         = shift;
    my $end           = shift;
    croak "\$start is not defined" if (!defined $start);
    croak "\$end is not defined" if (!defined $end);

    my @return_list   = ();
    my $delta         = 1;


    if ($start =~ /^[0-9]+$/) {
    my $len = length($start) < length($end)?length($end):length($start);
    if ($end < $start) {
        $delta = -1;
    }
    for (my $i = $start; $i <= $end; $i+=$delta) { ## no critic(ProhibitCStyleForLoops)
        push(@return_list, sprintf("%0${len}d", $i));
    }
    } else {
    if ($end lt $start) {
        $delta = -1;
    }
    for (my $i = ord($start); $i <= ord($end); $i+=$delta) { ## no critic(ProhibitCStyleForLoops)
        push(@return_list, chr($i));
    }
    }

    return @return_list;
}


sub _get_validated_start_end {

    my ($param_of) = @_;

    my ($start, $end);
    if ($param_of->{"start"} =~ m/^[0-9]{2}([0-9])([A-Z])-?([0-9]{1,4})([A-Z])$/i) {
        $start = $param_of->{"start"};
    }
    else {
        die "Invalid request parameters: start = " . $param_of->{"start"} . "\n";
    }

    if (!defined($param_of->{"end"})) {
        $end = $start;
    }
    elsif ($param_of->{"end"} =~ m/^[0-9]{2}([0-9])([A-Z])-?([0-9]{1,4})([A-Z])$/i) {
        $end = $param_of->{$end};
    }
    else {
        die "Invalid request parameters: end = " . $param_of->{"end"} . "\n";
    }
    return($start, $end);
}


sub _are_numeric_locations_valid {
    my ($locations, $param_of) = @_;

    foreach my $location(@$locations) {
        if (exists $param_of->{"start_$location"}) {
            if (
            (($param_of->{"start_$location"} .  $param_of->{"end_$location"}) !~ /^[0-9]+$/) ||
            ($param_of->{"start_$location"} >  $param_of->{"end_$location"})
            ) {
                croak "Invalid request parameters: start_$location = " . $param_of->{"start_$location"} . " end_$location = " .  $param_of->{"end_$location"};
            }
        }
    }
}

sub _are_alphabet_locations_valid {
    my ($locations, $param_of) = @_;

    foreach my $location(@$locations) {
        if (exists $param_of->{"start_$location"}) {
            if (
            (($param_of->{"start_$location"} .  $param_of->{"end_$location"}) !~ /^[A-Z][A-Z]$/) ||
            ($param_of->{"start_$location"} gt $param_of->{"end_$location"}
            )) {
                croak "Invalid request parameters: start_$location = " . $param_of->{"start_$location"} . " end_$location = " .  $param_of->{"end_$location"};
            }
        }
    }
}


sub get_start_end_location :Export() {
    my $param_of    = shift;

    my ($start, $end);
    if ($param_of->{"start"}) {
        ($start, $end) = _get_validated_start_end($param_of);
    }
    else {

        my @numeric_locations  = qw(floor location unit aisle bay position);
        my @alphabet_locations = qw(level zone);

        _are_numeric_locations_valid(\@numeric_locations, $param_of);
        _are_alphabet_locations_valid(\@alphabet_locations, $param_of);

        my $location_format = $param_of->{'location_format'} ?
                           (config_var('DistributionCentre', 'name') . '_' . $param_of->{'location_format'}) :
                           (config_var('DistributionCentre', 'name'));
        $start = NAP::DC::Location::Format::get_formatted_location_name($location_format, {
            floor       => $param_of->{'start_floor'},
            zone        => $param_of->{'start_zone'},
            location    => $param_of->{'start_location'},
            level       => $param_of->{'start_level'},
            bay         => $param_of->{'start_bay'},
            unit        => $param_of->{'start_unit'},
            aisle       => $param_of->{'start_aisle'},
            position    => $param_of->{'start_position'},
        });
        $end = NAP::DC::Location::Format::get_formatted_location_name($location_format, {
            floor       => $param_of->{'end_floor'},
            zone        => $param_of->{'end_zone'},
            location    => $param_of->{'end_location'},
            level       => $param_of->{'end_level'},
            bay         => $param_of->{'end_bay'},
            unit        => $param_of->{'end_unit'},
            aisle       => $param_of->{'end_aisle'},
            position    => $param_of->{'end_position'},
        });
    }

    return ($start, $end);
}


### Subroutine : format_currency                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub format_currency :Export() {
    my $number = shift;
    my $decimal_places = shift || 2;
    my $include_trailing_zeros = shift || 0;

    my $formatter = Number::Format->new(-thousands_sep   => ',',
                                        -decimal_point   => '.', );

    my $formatted = $formatter->format_number( $number, $decimal_places, $include_trailing_zeros );
}

sub format_currency_2dp :Export() {
    return format_currency(shift, 2, 1);
}

### Subroutine : get_random_id                   ###
# usage        : return a random 5 digit number    #
# description  : for use in avoiding image caching #
# parameters   : none                              #
# returns      : int                               #

sub get_random_id :Export {

    return sprintf( "%05d", (rand(1) * 100000) );
}

### Subroutine : portably_get_basename                 ###
# usage        : $file = portably_get_basename($path)    #
# description  : Gets the filename from a full path, for #
#              : any OS's filesystem. Useful when        #
#              : processing files uploaded from other OS #
# parameters   : $path                                   #
# returns      : string                                  #

sub portably_get_basename :Export {
    my ($path) = @_;

    foreach my $os ("MSWin32", "MacOS", "Unix", "DOS", "VMS", "AmigaOS", "OS2", "RISCOS", "Epoc" ) {
    fileparse_set_fstype($os);
    my $basename = File::Basename::fileparse($path);
    if (length($path) > length($basename)) {
        return $basename;
    }
    }

    return $path;
}


### Subroutine : printXLSfile                       ###
# usage        :                                      #
# description  : reads a file and prints to STDOUT    #
# parameters   :                                      #
# returns      :                                      #

sub printXLSfile :Export() {

    my $p = shift;

    open ( my $filehandle, "<", $p->{filename} ) or die $!;

    $p->{r}->content_type( $p->{header} );

    binmode $filehandle;
    binmode STDOUT;

    print <$filehandle>;
    close $filehandle;

    unlink $p->{filename};

}

=head2 parse_url

    ( $section, $sub_section, $short_url ) = parse_url( $r );

Gets the section, subsection & short url out of the URL.

=cut

sub parse_url :Export() {

    my $r = shift;

    my $uri       = $r->parsed_uri;
    my $path_info = $uri->path;

    my $parts = parse_url_path( $path_info );

    return (
        $parts->{section},
        $parts->{sub_section},
        $parts->{short_url},
    );
}

=head2 parse_url_path

    $hash_ref = parse_url_path( '/Fulfilment/DDU' );

Used to split up a URL and return the Section & Sub-Sections from it.

In full it returns the following in a Hash Ref:

    # this:
    $hash_ref = parse_url_path( 'NAPEvents/InTheBox/Create/1224' );

    # would return this:
    {
        section     => 'NAP Events',
        sub_section => 'In The Box',
        levels      => [
            'NAPEvents',
            'InTheBox',
            'Create',
            1224,
        ],
        short_url   => '/NAPEvents/InTheBox',
    }

NOTE: You can pass in a URL with or without a leading '/'

=cut

sub parse_url_path :Export() {
    my $url_path    = shift;

    my @levels;
    my $section;
    my $sub_section;
    my $short_url;

    if ( defined $url_path ) {
        $url_path   =~ s{^/}{};
        @levels  = split  /\//, $url_path;
        ( $section, $sub_section ) = @levels[0,1];
    }

    if ( defined $levels[0] ) {
        $short_url  = '/' . $levels[0];
        $short_url .= '/' . $levels[1]      if ( defined $levels[1] );
    }

    # the following patterns were originally in the function
    # '_current_section_info' in 'XTracker::Authenticate'

    if ( defined $section ) {
        # camelcase-esque split
        $section        =~ s/([a-z])([A-Z])/$1 $2/g;
        # DCS-710 "NAP Events"
        $section        =~ s/\A([A-Z]+)([A-Z][a-z]+)\z/$1 $2/g;
    }

    if ( defined $sub_section ) {
        # camelcase-esque split
        $sub_section    =~ s/([a-z])([A-Z])/$1 $2/g;
        # this was needed for 'Admin/ACL Admin'
        $sub_section    =~ s/\A([A-Z]+)([A-Z][a-z]+)\z/$1 $2/g;
        # this was needed for 'Admin/ACL Main Nav Info'
        $sub_section    =~ s/\A([A-Z]+)([A-Z][a-z]+) ([A-Z].*)\z/$1 $2 $3/g;
        # this was needed for 'Customer Care/Order Search by Designer'
        $sub_section    =~ s/Searchby/Search by/;
    }

    return {
        section     => $section,
        sub_section => $sub_section,
        levels      => \@levels,
        short_url   => $short_url,
    };
}

### Subroutine : d2                                   ###
# usage        : $var = d2($decimal_number)             #
# description  : Rounds to 2 decimal places any decimal #
#                number.                                #
# parameters   : A decimal number                       #
# returns      : a decimal number to 2 decimal places   #

sub d2 :Export() {
    my $val = shift;
    my $n   = sprintf( "%.2f", $val );

    # Get rid of -ve 0.00
    $n = '0.00' if ($n eq '-0.00');
    return $n;
}

### Subroutine : load_err_translations                                   ###
# usage        : $hash_ptr = load_err_translations(                        #
#                      $dbh,                                               #
#                      $module_name_1 .... $module_name_n                  #
#                 );                                                       #
# description  : This loads up a mapping between system messages ($@) and  #
#                their english translations. Module names passed in will   #
#                be read in from the table along with any messages for     #
#                under 'GENERAL'. General messages will be overwritten     #
#                if a dupe appears. The 'translate_error' sub is used to   #
#                make the actual translation.                              #
# parameters   : A Database Handle, A List of Modules Names to load        #
#                messages in for.                                          #
# returns      : A pointer to a HASH containing the translations the KEY   #
#                being the system messages needing translation.            #

sub load_err_translations :Export(:err_translations) {
    my ($dbh, @modules) = @_;

    my $vars        = join( ",", map { '?' }  @modules  );
    my %translations;

    my $qry =<<SQL
SELECT  *
FROM    system_to_english_errors
WHERE   module_name = 'GENERAL'
OR      module_name IN ($vars)
ORDER BY module_name, id
SQL
;
    my $sth = $dbh->prepare($qry);
    $sth->execute(@modules);

    while ( my $rec = $sth->fetchrow_hashref() ) {
        if ( exists $translations{ $rec->{system_error} } ) {
            $translations{ $rec->{system_error} }   = $rec->{english_translation}       unless ( $rec->{module_name} eq "GENERAL" );
        }
        else {
            $translations{ $rec->{system_error} }   = $rec->{english_translation};
        }
    }

    return \%translations;
}


### Subroutine : translate_error                                         ###
# usage        : $string = translate_error(                                #
#                     $translation_hash_ptr,                               #
#                     $err_to_translate                                    #
#                  );                                                      #
# description  : This will translate an error passed in using the          #
#                translation hash got from the sub 'load_err_translations' #
#                and return back the english translation or if the msg     #
#                could not be found then the original error msg is         #
#                returned.                                                 #
# parameters   : A Pointer to a HASH containing the translations,          #
#                A Message to translate.                                   #
# returns      : A string containing a message.                            #

sub translate_error :Export(:err_translations) {

    my $translations    = shift;
    my $msg_to_trans    = shift;

    my $ret_msg     = $msg_to_trans;

    foreach my $err ( sort keys %$translations ) {
        if ( $msg_to_trans =~ /$err/ ) {
            chomp($translations->{$err});
            $ret_msg    = $translations->{$err} . "\n" ;
            last;
        }
    }

    return $ret_msg;
}

sub number_in_list :Export {
    my $n=shift;
    for (@_) {
        return 1 if $_ == $n;
    }
    return 0;
}

sub string_in_list :Export {
    my $s=shift;
    for (@_) {
        return 1 if $_ eq $s;
    }
    return 0;
}

=head2 local_date

 my $dt = local_date($date_time_object);

=head3 What

Returns a clone of the L<DateTime> supplied, set to the correct
timezone, and with the correct time formatter set.

=head3 Why

Dates in the database are stored as UTC. Ha ha! No really. They're meant to be.
When you get a DBIC-inflated column back from it, you'll get a L<DateTime>
whose timezone is set to 'UTC'. That's all well and good, but if you'll be
using that to tell the user you'll want to set the timezone on it to the
application local time. Which you'll need to find out, and which should be set,
but only if you're using XTracker::Config::Local, and you can use that, but
that'll fail if it's not. And then if you actually change your DateTime object
you've changed the value in the DBIC row, and don't even think about committing
at that point and oh my.

The same applies to L<DateTime> objects obtained from other places.

=head3 How to use

 my $correctly_localized_date_time_object =
    local_date($date_time_object);

=head3 Options

We die if you use this on a DateTime without a timezone
defined. That's not always optimal. You can B<BUT SHOULDN'T> pass in
the C<naughty_local_time_zone> flag if you understand this, and want
to default to the local timezone.

If you want the date without the time, set C<date_only> to true.

=cut

{
    # Locally cache these as they may not change during application run, and
    # they might be expensive to calculate
    my $timezone;
    my $date_format;
    my $datetime_format;

    sub _local_timezone {
        return (
            ( $timezone //= XTracker::Config::Local::local_timezone() ),
            ( $date_format //= XTracker::Config::Local::local_date_format() ),
            ( $datetime_format //= XTracker::Config::Local::local_datetime_format() )
        );
    }
}

sub local_date {
    my ( $date_time, %opts ) = @_;

    return unless $date_time;

    croak("The object is not a DateTime object: [$date_time]") unless
        ( ref $date_time && $date_time->isa('DateTime') );

    croak("The DateTime object doesn't have a timezone, so can't convert to local time")
        if $date_time->time_zone->isa('DateTime::TimeZone::Floating') &&
            (! $opts{'naughty_local_time_zone'} );

    my ( $timezone, $date_format, $datetime_format ) = _local_timezone;

    my $format_to_use = $opts{'date_only'} ?
        $date_format : $datetime_format;

    my $clone = $date_time->clone();
    $clone->set_time_zone( $timezone );
    $clone->set_formatter( $format_to_use );

    return $clone;
}



=head2 time_diff_in_english(DateTime $to_datetime | Undef) : $english_duration_string

Return string describing the time difference from Now to $to_datetime,
or "" if $to_datetime is undef.

Example $english_duration_string: "2 days" or "16 hours".
If $to_datetime has passed, return e.g. "3 hours ago".

=cut

sub time_diff_in_english : Export {
    my ($to_datetime) = @_;
    $to_datetime or return "";
    my $to_epoch = $to_datetime->epoch;

    my $now_epoch = DateTime->now()->epoch;
    my $remaining_duration = $to_epoch - $now_epoch;
    my $time_diff = duration($remaining_duration, 1);

    $time_diff .= " ago" if($remaining_duration < 0); # overdue

    return $time_diff;
}

sub fix_encoding :Export {
    my @in=@_;my @ret;
    for my $v (@in) {
        my $r = eval { decode('utf-8',$v,Encode::FB_CROAK) };
        $r = eval { decode('iso-8859-1',$v,Encode::FB_CROAK) } unless defined $r;
        $r = $v unless defined $r;
        push @ret,$r;
    }
    return wantarray ? @ret : $ret[0];
}

sub ff :Export { fix_encoding(fix_encoding(@_)) }

sub ff_deeply :Export {
    my @ret;

    foreach my $arg (@_) {
        given (ref($arg)) {
            when (q{}) { # i.e. not a reference
                push @ret, ff($arg);
            }

            when ('ARRAY') {
                push @ret, [ff_deeply(@$arg)];
            }

            when ('HASH') {
                push @ret, {ff_deeply(%$arg)};
            }

            when (m{^JSON::(?:XS|PP)::}) {
                # this started coming in vie the mrp orders
                # e.g.
                #   "signature_required" => bless(do{\(my $o = 1)}, "JSON::XS::Boolean"),
                push @ret, ff($arg);
            }

            default {
                Carp::confess( "Unexpected type: arg=$arg, is a " . ref($arg) );
            }
        }
    }
    return wantarray ? @ret : $ret[0];
}

=head2 twelve_hour_time_format

    $string = twelve_hour_time_format( $date_time );

This returns a string formatting the DateTime object into a twelve hour human readable format including 'am' & 'pm' suffixes.
Also makes sure 13:00 becomes 1pm. So the following would be formatted as follows:

    14:25 - '2:25pm'
    00:00 - '12am'
    12:00 - '12pm'
    10:00 - '10am'
    11:05 - '11:05am'

Seconds are discarded.

=cut

sub twelve_hour_time_format :Export {
    my $date_time   = shift;

    croak("The object is not a DateTime object") unless
                ( ref $date_time && $date_time->isa('DateTime') );

    # decide if it is '1:00pm' then just have '1pm'
    my $mask    = ( ($date_time->minute * 1) ? 'h:mma' : 'ha' );

    return lc( $date_time->format_cldr( $mask ) );
}

=head2 is_date_in_range

    $boolean    = is_date_in_range( $date_to_check, $start_date, $end_date );

This will return 1 or 0 based on whether a Date is between two dates inclusively.

ALL of the dates passed in should be 'DateTime' objects. If any of the dates are 'undef' then 0 will be returned.

=cut

sub is_date_in_range :Export {
    my ( $chk_date, $start_date, $end_date )    = @_;

    # if not all dates are passed in then NO it's not in range
    return 0    if ( !$chk_date || !$start_date || !$end_date );

    # if they are all there then check they are all valid
    if ( grep { ref( $_ ) ne 'DateTime' } ( $chk_date, $start_date, $end_date ) ) {
        croak "All Dates need to be a 'DateTime' object for '" . __PACKAGE__ . "::is_date_in_range'";
    }

    if (
            DateTime->compare( $chk_date, $start_date ) >= 0
                                &&
            DateTime->compare( $chk_date, $end_date ) <= 0
       ) {
        return 1;
    }

    return 0;
}

=head2 prefix_country_code_to_phone

    $string = prefix_country_code_to_phone( $phone_number, $suggested_country_obj );

This adds the the Country Prefix for the Country including the '+' symbol to the front of a Phone Number.

It should only be supplied with a Phone Number that has only digits in it except for a leading Plus '+' sign, if it
has a leading plus sign then the number will be given straight back as it will be deemed to already have a
Country Prefix.

Requires a Phone Number and a DBIC 'Public::Country' Object.

Passing NO Phone Number results in an Empty String being passed back.

=cut

sub prefix_country_code_to_phone :Export {
    my ( $phone, $country )     = @_;

    if ( !$phone ) {
        return "";
    }

    # check the validity of the Number
    if ( $phone =~ m/[^\d\+]/ || $phone =~ m/((.\+)|(\+$))/ ) {
        croak "Invalid Phone Number: '$phone' passed to '" . __PACKAGE__ . "::prefix_country_code_to_phone";
    }

    # if there is a leading '+' then return straight back
    return $phone       if ( $phone =~ m/^\+/ );

    # going to need a country from now on
    if ( !$country || ref( $country ) !~ m/Public::Country$/ ) {
        croak "Missing Country or Country NOT a 'Public::Country' object passed to '" . __PACKAGE__ . "::prefix_country_code_to_phone";
    }

    my $number  = $phone;

    $number =~ s/^0//g;
    $number = '+' . ( $country->phone_prefix // '' ) . $number;

    return $number;
}

=head2 known_mobile_number_for_country

    $boolean    = known_mobile_number_for_country( $mobile_number );

Pass in a number prefixed with the country code (it relies on this, leading '+' optional) and it will return TRUE or FALSE based
on the country code prefix as to whether the number might be for a Mobile. If it can't tell the difference then it will also
return TRUE. Passing in an empty or undef number will return FALSE. The number should be as complete as you can make it before
calling this function.

Currently only the UK country code (+44) is recognised, which means any other country will return TRUE.

Remember this isn't DC specific as a UK (or any other) number will be a UK number anywhere in the World.

UK Mobile Numbers should all start '07*' or '447', US Mobile Numbers can't be identified as they are just another phone number.

=cut

sub known_mobile_number_for_country :Export {
    my $number      = shift;

    return 0        if ( !$number );

    my $result  = 1;

    # lose non digits
    $number =~ s/[^\d]//g;

    # UK
    # TODO: this could be made better using config or DB tables
    #       but for now this is the only country we can test
    #       and '447' shouldn't change.
    if ( $number =~ /^44/ ) {
        # it starts with a UK prefix
        $result = 0     if ( $number !~ /^447/ );   # UK mobiles must be '447*'
    }

    return $result;
}

=head2 get_class_suffix

    $string = get_class_suffix( $record or $class_name );

Will return the Last part of a DBIC Class Name. Pass in either a DBIC record or a Class Name it'self.

=cut

sub get_class_suffix :Export {
    my ( $class )   = @_;

    return ""       if ( !$class );

    my $class_name  = ref( $class ) || $class;

    $class_name =~ s/.*::(\w+)$/$1/;

    return $class_name;
}

=head2 class_suffix_matches

    $boolean    = class_suffix_matches( $record, $class_name );

Returns TRUE or FALSE depending on whether $class_name matches the Class of $record.

=cut

sub class_suffix_matches :Export {
    my ( $rec, $class )    = @_;
    return 0        if ( !$rec || !$class );
    return ( ref( $rec ) =~ m/\b${class}$/ ? 1 : 0 );
}

=head2 time_now

    $date_time_obj  = time_now();
                        or
    $date_time_obj  = time_now( $time_zone );

Returns a DateTime object for the Date & Time right now. Pass in an optional
Time Zone otherwise 'local' will be used.

=cut

sub time_now :Export() {
    my $tz  = shift || 'local';
    return DateTime->now( time_zone => $tz );
}

=head2 as_zulu

Given a DateTime object, return a string that represents it in
ISO-8601 format, in UTC, and with the UTC ('Zulu') timezone identifier
appended.

=cut

sub as_zulu :Export() { return shift->set_time_zone('UTC')->iso8601.'Z'; }

=head2 summarise_stack_trace_error

    $string = summarise_stack_trace_error( $stack_trace );

This will Summarise a Stack Trace Error by chopping off everything from the 'at' onwards
leaving behind the cause of the error. This can be used if communicating errors to other
systems which don't require chapter and verse on what went wrong.

=cut

sub summarise_stack_trace_error :Export() {
    my $e = shift;
    # grab output up to (but not including 'at /path/to/module.pm line 667'
    my $re = qr{\A(.*?)\s+at\s+[^\s]+\s+line\s+\d+};
    # build the summary
    my $summary = $e;
    $summary =~ s{${re}.*}{$1}ms;

    return $summary;
}

=head2 string_to_boolean

Given a string that represents a Boolean value, return 1 or 0 based on
what the string is.

Truthiness is any string that starts with 'T', 'Y' or '1'.
Falsiness is any string that starts with 'F', 'N' or '0', or the empty string;

We return undef if the string does not match any of the above, or if it is undef.

=cut

sub string_to_boolean :Export(:string) {
    my $s = shift;

    return      unless defined $s;

    return 0 if $s eq ''
             || $s =~ m{\A[FN0]}i;

    return 1 if $s =~ m{\A[TY1]}i;

    return;
}

=head2 set_time_to_start_of_day

    $datetime_obj   = set_time_to_start_of_day( $datetime_obj );

This will take a DateTime object and set the Time part to be midnight or '00:00:00',
to use when you are just interested in the date part.

=cut

sub set_time_to_start_of_day :Export() {
    my $datetime    = shift;

    return      if ( !$datetime );

    croak "No DateTime Object passed to '" . __PACKAGE__ . "::set_time_to_midnight' function"
                                if ( ref( $datetime ) !~ /DateTime/ );

    my $clone   = $datetime->clone;
    $clone->set( hour => 0, minute => 0, second => 0, nanosecond => 0 );

    return $clone;
}

=head2 extract_pids_skus_from_text

    $hash_ref   = extract_pids_skus_from_text( $text_string );

Given a Text String which could contain PIDs and/or SKUs amongst other things such as an Email text
or a comma seperated list of PIDs. This will parse the text and get those PIDs and SKUs out of it.
It will return a Hash Ref containing those PIDs found and those that it thinks might have been
inteneded to be PIDs or SKUs but weren't:

returns:
    {
        clean_pids  => [
                {
                    pid     => Product Id
                    size_id => Size Id if found
                    sku     => SKU
                },
                ...
            ],
        errors  => [
                "Bit it couldn't parse that looked like a PID or SKU",
                ...
            ]
    }

=cut

sub extract_pids_skus_from_text :Export() {
    my $text    = shift // '';

    my @clean_pids;
    my @errors;

    foreach my $dirty_pid ( split( /[\n\s,]+/, $text ) ) {
        if ( $dirty_pid =~ m/^(?<pid>\d+)(-(?<size_id>\d+))?/g ) {

            my $pid     = $+{pid};
            my $size_id = $+{size_id} // '';
            my $sku     = ( $size_id ? "${pid}-${size_id}" : '' );      # only have a SKU if it looks sane
            $size_id    *= 1        if ( $size_id );

            if ( is_valid_database_id( $pid ) ) {
                push @clean_pids, {
                    pid     => $pid,
                    size_id => $size_id,
                    ( $sku ? ( sku => $sku ) : () ),        # only show SKU if there is one
                };
            }
            else {
                push @errors, $dirty_pid;
            }
        }
    }

    return {
            clean_pids  => \@clean_pids,
            errors      => \@errors,
        };
}

=head2 ucfirst_roman_characters( $text )

This takes a string of $text and returns the string with just the
first character in upper case, only if it contains just roman
characters and is either all upper all lower case. Otherwise $text
is returned unaltered.

    my $lower = ucfirst_roman_characters( 'lower' );
    # $lower = 'Lower'

    my $upper = ucfirst_roman_characters( 'UPPER' );
    # $upper = 'Upper'

    my $mixed = ucfirst_roman_characters( 'MiXeD' );
    # $roman = 'MiXeD'

    my $non_roman = ucfirst_roman_characters( '英国' );
    # $non_roman = '英国'

    my $non_roman = ucfirst_roman_characters( 'text英国' );
    # $non_roman = 'text英国'

=cut

sub ucfirst_roman_characters :Export(:string) {
    my ( $text ) = @_;

    return ''
        unless defined $text;

    if ( $text =~ /^[\x{20}-\x{2AF}]+$/ ) {
    # If the string only contains Roman characters, we might need to correct
    # the case. Roman characters are determined by the unicode code-point
    # range U+0020 to U+02AF.

        if ( $text eq uc( $text ) || $text eq lc( $text ) ) {
        # If the string is either ALL upper case or ALL lower case, we need
        # to correct the case. Because we assume that if the string contains
        # mixed case, the customer probably got it right.

            return ucfirst( lc( $text ) );

       }

    }

    # By default just return whatever was passed in.
    return $text;

}

=head2 was_sent_ajax_http_header

    $boolean = was_sent_ajax_http_header( $apache_object );

Will return TRUE or FALSE based on whether the 'X-Requested-With' header has
the value of 'XMLHttpRequest'.

=cut

sub was_sent_ajax_http_header :Export() {
    my $apache_obj  = shift;

    my $header  = $apache_obj->headers_in->get('X-Requested-With') // '';

    return ( lc( $header ) eq 'xmlhttprequest' ? 1 : 0 );
}

sub running_in_dave : Export() {
    my $in_dave = 0;

    my $live = config_var('RunningEnvironment','live');
    my $dave = config_var('RunningEnvironment','dave') // '';
    if ( ! defined $live && $dave =~ /\A(Y|y|1)\z/ ) {
        $in_dave = 1;
    }

    return $in_dave;
}

=head2 exists_and_defined

    do { something } if exists_and_defined( \%hash, @list_of_keys);

Takes a reference to a hash and a reference to a list of keys which must exist
in the hash and have a defined value.

=cut

sub exists_and_defined :Export() {
    my $hashref = shift;
    croak "You must pass a hashref" unless ( ref $hashref &&
                                             ref $hashref eq 'HASH' );

    foreach my $key ( @_ ) {
        croak "keys must be defined values" unless defined $key;
        croak "you cannot pass a reference as a key" if ref $key;
        return unless exists $hashref->{$key} && defined $hashref->{$key};
    }
    return 1;
}

=head2 apply_discount

    $discounted_value = apply_discount( $value, $discount_percentage );

Will apply a Discount to a Value and return it.

=cut

sub apply_discount :Export() {
    my ( $value, $discount ) = @_;

    return $value   if ( !$discount );

    croak "Invalid Discount: '${discount}', can't be greater than 100%"
                        if ( $discount > 100 );

    $value *= 1000;
    my $new_value = $value - ( ( $discount / 100 ) * $value );
    return ( $new_value / 1000 );
}

=head2 remove_discount

    $value = remove_discount( $discount_value, $discount_percentage );

Will remove a Discount from a Value and give back the Original Value.

=cut

sub remove_discount :Export() {
    my ( $value, $discount ) = @_;

    return $value       if ( !$discount );

    croak "Invalid Discount: '${discount}', it doesn't make sense to remove 100% or more"
                        if ( $discount >= 100 );

    $value *= 1000;
    my $new_value = $value / ( 1 - ( $discount / 100 ) );
    return ( $new_value / 1000 );
}

=head2 obscure_card_token

    $string = obscure_card_token( $card_token );

Given a Card Token that you can get from the PSP or Seaview
will obscure it by returning a string containing the first
2 characters and the last 4 characters and then the middle
will be replaced with a '*' for each character.

Use this for outputting the token to Log files.

Will return the string 'undef' if $card_token is undefined.

=cut

sub obscure_card_token :Export() {
    my $token = shift;

    return 'undef'      if ( !defined $token );

    if ( length( $token ) <= 6 ) {
        # the Token should be a lot more than 6 characters long
        # so if it's less than or equal to 6 return whatever it is
        return $token;
    }

    my $number_of_stars = length( $token ) - 6;

    my $first = substr( $token, 0, 2 );
    my $last  = substr( $token, -4 );

    return $first . ( '*' x $number_of_stars ) . $last;
}

=head2 find_in_AoH

    $result = find_in_AoH ( $source_aoh, $search_hash );

Find in Array of Hashes, searches for given hash in Array of Hashes.
If it find the hash containing all the key/value pairs of given hash
it returns the source hash else return 0.

eq: my $aoh= [
    { sku=>'123',qty => '2', price =>100},
    { sku=>'23',qty => '2', price => 200},
    { sku=>'323',qty => '2' price => 300},
 ];

    $record = find_in_Aoh( $aoh, { sku=>'123',price=> 100} )
would return  { sku=>'123',qty => '2', price =>100};

=cut

sub find_in_AoH :Export() {
    my $source    = shift; # Array of Hashes
    my $find_hash = shift; # Hashref

    croak "You must pass a arrayref" unless (
        ref $source &&
        ref $source eq 'ARRAY'
    );

    ITEM:
    foreach my $record ( @{$source} ) {
        my $return_value = find_in_hash($record, $find_hash );
        $return_value ? return $return_value : next ITEM;

    }

    #nothing to return
    return 0;
}


=head2 find_in_hash

    $result = find_in_hash ( $source_hash $search_hash );

Finds the given keys in the source hash. If it find all the keys/values
of search_hash it returns the given hash else returns 0

eg:
  my $return = find_in_hash(
    {sku=>'123', price=>100, quantity=>2,name =>'abc'},
    {sku=> '123', quantity=>2}
  );

Would return { sku=>'123', price=>100, quantity=>2,name =>'abc'}.

=cut

sub find_in_hash : Export() {
    my $source       =  shift;
    my $find_hash    = shift;

    croak "You must pass a HashRef" unless (
        ref $find_hash &&
        ref $find_hash eq 'HASH'
    );

    croak "You must pass a HashRef" unless (
        ref $source &&
        ref $source eq 'HASH'
    );


    my $count =  grep{ exists $source->{$_} && $find_hash->{$_} eq $source->{$_} } keys %{$find_hash};
    # return the record if found
    return $source if ($count == keys %{$find_hash});

    return 0;

}

=head2 hh_uri($uri, $is_on_handheld) : $uri

Transform the C<$uri> into a handheld URI (i.e. add C<view='HandHeld'> to it)
if required. Returns a L<URI> object.

=cut

sub hh_uri {
    my ($uri, $is_on_handheld) = @_;
    $uri = URI->new($uri);
    $uri->query_form($uri->query_form, view => 'HandHeld') if $is_on_handheld;
    return $uri;
}

1;
