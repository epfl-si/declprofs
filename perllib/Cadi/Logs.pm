#!/usr/bin/perl
#
package Cadi::Logs;

use strict;
use Cadi::CadiDB;

my $actions = {
         creategroup => {
                id => 10,
             label => "Add a group",
           },

         removegroup => {
                id => 11,
             label => "Remove a group",
           },

         modifygroup => {
                id => 12,
             label => "Modify a group",
           },

     addgroupmembers => {
                id => 13,
             label => "Add a group member",
           },

  removegroupmembers => {
                id => 14,
             label => "Remove a group member",
           },

       addgroupadmin => {
                id => 15,
             label => "Add a group admin",
           },

    removegroupadmin => {
                id => 15,
             label => "Remove a group admin",
           },

   excludegroupmember => {
                id => 16,
             label => "Exclude a group member",
           },

  unexcludegroupmember => {
                id => 17,
             label => "Unexclude a group member",
           },

          addservice => {
                id => 20,
             label => "Add a service",
           },

       removeservice => {
                id => 21,
             label => "Remove a service",
           },

       modifyservice => {
                id => 22,
             label => "Modify a service",
           },

            addguest => {
                id => 30,
             label => "Add a guest",
           },

         removeguest => {
                id => 31,
             label => "Remove a guest",
           },

         modifyguest => {
                id => 32,
             label => "Modify a guest",
           },

       unknownaction => {
                id => 0,
             label => "Unknown action",
           },
};
my $bycode;

sub new { # Exported
  my $class = shift;
  my  %args = @_;
  my $self = {
     caller => undef,
         db => undef,
     errmsg => undef,
    errcode => undef,
       fake => 0,
      debug => 0,
    verbose => 0,
      trace => 0,
  };
  foreach my $arg (keys %args) {
    $self->{$arg} = $args {$arg};
  }
  $bycode = { map { $actions->{$_}->{id}, $actions->{$_} } keys %$actions };
  $self->{db} = new Cadi::CadiDB (
    dbname => 'cadi',
      utf8 => 1,
     trace => $self->{trace},
  );
  bless $self, $class;
}

sub log {
  my ($self, $author, $opcode, $objid, $new, $old) = @_;
  my $action = $actions->{$opcode};
  return $self->error ('Unknown action : $opcode') unless $action;
  my $mod = {};
  if ($old) { # update an object.
    $old = { old => $old } unless (ref $old eq 'HASH');
    foreach my $key (keys %$old) {
      next unless exists $new->{$key};
      my $oldval = flatten ($old->{$key});
      my $newval = flatten ($new->{$key});
      next if ($newval eq $oldval);
      $oldval =~ s/,/\,/g;
      $newval =~ s/,/\,/g;
      $mod->{$key} = $oldval . '->' . $newval;
    }
  } elsif ($new) {
    $new = { new => $new } unless (ref $new eq 'HASH');
    foreach my $key (keys %$new) {
      next unless $new->{$key};
      my $newval = flatten ($new->{$key});
      $newval =~ s/,/\,/g;
      $mod->{$key} = $newval;
    }
  }
  my $sql = qq{
    insert into cadi.logs
       set   date = now(),
           caller = ?,
           opcode = ?,
           author = ?,
            objid = ?,
           detail = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return unless $sth;
  my @details = map { "$_:$mod->{$_}" } keys %$mod;
  my $details = join (',', @details);
  my $rv = $self->{db}->execute ($sth,
    $self->{caller}, $action->{id}, $author, $objid, $details);
  return unless $rv;
  return 1;
}

sub flatten {
  my $object = shift;
  if (ref $object eq 'ARRAY') {
    my @objs;
    foreach my $obj (@$object) {
      push (@objs, flatten ($obj));
    }
    return join ('+', @objs);
  }
  if (ref $object eq 'HASH') {
    return $object->{id} || $object->{sciper} || $object->{name};
  }
  return $object;
}

sub getlogs {
  my ($self, $what) = @_;
  my (@args, @wheres);
  if ($what->{subject}) {
    push (@args,   $what->{subject});
    push (@wheres, 'author = ?');
  }
  if ($what->{object}) {
    push (@args,   $what->{object}, "%$what->{object}%");
    push (@wheres, '(objid = ? or detail like ?)');
  }
  if ($what->{when}) {
    my $now = time;
    my $froms = {
        oneday => 1,
       oneweek => 7,
      onemonth => 31,
       oneyear => 365,
    };
    my $from = $froms->{$what->{when}} || 10000;
    push (@args,   $from);
    push (@wheres, 'to_days(date) > to_days(now()) - ?');
  }
  if ($what->{opcode}) {
    push (@args,   $what->{opcode});
    push (@wheres, 'opcode = ?');
  }
  my $where = @wheres ? 'where ' . join (' and ', @wheres) : '';
  my $sql = qq{
    select *
      from cadi.logs
    $where
     order by date desc
  };
  my $sth = $self->{db}->prepare ($sql);
  return unless $sth;
  my $rv = $self->{db}->execute ($sth, @args);
  return unless $rv;

  my @logs;
  while (my $log = $sth->fetchrow_hashref) {
    push (@logs, $log);
  }
  $sth->finish;
  return @logs;
}

sub getaction {
  my ($self, $opcode) = @_;
  return ($opcode =~ /^\d+$/)
    ? $bycode->{$opcode}
    : $actions->{$opcode}
    ;
}

sub getactions {
  my $self = shift;
  return $actions;
}

sub error {
  my ($self, $msg, @args) = @_;
  foreach (@args) {
    $msg =~ s/%s/$_/;
  }
  warn scalar localtime, ' : ', $msg, "\n";
  $self->{errmsg}  = $msg;
  return;
}

my $createtable = qq{
  create table cadi.logs (
      date datetime,
    caller varchar(32),
    opcode smallint,
    author char(6),
     objid varchar(16),
    detail text,
    index (date, caller, opcode, author, objid, detail(128))
  );
};

sub flattenfull {
  my $object = shift;
  if (ref $object eq 'ARRAY') {
    my @objs;
    foreach my $obj (@$object) {
      push (@objs, flatten ($obj));
    }
    return '[' . join (',', @objs) . ']';
  }
  if (ref $object eq 'HASH') {
    my @objs;
    foreach my $key (keys %$object) {
      push (@objs, $key . ':' . flatten ($object->{$key}));
    }
    return '{' . join (',', @objs) . '}';
  }
  return $object;
}

sub expand {
  my $string = shift;
  warn "expand: string = $string\n";
  
  if ($string =~ /^\[(.*)\]$/) {
    my $content = $1;
    my @subs = split (',', $content);
    my $objects;
    foreach my $sub (@subs) {
      push (@$objects, expand ($sub));
    }
    return $objects;
  }
  if ($string =~ /^\{(.*)\}$/) {
    my $content = $1;
    my @subs = split (',', $content);
    my $objects;
    foreach my $sub (@subs) {
      my ($key, $val) = split (':', $sub);
      $objects->{$key} = expand ($val);
    }
    return $objects;
  }
  return $string;
}


1;
