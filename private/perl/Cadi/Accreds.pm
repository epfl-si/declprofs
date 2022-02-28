#!/usr/bin/perl
#
use lib qw(/opt/dinfo/lib/perl);

use strict;
use Cadi::CadiDB;
use Cadi::Units;
use Accred::AccredDB;
use Accred::Units;
use Accred::Roles;
use Accred::RolesAdmin;
use Accred::Rights;
use Accred::RightsAdmin;
use Accred::Properties;
use Accred::Workflows;

package Cadi::Accreds;

our $errmsg;

sub new { # Exported
  my $class = shift;
  my  $args = (@_ == 1) ? shift : { @_ } ;
  my  $self = {
        caller => undef,
        errmsg => undef,
       errcode => undef,
      language => 'en',
          utf8 => 1,
         debug => 0,
       verbose => 0,
         trace => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  $self->{accreddb} = new Accred::AccredDB ($self);
  $self->{cadidb}   = new Cadi::CadiDB (
    dbname => 'accred',
     trace => 1,
      utf8 => $self->{utf8},
  );
  $self->{Units}    = new Accred::Units ($self);
  bless $self, $class;
}

sub getStatus {
  my ($self, $id) = @_;
  return $self->{accreddb}->getObject (
    type => 'statuses',
      id => $id,
  );
}

sub getClass {
  my ($self, $id) = @_;
  return $self->{accreddb}->getObject (
    type => 'classes', 
      id => $id,
  );
}

sub getPosition {
  my ($self, $id) = @_;
  return $self->{accreddb}->getObject (
    type => 'positions',
      id => $id,
  );
}

sub getAttrLabel {
  my ($self, $type, $id) = @_;
  my $table;
  if ($type eq 'position') {
    $table = 'positions';
  }
  elsif ($type eq 'status') {
    $table = 'statuses'
  }
  elsif ($type eq 'classe') {
    $table = 'classes'
  } else {
    return;
  }
  my @labels = $self->{accreddb}->dbselect (
    table => $table,
     what => [ 'labelfr' ],
    where => { id => $id, },
  );
  return $self->error ("No such object $table:$id") unless @labels;
  my $label = shift @labels;
  return $label;
}

sub getAccredInfos {
  getAccred (@_);
}

sub getAccred {
  my ($self, $persid, $unitid, %opt) = @_;
  my $unit = $self->{Units}->getUnit ($unitid);
  unless ($unit) {
    $self->{errmsg} = "getAccred : Unknown unit : $unitid.";
    return;
  }
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => {
      persid => $persid,
      unitid => $unitid,
    },
  );
  return $self->error ("No such accred $persid:$unitid") unless @accreds;
  unless (@accreds) {
    $self->{errmsg} = "getAccred : Unknown accred : ($persid, $unitid)";
    return;
  }
  my $accred = shift @accreds;
  $accred->{unite}    = $accred->{unitid};
  $accred->{sciper}   = $accred->{persid};
  $accred->{statut}   = $accred->{statusid};
  $accred->{classe}   = $accred->{classid};
  $accred->{fonction} = $accred->{posid};
  return $accred;
}

sub getAccreds {
  my ($self, $persid, %opt) = @_;
  my @unitids = $self->getUnitsOfAccreds ($persid);
  my @accreds;
  foreach my $unitid (@unitids) {
    my $accred = $self->getAccred ($persid, $unitid);
    push (@accreds, $accred) if $accred;
  }
  return @accreds;
}

sub getAllAccreds {
  my $self = shift;
  my $sql = qq{
    select * from accred.accreds
     where (debval is NULL or debval <= now())
       and (finval is NULL or finval  > now())
  };
  my $cadidb = $self->{cadidb};
  my $sth = $cadidb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getAllAccreds : $cadidb->{errmsg}";
    return;
  }
  my $rv = $cadidb->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "getAllAccreds : $cadidb->{errmsg}";
    return;
  }
  my @accreds;
  while (my $accred = $sth->fetchrow_hashref) {
    push (@accreds, $accred);
  }
  return @accreds;
}

sub getAllAccredsSolved {
  my ($self, $type, $val) = @_;
  my $persid = $val if $type eq 'persid';
  my $unitid = $val if $type eq 'unitid';
  my $sql = qq{
    select accreds.*,
        dinfo.sciper.nom_acc,      dinfo.sciper.nom_usuel, 
        dinfo.sciper.prenom_acc,   dinfo.sciper.prenom_usuel, dinfo.sciper.sexe,
        dinfo.allunits.sigle,      dinfo.allunits.libelle, 
        dinfo.allunits.hierarchie,
        dinfo.groups.gid,
        dinfo.annu.local as room,
        dinfo.annu.telephone1,
        dinfo.annu.telephone2,
        dinfo.adrspost.adresse as address,
        dinfo.adrspost.ordre as address_ordre,
        statuses.name     as statusname,
        statuses.labelfr  as statuslabelfr,
        statuses.labelen  as statuslabelen,
        classes.name      as classname,
        classes.labelfr   as classlabelfr,
        classes.labelen   as classlabelen,
        positions.labelfr as poslabelfr,
        positions.labelen as poslabelen,
        positions.labelxx as poslabelxx
      from accreds
      join dinfo.sciper   on     dinfo.sciper.sciper = accreds.persid
      join dinfo.allunits on dinfo.allunits.id_unite = accreds.unitid
      join dinfo.groups   on         dinfo.groups.id = accreds.unitid
      join statuses       on             statuses.id = accreds.statusid
      left outer join classes        on        classes.id = accreds.classid
      left outer join positions      on      positions.id = accreds.posid
      left outer join dinfo.annu     on       dinfo.annu.sciper = accreds.persid
                                    and        dinfo.annu.unite = accreds.unitid
      left outer join dinfo.adrspost on   dinfo.adrspost.sciper = accreds.persid
                                    and   dinfo.adrspost.unite = accreds.unitid
  };
  my ($debcond, $fincond, @dateconds);
  $debcond = "(accreds.debval is NULL or accreds.debval <= now())";
  $fincond = "(accreds.finval is NULL or accreds.finval  > now())";
  $sql .= qq{
     where $debcond
       and $fincond
  };
  my @args;
  if ($persid) {
    $sql .= ' and accreds.persid = ?';
    @args = $persid;
  }
  if ($unitid) {
    $sql .= ' and ? IN (dinfo.allunits.level1, dinfo.allunits.level2, dinfo.allunits.level3, dinfo.allunits.level4)';
    @args = $unitid;
  }
  my $cadidb = $self->{cadidb};
  my $sth = $cadidb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getAccreds : $cadidb->{errmsg}";
    return;
  }
  my $rv = $cadidb->execute ($sth, @args, @dateconds);
  unless ($rv) {
    $self->{errmsg} = "getAccreds : $cadidb->{errmsg}";
    return;
  }
  my $PropsAdmin = new Accred::PropsAdmin ();
  my @allprops = $PropsAdmin->listProperties ();
  my $allprops = { map { $_->{id} => $_ } @allprops };
  my $Properties = new Accred::Properties ();
  my @accreds;
  while (my $accred = $sth->fetchrow_hashref) {
    my $properties = $Properties->getAccredProperties ($accred);
    foreach my $propid (keys %$properties) {
      my $defined = $properties->{$propid}->{defined};
      my $allowed = $properties->{$propid}->{allowed};
      my $granted = $properties->{$propid}->{granted};
      my $value;
      if    ($defined)          { $value = $defined; }
      elsif ($allowed =~ /^n:/) { $value = 'n'; }
      elsif ($granted =~ /^y:/) { $value = 'y'; }
      else                      { $value = 'n'; }
      my $propname = $allprops->{$propid}->{name};
      $accred->{properties}->{$propid}   = $value eq 'y' ? 1 : 0;
      $accred->{properties}->{$propname} = $accred->{properties}->{$propid};
    }
    $accred->{person} = {
         id => $accred->{persid},
       name => $accred->{nom_usuel}    || $accred->{nom_acc},
      fname => $accred->{prenom_usuel} || $accred->{prenom_acc},
       sexe => $accred->{sexe},
    };
    delete $accred->{nom_usuel};
    delete $accred->{nom_acc};
    delete $accred->{prenom_usuel};
    delete $accred->{prenom_acc};
    delete $accred->{sexe};

    $accred->{unit} = {
         id => $accred->{unitid},
      sigle => $accred->{sigle},
      label => $accred->{libelle},
       path => $accred->{hierarchie},
        gid => $accred->{gid},
    };
    delete $accred->{sigle};
    delete $accred->{libelle};
    delete $accred->{hierarchie};
    delete $accred->{gid};
    
    $accred->{status} = {
           id => $accred->{statusid},
         name => $accred->{statusname},
      labelfr => $accred->{statuslabelfr},
      labelen => $accred->{statuslabelen},
    };
    delete $accred->{statusname};
    delete $accred->{statuslabelfr};
    delete $accred->{statuslabelen};
    
    $accred->{class} = {
           id => $accred->{classid},
         name => $accred->{classname},
      labelfr => $accred->{classlabelfr},
      labelen => $accred->{classlabelen},
    };
    delete $accred->{classname};
    delete $accred->{classlabelfr};
    delete $accred->{classlabelen};
    
     $accred->{position} = {
           id => $accred->{posid},
         name => $accred->{posname},
      labelfr => $accred->{poslabelfr},
      labelen => $accred->{poslabelen},
      labelxx => $accred->{poslabelxx},
    };
    delete $accred->{posname};
    delete $accred->{poslabelfr};
    delete $accred->{poslabelen};
    # FIXME: delete $accred->{poslabelxx}; ?
    
    $accred->{annu} = {
         room => $accred->{room},
       phones => [ $accred->{telephone1}, $accred->{telephone2}, ],
    };
    delete $accred->{room};
    delete $accred->{telephone1};
    delete $accred->{telephone2};

    $accred->{address} = {
      address => $accred->{address},
        ordre => $accred->{address_ordre},
    };
    delete $accred->{address_ordre};

    push (@accreds, $accred);
  }
  return @accreds;
}

sub getAccredsOrders {
  my ($self, $persid) = @_;
  my $accreddb = $self->{accreddb};
  my @orders = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ 'unitid', 'ordre' ],
    where => {
      persid => $persid,
    },
  );
  return $self->error ("getAccredsOrders: $accreddb->{errmsg}") unless @orders;
  my $orders = { map { $_->{unitid}, $_->{ordre} } @orders };
  return $orders;
}

sub getUnitsOfAccreds {
  my ($self, $persid) = @_;
  my $accreddb = $self->{accreddb};
  my @unitids = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => 'unitid',
    where => {
      persid => $persid,
    },
    order => 'ordre',
  );
  return $self->error ("getUnitsOfAccreds: $accreddb->{errmsg}") unless @unitids;
  return @unitids;
}

sub getAllUnitsOfPerson {
  my ($self, $persid) = @_;
  my $accreddb = $self->{accreddb};
  my @unitids = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => 'unitid',
    where => {
      persid => $persid,
    },
    order => 'ordre',
  );
  return unless @unitids;
  my $allunitids;
  my $Units = new Cadi::Units ();
  foreach my $unitid (@unitids) {
    my @ancestorids = $Units->getAncestorIds ($unitid);
    map { $allunitids->{$_} = 1; } @ancestorids;
  }
  return keys %$allunitids;
}

sub getAccredsOfUnit {
  my ($self, $unitid, %opts) = @_;
  my $cadidb = $self->{cadidb};
  if ($unitid && $unitid !~ /^\d+$/) {
    my $sql = qq{select * from dinfo.allunits where sigle = ?};
    my $sth = $cadidb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "getAccredsOfUnit : $cadidb->{errmsg}";
      return;
    }
    my $rv = $cadidb->execute ($sth, $unitid);
    unless ($rv) {
      $self->{errmsg} = "getAccredsOfUnit : $cadidb->{errmsg}";
      return;
    }
    my $unit = $sth->fetchrow_hashref;
    return unless $unit;
    $unitid = $unit->{id_unite};
  }
  my $solvscip = '';
  if ($opts {solvescipers}) {
    $solvscip = 'join dinfo.sciper on dinfo.sciper.sciper = accreds.persid';
  }
  my $sql = qq{
    select *
      from accreds
      join dinfo.allunits on accreds.unitid = dinfo.allunits.id_unite
      $solvscip
     where (accreds.debval is NULL or accreds.debval <= now())
       and (accreds.finval is NULL or accreds.finval  > now())
  };
  $sql .= " and ($unitid in (level1, level2, level3, level4))" if $unitid;
  my $sth = $cadidb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getAccredsOfUnit : $cadidb->{errmsg}";
    return;
  }
  my $rv = $cadidb->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "getAccredsOfUnit : $cadidb->{errmsg}";
    return;
  }
  my @accreds;
  while (my $accred = $sth->fetchrow_hashref) {
    $accred->{person} = {
         id => $accred->{persid},
       name => $accred->{nom_usuel}    || $accred->{nom_acc},
      fname => $accred->{prenom_usuel} || $accred->{prenom_acc},
       sexe => $accred->{sexe},
    };
    delete $accred->{nom_usuel};
    delete $accred->{nom_acc};
    delete $accred->{prenom_usuel};
    delete $accred->{prenom_acc};
    delete$accred->{sexe};

    $accred->{unit} = {
         id => $accred->{unitid},
      sigle => $accred->{sigle},
      label => $accred->{libelle},
       path => $accred->{hierarchie},
    };
    delete $accred->{sigle};
    delete $accred->{libelle};
    push (@accreds, $accred);
  }
  return @accreds;
}

sub getPersonsInUnit {
  my ($self, $unitid) = @_;
  my $cadidb = $self->{cadidb};
  my $sigle;
  if ($unitid =~ /^\d+$/) {
    my $sql = qq{
      select sigle
        from dinfo.unites
      where id_unite = ?
    };
    my $sth = $cadidb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "getPersonsInUnit : $cadidb->{errmsg}";
      return;
    }
    my $rv = $cadidb->execute ($sth, $unitid);
    unless ($rv) {
      $self->{errmsg} = "getPersonsInUnit : $cadidb->{errmsg}";
      return;
    }
    ($sigle) = $sth->fetchrow;
    return unless $sigle;
  } else {
    $sigle = $unitid;
  }
  my $sql = qq{
    select persid
      from accreds
      join dinfo.unites on accreds.unitid = dinfo.unites.id_unite
     where (accreds.debval is NULL or accreds.debval <= now())
       and (accreds.finval is NULL or accreds.finval  > now())
       and   (dinfo.unites.hierarchie like '$sigle %'
           or dinfo.unites.hierarchie like '% $sigle %'
           or dinfo.unites.hierarchie like '%$sigle')
  };
  my $sth = $cadidb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getPersonsInUnit : $cadidb->{errmsg}";
    return;
  }
  my $rv = $cadidb->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "getPersonsInUnit : $cadidb->{errmsg}";
    return;
  }
  my $persids = $sth->fetchall_arrayref ([0]);
  my @persids = map { $_->[0] } @$persids;
  $sth->finish;
  return @persids;
}

sub getRight {
  my ($self, $nameorid) = @_;
  return new Accred::RightsAdmin ($self)->getRight ($nameorid);
}

sub getRole {
  my ($self, $nameorid) = @_;
  return new Accred::RolesAdmin ($self)->getRole ($nameorid);
}

sub getAdminRights {
  my ($self,$roleid ) = @_;
  return new Accred::RolesAdmin ($self)->getRightAdminByRole ($roleid);
}

sub listPersonsWithRole {
  my ($self, $unitid, $rolenameorid) = @_;
  my $role = new Accred::RolesAdmin ($self)->getRole ($rolenameorid);
  return unless $role;
  my $roleid = $role->{id};
  my  $Roles = new Accred::Roles ($self);
  my $rup = $Roles->getRoles (
    roleid => $roleid,
    unitid => $unitid,
  );
  my $persids = $rup->{$roleid}->{$unitid};
  my @results;
  foreach my $persid (keys %$persids) {
    push (@results, $persid) if ($persids->{$persid} =~ /^y/);
  }
  return @results;
}

sub getUnitsRights {
  getUnitsWhereHasRight (@_);
}

sub getUnitsWhereHasRight {
  my ($self, $persid, $rightid) = @_;
  my $Rights = new Accred::Rights ($self);
  my $rup = $Rights->getRights (
      rightid => $rightid,
       persid => $persid,
     noexpand => 1,
  );
  my @unitids = keys %{$rup->{$rightid}};
  my $values;
  map { $values->{$_} = $rup->{$rightid}->{$_}->{$persid} } @unitids;
  return $values;
}

sub getAllUnitsWhereHasRight {
  my ($self, $persid, $rightid) = @_;
  my $Rights = new Accred::Rights ($self);
  my $rup = $Rights->getRights (
      rightid => $rightid,
       persid => $persid,
  );
  my @unitids = keys %{$rup->{$rightid}};
  my $values;
  map { $values->{$_} = $rup->{$rightid}->{$_}->{$persid} } @unitids;
  return $values;
}

sub getUnitsWhereHasRole {
  my ($self, $persid, $rolenameorid) = @_;
  my $roleid = $rolenameorid;
  if ($rolenameorid !~ /^\d+$/) {
    my $role = new Accred::RolesAdmin ($self)->getRole ($rolenameorid);
    return unless $role;
    $roleid = $role->{id};
  }
  my $Roles = new Accred::Roles ($self);
  my $Units = new Accred::Units ($self);
  my $rup = $Roles->getRoles (
      roleid => $roleid,
      persid => $persid,
  );
  my @unitids = keys %{$rup->{$roleid}};
  my   $units = $Units->getUnits (\@unitids);
  my   @units = map { $units->{$_}->{level} == 4 ? $units->{$_} : () } keys %$units;
  map { $_->{id_unite} = $_->{id}   } @units;
  map { $_->{sigle}    = $_->{name} } @units;
  return @units;
}

sub getAllUnitsWhereHasRole {
  my ($self, $persid, $rolenameorid) = @_;
  my $roleid = $rolenameorid;
  if ($rolenameorid !~ /^\d+$/) {
    my $role = new Accred::RolesAdmin ($self)->getRole ($rolenameorid);
    return unless $role;
    $roleid = $role->{id};
  }
  my $Roles = new Accred::Roles ($self);
  my $Units = new Accred::Units ($self);
  my $rup = $Roles->getRoles (
    roleid => $roleid,
    persid => $persid,
  );
  my @unitids = keys %{$rup->{$roleid}};
  my   $units = $Units->getUnits (\@unitids);
  my   @units = values %$units;
  map { $_->{id_unite} = $_->{id}   } @units;
  map { $_->{sigle}    = $_->{name} } @units;
  return @units;
}

sub hasProperty {
  my ($self, $accred, $propid) = @_;
  my $Properties = new Accred::Properties ($self);
  return $Properties->hasProperty ($accred, $propid);
}

sub getAccredProperty {
  my ($self, $accred, $propid) = @_;
  my $Properties = new Accred::Properties ($self);
  my $accprop = $Properties->getAccredProperty ($accred, $propid);
  my $defined = $accprop->{defined};
  my $allowed = $accprop->{allowed};
  my $granted = $accprop->{granted};
  my $value;
  if    ($defined)          { $value = $defined; }
  elsif ($allowed =~ /^n:/) { $value = 'n'; }
  elsif ($granted =~ /^y:/) { $value = 'y'; }
  else                      { $value = 'n'; }
  return ($value eq 'y') ? 1 : 0;
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub error {
  my ($self, @msgs) = @_;
  $errmsg = join (',', @msgs);
  $self->{errmsg} = $errmsg if $self;
  return;
}



1;
