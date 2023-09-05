# frozen_string_literal: true

# This provide a centralized place for shared code and behavior that needs to be available across
# all your application's models that does not inherit from ApplicationRecord.
class Resource
  include ModelHelper
end
