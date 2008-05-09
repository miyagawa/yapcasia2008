#!/usr/bin/perl
use strict;
use warnings;
use Encode;
use Text::CSV_XS;

my @payments = read_csv('payments.csv');
my @users    = read_csv('export.csv');
my @talks    = read_csv('exported_talks.csv');

my %payments = map { $_->{user_id} => $_ } @payments;
my %talks    = map { $_->{user_id} => 1 } grep $_->{accepted}, @talks;

# schwertzian transform
my $i;
my @sorted = map {
    $_->[6]->{party} = ++$i < 300 ? '1' : '0';
    $_->[6];
} sort {
    $b->[0] cmp $a->[0] || # is staff?
    $b->[1] cmp $a->[1] || # is speaker?
    $b->[2] cmp $a->[2] || # has paid?
    $b->[3] cmp $a->[3] || # from abroad?
    $b->[4] cmp $a->[4] || # from outside Tokyo?
    $a->[5] cmp $b->[5]    # paid earlier?
} map {
    $_->{has_accepted_talk} = exists $talks{$_->{user_id}};
    $_->{paid_date}         = $payments{$_->{user_id}}->{datetime} || "9999-99-99 99:99:99";
    $_->{not_tokyo}         = $_->{town} && !is_tokyo($_->{town});
    $_->{payment_means}     = $payments{$_->{user_id}}->{means} || 'UNPAID';
    $_->{has_really_paid}   = $_->{has_paid} && $_->{payment_means} eq 'ONLINE';
    [ $_->{is_staff} || $_->{is_orga},
      $_->{has_accepted_talk},
      $_->{has_really_paid},
      $_->{country} ne 'jp',
      $_->{not_tokyo},
      $_->{paid_date},
      $_ ];
} @users;

my $csv = Text::CSV_XS->new({ binary => 1 });

my @cols = qw( user_id first_name last_name is_staff has_accepted_talk country town not_tokyo payment_means paid_date party );

$csv->combine(@cols);
print $csv->string, "\n";
for my $u (sort { $a->{user_id} <=> $b->{user_id} } @sorted) {
    $csv->combine(@$u{@cols});
    print $csv->string, "\n";
}

sub is_tokyo {
    my $town = decode_utf8 shift;
    $town =~ /tokyo|\x{6771}\x{4eac}|Hongo|chiyoda|shibuya|shinagawa/i;
}

sub read_csv {
    open my $fh, "<", shift or die $!;

    my $csv = Text::CSV_XS->new({ binary => 1 });
    my $header = $csv->getline($fh);
    $csv->column_names(@$header);

    my @list;
    while (!$csv->eof) {
        my $ref = $csv->getline_hr($fh);
        next unless $ref->{user_id};
        push @list, $ref;
    }

    return @list;
}
