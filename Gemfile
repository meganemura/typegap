# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "minitest", "6.0.6"

# hegeltest needs Ruby 3.4; CI runs the property tests there only.
group :hegel do
  gem "hegeltest", "0.4.1"
end

group :types do
  gem "rbs-inline", "0.14.0", require: false
end
