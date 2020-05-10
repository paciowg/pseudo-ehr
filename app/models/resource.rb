# frozen_string_literal: true

################################################################################
#
# Abstract Resource Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Resource

  # Adds a warning message to the specified resource

  def warning(message)
    @warnings = [] unless @warnings.present?
    @warnings.append(message)
  end

  #-----------------------------------------------------------------------------

  # Adds an error message to the specified resource

  def error(message)
    @errors = [] unless @errors.present?
    @errors.append(message)
  end

end
