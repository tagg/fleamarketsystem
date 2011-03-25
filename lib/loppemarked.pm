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
  template 'data', { data => 'Hello get' };
};

post '/afhentning' => sub {
  template 'data', { data => 'Hello post' };
};


get '/hjaelper' => sub {
  my $dbh = DBI->connect("dbi:SQLite:dbname=$FindBin::Bin/../data/$databasename","","");
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
  my $dbh = DBI->connect("dbi:SQLite:dbname=$FindBin::Bin/../data/$databasename","","");
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

   

#   INSERTING DATA IF GOOD
#    $dbh->do("INSERT INTO user (firstname,lastname,branch_id) 
#              VALUES (?, ?, ?)",
#              undef,params->{firstname},params->{lastname},params->{branch_id});

    my ($user_id) = $dbh->selectrow_array("SELECT user_id 
                                           FROM user 
                                           WHERE firstname = ? and lastname = ? and branch_id = ?;"
                                           ,undef,params->{firstname},params->{lastname},params->{branch_id});
    if (defined params->{cake}) {
#      $dbh->do("INSERT INTO cake (user_id) 
#                VALUES (?)",
#                undef,$user_id);
    }
  
    if (defined params->{team1check}) {
      my ($period_id,$adults,$scouts,$car,$trailer,$pull);
      $period_id = 1;
      $adults = params->{adults};
      $scouts = params->{scouts};
      $car = 1 if defined params->{car};
      $trailer = 1 if defined params->{trailer};
      $pull = 1 if defined params->{pull};
  
#      $dbh->do("INSERT INTO team (user_id,period_id,adults,scouts,car,trailer,pull)
#                VALUES (?, ?, ?, ?, ?, ?, ?);",undef,$user_id,$period_id,$adults,$scouts,$car,$trailer,$pull);
    }
  }
   
# REPLYING TO SUBMITTER

  template 'hjaelper', $content;
};

get '/data' => sub {
  my $dbh = DBI->connect("dbi:SQLite:dbname=$FindBin::Bin/../data/$databasename","","");
  my $data = '';

  my ($periods) = $dbh->selectrow_array("SELECT count(*) FROM period");

  for (my $i = 1; $i <= $periods; $i++) {
    data(\$data,"<br>Periode $i<br>");
    my @result_array = @{$dbh->selectall_arrayref("SELECT user.firstname,user.lastname,adults,scouts,car,trailer,pull FROM user INNER JOIN team ON user.user_id=team.user_id WHERE period_id = $i")};
    foreach my $result (@result_array) {
      my @array = @{$result};
      data(\$data,$array[0]." ".$array[1]." kommer ".$array[2]." voksne og ".$array[3]." spejdere. ");
      data(\$data,"Han har bil. ") if $array[4];
      data(\$data,"Han har trailer. ") if $array[5];
      data(\$data,"Han har bil med traek. ") if $array[6];
      data(\$data,"<br>");
    }
  }
  
  data(\$data,"<br><br>");

  my @brings_cake = @{$dbh->selectcol_arrayref("SELECT user.firstname FROM user INNER JOIN cake ON user.user_id=cake.user_id")};
  foreach my $person (@brings_cake) {
    data(\$data,$person." kommer med kage.<br>");
  }

  data(\$data,"<br><br>");

  template 'data', {data => $data};
};

any qr{.*} => sub {
  status 'not_found';
  template 'special_404', { path => request->path };
};


sub data {
  my ($string,$add) = @_;
  $$string = $$string.$add; 
  return;
}

1;
