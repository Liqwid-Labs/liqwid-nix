{ pkgs, lib, ... }:
{
  # Flatten 2-deep nested attrmap to one where attr keys are zipped together with the passed function.
  flat2With = f: xs: builtins.listToAttrs (lib.flatten (lib.mapAttrsToList (ns: attrs: lib.mapAttrsToList (checkName: value: { name = f ns checkName; inherit value; }) attrs) xs));


  # Combine multiple checks in an attrset together.
  combineChecks = name: allChecks:
    pkgs.runCommand name { allChecks = builtins.attrValues allChecks; }
      ''
        echo $allChecks
        touch $out
      '';

  shellCheck = name: source: arguments: exec:
    pkgs.runCommand name arguments
      ''
        export LC_CTYPE=C.UTF-8
        export LC_ALL=C.UTF-8
        export LANG=C.UTF-8
        cd ${source}
        ${exec}
        mkdir $out
      '';
}
