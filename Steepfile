# frozen_string_literal: true

# `sig` holds this gem's own signatures, which the gem ships. `sig-deps`
# holds stubs for the parts of Steep, Parser, and RBS that lib/ calls and
# that their own signatures do not give.
target :lib do
  signature "sig", "sig-deps"
  check "lib"
  library "pathname", "json", "optparse", "prism", "rbs"

  # Steep reports a node it cannot type as UnexpectedError and skips the
  # rest of that node. The default level is hint, so the check would pass.
  configure_code_diagnostics do |hash|
    hash[Steep::Diagnostic::Ruby::UnexpectedError] = :error
  end
end
