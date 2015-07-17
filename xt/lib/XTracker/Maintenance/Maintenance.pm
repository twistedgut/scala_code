package XTracker::Maintenance::Maintenance;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Handler;

use XTracker::DBEncode  qw( encode_it );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $param_of    = $handler->_get_params;
    my $html_out;
    my $fields      = "";
    my $uri         = $handler->path;

    foreach ( sort keys %$param_of ) {

        next        if ( $_ eq "xxxbuttonxxx" );

        if ( ref($param_of->{$_}) eq "ARRAY" ) {
            foreach my $value ( @{ $param_of->{$_} } ) {
                $fields .= '<input type="hidden" name="'.$_.'" value="'.$value.'" />';
            }
        }
        else {
            $fields .= '<input type="hidden" name="'.$_.'" value="'.$param_of->{$_}.'" />';
        }
        $fields .= "\n";
    }

    if ( $fields eq "" ) {
        $fields = '<input type="hidden" name="xnamex" value="1" />';
    }

    $html_out   =<<HTML
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
    <head>
        <title>xTracker Maintenance Mode</title>
        <style type="text/css">
            * {
                font-family: Arial, Avenir, "Lucida Grande", Verdana, "Bitstream Vera Sans", Helvetica, sans-serif;
                font-size: 12px;
            }
            FORM { margin: 0px !important; padding: 0px !important; }

            H1 {
                margin: 0 10px 0 0;
                display: inline;
                padding: 0;
                background: transparent;
                color: #777;
                text-transform: none;
                font-family: Arial, Avenir, "Lucida Grande", Verdana, "Bitstream Vera Sans", Helvetica, sans-serif;
                font-weight: bold;
                font-size: 1.4em;
            }

            #mt_outer {
                width: 100%;
                text-align: center;
                padding-top: 20px;
            }
            #mt_inner {
                width: 210px;
                margin-left: auto;
                margin-right: auto;
                text-align: left;
            }

            #mt_top {
                position: relative;
                margin-bottom: 10px;
                border-bottom: 1px dotted #666;
            }
            #mt_top P {
                padding: 0px 0px 0px 50px;
                margin: 0px;
                font-family: Arial;
                font-size: 10px;
                font-weight: bold;
                color: #999999;
            }

            #mt_middle {
                position: relative;
            }
            #mt_middle P {
                margin: 0px;
                padding: 10px 0px;
            }
            #mt_middle BR { height: 10px; line-height: 10px; }
            #mt_middle FORM {
                border-top: 1px dotted #666;
                border-bottom: 1px dotted #666;
                padding: 5px 0px !important;
                text-align: center;
                background-color: #dddddd;
            }

            #mt_footer {
                position: relative;
                margin-top: 10px;
                border-top: 12px solid #494949;
            }
        </style>
    </head>
    <body>
        <div id="mt_outer">
            <div id="mt_inner">
                <div id="mt_top">
                    <img src="/images/logo_small.gif" border="0" width="170" height="25" alt="xTracker" title="xTracker" />
                    <p>DISTRIBUTION</p>
                </div>
                <div id="mt_middle">
                    <h1>Site in Maintenance</h1>
                    <p>
                        <strong>xTracker</strong> is currently suspended due to essential maintenance work being performed. This work should be concluded shortly and you shall be-able to continue with your work soon.
                        <br/><br/>
                        Please be <strong>patient</strong> and after a short time click on the 'Retry' button below to continue, if you still see this page then please wait a little longer before trying again.
                    </p>
                    <form name="f_form" action="$uri" method="post">
                        $fields
                        <input class="button" type="submit" name="xxxbuttonxxx" value="Retry &raquo;" />
                    </form>
                </div>
                <div id="mt_footer">
                    &nbsp;
                </div>
            </div>
        </div>
    </body>
</html>
HTML
;

    $handler->{request}->content_type( 'text/html' );
    $handler->{request}->print( encode_it($html_out) );

    return OK;
}

1;
