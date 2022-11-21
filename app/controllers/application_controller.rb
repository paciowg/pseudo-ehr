################################################################################
#
# Application Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class ApplicationController < ActionController::Base

  
  protected

    # set @patient_server by session or by history or redirect to root
    def set_patient_server
      @patient_server = PatientServer.find(session[:patient_server_id]) if session[:patient_server_id]
      @patient_server ||= PatientServer.last
	  redirect_to(root_url, {alert: "Please set a server to query."}) and return unless @patient_server
    end

  
end
