package FleaMarket::Model;

use strict;
use warnings;
use utf8;

use base 'Exporter';
our @EXPORT = qw(getBranches getPeriods addHelper getHelpers);

use DBI;
use Data::Dumper;
use POSIX;

use Mojo::Base qw(Mojolicious);
use Mojo::Log;

my $app = new Mojolicious;
my $log = Mojo::Log->new;
my $dbh = _connect();

sub getHelpers {
    my $helperdata = [];
   
    my @periods = getPeriods();
    

    foreach my $period (@{getPeriods()}) {
        my $id = $period->{id};
        my $result->{period} = $period;
        $result->{data} = $dbh->selectall_arrayref("
            SELECT user.user_id as id, CONCAT(firstname, ' ', lastname) as name, adults, scouts, car, trailer, pull 
            FROM user 
                INNER JOIN team 
                    ON user.user_id = team.user_id 
            WHERE period_id = ?
	", { Slice => {} }, $id);

        $result->{totals} = {adults => 0, scouts => 0, car => 0, trailer => 0, pull => 0};
        foreach my $team (@{$result->{data}}) {
            $result->{totals}{adults} += $team->{adults};
            $result->{totals}{scouts} += $team->{scouts};
            $result->{totals}{car} += $team->{car};
            $result->{totals}{trailer} += $team->{trailer};
            $result->{totals}{pull} += $team->{pull};
	}
	

        push @{$helperdata}, $result;
    }

    return $helperdata;
}

sub addHelper {
    my $userdata = shift;

## sync

    my $user_id = _getNextUserId();

    $dbh->do("
        INSERT INTO user (user_id, firstname, lastname, branch_id) 
	VALUES (?, ?, ?, ?)
    ;", undef, $user_id, $userdata->{firstname}, $userdata->{lastname}, $userdata->{branch_id})
        or return $dbh->errstr;

## sync

    if ($userdata->{cake}) {
        $dbh->do("
            INSERT INTO cake (user_id)
            VALUES (?)
        ;", undef, $user_id)
            or return $dbh->errstr;
    }

    foreach my $period (@{$userdata->{periods}}) {
        next unless defined $period;
        $dbh->do("
            INSERT INTO team (user_id, period_id, adults, scouts, car, trailer, pull) 
	    VALUES (?, ?, ?, ?, ?, ?, ?)
        ;", undef, $user_id, $period->{id}, $period->{adults}, $period->{scouts}, $period->{car}, $period->{trailer}, $period->{pull})
            or return $dbh->errstr;
    }

    return undef;
}

sub getBranches {
    my $branches = $dbh->selectall_arrayref("
        SELECT branch_id as id, name   
	FROM branch
    ;",{ Slice => {} });

    return $branches;
}

sub getPeriods {
    my $periods = $dbh->selectall_arrayref("
        SELECT period_id as id, name, cars, pickup
        FROM period
    ;",{ Slice => {} });

    return $periods;
}

sub _getNextUserId {
    my ($user_id) = $dbh->selectrow_array("
        SELECT max(user_id)+1 
        FROM user
    ;"); 

    $user_id = 1 if !defined $user_id;
    return $user_id;
}

sub _connect {
    my $dbh = DBI->connect('DBI:mysql:fleamarket', 'root', '') || die "Could not connect to database: $DBI::errstr";
    $dbh->{'mysql_enable_utf8'} = 1;
    $dbh->{'mysql_auto_reconnect'} = 1;
    return $dbh;
}

1;
