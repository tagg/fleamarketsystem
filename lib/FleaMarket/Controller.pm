package FleaMarket::Controller;
use Mojo::Base 'Mojolicious::Controller';

use FleaMarket::Model;
use Data::Dumper;

my $mode = "SANDBOX MODE";

sub index {
    my $self = shift;
    $self->render(debug => '', mode => $mode);
}

sub hjaelperdata {
    my $self = shift;
    
    my $helperdata = getHelpers();
    my $cake = getCakes();

    $self->render(helperdata => $helperdata, debug => '', mode => $mode, cakedata => $cake);
}

sub hjaelper {
    my $self = shift;

    my $staticdata->{branches} = getBranches();
    $staticdata->{periods} = getPeriods();

    $self->stash(userdata => {}, staticdata => $staticdata, errordata => {}, status => {}, debug => '', mode => $mode);

    $self->render();
}

sub hjaelperpost {
    my $self = shift;
    my $status;

    my $userdata = gethelperdata($self->req);
    my $errordata = validatehelperdata($userdata);
    $errordata = validatehelperdata($userdata) unless $errordata;
    $errordata = submithelperdata($userdata) unless $errordata;

    if ($errordata) {
	$status->{error} = $errordata->{error} || 'Der skete en fejl under tilmeldingen';
    } else {
        $status->{success} = 'Din tilmelding er modtaget. Vi ses! :)';
	$userdata = {};
    }

    my $staticdata->{branches} = getBranches();
    $staticdata->{periods} = getPeriods();
    $self->stash(userdata => $userdata, staticdata => $staticdata, errordata => $errordata, status => $status, debug => '', mode => $mode);
    $self->render(template => 'controller/hjaelper');
}

sub submithelperdata {
    return addHelper(shift);
}

sub validatehelperdata {
    my $userdata = shift;
    my $errordata;

    #validate data

    $errordata->{firstname} = "Skriv venligst dit fornavn." if ($userdata->{firstname} eq '');
    $errordata->{lastname} = "Skriv venligst dit efternavn." if ($userdata->{lastname} eq '');

    my $periods = 0;

    foreach my $period (@{$userdata->{periods}}) {
	next unless defined $period;
	$periods++;
        my $id = $period->{id};
	unless ($period->{adults} =~ m/^(\d*|)$/ && $period->{scouts} =~ m/^(\d*|)$/) {
             $errordata->{periods}[$id] = 'Indtast kun tal i felterne';
	} 
	elsif ((($period->{adults} ? $period->{adults} : 0) + $period->{scouts}) == 0) {
             $errordata->{periods}[$id] = 'Hvis ingen deltager, så fjern fluebenet.';
        }
    }
    
    $errordata->{error} = 'Du behøver ikke tilmelde dig, hvis du ikke kan deltage.' unless $periods;

    return $errordata;
}

sub gethelperdata {
    my $request = shift;

    my $hash = _postToHashref($request);

    my $userdata = {};
    $userdata->{firstname} = $hash->{firstname} || '';
    $userdata->{lastname} = $hash->{lastname} || '';
    $userdata->{branch_id} = $hash->{branch_id} || 0;
    $userdata->{cake} = $hash->{cake} || '';

    foreach my $period (@{getPeriods()}) {
        my $id = $period->{id};
        if ($hash->{'check' . $id}) {
            $userdata->{periods}[$id]{id}      = $id;
            $userdata->{periods}[$id]{adults}  = $hash->{$id . 'adults'}  || 0;
            $userdata->{periods}[$id]{scouts}  = $hash->{$id . 'scouts'}  || 0;
            $userdata->{periods}[$id]{car}     = $hash->{$id . 'car'}     ? 1 : '';
            $userdata->{periods}[$id]{trailer} = $hash->{$id . 'trailer'} ? 1 : '';
            $userdata->{periods}[$id]{pull}    = $hash->{$id . 'pull'}    ? 1 : '';
        }
    }
    
    return $userdata;
}


sub _postToHashref {
    my $request = shift;
    return {@{${$request->params}{params}}};
}

1;
