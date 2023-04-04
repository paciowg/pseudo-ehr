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

  def restart
    redirect_to root_path, notice: "Restarted Pseudo EHR."
  end

end


