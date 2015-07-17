package Test::XTracker::Utils;

use NAP::policy "tt", 'test';
use IO::File;
use JSON;
use Path::Class;
use Template;
use File::Temp qw/ tempfile /;

use Test::XTracker::Data;
use File::Copy;


sub find_json_in_dir {
    my($self,$dir_name,$filter) = @_;

    my $dir = Path::Class::Dir->new($dir_name);
#    my $path =  $dir->absolute;


    my @files = $dir->children;
    my @matches;
    foreach my $file (@files) {
        next if ($file->absolute !~ /\.json$/i);

        push @matches, $file;
    }

    return \@matches;
}

{
    my $json;
    sub slurp_json_file {
        my($self,$file) = @_;
        my $raw = $self->slurp_file($file);

        isnt($raw, undef, "Read any JSON data from file ($file)");

        $json ||= JSON->new;
        my $data;
        eval {
            $data = $json->decode($raw);
        };
        if (my $e = $@) {
            die $file ." - failed to parse test data - $e";
        }
        return $data;
    }

    sub write_json_file {
        my($self,$file,$data) = @_;

        my($fh,$filename) = tempfile();
        binmode($fh,":encoding(UTF-8)");
        note "  writting to: $filename";

        print $fh to_json($data, { utf8 => 1, pretty => 1 });

        $fh->close;

        note "  moving to: $file";
        isnt(move($filename,$file),0,
            "moved file $filename to $file");

    }
}

{
    my $tt;
    sub process_template {
        my($self,$file,$order_nr,$data) = @_;

        $tt ||= Template->new({ ABSOLUTE => 1 });

        my $outfile = Test::XTracker::Data->pending_orders_dir ."/${order_nr}.xml";

use Data::Dump qw/pp/;
    note pp($data);
        $tt->process(
            $file,
            { order => $data },
            $outfile,
        ) or die $tt->error;

        note "  wrote $outfile using $file template";

        return $outfile;
    }
}


sub make_order_xml {
    my($self,$data) = @_;
    my $order_nr = rand; # using rand to get a unique time
    my $file = $order_nr .".xml";

    note "TODO: need to replace dynamic stuff like order_nr";
    $data->{_o_id} = $order_nr;
    $data->{_order_data} ||= DateTime->now(time_zone => 'local')
        ->strftime('%Y-%m-%d %H:%m');


    return $self->process_template('t/data/orders.xml.tt', $order_nr, $data);
}

sub slurp_order_object_test {
    my($self,$file) = @_;
    my $data = $self->slurp_json_file($file);

    # there should be two keys in json one data, one result
    my $order = delete $data->{order};
    my $expected = delete $data->{expected};

    return($order,$expected);
}

sub slurp_file {
    my($self,$file) = @_;

    return undef if ($file->isa('Path::Class::Dir'));
    return undef if ($file->basename =~ /^\./);

    my $fh = IO::File->new;
    if ($fh->open("< ". $file->absolute)) {
        my $out = undef;

        while (my $line = <$fh>) {
            $out .= $line;
        }
        return $out;
    }
    return undef;
}

sub match_moose_error {
    my($self,$str,$msg) = @_;

    return 1 if ($msg =~ /${str}/);
    return undef;
}

1;
