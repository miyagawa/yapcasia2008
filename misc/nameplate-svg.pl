#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
use SVG;
use SVG::Parser;
use Text::CSV_XS;
use Locale::Country;

Locale::Country::rename_country('tw' => 'Taiwan');
Locale::Country::rename_country('kr' => 'Korea');

my $base_file = "namecard_2x5.svg";
my $csv_file  = shift @ARGV || "sample.csv";

open my $fh, $csv_file or die $!;

my $csv = Text::CSV_XS->new({ binary => 1 });
my $header = $csv->getline($fh);
$csv->column_names(@$header);

my $out_dir = "$ENV{HOME}/Sites/yapc-nameplates";

#my $font = '&quot;M+ 1c&quot;';
my $font = 'mplus-1c-medium';

my @users;
while (!$csv->eof) {
    my $ref = $csv->getline_hr($fh);
    next unless $ref->{user_id};
    push @users, $ref;
}

while (my @chunk = splice(@users, 0, 10)) {
    my $first_id = $chunk[0]->{user_id};
    my $ox = 0;
    my $oy = 0;

    my $parser = SVG::Parser->new;
    my $svg = $parser->parse_file($base_file);

    for my $ref (@chunk) {
        my $name = get_name($ref);
        my $size = length($name) > 20 ? 18 
                 : length($name) > 16 ? 21 
                 : 24;
        $svg->text(x => $ox + 35, y => $oy + 55, style => { 'font-family' => $font, 'font-weight' => 'bold', 'color' => 'black', 'font-size' => $size }, 'font-family' => $font, 'font-size' => $size)->cdata($name);
        $svg->text(x => $ox + 35, y => $oy + 75, style => { 'font-family' => $font, 'color' => 'black', 'font-size' => 11 }, 'font-family' => $font, 'font-size' => 11)->cdata(($ref->{pm_group} ? "$ref->{pm_group} / " : "") . code2country($ref->{country}));
        if ($ref->{company}) {
            $svg->text(x => $ox + 35, y => $oy + 90, style => { 'font-family' => $font, color => 'black', 'font-size' => 11 }, 'font-family' => $font, 'font-size' => 11)->cdata( decode_utf8($ref->{company}) );
        }

        my $role = ($ref->{is_orga} || $ref->{is_staff}) ? 'STAFF' : 
            $ref->{has_talk} ? 'SPEAKER' :'';

        if ($role) {
            $svg->text(x => $ox + 35, y => $oy + 126, style => { 'font-family' => $font, 'font-weight' => 'bold', color => 'black', 'font-size' => 16 }, 'font-family' => $font, 'font-size' => 16)->cdata($role);
        }

        $svg->text(x => $ox + 266, y => $oy + 16, style => { 'font-family' => $font, color => 'black', 'font-size' => 8 }, 'font-family' => $font, 'font-size' => 8)->cdata($ref->{user_id});

        $ox = $ox == 0 ? 296 : 0;
        $oy+= 168 if $ox == 0;
    }

    my $outfile = "$out_dir/$first_id.svg";
    open my $out, ">:utf8", $outfile or die "$outfile: $!";
    print $out $svg->xmlify;
    warn $outfile, "\n";
}

sub get_name {
    my $ref = shift;

    if ($ref->{pseudonymous}) {
        return decode_utf8( $ref->{nick_name} );
    }

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
