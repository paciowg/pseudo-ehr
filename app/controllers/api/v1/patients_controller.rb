################################################################################
#
# Patients Controller
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

module Api
  module V1

    class PatientsController < ActionController::API

      respond_to :json

      before_action :setup_fhir_client

      def index
        reply = @fhir_client.search(FHIR::Patient)
        fhir_bundle = reply.resource

        render json: fhir_bundle.to_json, status: reply.code
      end

      #-------------------------------------------------------------------------

      def show
        reply = @fhir_client.read(FHIR::Patient, params[:id])
        fhir_patient = reply.resource

        render json: fhir_patient.to_json, status: reply.code
      end

      #-------------------------------------------------------------------------
      private
      #-------------------------------------------------------------------------

      def setup_fhir_client
        @fhir_client ||= FHIR::Client.new(HEALTH_DATA_MGR)
      end

    end

  end
end
