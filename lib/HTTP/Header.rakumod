unit class HTTP::Header;

use HTTP::Header::Field;

# headers container
has @.fields;

our grammar HTTP::Header::Grammar {
    token TOP {
        [ <message-header> \r?\n ]*
    }

    token message-header {
        $<field-name>=[ <-[:]>+ ] ':' <field-value>
    }

    token field-value {
        [ <!before \h> ( ['W/' | 'w/'] )? <quot>?
            $<field-content>=[ <-[\r\n"]>+ ]  || \h+ ]*
        <quot>?
    }
    token quot {
        <['"]>
    }
}

our class HTTP::Header::Actions {
    method message-header($/) {
      my $value = $<field-value>.made;
      my $k = ~$<field-name>;
      my @v = $value<content>.Array;

      @v[0] = $value<prefix> ~ @v[0] if $value<prefix> && $k.lc ne 'etag';
      if $k && @v -> $v {
        if $*OBJ.field($k) {
          $*OBJ.push-field: |($k => $v);
        } else {
          $*OBJ.field: |($k => $v);
        }
      }
    }

    method field-value($/) {
        make {
          prefix => $0,
          content => $<field-content> ??
            $<field-content>.Str.split(',')>>.trim !! Nil
        }
    }
}

# we want to pass arguments like this: .new(a => 1, b => 2 ...)
method new(*%fields) {
    my @fields = %fields.sort(*.key).map: {
        HTTP::Header::Field.new(:name(.key), :values(.value.list));
    }

    self.bless(:@fields)
}

proto method field(|) {*}

# set fields
multi method field(*%fields) {
    for %fields.sort(*.key) -> (:key($k), :value($v)) {
        my $f = HTTP::Header::Field.new(:name($k), :values($v.list));
        if @.fields.first({ .name.lc eq $k.lc }) {
            @.fields[@.fields.first({ .name.lc eq $k.lc }, :k)] = $f;
        }
        else {
            @.fields.push: $f;
        }
    }
}

# get fields
multi method field($field) {
    my $field-lc := $field.lc;
    @.fields.first(*.name.lc eq $field-lc)
}

# initialize fields
method init-field(*%fields) {
    for %fields.sort(*.key) -> (:key($k), :value($v)) {
        my $k-lc := $k.lc;
        @.fields.push:
          HTTP::Header::Field.new(:name($k), :values($v.list))
          unless @.fields.first(*.name.lc eq $k-lc);
    }
}

# add value to existing fields
method push-field(*%fields) {
    for %fields.sort(*.key) -> (:key($k), :value($v)) {
        my $k-lc := $k.lc;
        @.fields.first(*.name.lc eq $k-lc).values.append: $v.list;
    }
}

# remove a field
method remove-field(Str $field) {
    my $field-lc := $field.lc;
    @.fields.splice($_, 1)
      with @.fields.first(*.name.lc eq $field-lc, :k);
}

# get fields names
method header-field-names() {
    @.fields.map(*.name)
}

# return the headers as name -> value hash
method hash(--> Hash:D) {
    @.fields.map({ $_.name => $_.values }).Hash
}

# remove all fields
method clear() {
    @.fields = ();
}

# get header as string
method Str($eol = "\n") {
    @.fields.map({ "$_.name(): {self.field($_.name)}$eol" }).join
}

method parse($raw) {
    my $*OBJ = self;
    HTTP::Header::Grammar.parse($raw, :actions(HTTP::Header::Actions));
}

# vim: expandtab shiftwidth=4
