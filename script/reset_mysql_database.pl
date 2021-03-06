#!/usr/bin/env perl

use autodie;
use Modern::Perl;

use FindBin;
use lib "$FindBin::Bin/../lib";

use DBI;
use DBD::mysql;

my $testdata = 1;


my $dbh = DBI->connect("dbi:mysql:fleamarket:localhost:3306","root","");
say "Connected to database.";

$dbh->do("DROP TABLE pickup_period");
$dbh->do("DROP TABLE pickup");
$dbh->do("DROP TABLE team");
$dbh->do("DROP TABLE period");
$dbh->do("DROP TABLE cake");
$dbh->do("DROP TABLE user");
$dbh->do("DROP TABLE branch");

$dbh->do("CREATE TABLE branch(
            branch_id INT(5) NOT NULL AUTO_INCREMENT,
            name TEXT NOT NULL,
            PRIMARY KEY (branch_id)
          );");

$dbh->do("CREATE TABLE user(
            user_id INT(32) NOT NULL AUTO_INCREMENT,
            firstname TEXT NOT NULL,
            lastname TEXT NOT NULL,
            branch_id INTEGER NOT NULL,
            PRIMARY KEY (user_id),
	    INDEX (branch_id),
            CONSTRAINT FOREIGN KEY(branch_id) REFERENCES branch(branch_id)
          );");

$dbh->do("CREATE TABLE cake(
            user_id INTEGER NOT NULL,
            PRIMARY KEY (user_id),
	    INDEX (user_id),
            CONSTRAINT FOREIGN KEY(user_id) REFERENCES user(user_id)
          );");

$dbh->do("CREATE TABLE period(
            period_id INT(5) NOT NULL AUTO_INCREMENT,
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
	    INDEX (user_id,period_id),
            CONSTRAINT FOREIGN KEY(user_id) REFERENCES user(user_id),
            CONSTRAINT FOREIGN KEY(period_id) REFERENCES period(period_id)
          );");

$dbh->do("CREATE TABLE pickup(
            pickup_id INT(32) NOT NULL AUTO_INCREMENT,
            createdate TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
            name TEXT,
            phonenumber TEXT,
            email TEXT,
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
	    INDEX (pickup_id, period_id),
            CONSTRAINT FOREIGN KEY (pickup_id) REFERENCES pickup(pickup_id),
            CONSTRAINT FOREIGN KEY (period_id) REFERENCES period(period_id)
          );");


say "Created tables.";

# INSERTING INTO STATIC DATATABLES
my @branches = qw(Ingen Mikro Mini Junior Trop Klan Leder);

foreach my $branch (@branches) {
  $dbh->do("INSERT INTO branch (name) VALUES ('$branch')");
}

my @periods = ({pickup => 1, cars => 1, name => 'Indsamling 26. april 13.00 til 15.00'},
	       {pickup => 1, cars => 1, name => 'Indsamling 26. april 15.00 til 17.30'},
	       {pickup => 1, cars => 1, name => 'Indsamling 27. april 10.00 til 13.00'},
	       {pickup => 1, cars => 1, name => 'Indsamling 27. april 13.00 til 16.00'},
               {pickup => 0, cars => 0, name => 'Morgenholdet Loppemarkedsdagen 10. maj 7.00 til 10.00'},
               {pickup => 0, cars => 0, name => 'Salgsholdet Loppemarkedsdagen 10. maj 10.00 til 15.00'},
               {pickup => 0, cars => 1, name => 'Oprydningsholdet Loppemarkedsdagen 10. maj 15.00 til 18.00'},
              );

foreach my $period (@periods) {
  $dbh->do("INSERT INTO period (name,cars,pickup) 
            VALUES (?, ?, ?)", 
            undef, $period->{name}, $period->{cars}, $period->{pickup},
          );
}

say "Inserted into static datatables.";

# INSERTING TESTDATA IF $TESTDATA
exit(0) unless $testdata;

my @firstnames = qw( Tom Per Hans Nina Lone Kim Ole Jens Line Frede Asbjørn);
my @lastnames = qw( Hansen Jensen Persson Larsen Nielsen Ingersen Petersen Aagård);
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
my @roads = qw(Gammelmosevej Hanehøj Jordbærvænget Hjaltesvej Sæbjørnsvej Buddingehovedgade Jernbanevej);
my @postalcodes = qw(2880 2860 2900 9000);
my @cities = qw(Bagsværd Lyngby Søborg Andeby Hareskov);
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
