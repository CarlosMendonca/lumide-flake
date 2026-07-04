# Turn an upstream version string into a valid (and readable) Nix attr suffix.
#   "0.14.0"   -> "0_14_0"
#   "0.13.0-1" -> "0_13_0_1"
version: builtins.replaceStrings [ "." "-" "+" ] [ "_" "_" "_" ] version
