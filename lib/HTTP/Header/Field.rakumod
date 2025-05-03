unit class HTTP::Header::Field;

has $.name;
has @.values;

method Str { @.values.join(', ') }

# vim: expandtab shiftwidth=4
