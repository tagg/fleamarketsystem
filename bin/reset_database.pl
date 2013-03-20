#!/usr/bin/env perl

use autodie;
use Modern::Perl;

use FindBin;
use lib "$FindBin::Bin/../lib";

use DBI;

my $databasename = 'loppe.db';
my $testdata = 1;

if (-e ("$FindBin::Bin/../data/$databasename")) {
  unlink("$FindBin::Bin/../data/$databasename");
  say "Deleted old database.";
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$FindBin::Bin/../data/$databasename","","");
say "Created SQLite database.";

$dbh->do("CREATE TABLE branch(
            branch_id INTEGER,
            name TEXT,
            PRIMARY KEY (branch_id)
          );");

$dbh->do("CREATE TABLE user(
            user_id INTEGER,
            firstname TEXT NOT NULL,
            lastname TEXT NOT NULL,
            branch_id INTEGER,
            PRIMARY KEY (user_id)
            FOREIGN KEY(branch_id) REFERENCES branch(branch_id)
          );");

$dbh->do("CREATE TABLE cake(
            user_id INTEGER,
            PRIMARY KEY (user_id)
            FOREIGN KEY(user_id) REFERENCES user(user_id)
          );");

$dbh->do("CREATE TABLE period(
            period_id INTEGER,
            name TEXT NOT NULL,
            cars BOOLEAN DEFAULT 0,
            pickup BOOLEAN DEFAULT 0,
            PRIMARY KEY (period_id)
          );");

$dbh->do("CREATE TABLE team(
            user_id INTEGER,
            period_id INTEGER,
            adults INTEGER DEFAULT 0,
            scouts INTEGER DEFAULT 0,
            car BOOLEAN DEFAULT 0,
            trailer BOOLEAN DEFAULT 0,
            pull BOOLEAN DEFAULT 0,
            PRIMARY KEY (user_id,period_id),
            FOREIGN KEY(user_id) REFERENCES user(user_id),
            FOREIGN KEY(period_id) REFERENCES period(period_id)
          );");

$dbh->do("CREATE TABLE pickup(
            pickup_id INTEGER,
            createdate TEXT DEFAULT (datetime('now','localtime')), 
            name TEXT,
            phonenumber TEXT,
            road TEXT,
            postalcode TEXT,
            city TEXT,
            description TEXT,
            pickedup BOOLEAN DEFAULT 0,
            PRIMARY KEY (pickup_id)
          );");

$dbh->do("CREATE TABLE pickup_period(
            pickup_id INTEGER,
            period_id INTEGER,
            PRIMARY KEY (pickup_id,period_id),
            FOREIGN KEY (pickup_id) REFERENCES pickup(pickup_id),
            FOREIGN KEY (period_id) REFERENCES period(period_id)
          );");


say "Created tables.";

# INSERTING INTO STATIC DATATABLES
my @branches = qw(Ingen Mikro Mini Junior Trop Klan Leder);

foreach my $branch (@branches) {
  $dbh->do("INSERT INTO branch (name) VALUES ('$branch')");
}

my @periods = ('Indsamling 6. april 13.00 til 17.30',
               'Indsamling 7. april 10.00 til 16.00',
               'Morgenholdet Loppemarkedsdagen 13. april 7.00 til 10.00',
               'Salgsholdet Loppemarkedsdagen 13. april 10.00 til 15.00',
               'Oprydningsholdet Loppemarkedsdagen 13. april 15.00 til 18.00'
              );

foreach my $periodnumber (0..(scalar(@periods)-1)) {
  my ($cars,$pickup) = (1,1);
  $cars = 0 if ($periodnumber == 2 || $periodnumber == 3);
  $pickup = 0 if ($periodnumber > 1);
  $dbh->do("INSERT INTO period (name,cars,pickup) 
            VALUES (?, ?, ?)", 
            undef, $periods[$periodnumber], $cars, $pickup
          );
}

say "Inserted into static datatables.";

# INSERTING TESTDATA IF $TESTDATA
exit(0) unless $testdata;

my @firstnames = qw( Tom Per Hans Nina Lone Kim Ole Jens Line Frede );
my @lastnames = qw( Hansen Jensen Persson Larsen Nielsen Ingersen Petersen );
my $users = scalar(@firstnames);

foreach my $firstname (@firstnames) {
  my $branch = int(rand(scalar(@branches))+1);
  my $lastname = $lastnames[int(rand(scalar(@lastnames)))];
  $dbh->do("INSERT INTO user (firstname, lastname, branch_id) VALUES (?, ?, ?);",undef,$firstname,$lastname,$branch);
}

my @cache = ();
for (my $i = 0; $i < int($users/3); $i++) {
  my $user_id = int(rand($users)+1);
  while (grep {$_ eq $user_id} @cache) {
    $user_id = int(rand($users)+1);
  }
  $dbh->do("INSERT INTO cake (user_id) values ($user_id);");
  push @cache, $user_id;
}


for (my $i = 1; $i <= $users; $i++) {
  my $period1 = int(rand(scalar(@periods)))+1;
  $dbh->do("INSERT INTO team (user_id,period_id,adults,scouts,car,trailer,pull)
            VALUES ($i,$period1,".int(rand(3)).",".int(rand(3)+1).",".int(rand(2)).",".int(rand(2)).",".int(rand(2)).");"
          );
  my $period2 = int(rand(scalar(@periods)))+1;
  while ($period2 == $period1) {
    $period2 = int(rand(scalar(@periods)))+1;
  }
  $dbh->do("INSERT INTO team (user_id,period_id,adults,scouts,car,trailer,pull)
            VALUES ($i,$period2,".int(rand(3)).",".int(rand(3)+1).",".int(rand(2)).",".int(rand(2)).",".int(rand(2)).");"
          );
}

my @phonenumbers = qw(12345678 87653672 12315234 27312387 21367329);
my @roads = qw(gammelmosevej hanehøj jordbærvænget hjaltesvej sæbjørnsvej buddingehovedgade jernbanevej);
my @postalcodes = qw(2880 2860 2900 9000);
my @cities = qw(bagsværd lyngby søborg andeby hareskov);
my @items = qw(skab lampe seng sofa bord sofabord flasker fjernsyn hylder billeder toej lamper doer taske);

my @period_ids = @{ $dbh->selectcol_arrayref("SELECT period_id FROM period WHERE pickup = 1") };

for (my $i = 0; $i < 50; $i++) {
  my ($pickup_id) = $dbh->selectrow_array("SELECT max(pickup_id)+1
                                           FROM pickup;");
  $pickup_id = 1 if !defined $pickup_id;

  my $name = $firstnames[int(rand(scalar(@firstnames)))];
  my $phonenumber = $phonenumbers[int(rand(scalar(@phonenumbers)))];
  my $road = $roads[int(rand(scalar(@roads)))];
  my $postalcode = $postalcodes[int(rand(scalar(@postalcodes)))];
  my $city = $cities[int(rand(scalar(@cities)))];
  my $item = $items[int(rand(scalar(@items)))];
  $dbh->do("INSERT INTO pickup (pickup_id, name, phonenumber, road, postalcode, city, description)
            VALUES (?, ?, ?, ?, ?, ?, ?);",
            undef,$pickup_id,$name,$phonenumber,$road,$postalcode,$city,$item
          );

  foreach my $period_id (@period_ids) {
    if (int(rand(2))) {
      $dbh->do("INSERT INTO pickup_period (pickup_id,period_id)
                VALUES (?, ?)",
                undef,$pickup_id,$period_id
              );
    }
  }
  
}

say "Inserted testdata.";
exit(0);
