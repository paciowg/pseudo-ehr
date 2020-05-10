################################################################################
#
# Welcome Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class WelcomeController < ApplicationController

  def index
    # Start from scratch
    SessionHandler.disconnect(session.id) if session.id
  end

end


