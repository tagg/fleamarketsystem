#!/usr/bin/env perl

package loppemarked;

use autodie;
use Modern::Perl;
use Dancer ':syntax';
use DBI;
use FindBin;
use Data::Dumper;
use String::CamelCase;

our $VERSION = '0.1';

my $databasename = 'loppe.db';


get '/' => sub {
    template 'index';
};

get '/afhentning' => sub {
  template 'clean', { data => 'Hello get' };
};

post '/afhentning' => sub {
  template 'clean', { data => 'Hello post' };
};


get '/hjaelper' => sub {
  my $dbargs = {AutoCommit => 0,
                PrintError => 1};

  my $dbh = DBI->connect("dbi:SQLite:dbname=$FindBin::Bin/../data/$databasename","","",$dbargs);
  my $message;
  
  my $branches = $dbh->selectall_arrayref("SELECT branch_id,name 
                                           FROM branch;",
                                         );
  my $periods = $dbh->selectall_arrayref("SELECT period_id,name,cars 
                                           FROM period;",
                                         );

  template 'hjaelper', {branches => $branches, periods => $periods, message => $message};
};

post '/hjaelper' => sub {
  my $dbargs = {AutoCommit => 0,
                PrintError => 1};

  my $dbh = DBI->connect("dbi:SQLite:dbname=$FindBin::Bin/../data/$databasename","","",$dbargs);
  my $content;

  my ($firstname, $lastname, $branch, $cake) = (params->{firstname},params->{lastname},params->{branch_id},params->{cake});

  my $branches = $dbh->selectall_arrayref("SELECT branch_id,name 
                                           FROM branch;",
                                         );
  my $periods = $dbh->selectall_arrayref("SELECT period_id,name,cars 
                                           FROM period;",
                                         );
  $content->{branches} = $branches;
  $content->{periods} = $periods;
# CHECK IF INPUT IS GOOD

  my $error = 0;

  if ($firstname eq '' || $lastname eq '') {
    $content->{firstnameerror} = "Skriv venligst dit fornavn." if ($firstname eq '');
    $content->{lastnameerror} = "Skriv venligst dit efternavn." if ($lastname eq '');
    $error = 1;
  }

  my $branch_selected = 0;
  foreach my $period (@{$periods}) {
    my $period_id = @{$period}[0];
    if (exists params->{'team'.$period_id.'check'}) {
      if ((params->{$period_id.'adults'} eq '' || params->{$period_id.'adults'} eq '0') && 
          (params->{$period_id.'scouts'} eq '' || params->{$period_id.'scouts'} eq '0')) {
        push @{$period}, 'Hvis ingen deltager, så fjern fluebenet.';
        $error = 1;
      } else {
        push @{$period}, '';
      }
      push @{$period}, params->{'team'.$period_id.'check'};
      push @{$period}, params->{$period_id.'adults'};
      push @{$period}, params->{$period_id.'scouts'};
      push @{$period}, params->{$period_id.'car'};
      push @{$period}, params->{$period_id.'trailer'};
      push @{$period}, params->{$period_id.'pull'};
      $branch_selected = 1;
    }
  }

  if ($error || !$branch_selected) {
    if ($branch_selected) {
      $content->{error} = 'Der er fejl i tilmeldingen.';
    } else {
      $content->{error} = 'Du burde nok v&aelig;lge en periode at deltage i, ellers behøver du ikke tilmelde dig.';
    }
    $content->{firstname} = params->{firstname};
    $content->{lastname} = params->{lastname};
    $content->{branch_id} = params->{branch_id};
    $content->{cake} = params->{cake};

  } else {
    $content->{message} = "Tilmeldingen er modtaget.";

    
    my ($user_id) = $dbh->selectrow_array("SELECT max(user_id)+1
                                           FROM user;");

#   INSERTING DATA IF GOOD
    $dbh->do("INSERT INTO user (user_id,firstname,lastname,branch_id) 
              VALUES (?, ?, ?, ?)",
              undef,$user_id,params->{firstname},params->{lastname},params->{branch_id});

    if (defined params->{cake}) {
      $dbh->do("INSERT INTO cake (user_id) 
                VALUES (?)",
                undef,$user_id);
    }
  
    foreach my $period (@{$periods}) {
      my $period_id = @{$period}[0];
      if (defined params->{'team'.$period_id.'check'}) {
        my ($adults,$scouts,$car,$trailer,$pull) = (0,0,0,0,0);
        $adults = params->{$period_id.'adults'} if (params->{$period_id.'adults'} ne '');
        $scouts = params->{$period_id.'scouts'} if (params->{$period_id.'scouts'} ne '');
        $car = 1 if defined params->{$period_id.'car'};
        $trailer = 1 if defined params->{$period_id.'trailer'};
        $pull = 1 if defined params->{$period_id.'pull'};
  
        $dbh->do("INSERT INTO team (user_id,period_id,adults,scouts,car,trailer,pull)
                  VALUES (?, ?, ?, ?, ?, ?, ?);",
                  undef,$user_id,$period_id,$adults,$scouts,$car,$trailer,$pull);
        pop @{$period} foreach (1..7);
      }
    }
    $dbh->commit;
  }
   
# REPLYING TO SUBMITTER
  template 'hjaelper', $content;
};

get '/data' => sub {
  my $dbh = DBI->connect("dbi:SQLite:dbname=$FindBin::Bin/../data/$databasename","","");
  my $data;
  my $cake;

  my $periods = $dbh->selectall_arrayref("SELECT period_id,name,cars 
                                          FROM period");

  foreach my $period (@{$periods}) {
    my $period_id = @{$period}[0];
    my %period_data;
    $period_data{period_id} = $period_id;
    $period_data{name} = @{$period}[1];
    $period_data{cars} = @{$period}[2];
    $period_data{result} = {adults => 0, scouts => 0, car => 0, trailer => 0, pull => 0};
    my @result_array = @{$dbh->selectall_arrayref("SELECT user.firstname||' '||user.lastname,adults,scouts,car,trailer,pull 
                                                   FROM user 
                                                     INNER JOIN team 
                                                     ON user.user_id=team.user_id 
                                                   WHERE period_id = ?",
                                                   undef, $period_id)};
    foreach my $result (@result_array) {
      my @array = @{$result};
      push @{$period_data{data}}, {name    => $array[0], 
                                   adults  => $array[1], 
                                   scouts  => $array[2], 
                                   car     => $array[3], 
                                   trailer => $array[4], 
                                   pull    => $array[5],
                                  };
      $period_data{result}{adults}  += $array[1];
      $period_data{result}{scouts}  += $array[2];
      $period_data{result}{car}     += $array[3];
      $period_data{result}{trailer} += $array[4];
      $period_data{result}{pull}    += $array[5];

    }
    push @{$data}, \%period_data;
  }
  
  $cake->{amount} = 0;
  my @brings_cake = @{$dbh->selectcol_arrayref("SELECT user.firstname||' '||user.lastname 
                                                FROM user 
                                                  INNER JOIN cake 
                                                  ON user.user_id=cake.user_id"
                                              )};
  foreach my $person (@brings_cake) {
    push @{$cake->{names}},$person;
    $cake->{amount}++;
  }

  #template 'data', {data => Dumper($data), cake => $cake};
  template 'data', {data => $data, cake => $cake};
};

any qr{.*} => sub {
  status 'not_found';
  template 'special_404', { path => request->path };
};

1;
