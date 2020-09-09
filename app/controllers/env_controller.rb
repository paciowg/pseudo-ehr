################################################################################
#
# Env Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class EnvController < ApplicationController

  def index
    @client_id = ENV['CLIENT_ID']
    @scope = ENV['SCOPE']
    @redirect_uri = ENV['REDIRECT_URI']
  end

end
