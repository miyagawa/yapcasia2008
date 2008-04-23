#!/usr/bin/perl
use strict;
use warnings;
use Encode;
use SVG;
use SVG::Parser;
use Text::CSV_XS;
use Locale::Country;

Locale::Country::rename_country('tw' => 'Taiwan');

my $base_file = "namecard_2x5.svg";
my $csv_file  = shift || "sample.csv";

open my $fh, $csv_file or die $!;

my $csv = Text::CSV_XS->new({ binary => 1 });
my $header = $csv->getline($fh);
$csv->column_names(@$header);

my $out_dir = "$ENV{HOME}/Sites/yapc-nameplates";

my $font = '&quot;M+ 1c&quot;';

my @users;
while (!$csv->eof) {
    my $ref = $csv->getline_hr($fh);
    next unless $ref->{user_id};
    warn $ref->{user_id};
    push @users, $ref;
}

while (my @chunk = splice(@users, 0, 10)) {
    my $first_id = $chunk[0]->{user_id};
    my $ox = 0;
    my $oy = 0;

    my $parser = SVG::Parser->new;
    my $svg = $parser->parse_file($base_file);

    for my $ref (@chunk) {
        $svg->text(x => $ox + 50, y => $oy + 60, style => { 'font-family' => $font, 'font-weight' => 'bold', 'color' => 'black', 'font-size' => 24 })->cdata(get_name($ref));
        $svg->text(x => $ox + 50, y => $oy + 80, style => { 'font-family' => $font, 'color' => 'black', 'font-size' => 12 })->cdata(($ref->{pm_group} ? "$ref->{pm_group} / " : "") . code2country($ref->{country}));

        my $role = $ref->{has_talk} ? 'SPEAKER' :
            ($ref->{is_orga} || $ref->{is_staff}) ? 'STAFF' : '';

        if ($role) {
            $svg->text(x => $ox + 50, y => $oy + 120, style => { 'font-family' => $font, 'font-weight' => 'bold', color => 'black', 'font-size' => 16 })->cdata($role);
        }

        $ox = $ox == 0 ? 296 : 0;
        $oy+= 168 if $ox == 0;
    }

    my $outfile = "$out_dir/$first_id.svg";
    open my $out, ">:utf8", $outfile or die "$outfile: $!";
    print $out $svg->xmlify;
}

sub get_name {
    my $ref = shift;

    ## xxx nickname
    if (is_cjk($ref)) {
        return decode_utf8( $ref->{last_name} . $ref->{first_name} );
    } else {
        return decode_utf8( join " ", $ref->{first_name}, $ref->{last_name} );
    }
}

sub is_cjk {
    my $ref = shift;
    my $name = decode_utf8($ref->{first_name} . $ref->{last_name});
    $name =~ /\p{Han}/;
}
