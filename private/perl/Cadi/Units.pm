#!/usr/bin/perl
#
use lib qw(/opt/dinfo/lib/perl);

use strict;
use utf8;
use Cadi::CadiDB;

package Cadi::Units;

my $searchkeys = {
         'id' => 'dinfo.allunits.id_unite',
       'acro' => 'dinfo.allunits.sigle',
       'name' => 'dinfo.allunits.sigle',
      'label' => 'dinfo.allunits.libelle',
       'path' => 'dinfo.allunits.hierarchie',
   'unittype' => 'dinfo.allunits.unittype',
  'typelabel' => 'dinfo.types_unites.libelle',
         'cf' => 'dinfo.allunits.cf',
};

my $selectunit = qq{
    select dinfo.allunits.id_unite    as id,
           dinfo.allunits.sigle       as sigle,
           dinfo.allunits.libelle     as label,
           dinfo.allunits.hierarchie  as path,
           dinfo.allunits.cf          as cf,
           dinfo.allunits.type        as type,
           dinfo.allunits.unittype    as unittype,
           dinfo.allunits.resp_unite  as respsciper,
           dinfo.allunits.id_parent   as parentid,
           dinfo.allunits.url         as url,
           dinfo.allunits.niveau      as level,
           dinfo.groups.gid           as gid,
           dinfo.types_unites.libelle as typelabel,
           dinfo.sciper.nom_acc       as respname,
           dinfo.sciper.prenom_acc    as respfirstname
      from dinfo.allunits
      join dinfo.groups
              on dinfo.groups.id = dinfo.allunits.id_unite
      left outer join dinfo.types_unites
              on dinfo.types_unites.code = dinfo.allunits.unittype
      left outer join dinfo.sciper
              on dinfo.sciper.sciper = dinfo.allunits.resp_unite
};

sub new { # Exported
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
      caller => undef,
          db => undef,
      errmsg => undef,
     errcode => undef,
        utf8 => 1,
    language => 'fr',
       debug => 0,
     verbose => 0,
       trace => 0,
    tracesql => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  warn "new Cadi::Units ()\n" if $self->{verbose};
  $self->{messages} = initmessages ($self);
  $self->{dinfodb} = new Cadi::CadiDB (
    dbname => 'dinfo',
     trace => $self->{trace},
      utf8 => $self->{utf8},
  );
  bless $self, $class;
}

sub getUnit {
  getUnitInfos (@_);
}

sub getUnitInfos {
  my ($self, $id) = @_;
  my @units = $self->getUnitsInfos ($id);
  return unless @units;
  return $units [0];
}

sub getUnitsInfos {
  my ($self, @ids) = @_;
  return unless @ids;
  my $dinfodb = $self->{dinfodb};
  return $self->error ("getUnitsInfos1 : $DBI::errstr") unless $dinfodb;
  my $field = ($ids [0] =~ /^\d+$/)
    ? 'dinfo.allunits.id_unite'
    : 'dinfo.allunits.sigle'
    ;
  my  $in = join (', ', map { '?' } @ids);
  my $sql = "$selectunit where $field in ($in)";
  my $sth = $dinfodb->prepare ($sql);
  return $self->error ("getUnitsInfos2 : $dinfodb->{errmsg}")  unless $sth;
  my $rv = $dinfodb->execute ($sth, @ids);
  return $self->error ("getUnitsInfos3 : $dinfodb->{errmsg}")  unless $rv;
  my (@units, $units);
  while (my $unit = $sth->fetchrow_hashref) {
    $unit->{display} = $unit->{sigle};
    $unit->{resp}    = {
           id => $unit->{respsciper},
      display => "$unit->{respfirstname} $unit->{respname}",
    };
    delete $unit->{respsciper};
    delete $unit->{respfirstname};
    delete $unit->{respname};
    push (@units, $unit);
    $units->{$unit->{id}} = $unit;
  }
  return $self->error ("getUnitsInfos4 : no matching unit for @ids") unless @units;
  $sth->finish;
  #
  # Children ids.
  #
  foreach my $unit (@units) {
    my $sql = "select id_unite from allunits where id_parent = ?";
    my $sth = $dinfodb->prepare ($sql);
    return $self->error ("getUnitsInfos21 : $dinfodb->{errmsg}")  unless $sth;
    my $rv = $dinfodb->execute ($sth, $unit->{id});
    return $self->error ("getUnitsInfos31 : $dinfodb->{errmsg}")  unless $rv;
    my @childrenids;
    while (my ($childid) = $sth->fetchrow) {
      push (@childrenids, $childid);
    }
    $unit->{childrenids} = \@childrenids;
  }
  $sth->finish;
  #
  # Accreds
  #
  my     $in = join (', ', map { '?' } @units);
  my @values = map { $_->{id} } @units;
  my $sql = qq{
    select dinfo.sciper.sciper     as sciper,
           dinfo.sciper.nom_acc    as name,
           dinfo.sciper.prenom_acc as firstname,
           accred.accreds.unitid  as unitid
      from accred.accreds
      join dinfo.sciper on accred.accreds.persid = dinfo.sciper.sciper
     where accred.accreds.unitid in ($in)
       and accred.accreds.debval <= now()
       and (accred.accreds.finval is null or accred.accreds.finval > now())
  };
  #$sql =~ s/\s+/ /g; warn "sql = $sql\n";
  my $sth = $dinfodb->prepare ($sql);
  return $self->error ("getUnitsInfos5 : $dinfodb->{errmsg}")  unless $sth;
  my $rv = $dinfodb->execute ($sth, @values);
  return $self->error ("getUnitsInfos6 : $dinfodb->{errmsg}")  unless $rv;
  while (my $accred = $sth->fetchrow_hashref) {
    my $unitid = $accred->{unitid};
    my   $unit = $units->{$unitid};
    push (@{$unit->{accreds}}, {
       accred => {
              id => "$unit->{id}:$accred->{sciper}",
          sciper => $accred->{sciper},
         display => "$accred->{name} $accred->{firstname}",
       },
    });
  }
  $sth->finish;
  return $self->error ("No results for @ids")  unless @units;
  return @units;
}

sub listAllUnits {
  my ($self, $rootid) = @_;
  my $dinfodb = $self->{dinfodb};
  my $units;
  my $sql = qq{
    select a.*, g.gid from dinfo.allunits a
    left outer join dinfo.groups g on (g.id = a.id_unite)
  };
  if ($rootid) {
    $sql .= " where $rootid in (level1, level2, level3, level4)";
  }
  my $sth = $dinfodb->query ($sql);
  return $self->error ("listAllUnits : $dinfodb->{errmsg}") unless $sth;
  while (my $unit = $sth->fetchrow_hashref) {
    $units->{$unit->{id_unite}} = $unit;
  }
  $sth->finish;
  foreach my $unitid (keys %$units) {
    my     $unit = $units->{$unitid};
    my $parentid = $unit->{id_parent};

    my $ancestorid = $parentid;
    while ($ancestorid) {
      push (@{$units->{$unitid}->{ancestors}}, $ancestorid);
      $ancestorid = $units->{$ancestorid}->{id_parent};
    }

    push (@{$units->{$parentid}->{children}}, $unitid);
  }

  return $units;
}

sub searchUnits {
  my ($self, $key, $value) = @_;
  return $self->matchUnits ({ $key => $value });
}

sub matchUnits {
  my ($self, $filter) = @_;
  my $dinfodb = $self->{dinfodb};
  return $self->error ("matchUnits : $DBI::errstr") unless $dinfodb;

  my (@wheres, @values);
  foreach my $key (keys %$filter) {
    next unless $searchkeys->{$key};
    my $value = $filter->{$key};
    my $op = ($value =~ /%/) ? 'like' : '=';
    push (@wheres, "$searchkeys->{$key} $op ?");
    push (@values, $filter->{$key});
  }
  my $sql = @wheres
    ? "$selectunit where " . join (' and ', @wheres)
    : $selectunit
    ;
  my $sth = $dinfodb->prepare ($sql);
  return $self->error ("matchUnits : $dinfodb->{errmsg}")  unless $sth;
  my $rv = $dinfodb->execute ($sth, @values);
  return $self->error ("matchUnits : $dinfodb->{errmsg}")  unless $rv;
  my $unittypes = $self->listUnitTypes ();
  return unless $unittypes;
  my $units;
  while (my $unit = $sth->fetchrow_hashref) {
    my $unitid = $unit->{id};
    $units->{$unitid} = {
          type => 'unit',
            id => $unit->{id},
         sigle => $unit->{sigle},
          path => $unit->{path},
      typename => $unittypes->{$unit->{unittype}},
       display => $unit->{label},
            cf => $unit->{cf},
           url => $unit->{url},
    };
  }
  $sth->finish;
  my @units = sort { $a->{display} cmp $b->{display} } values %$units;
  return \@units;
}

sub getHierarchy {
  my ($self, $unit) = @_;
  my @parents = ();
  my $dinfodb = $self->{dinfodb};
  return $self->error ("getHierarchy : $DBI::errstr") unless $dinfodb;
  while ($unit) {
    my $table = ($unit >= 50000)
      ? (($unit >= 60000) ? 'unites_alumni' : 'unites_etud')
      : 'unites'
      ;
    my $sql = qq{
      select sigle, id_parent
       from dinfo.$table
      where dinfo.$table.id_unite = ?
    };
    my $sth = $dinfodb->prepare ($sql);
    return $self->error ("getHierarchy : $dinfodb->{errmsg}")  unless $sth;
    my $rv = $dinfodb->execute ($sth, $unit);
    return $self->error ("getHierarchy : $dinfodb->{errmsg}")  unless $rv;
    my ($sigle, $parent) = $sth->fetchrow;
    $sth->finish;
    push (@parents, { id => $unit, sigle => $sigle, });
    $unit = $parent;
  }
  return @parents;
}

sub getAncestorIds {
  my ($self, $unitid) = @_;
  my $dinfodb = $self->{dinfodb};
  my $sql = qq{
    select level4, level3, level2, level1
      from dinfo.allunits
     where id_unite = ?
  };
  my $sth = $dinfodb->prepare ($sql) || last;
  my  $rv = $dinfodb->execute ($sth, $unitid) || last;
  my ($level4, $level3, $level2, $level1) = $sth->fetchrow ();
  return ($level4, $level3, $level2, $level1);
}

sub listUnitTypes {
  my $self = shift;
  my $dinfodb = $self->{dinfodb};
  return $self->error ("listUnitTypes : $DBI::errstr") unless $dinfodb;
  my $sql = qq{
    select code,
           libelle
      from types_unites
  };
  my $sth = $dinfodb->prepare ($sql);
  return $self->error ("listUnitTypes : $dinfodb->{errmsg}") unless $sth;
  my $rv = $dinfodb->execute ($sth);
  return $self->error ("listUnitTypes : $dinfodb->{errmsg}") unless $rv;
  my $unittypes;
  while (my ($code, $libelle) = $sth->fetchrow_array) {
    $unittypes->{$code} = $libelle;
  }
  $sth->finish;
  return $unittypes;
}

sub getmanyunits {
  my ($self, @ids) = @_;
  my $dinfodb = $self->{dinfodb};
  return $self->error ("getUnitInfos : $dinfodb->{errmsg}") unless $dinfodb;

  my  $in = join (', ', map { '?' } @ids);
  my $sql = qq{
    select dinfo.allunits.id_unite   as id,
           dinfo.allunits.sigle      as sigle,
           dinfo.allunits.libelle    as label,
           dinfo.allunits.hierarchie as path,
           dinfo.allunits.libelle    as type
      from dinfo.allunits
     where dinfo.allunits.id_unite in ($in)
  };
  #$sql =~ s/\s+/ /g; warn "sql = $sql, ids = @ids\n";
  my $sth = $dinfodb->prepare ($sql);
  return $self->error ("getManyUnitsInfos : $dinfodb->{errmsg}") unless $sth;
  my $rv = $dinfodb->execute ($sth, @ids);
  return $self->error ("getManyUnitsInfos1 : $dinfodb->{errmsg}") unless $rv;
  my $units;
  while (my $unit = $sth->fetchrow_hashref) {
    $unit->{display} = $unit->{sigle};
    $units->{$unit->{id_unite}} = $unit;
  }
  $sth->finish;
  return $units;
}

sub initmessages {
  my $self = shift;
  return {
    nosciper => {
      fr => "No sciper",
      en => "Pas de sciper",
    },
    invalidsciper => {
      fr => "Invalid sciper : %s",
      en => "Numéro sciper invalide : %s",
    },
    nocaller => {
      fr => "Pas d'appelant",
      en => "No caller",
    },
  };
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub error {
  my ($self, $msg) = @_;
  $self->{errmsg} = "Units::$msg";
  warn "$self->{errmsg}\n";
  return;
}

sub error1 {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $self->{messages}->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
  warn "$self->{errmsg}\n";
  return;
}


1;
